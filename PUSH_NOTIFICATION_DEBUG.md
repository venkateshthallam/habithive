# Push Notification Debugging Guide

## Issues Found & Solutions

### 1. ⚠️ Critical: Testing on Simulator
**Problem**: Push notifications DO NOT work on iOS Simulator. Only real devices receive APNs tokens.

**Solution**: You MUST test on a real physical device.

---

### 2. 🔍 Player ID Format Issue
**Problem**: Your notification logs show `recipient_count: 0`, indicating OneSignal is not delivering to the device.

The player ID `34fdb985-cf6b-4116-92b9-c6481aae33b3` looks like a UUID but OneSignal player IDs are typically longer alphanumeric strings like `ffffffff-ffff-ffff-ffff-ffffffffffff`.

**Possible Causes**:
- Device might not be properly registered with OneSignal
- APNs certificate might not be configured correctly in OneSignal dashboard
- APNs environment mismatch (dev vs prod)

---

## Step-by-Step Debugging Process

### Step 1: Verify OneSignal Dashboard Setup

1. **Go to OneSignal Dashboard** → Your App → Settings → Platforms → Apple iOS (APNs)

2. **Check APNs Configuration**:
   - [ ] Is the APNs certificate uploaded?
   - [ ] Is it a Production or Sandbox certificate?
   - [ ] Is the certificate expired?
   - [ ] Does the certificate match your app's bundle ID?

3. **Environment Match**:
   - Development builds need **Sandbox APNs** certificate
   - Production builds need **Production APNs** certificate
   - Currently your app sends `environment: "dev"` for DEBUG builds

---

### Step 2: Test on Real Device

**Requirements**:
- [ ] Physical iPhone (not simulator)
- [ ] Signed with valid provisioning profile
- [ ] Device has internet connection
- [ ] Device has notifications enabled in Settings

**Steps**:
1. Build and run app on real device
2. Complete onboarding (enable notifications when prompted)
3. Check Xcode console for these logs:
   ```
   📱 ===== APNs Token Received =====
   📱 Device Token: [64-character hex string]
   📱 Token Length: 64 characters
   ```
4. Look for backend registration confirmation:
   ```
   ✅ ===== Device Registration Success =====
   ✅ Device successfully registered with backend
   ```

---

### Step 3: Verify Backend Logs

After device registration, check your backend logs for:

```
📱 Device registration request from user: [user_id]
📱 APNs Token: [first 20 chars]...[last 20 chars]
📱 Environment: dev
🔄 Registering device with OneSignal...
🔄 App ID: [your OneSignal app ID]
🔄 Device Type: 0
🔄 Token: [first 20 chars]...[last 20 chars]
🔄 OneSignal response status: 200
🔄 OneSignal response: {id: "[player_id]", ...}
✅ OneSignal registration successful. Player ID: [player_id]
```

**Key Things to Check**:
- [ ] OneSignal response status is 200
- [ ] Player ID is returned in response
- [ ] Player ID is saved to database correctly

---

### Step 4: Check Database

Query your `device_tokens` table:
```sql
SELECT * FROM device_tokens
WHERE user_id = '[your_user_id]'
ORDER BY created_at DESC;
```

**Verify**:
- [ ] `apns_token` is a 64-character hex string
- [ ] `onesignal_player_id` is populated
- [ ] `environment` matches your build (dev/prod)
- [ ] `created_at` is recent

---

### Step 5: Test Notification Sending

**Option 1: Via OneSignal Dashboard**
1. Go to OneSignal → Messages → New Push
2. Click "Send to Test Device"
3. Enter the Player ID from your database
4. Send test notification
5. Should receive notification on device immediately

