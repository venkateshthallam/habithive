import SwiftUI

struct HabitTemplateSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTemplates: Set<String> = []
    @State private var isCreatingHabits = false
    let onComplete: ([HabitTemplate]) -> Void
    let onSkip: () -> Void
    let singleSelection: Bool

    private let allTemplates = HabitTemplatesData.allTemplates

    init(onComplete: @escaping ([HabitTemplate]) -> Void, onSkip: @escaping () -> Void, singleSelection: Bool = false) {
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.singleSelection = singleSelection
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: HiveSpacing.lg) {
                        ForEach(allTemplates) { template in
                            TemplateRow(
                                template: template,
                                isSelected: selectedTemplates.contains(template.id),
                                onTap: {
                                    toggleSelection(template.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.vertical, HiveSpacing.md)
                }

                bottomButtons
            }
        }
        .overlay(alignment: .topTrailing) {
            if isCreatingHabits {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: HiveColors.honeyGradientEnd))
                    .padding(HiveSpacing.lg)
            }
        }
    }

    private var header: some View {
        VStack(spacing: HiveSpacing.sm) {
            HStack {
                Spacer()
                Button(singleSelection ? "Cancel" : "Skip") {
                    onSkip()
                }
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                .padding(.trailing, HiveSpacing.md)
            }
            .padding(.top, HiveSpacing.md)

            Text(singleSelection ? "Choose a template" : "Choose your first habits")
                .font(HiveTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                .padding(.horizontal, HiveSpacing.lg)

            Text(singleSelection ? "Select a habit template to get started quickly." : "Select habits you want to track. You can add more later.")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HiveSpacing.lg)
        }
        .padding(.bottom, HiveSpacing.md)
    }

    private var bottomButtons: some View {
        VStack(spacing: HiveSpacing.md) {
            if !selectedTemplates.isEmpty {
                Button(action: handleContinue) {
                    Text("Create \(selectedTemplates.count) Habit\(selectedTemplates.count == 1 ? "" : "s")")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                .fill(themeManager.currentTheme.primaryGradient)
                        )
                        .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 16, x: 0, y: 8)
                }
                .disabled(isCreatingHabits)
            }
        }
        .padding(.horizontal, HiveSpacing.lg)
        .padding(.bottom, HiveSpacing.xl)
    }

    private func toggleSelection(_ id: String) {
        if singleSelection {
            // In single selection mode, immediately select and complete
            if let template = allTemplates.first(where: { $0.id == id }) {
                onComplete([template])
            }
        } else {
            // In multi-selection mode, toggle selection
            if selectedTemplates.contains(id) {
                selectedTemplates.remove(id)
            } else {
                selectedTemplates.insert(id)
            }
        }
    }

    private func handleContinue() {
        let selected = allTemplates.filter { selectedTemplates.contains($0.id) }
        isCreatingHabits = true
        onComplete(selected)
    }
}

private struct TemplateRow: View {
    let template: HabitTemplate
    let isSelected: Bool
    let onTap: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HiveSpacing.md) {
                // Emoji circle
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Text(template.emoji)
                        .font(.system(size: 24))
                }

                // Text content
                VStack(alignment: .leading, spacing: HiveSpacing.xxs) {
                    Text(template.name)
                        .font(HiveTypography.headline)
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)

                    Text(template.description)
                        .font(HiveTypography.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                ZStack {
                    Circle()
                        .stroke(isSelected ? template.color : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(template.color)
                    }
                }
            }
            .padding(HiveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.large)
                    .fill(themeManager.currentTheme.cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .stroke(isSelected ? template.color : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
