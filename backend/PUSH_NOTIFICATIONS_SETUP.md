# 🔔 Push Notifications Setup Guide

This guide covers setting up push notifications for HabitHive using OneSignal and Supabase pg_cron.

## Architecture

```
Supabase pg_cron (every minute)
    ↓
FastAPI Backend (/api/notifications/send-reminders)
    ↓
OneSignal API
    ↓
iOS Devices (APNs)
```

---

## 📋 Manual Steps Required

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

This installs the OneSignal SDK and other dependencies.

---

### 2. OneSignal Setup

#### A. Create OneSignal Account
1. Go to https://onesignal.com
2. Sign up for a free account
3. Create a new app for HabitHive

#### B. Configure iOS Platform
1. In OneSignal dashboard, go to **Settings** → **Platforms**
2. Click **Apple iOS (APNs)**
3. Upload your APNs Auth Key (.p8 file) or APNs Certificate
   - **Recommended**: Use APNs Auth Key (easier, doesn't expire yearly)
   - Get from Apple Developer Console: https://developer.apple.com/account/resources/authkeys/list
4. Enter your Team ID and Key ID
5. Save the configuration

#### C. Get OneSignal Credentials
1. Go to **Settings** → **Keys & IDs**
2. Copy the following:
   - **OneSignal App ID**
   - **REST API Key**

---

### 3. Update Environment Variables

Add the following to your `backend/.env` file:

```env
# OneSignal Configuration
ONESIGNAL_APP_ID=your_onesignal_app_id_here
ONESIGNAL_REST_API_KEY=your_rest_api_key_here

# Internal Service Key (generate a secure random string)
INTERNAL_SERVICE_KEY=your_secure_service_key_here

# Existing vars (keep these)
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_role_key
```

**Generate a secure service key:**
```bash
# macOS/Linux
openssl rand -base64 32

# Or use any password generator
```

---

### 4. Run Database Migrations

Run these migrations **in order** on Supabase:

#### A. Add notification_logs table
```bash
# In Supabase SQL Editor, run:
backend/data/migrations/2025-10-01-add-notification-logs.sql
```

#### B. Add OneSignal player_id to device_tokens
```bash
# In Supabase SQL Editor, run:
backend/data/migrations/2025-10-01-add-onesignal-player-id.sql
```

#### C. Add helper functions
```bash
# In Supabase SQL Editor, run:
backend/data/migrations/2025-10-01-add-reminder-helpers.sql
```

#### D. Setup pg_cron job (IMPORTANT - read below first!)
**Before running this migration**, you need to:
1. Deploy your FastAPI backend to a publicly accessible URL
2. Note your backend URL (e.g., `https://api.habithive.com` or `https://your-app.railway.app`)

Then:
1. Open `backend/data/migrations/2025-10-01-add-pg-cron-job.sql`
2. Replace `YOUR_BACKEND_API_URL` with your actual backend URL
3. Replace `YOUR_SERVICE_KEY_HERE` with the `INTERNAL_SERVICE_KEY` from your `.env`
4. Run the migration in Supabase SQL Editor

**Note**: The pg_cron extension requires superuser privileges. On Supabase, this is automatically available.

---

### 5. Deploy Backend

Make sure your FastAPI backend is deployed and accessible at the URL you configured in the pg_cron job.

**Test the health endpoint:**
```bash
curl https://your-backend-url.com/health
```

Expected response:
```json
{"status": "healthy", "service": "habithive-api"}
```

---

### 6. Update iOS App (Frontend)

You'll need to update your iOS app to register devices with the new OneSignal integration:

1. The device registration endpoint (`POST /api/devices/register`) now returns:
```json
{
  "success": true,
  "id": "uuid",
  "onesignal_player_id": "player-id-from-onesignal"
}
```

2. No changes needed to the request payload - it's backward compatible.

---

### 7. Testing

#### A. Test Device Registration
```bash
# Register a device (replace with your token and auth)
curl -X POST https://your-backend-url.com/api/devices/register \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "apns_token": "your_device_apns_token",
    "environment": "dev",
    "device_model": "iPhone 15 Pro",
    "app_version": "1.0.0"
  }'
```

#### B. Test Notification Sending
```bash
# Send a test notification to yourself
curl -X POST https://your-backend-url.com/api/notifications/test \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

You should receive a push notification on your device!

#### C. Test the Reminder Endpoint (Simulating pg_cron)
```bash
# Manually trigger the reminder sending (requires service key)
curl -X POST https://your-backend-url.com/api/notifications/send-reminders \
  -H "X-Service-Key: YOUR_SERVICE_KEY"
```

Expected response:
```json
{
  "total_habits": 5,
  "notifications_sent": 5,
  "notifications_failed": 0,
  "errors": []
}
```

---

### 8. Create Test Habits with Reminders

To test the full flow:

1. In your app, create a habit
2. Enable reminders for the habit
3. Set `reminder_time` to the current time + 2 minutes (in the database or via app)
4. Make sure `reminder_enabled = true`
5. Wait for the next minute to tick over
6. You should receive a push notification!

**SQL to set reminder time:**
```sql
UPDATE habits
SET reminder_enabled = true,
    reminder_time = '14:30:00'  -- Set to current time + 2 minutes in your timezone
WHERE id = 'your-habit-id';
```

---

### 9. View Notification Logs

```bash
# Get your notification history
curl -X GET https://your-backend-url.com/api/notifications/logs \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🔍 Monitoring & Debugging

### Check pg_cron Job Status

In Supabase SQL Editor:

```sql
-- View scheduled jobs
SELECT * FROM cron.job;

-- View recent job runs
SELECT *
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'habit-reminders-job')
ORDER BY start_time DESC
LIMIT 10;
```

### Check OneSignal Dashboard
1. Go to OneSignal dashboard
2. Click **Messages** → **Sent Messages**
3. View delivery stats and any errors

### Backend Logs
Monitor your FastAPI backend logs for errors:
- Look for `send_reminders` function logs
- Check for OneSignal API errors
- Verify database queries are working

---

## 🐛 Troubleshooting

### No notifications being sent?

1. **Check pg_cron is running:**
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'habit-reminders-job';
   ```

2. **Check backend is accessible:**
   ```bash
   curl https://your-backend-url.com/health
   ```

3. **Verify environment variables are set:**
   - `ONESIGNAL_APP_ID`
   - `ONESIGNAL_REST_API_KEY`
   - `INTERNAL_SERVICE_KEY`

4. **Check habits are eligible:**
   ```sql
   SELECT * FROM get_habits_needing_reminders();
   ```

5. **Check notification logs:**
   ```sql
   SELECT * FROM notification_logs ORDER BY sent_at DESC LIMIT 10;
   ```

### Notifications sent but not received?

1. Check device has notifications enabled
2. Verify APNs certificate/key in OneSignal is correct
3. Check OneSignal dashboard for delivery status
4. Ensure app is configured with correct OneSignal App ID

### pg_cron not calling the API?

1. Check the URL is publicly accessible
2. Verify the service key matches
3. Check Supabase logs for HTTP errors
4. Ensure `net` extension is available (it should be on Supabase)

---

## 📊 Database Schema

### notification_logs table
- `id`: UUID primary key
- `user_id`: References auth.users
- `habit_id`: References habits
- `notification_type`: 'habit_reminder' | 'streak_milestone' | 'test'
- `sent_at`: Timestamp when sent
- `sent_date`: Date in user's timezone
- `onesignal_id`: OneSignal notification ID
- `status`: 'sent' | 'failed' | 'delivered'
- `error_message`: Error details if failed
- `metadata`: JSONB with additional data

### device_tokens table (updated)
- Existing fields remain
- **New field**: `onesignal_player_id` - OneSignal player identifier

---

## 🎯 Notification Logic

Reminders are sent when **ALL** of these conditions are met:

1. ✅ Habit has `reminder_enabled = true`
2. ✅ Habit has `reminder_time` set
3. ✅ Habit is `is_active = true` and `is_archived = false`
4. ✅ User has `notification_habits = true` in profile
5. ✅ Current time matches `reminder_time` (within 1 minute window)
6. ✅ Habit is scheduled for today (based on `schedule_daily` or `schedule_weekmask`)
7. ✅ No notification sent today for this habit
8. ✅ User has at least one registered device with OneSignal player ID

---

## 🚀 Production Checklist

- [ ] OneSignal app created and configured
- [ ] APNs certificate/key uploaded to OneSignal
- [ ] Environment variables set in production
- [ ] All migrations run on production database
- [ ] Backend deployed and accessible
- [ ] pg_cron job configured with correct URL and service key
- [ ] Test notification sent successfully
- [ ] Monitoring set up for notification failures
- [ ] iOS app updated to register devices

---

## 📝 Notes

- Notifications are sent **every minute** based on pg_cron schedule
- Each user/habit gets **one reminder per day maximum**
- Timezone-aware: respects user's `timezone` setting in profile
- Deduplication: checks `notification_logs` to avoid duplicate sends
- Batching: OneSignal handles multiple player IDs efficiently
- Logging: All notification attempts are logged for debugging

---

## 🔗 Useful Links

- [OneSignal Docs](https://documentation.onesignal.com/)
- [Supabase pg_cron Docs](https://supabase.com/docs/guides/database/extensions/pg_cron)
- [APNs Setup Guide](https://developer.apple.com/documentation/usernotifications)

---

**Questions or Issues?** Check the backend logs and OneSignal dashboard for debugging info.
