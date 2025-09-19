import SwiftUI

struct OnboardingSeedHabitsView: View {
    @Binding var selections: Set<String>
    @StateObject private var themeManager = ThemeManager.shared
    var onContinue: () -> Void
    private let seeds = ["Drink Water","Walk","Read","Meditate","Sleep Early","Stretch"]

    var body: some View {
        ZStack {
            // Background gradient like WelcomeView
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                // Title
                VStack(spacing: HiveSpacing.md) {
                    Text("Pick 2+ Starter Habits")
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Choose habits you'd like to build together")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, HiveSpacing.xl)

                // Habit selection grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HiveSpacing.md) {
                    ForEach(seeds, id: \.self) { name in
                        let selected = selections.contains(name)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selected { selections.remove(name) } else { selections.insert(name) }
                            }
                        } label: {
                            HStack {
                                Text(habitEmoji(for: name))
                                    .font(.title2)
                                Text(name)
                                    .font(HiveTypography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(selected ? themeManager.currentTheme.primaryTextColor : .white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.large)
                                    .fill(selected ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HiveRadius.large)
                                            .stroke(Color.white.opacity(selected ? 0.8 : 0.3), lineWidth: 2)
                                    )
                            )
                            .scaleEffect(selected ? 1.05 : 1.0)
                            .shadow(color: selected ? .black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(.horizontal, HiveSpacing.lg)

                Spacer()

                // Continue button
                VStack(spacing: HiveSpacing.sm) {
                    Button(action: onContinue) {
                        HStack {
                            Text("Create Habits")
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
                                .fill(Color.white.opacity(selections.count >= 2 ? 0.2 : 0.1))
                                .background(
                                    Capsule()
                                        .stroke(Color.white.opacity(selections.count >= 2 ? 0.3 : 0.1), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(selections.count < 2)
                    .opacity(selections.count >= 2 ? 1.0 : 0.5)

                    Text("Select at least 2 habits to continue")
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(selections.count < 2 ? 1.0 : 0.0)
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
    }

    private func habitEmoji(for name: String) -> String {
        switch name.lowercased() {
        case "drink water": return "💧"
        case "walk": return "🚶"
        case "read": return "📚"
        case "meditate": return "🧘"
        case "sleep early": return "😴"
        case "stretch": return "🤸"
        default: return "🍯"
        }
    }
}