**Option 2: Via Your API**
```bash
curl -X POST https://your-api.com/api/notifications/test \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Logs**:
```
📤 Sending OneSignal notification...
📤 Player IDs: ["player_id_here"]
📤 Heading: Test Notification
📤 Message: 🐝 Your HabitHive notifications are working!
📤 OneSignal notification response status: 200
📤 OneSignal notification response: {
  "id": "notification_id",
  "recipients": 1,
  "errors": []
}
```

**Key Checks**:
- [ ] `recipients` should be > 0
- [ ] `errors` array should be empty
- [ ] Device receives notification within seconds

---

### Step 6: Check Notification Logs

Query your `notification_logs` table:
```sql
SELECT * FROM notification_logs
WHERE user_id = '[your_user_id]'
ORDER BY sent_at DESC
LIMIT 10;
```

**Analyze**:
- [ ] `status` should be "sent" (not "failed")
- [ ] `metadata->recipient_count` should be > 0
- [ ] `onesignal_id` should be populated
- [ ] Check for any `error_message`

---

## Common Issues & Fixes

### Issue: `recipient_count: 0`

**Causes**:
1. **Player ID doesn't exist in OneSignal**
   - Device never registered properly
   - Player ID was deleted/invalidated

2. **APNs Certificate Mismatch**
   - Using dev certificate for prod build (or vice versa)
   - Certificate expired or invalid

3. **Device Unsubscribed**
   - User uninstalled app
   - User disabled notifications in Settings

**Fix**:
- Delete device from `device_tokens` table
- Delete and reinstall app on device
- Re-enable notifications during onboarding
- Check OneSignal dashboard for player ID

---

### Issue: "Invalid identifier"

**Cause**: APNs token is malformed or invalid

**Fix**:
- Ensure token is exactly 64 hex characters
- No spaces or special characters
- Lowercase or uppercase (both work)

---

### Issue: Notifications work from OneSignal Dashboard but not from API

**Causes**:
1. Player IDs mismatch between dashboard and database
2. OneSignal credentials wrong in backend config
3. API key doesn't have permission to send notifications

**Fix**:
- Verify `ONESIGNAL_APP_ID` and `ONESIGNAL_REST_API_KEY` in backend
- Check API key permissions in OneSignal dashboard
- Compare player ID in dashboard vs database

---

## Enhanced Logging Added

### iOS App Logs
- ✅ APNs token receipt confirmation
- ✅ Token length validation
- ✅ Backend registration status
- ✅ Detailed error messages

### Backend Logs
- ✅ Device registration flow
- ✅ OneSignal API requests/responses
- ✅ Player ID creation/validation
- ✅ Notification sending details
- ✅ Recipient counts and errors

---

## Checklist Before Going Live

- [ ] Tested on real device (not simulator)
- [ ] APNs Production certificate uploaded to OneSignal
- [ ] Backend uses correct OneSignal App ID and API Key
- [ ] Test notification received successfully
- [ ] Habit reminders trigger at correct times
- [ ] Notifications appear when app is in background
- [ ] Notifications appear when app is closed
- [ ] Deep links work when tapping notifications
- [ ] Badge count increments correctly
- [ ] Sounds play correctly

---

## Next Steps

1. **Build app on REAL device** (most critical!)
2. Check Xcode console for APNs token
3. Verify device registration in backend logs
4. Check database for player ID
5. Test from OneSignal dashboard first
6. Then test from your API endpoint
7. Check notification logs for errors

---

## Support Resources

- [OneSignal iOS Setup Guide](https://documentation.onesignal.com/docs/ios-sdk-setup)
- [APNs Certificate Guide](https://documentation.onesignal.com/docs/generate-an-ios-push-certificate)
- [Testing Push Notifications](https://documentation.onesignal.com/docs/testing-push-notifications)

---

## Current Status

Based on your logs showing `recipient_count: 0`, the most likely issues are:

1. ⚠️ **Testing on simulator** (push won't work)
2. ⚠️ **APNs certificate not configured** or wrong environment
3. ⚠️ **Player ID invalid or expired**

**Immediate Action**: Test on a real device and check OneSignal dashboard APNs settings.
