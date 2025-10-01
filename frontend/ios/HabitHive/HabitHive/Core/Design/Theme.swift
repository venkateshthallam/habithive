import SwiftUI

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case honey = "honey"
    case mint = "mint"
    case night = "night"

    var primaryGradient: LinearGradient {
        switch self {
        case .honey:
            return LinearGradient(
                colors: [Color(hex: "#FFD166"), Color(hex: "#FF9F1C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mint:
            return LinearGradient(
                colors: [Color(hex: "#34C759"), Color(hex: "#2FB344")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [Color(hex: "#5AC8FA"), Color(hex: "#007AFF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var backgroundColor: Color {
        switch self {
        case .honey:
            return Color(hex: "#FAFAFA") // Neutral background
        case .mint:
            return Color(hex: "#F0FFF4")
        case .night:
            return Color(hex: "#121212")
        }
    }

    var backgroundGradient: LinearGradient {
        switch self {
        case .honey:
            return LinearGradient(
                colors: [Color(hex: "#FAFAFA"), Color(hex: "#FDFDFD")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .mint:
            return LinearGradient(
                colors: [Color(hex: "#F0FFF4"), Color(hex: "#F7FFFA")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .night:
            return LinearGradient(
                colors: [Color(hex: "#121212"), Color(hex: "#1A1A1A")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var cardBackgroundColor: Color {
        switch self {
        case .honey, .mint:
            return Color.white
        case .night:
            return Color(hex: "#1C1C1E")
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .honey, .mint:
            return Color(hex: "#111827") // Dark gray, not pure black
        case .night:
            return Color.white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .honey, .mint:
            return Color(hex: "#6B7280") // Medium gray for labels
        case .night:
            return Color.white.opacity(0.6)
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme = .honey

    private init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
}

// MARK: - Design System Colors
struct HiveColors {
    // Primary Colors (Updated palette)
    static let honeyPrimary = Color(hex: "#FFC93C") // Primary honey-yellow highlight
    static let honeyGradientStart = Color(hex: "#FFC93C")
    static let honeyGradientEnd = Color(hex: "#FFB703")
    static let mintSuccess = Color(hex: "#34D399") // Updated green with gradient
    static let mintGradientStart = Color(hex: "#4ECDC4")
    static let mintGradientEnd = Color(hex: "#34D399")

    // Secondary Accents
    static let tealAccent = Color(hex: "#4ECDC4") // Light teal for contrast
    static let coralAccent = Color(hex: "#FF6B6B") // Warm coral for alerts

    // Text Colors
    static let primaryText = Color(hex: "#111827") // Dark gray, not pure black
    static let secondaryText = Color(hex: "#6B7280") // Medium gray for labels
    static let beeBlack = Color(hex: "#111827") // Updated to match new primary text
    static let slateText = Color(hex: "#6B7280")

    // Background Colors
    static let backgroundStart = Color(hex: "#FAFAFA")
    static let backgroundEnd = Color(hex: "#FDFDFD")
    static let creamBase = Color(hex: "#FAFAFA") // Updated to neutral
    static let skyAccent = Color(hex: "#4ECDC4") // Updated to teal

    // Neutral Grays
    static let cardBackground = Color.white
    static let borderColor = Color(hex: "#E5E7EB") // Slightly lighter border
    static let lightGray = Color(hex: "#F2F2F7")

    // Semantic Colors
    static let error = Color(hex: "#FF3B30") // Red only for errors
    static let warning = Color(hex: "#FF9500")
    static let success = mintSuccess

    // Habit Card Colors (soft pastels like in mocks)
    static let habitCardColors = [
        Color(hex: "#FFF2CC"), // Light yellow
        Color(hex: "#FFE1E1"), // Light pink
        Color(hex: "#E1F5E1"), // Light green
        Color(hex: "#E1F0FF"), // Light blue
        Color(hex: "#F0E1FF"), // Light purple
        Color(hex: "#FFE1CC"), // Light orange
    ]

    // Habit Colors for icons/accents
    static let habitColors = [
        Color(hex: "#FF9F1C"), // Orange
        Color(hex: "#34C8ED"), // Blue
        Color(hex: "#FF6B6B"), // Red
        Color(hex: "#4ECDC4"), // Teal
        Color(hex: "#95E77E"), // Green
        Color(hex: "#FFE66D"), // Yellow
        Color(hex: "#A8DADC"), // Light Blue
        Color(hex: "#E63946"), // Dark Red
    ]
}

// MARK: - Typography (SF Pro Rounded for approachable feel)
struct HiveTypography {
    // Headings (Bold, size 22-24)
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    // Body Text (Regular, size 14-15)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 16, weight: .medium, design: .rounded)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

    // Labels (Medium, size 15-16)
    static let label = Font.system(size: 16, weight: .medium, design: .rounded)
    static let labelSmall = Font.system(size: 15, weight: .medium, design: .rounded)

    // Captions
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)

    // Numbers / Metrics (Bigger + bold, monospace for consistency)
    static let metricLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let metricMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    static let streakNumber = Font.system(size: 36, weight: .bold, design: .monospaced)
    static let statNumber = Font.system(size: 32, weight: .bold, design: .monospaced)
}

// MARK: - Spacing & Sizing
struct HiveSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct HiveRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16   // standard cards
    static let card: CGFloat = 20    // primary cards (updated)
    static let xlarge: CGFloat = 24
    static let modal: CGFloat = 28   // modals
}

// MARK: - Shadows
struct HiveShadow {
    // Soft card shadow: 0 2px 6px rgba(0,0,0,0.05)
    static let card = (color: Color.black.opacity(0.05), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(2))
    // Medium shadow for elevated elements
    static let elevated = (color: Color.black.opacity(0.08), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
    // Strong shadow for modals
    static let modal = (color: Color.black.opacity(0.15), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(10))
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
