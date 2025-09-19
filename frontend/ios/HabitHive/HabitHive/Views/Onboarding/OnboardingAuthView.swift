import SwiftUI

struct OnboardingAuthView: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Background gradient like WelcomeView
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                Spacer()

                // Title and description
                VStack(spacing: HiveSpacing.md) {
                    Text("Almost There!")
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Continue with your phone number. We'll send a one-time code to verify your account.")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HiveSpacing.lg)
                }

                Spacer()

                // Phone Auth Component
                PhoneAuthView()
                    .padding(.horizontal, HiveSpacing.lg)

                Spacer()
            }
        }
    }
}

