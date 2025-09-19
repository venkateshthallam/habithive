import SwiftUI

struct OnboardingThemeView: View {
    @Binding var selectedTheme: AppTheme
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: HiveSpacing.lg) {
            Text("Choose Your Theme")
                .font(HiveTypography.title2)
                .foregroundColor(HiveColors.slateText)
            HStack(spacing: HiveSpacing.md) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        selectedTheme = theme
                    } label: {
                        VStack {
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(theme.primaryGradient)
                                .frame(width: 90, height: 120)
                            Text(theme.rawValue.capitalized).font(HiveTypography.caption)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .stroke(selectedTheme == theme ? Color.white : Color.clear, lineWidth: 3)
                        )
                    }
                }
            }
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding(HiveSpacing.lg)
        .background(ThemeManager.shared.currentTheme.backgroundColor.ignoresSafeArea())
    }
}
