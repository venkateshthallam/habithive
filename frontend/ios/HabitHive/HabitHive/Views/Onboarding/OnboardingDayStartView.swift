import SwiftUI

struct OnboardingDayStartView: View {
    @Binding var dayStartHour: Int
    @Binding var timezone: String
    @StateObject private var themeManager = ThemeManager.shared
    var onContinue: () -> Void

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            // Background gradient like WelcomeView
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                Spacer()

                // Title with better styling
                VStack(spacing: HiveSpacing.md) {
                    Text("When does your day start?")
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                // Time selector with enhanced styling
                VStack(spacing: HiveSpacing.lg) {
                    // Large time display
                    Text(formattedTime)
                        .font(.system(size: 64, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    // Custom slider with better styling
                    VStack(spacing: HiveSpacing.sm) {
                        Slider(
                            value: Binding(
                                get: { Double(dayStartHour) },
                                set: { dayStartHour = Int($0) }
                            ),
                            in: 0...6,
                            step: 1
                        )
                        .accentColor(.white)

                        // Hour labels
                        HStack {
                            Text("12 AM")
                                .font(HiveTypography.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("6 AM")
                                .font(HiveTypography.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, HiveSpacing.lg)

                    // Timezone info with enhanced styling
                    VStack(spacing: HiveSpacing.xs) {
                        Text("Timezone")
                            .font(HiveTypography.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .fontWeight(.medium)
                        Text(timezone.replacingOccurrences(of: "_", with: " "))
                            .font(HiveTypography.body)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, HiveSpacing.sm)
                    .padding(.horizontal, HiveSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(Color.white.opacity(0.1))
                    )
                }

                Spacer()

                // Continue Button with enhanced styling
                Button(action: onContinue) {
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
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
    }
}
