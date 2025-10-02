# 📱 iOS Push Notifications Setup Guide

All the code is implemented! Here's what you need to do to enable push notifications:

## ✅ What Was Implemented

### 1. **NotificationManager.swift** (NEW)
- Handles APNs device token registration
- Calls backend `/api/devices/register` endpoint
- Manages notification permissions
- Stores device token locally

### 2. **FastAPIClient.swift** (UPDATED)
- Added `registerDevice()` method
- Sends APNs token to backend with OneSignal integration

### 3. **HabitHiveApp.swift** (UPDATED)
- Added `AppDelegate` to receive device token callbacks
- Added `NotificationManager` as StateObject
- Sets UNUserNotificationCenter delegate
- Re-registers device on app launch if needed

### 4. **ProfileSetupFlowView.swift** (UPDATED)
- Updated notification request to use `NotificationManager`
- Automatically registers device after permission granted

### 5. **HabitHive.entitlements** (UPDATED)
- Added `aps-environment` key for push notifications

---

## 🛠️ Manual Steps Required

### Step 1: Enable Push Notifications in Xcode

1. Open the project in Xcode
2. Select the **HabitHive** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **Push Notifications**

You should see "Push Notifications" appear in the capabilities list.

---

### Step 2: Configure APNs in Apple Developer Portal

#### Option A: Using APNs Auth Key (Recommended - Easier)

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles** → **Keys**
3. Click the **+** button to create a new key
4. Check **Apple Push Notifications service (APNs)**
5. Give it a name like "HabitHive APNs Key"
6. Click **Continue**, then **Register**
7. **Download the .p8 file** (you can only download once!)
8. Note the **Key ID** and your **Team ID**

#### Option B: Using APNs Certificate (Traditional)

1. In Xcode, go to **Signing & Capabilities**
2. Note your **Bundle Identifier** (e.g., `com.habithive.app`)
3. Go to [Apple Developer Portal](https://developer.apple.com/account)
4. Navigate to **Certificates, Identifiers & Profiles** → **Identifiers**
5. Select your app identifier
6. Enable **Push Notifications**
7. Click **Configure** and create Development/Production SSL certificates
8. Download and install the certificates in Keychain Access

---

### Step 3: Configure OneSignal Dashboard

1. Log in to [OneSignal Dashboard](https://app.onesignal.com)
2. Select your HabitHive app
3. Go to **Settings** → **Platforms** → **Apple iOS (APNs)**

#### If using Auth Key (Option A):
- Upload the `.p8` file you downloaded
- Enter your **Team ID** (found in Apple Developer Portal)
- Enter your **Key ID**
- Select **Sandbox (Development)** for testing

#### If using Certificate (Option B):
- Export certificates from Keychain as `.p12` files
- Upload Development certificate to OneSignal
- Upload Production certificate when ready

4. Click **Save**

---

### Step 4: Update Xcode Project Settings

1. Make sure **Automatic Signing** is enabled
2. Select your **Team** in Signing & Capabilities
3. Ensure **Bundle Identifier** matches what's in Apple Developer Portal
4. Build configuration:
   - Debug builds use `aps-environment: development`
   - Release builds will use `aps-environment: production`

---

### Step 5: Test on Real Device (Required)

⚠️ **Push notifications DO NOT work on simulator!**

1. Connect a physical iPhone/iPad
2. Select your device as the build target
3. Build and run the app (`Cmd + R`)
4. Go through onboarding
5. When prompted, **Allow notifications**
6. Check Xcode console for:
   ```
   📱 APNs Device Token: [long hex string]
   ✅ Device registered with OneSignal player ID: [uuid]
   ✅ Device successfully registered with backend
   ```

---

### Step 6: Test Sending Notifications

#### Method 1: Use the Test Endpoint (Easiest)

```bash
# Get your JWT token from the app (check Xcode console or use your login flow)
curl -X POST https://habithive-production.up.railway.app/api/notifications/test \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

You should receive a notification: "🐝 Your HabitHive notifications are working!"

#### Method 2: Create a Test Habit with Reminder

1. Create a habit in the app
2. Enable reminders
3. Set reminder time to **current time + 2 minutes**
4. Wait for the next minute to tick over
5. You should receive: "Don't forget to log [habit] to keep the streak!"

#### Method 3: Send from OneSignal Dashboard

1. Go to OneSignal → **Messages** → **New Push**
2. Select your device (it should appear if registered)
3. Write a test message
4. Send
5. Check if you receive it

---

## 🔍 Troubleshooting

### "No device token received"
- Make sure you're running on a **real device**, not simulator
- Check that Push Notifications capability is enabled in Xcode
- Verify your provisioning profile includes push notifications
- Try deleting the app and reinstalling

### "Device registered but no OneSignal player ID"
- Check OneSignal credentials in backend `.env`:
  - `ONESIGNAL_APP_ID`
  - `ONESIGNAL_REST_API_KEY`
- Check backend logs for errors
- Verify APNs certificate/key is uploaded to OneSignal

### "User not authenticated, deferring device registration"
- This is normal if the app tries to register before login
- The device will register automatically after successful login
- Check that `NotificationManager.reregisterIfNeeded()` is called

### "Failed to register device with backend"
- Check network connectivity
- Verify backend is deployed and accessible
- Check that user is authenticated (has valid JWT token)
- Look for error details in Xcode console

---

## 📊 How It Works

```
User enables notifications in onboarding
    ↓
iOS requests permission
    ↓
User grants permission
    ↓
NotificationManager.requestPermissionAndRegister()
    ↓
UIApplication.registerForRemoteNotifications()
    ↓
AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken()
    ↓
NotificationManager.handleDeviceToken()
    ↓
FastAPIClient.registerDevice()
    ↓
Backend /api/devices/register
    ↓
OneSignal.create_device()
    ↓
Supabase stores: apns_token + onesignal_player_id
    ↓
✅ Device registered!
```

---

## 🎯 Testing Checklist

- [ ] Push Notifications capability enabled in Xcode
- [ ] APNs certificate/key configured in Apple Developer Portal
- [ ] APNs uploaded to OneSignal dashboard
- [ ] Backend deployed with OneSignal credentials
- [ ] Tested on real device (not simulator)
- [ ] Device token received in console logs
- [ ] OneSignal player ID received in console logs
- [ ] Test notification sent and received successfully
- [ ] Habit reminder created and received at scheduled time

---

## 📝 Console Logs to Look For

**Success:**
```
📱 APNs Device Token: abc123def456...
✅ Device registered with OneSignal player ID: 12345678-1234-1234-1234-123456789abc
✅ Device successfully registered with backend
```

**Warnings (Normal):**
```
⚠️ Push notifications not supported on simulator  // Expected when running on simulator
⚠️ User not authenticated, deferring device registration  // Will retry after login
```

**Errors (Need to Fix):**
```
❌ Failed to register for remote notifications: [error]
❌ Failed to register device with backend: [error]
```

---

## 🚀 Production Deployment

When ready for production:

1. Change `aps-environment` in entitlements to `production`:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

2. Upload production APNs certificate to OneSignal

3. Archive and upload to App Store Connect

4. Test with TestFlight build before release

---

**Need Help?** Check the backend logs and OneSignal dashboard for detailed error messages.
