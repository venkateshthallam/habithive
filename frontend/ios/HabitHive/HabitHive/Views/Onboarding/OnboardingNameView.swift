import SwiftUI

struct OnboardingNameView: View {
    @State private var name: String = ""
    @StateObject private var themeManager = ThemeManager.shared
    var onContinue: (String) -> Void

    var body: some View {
        ZStack {
            // Background gradient like WelcomeView
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                Spacer()

                // Title with better styling
                VStack(spacing: HiveSpacing.md) {
                    Text("What's your name?")
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                // Input field with better styling
                TextField("Enter your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(HiveTypography.headline)
                    .padding(HiveSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, HiveSpacing.lg)

                Spacer()

                // Continue Button with enhanced styling
                Button(action: {
                    onContinue(name.trimmingCharacters(in: .whitespacesAndNewlines))
                }) {
                    HStack {
                        Text("Continue")
                            .font(HiveTypography.headline)
                            .foregroundColor(.white)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.md)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
    }
}
