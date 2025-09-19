//
//  HabitHiveApp.swift
//  HabitHive
//
//  Created by Venkatesh Thallam on 9/14/25.
//

import SwiftUI

@main
struct HabitHiveApp: App {
    @StateObject private var apiClient = APIClient.shared
    
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
            if apiClient.isAuthenticated {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
    }
}
