//
//  NotificationManager.swift
//  HabitHive
//
//  Created by Claude on 10/1/25.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var deviceToken: String?
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var isRegistered: Bool = false

    private let deviceTokenKey = "notificationManager.deviceToken"

    override init() {
        super.init()
        // Load stored device token
        deviceToken = UserDefaults.standard.string(forKey: deviceTokenKey)

        // Check current permission status
        Task {
            await checkPermissionStatus()
        }
    }

    /// Check the current notification permission status
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Request notification permission and register for remote notifications
    func requestPermissionAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            await MainActor.run {
                permissionStatus = granted ? .authorized : .denied
            }

            if granted {
                await registerForPushNotifications()
            }

            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Register for APNs push notifications
    func registerForPushNotifications() async {
        #if targetEnvironment(simulator)
        print("⚠️ Push notifications not supported on simulator")
        return
        #endif

        await UIApplication.shared.registerForRemoteNotifications()
    }

    /// Handle the device token received from APNs
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        // Store the token
        UserDefaults.standard.set(tokenString, forKey: deviceTokenKey)

        print("📱 APNs Device Token: \(tokenString)")

        // Register with backend
        Task {
            await registerDeviceWithBackend(token: tokenString)
        }
    }

    /// Handle registration error
    func handleRegistrationError(_ error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        isRegistered = false
    }

    /// Register the device token with the backend
    private func registerDeviceWithBackend(token: String) async {
        guard FastAPIClient.shared.isAuthenticated else {
            print("⚠️ User not authenticated, deferring device registration")
            return
        }

        do {
            #if DEBUG
            let environment = "dev"
            #else
            let environment = "prod"
            #endif

            try await FastAPIClient.shared.registerDevice(
                apnsToken: token,
                environment: environment
            )

            await MainActor.run {
                isRegistered = true
            }

            print("✅ Device successfully registered with backend")
        } catch {
            print("❌ Failed to register device with backend: \(error.localizedDescription)")
            isRegistered = false
        }
    }

    /// Re-register device if we have a token but haven't registered yet
    func reregisterIfNeeded() async {
        guard let token = deviceToken, !isRegistered else { return }
        await registerDeviceWithBackend(token: token)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap based on type
        if let notificationType = userInfo["type"] as? String {
            print("📬 User tapped notification of type: \(notificationType)")

            // You can handle different notification types here
            // For example, navigate to a specific habit detail view
        }
    }
}
