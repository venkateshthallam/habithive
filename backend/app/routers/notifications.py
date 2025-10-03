"""
Notifications Router
Handles push notification sending and management
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import Dict, Any, List
from pydantic import BaseModel
from datetime import datetime
from app.core.auth import get_current_user, verify_service_key
from app.core.supabase import get_supabase_admin
from app.core.onesignal import onesignal_client
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


class NotificationResult(BaseModel):
    """Result of sending notifications"""
    total_habits: int
    notifications_sent: int
    notifications_failed: int
    errors: List[str] = []


@router.post("/send-reminders", response_model=NotificationResult)
async def send_reminders(
    _: bool = Depends(verify_service_key)
):
    """
    Send habit reminder notifications to users.
    This endpoint is called by pg_cron every minute.
    Protected by service key authentication.
    """
    supabase = get_supabase_admin()
    total_habits = 0
    sent = 0
    failed = 0
    errors = []

    try:
        # Get habits that need reminders right now
        response = supabase.rpc("get_habits_needing_reminders").execute()
        habits = response.data or []
        total_habits = len(habits)

        logger.info(f"Found {total_habits} habits needing reminders")

        for habit in habits:
            try:
                habit_id = habit["habit_id"]
                user_id = habit["user_id"]
                habit_name = habit["habit_name"]
                habit_emoji = habit.get("habit_emoji")
                player_ids = habit.get("onesignal_player_ids", [])
                user_timezone = habit.get("user_timezone", "UTC")

                if not player_ids:
                    logger.warning(f"No player IDs for habit {habit_id}, skipping")
                    failed += 1
                    errors.append(f"No devices registered for habit {habit_name}")
                    continue

                # Send notification via OneSignal
                onesignal_response = await onesignal_client.send_habit_reminder(
                    player_ids=player_ids,
                    habit_name=habit_name,
                    habit_emoji=habit_emoji
                )

                onesignal_id = onesignal_response.get("id")
                recipient_count = onesignal_response.get("recipients", 0)
                onesignal_errors = onesignal_response.get("errors") or []
                onesignal_warnings = onesignal_response.get("warnings") or []

                if onesignal_errors:
                    error_message = (
                        f"OneSignal returned errors for habit {habit_name}: {onesignal_errors}"
                    )
                    logger.warning(error_message)
                    errors.append(error_message)

                if onesignal_warnings:
                    logger.info(
                        "OneSignal warnings for habit %s: %s", habit_name, onesignal_warnings
                    )

                # Calculate sent_date in user's timezone
                sent_date_query = supabase.rpc(
                    "user_current_date",
                    {"p_user_id": user_id}
                ).execute()
                sent_date = sent_date_query.data if sent_date_query.data else datetime.utcnow().date().isoformat()

                # Log the notification
                log_entry = {
                    "user_id": user_id,
                    "habit_id": habit_id,
                    "notification_type": "habit_reminder",
                    "sent_at": datetime.utcnow().isoformat(),
                    "sent_date": sent_date,
                    "onesignal_id": onesignal_id,
                    "status": "sent" if recipient_count > 0 else "failed",
                    "metadata": {
                        "habit_name": habit_name,
                        "habit_emoji": habit_emoji,
                        "recipient_count": recipient_count,
                        "player_ids": player_ids,
                        "onesignal_errors": onesignal_errors,
                        "onesignal_warnings": onesignal_warnings
                    }
                }

                supabase.table("notification_logs").insert(log_entry).execute()

                if recipient_count > 0:
                    sent += 1
                    logger.info(f"Sent reminder for habit {habit_name} to {recipient_count} devices")
                else:
                    failed += 1
                    failure_reason = \
                        f"Failed to send notification for habit {habit_name}: 0 recipients"
                    errors.append(failure_reason)
                    logger.warning(failure_reason)

            except Exception as e:
                failed += 1
                error_msg = f"Error sending notification for habit {habit.get('habit_name', 'unknown')}: {str(e)}"
                errors.append(error_msg)
                logger.error(error_msg, exc_info=True)

                # Log the failed attempt
                try:
                    log_entry = {
                        "user_id": habit.get("user_id"),
                        "habit_id": habit.get("habit_id"),
                        "notification_type": "habit_reminder",
                        "sent_at": datetime.utcnow().isoformat(),
                        "sent_date": datetime.utcnow().date().isoformat(),
                        "status": "failed",
                        "error_message": str(e),
                        "metadata": {
                            "habit_name": habit.get("habit_name"),
                            "player_ids": habit.get("onesignal_player_ids"),
                            "onesignal_errors": onesignal_response.get("errors") if 'onesignal_response' in locals() else None,
                            "onesignal_warnings": onesignal_response.get("warnings") if 'onesignal_response' in locals() else None,
                        }
                    }
                    supabase.table("notification_logs").insert(log_entry).execute()
                except Exception as log_error:
                    logger.error(f"Failed to log notification error: {log_error}")

        return NotificationResult(
            total_habits=total_habits,
            notifications_sent=sent,
            notifications_failed=failed,
            errors=errors
        )

    except Exception as e:
        logger.error(f"Error in send_reminders: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send reminders: {str(e)}"
        )


@router.post("/test")
async def send_test_notification(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Send a test notification to the current user.
    Useful for testing push notification setup.
    """
    user_id = current_user["id"]

    try:
        supabase = get_supabase_admin()

        # Get user's OneSignal player IDs
        response = supabase.table("device_tokens")\
            .select("onesignal_player_id")\
            .eq("user_id", user_id)\
            .not_.is_("onesignal_player_id", "null")\
            .execute()

        devices = response.data or []
        player_ids = [d["onesignal_player_id"] for d in devices if d.get("onesignal_player_id")]

        if not player_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No devices registered for push notifications"
            )

        # Send test notification
        onesignal_response = await onesignal_client.send_notification(
            player_ids=player_ids,
            heading="Test Notification",
            message="🐝 Your HabitHive notifications are working!",
            data={"type": "test"}
        )

        # Log the test notification
        sent_date_query = supabase.rpc(
            "user_current_date",
            {"p_user_id": user_id}
        ).execute()
        sent_date = sent_date_query.data if sent_date_query.data else datetime.utcnow().date().isoformat()

        log_entry = {
            "user_id": user_id,
            "habit_id": None,  # No specific habit for test
            "notification_type": "test",
            "sent_at": datetime.utcnow().isoformat(),
            "sent_date": sent_date,
            "onesignal_id": onesignal_response.get("id"),
            "status": "sent",
            "metadata": {
                "recipient_count": onesignal_response.get("recipients", 0),
                "player_ids": player_ids
            }
        }

        # Note: This will fail because habit_id is NOT NULL in the schema
        # We'll need to handle this differently - either make habit_id nullable for test notifications
        # or skip logging for test notifications
        try:
            supabase.table("notification_logs").insert(log_entry).execute()
        except Exception as log_error:
            logger.warning(f"Could not log test notification (expected if habit_id is required): {log_error}")

        return {
            "success": True,
            "message": "Test notification sent",
            "recipients": onesignal_response.get("recipients", 0),
            "onesignal_id": onesignal_response.get("id")
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending test notification: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send test notification: {str(e)}"
        )


@router.get("/logs")
async def get_notification_logs(
    limit: int = 50,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get notification logs for the current user
    """
    user_id = current_user["id"]

    try:
        supabase = get_supabase_admin()

        response = supabase.table("notification_logs")\
            .select("*")\
            .eq("user_id", user_id)\
            .order("sent_at", desc=True)\
            .limit(limit)\
            .execute()

        return {
            "logs": response.data or [],
            "count": len(response.data or [])
        }

    except Exception as e:
        logger.error(f"Error fetching notification logs: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch notification logs: {str(e)}"
        )
