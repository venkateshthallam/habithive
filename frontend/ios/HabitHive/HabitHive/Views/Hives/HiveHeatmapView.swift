import SwiftUI

/// A heatmap visualization showing hive activity over the last 30 days
/// - Empty cells (no activity) = light gray
/// - Partial fill (some members logged) = gradient based on completion ratio
/// - Full fill (all members logged) = solid green
struct HiveHeatmapView: View {
    let heatmap: [HiveHeatmapDay]
    @StateObject private var themeManager = ThemeManager.shared

    // Grid configuration: 5 rows x 6 columns = 30 days
    private let columns = 6
    private let rows = 5
    private let cellSize: CGFloat = 36
    private let spacing: CGFloat = 6

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            // Grid
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < heatmap.count {
                                let day = heatmap[index]
                                HeatmapCell(day: day)
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                // Empty placeholder
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: HiveSpacing.md) {
                legendItem(
                    color: HiveColors.lightGray.opacity(0.3),
                    label: "No activity"
                )
                legendItem(
                    color: HiveColors.honeyGradientEnd.opacity(0.5),
                    label: "Some members"
                )
                legendItem(
                    color: HiveColors.mintSuccess,
                    label: "All members"
                )
            }
            .padding(.top, HiveSpacing.xs)

            Text("Each square represents one day. Color intensity shows how many members completed their goal.")
                .font(HiveTypography.caption)
                .foregroundColor(theme.secondaryTextColor)
                .padding(.top, HiveSpacing.xs)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: HiveSpacing.xs) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(HiveTypography.caption)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
        }
    }
}

/// Individual cell in the heatmap grid
private struct HeatmapCell: View {
    let day: HiveHeatmapDay
    @StateObject private var themeManager = ThemeManager.shared

    private var fillColor: Color {
        let ratio = day.completionRatio

        if ratio == 0 {
            // No one logged
            return HiveColors.lightGray.opacity(0.3)
        } else if ratio >= 1.0 {
            // Everyone logged
            return HiveColors.mintSuccess
        } else {
            // Some people logged - use orange/honey gradient based on ratio
            return HiveColors.honeyGradientEnd.opacity(0.3 + (ratio * 0.7))
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        themeManager.currentTheme.backgroundColor.opacity(0.2),
                        lineWidth: 1
                    )
            )
    }
}

// Preview
#Preview {
    let sampleHeatmap: [HiveHeatmapDay] = (0..<30).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
        let ratio: Double
        if offset % 5 == 0 {
            ratio = 0.0 // No activity
        } else if offset % 3 == 0 {
            ratio = 1.0 // Full activity
        } else {
            ratio = Double.random(in: 0.3...0.8) // Partial
        }
        return HiveHeatmapDay(
            date: date,
            completionRatio: ratio,
            completedCount: Int(ratio * 5),
            totalCount: 5
        )
    }.reversed()

    return VStack {
        HiveHeatmapView(heatmap: sampleHeatmap)
            .padding()
    }
    .background(Color(.systemBackground))
}
