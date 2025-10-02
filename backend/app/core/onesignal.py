"""
OneSignal Push Notification Service
Handles sending push notifications via OneSignal API
"""

from typing import List, Dict, Any, Optional
import httpx
from app.core.config import settings


class OneSignalClient:
    """Client for interacting with OneSignal API"""

    def __init__(self):
        self.app_id = settings.ONESIGNAL_APP_ID
        self.rest_api_key = settings.ONESIGNAL_REST_API_KEY
        self.base_url = "https://onesignal.com/api/v1"

    def _get_headers(self) -> Dict[str, str]:
        """Get headers for OneSignal API requests"""
        return {
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Basic {self.rest_api_key}"
        }

    async def send_notification(
        self,
        player_ids: List[str],
        heading: str,
        message: str,
        data: Optional[Dict[str, Any]] = None,
        subtitle: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send a push notification to specific player IDs

        Args:
            player_ids: List of OneSignal player IDs
            heading: Notification title
            message: Notification body/content
            data: Optional additional data to include
            subtitle: Optional subtitle for iOS notifications

        Returns:
            OneSignal API response containing notification ID and recipient count
        """
        if not self.app_id or not self.rest_api_key:
            raise ValueError("OneSignal credentials not configured")

        if not player_ids:
            raise ValueError("No player IDs provided")

        payload = {
            "app_id": self.app_id,
            "include_player_ids": player_ids,
            "headings": {"en": heading},
            "contents": {"en": message},
        }

        if subtitle:
            payload["subtitle"] = {"en": subtitle}

        if data:
            payload["data"] = data

        # iOS-specific settings for better UX
        payload["ios_badgeType"] = "Increase"
        payload["ios_badgeCount"] = 1
        payload["ios_sound"] = "default"

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/notifications",
                headers=self._get_headers(),
                json=payload,
                timeout=30.0
            )
            response.raise_for_status()
            return response.json()

    async def send_habit_reminder(
        self,
        player_ids: List[str],
        habit_name: str,
        habit_emoji: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send a habit reminder notification

        Args:
            player_ids: List of OneSignal player IDs
            habit_name: Name of the habit
            habit_emoji: Optional emoji for the habit

        Returns:
            OneSignal API response
        """
        emoji_prefix = f"{habit_emoji} " if habit_emoji else ""
        heading = "Habit Reminder"
        message = f"Don't forget to log {emoji_prefix}{habit_name} to keep the streak!"

        return await self.send_notification(
            player_ids=player_ids,
            heading=heading,
            message=message,
            data={
                "type": "habit_reminder",
                "habit_name": habit_name
            }
        )

    async def create_device(
        self,
        device_token: str,
        device_type: int = 0  # 0 = iOS, 1 = Android
    ) -> Dict[str, Any]:
        """
        Register a device with OneSignal

        Args:
            device_token: APNs or FCM device token
            device_type: 0 for iOS, 1 for Android

        Returns:
            OneSignal response with player_id
        """
        payload = {
            "app_id": self.app_id,
            "device_type": device_type,
            "identifier": device_token
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/players",
                headers=self._get_headers(),
                json=payload,
                timeout=30.0
            )
            response.raise_for_status()
            return response.json()


# Singleton instance
onesignal_client = OneSignalClient()
