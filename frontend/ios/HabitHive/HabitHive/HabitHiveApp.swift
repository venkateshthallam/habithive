//
//  HabitHiveApp.swift
//  HabitHive
//
//  Created by Venkatesh Thallam on 9/14/25.
//

import SwiftUI
import UserNotifications

@main
struct HabitHiveApp: App {
    @StateObject private var apiClient = FastAPIClient.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showSplash = true

    init() {
        // Improve tab bar contrast and visibility
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().unselectedItemTintColor = UIColor(named: "BeeBlack") ?? UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 0.65)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if apiClient.isAuthenticated {
                        if !apiClient.hasLoadedProfile {
                            SplashScreenView()
                        } else if apiClient.requiresProfileSetup {
                            ProfileSetupFlowView()
                        } else {
                            MainTabView()
                        }
                    } else {
                        WelcomeView()
                    }
                }
                .task(id: apiClient.isAuthenticated) {
                    await apiClient.bootstrapIfNeeded()
                }

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }

                // Set notification delegate
                UNUserNotificationCenter.current().delegate = notificationManager

                // Check if we need to register for push notifications
                Task {
                    await setupNotifications()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh token when app comes to foreground
                Task {
                    await apiClient.refreshTokenIfNeeded()
                }
            }
        }
    }

    private func setupNotifications() async {
        // Check current permission status
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        print("🔔 Notification permission status: \(settings.authorizationStatus.rawValue)")

        if settings.authorizationStatus == .authorized {
            // Permission already granted, make sure we're registered
            print("🔔 Permission already granted, registering for remote notifications...")
            await notificationManager.registerForPushNotifications()
        }

        // Re-register device if we have a token but haven't registered with backend
        await notificationManager.reregisterIfNeeded()
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("🚀 App launched")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ APNs registration successful!")
        Task { @MainActor in
            NotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
        Task { @MainActor in
            NotificationManager.shared.handleRegistrationError(error)
        }
    }
}
