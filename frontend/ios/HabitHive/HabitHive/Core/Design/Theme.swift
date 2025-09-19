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
            return Color(hex: "#FAFAFA") // Light gray background like in mocks
        case .mint:
            return Color(hex: "#F0FFF4")
        case .night:
            return Color(hex: "#121212")
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
            return Color(hex: "#1C1C1E") // Dark text for light themes
        case .night:
            return Color.white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .honey, .mint:
            return Color(hex: "#1C1C1E").opacity(0.6) // Dark text with opacity
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
    // Primary Colors
    static let honeyGradientStart = Color(hex: "#FFD166")
    static let honeyGradientEnd = Color(hex: "#FF9F1C")
    static let mintSuccess = Color(hex: "#34C759")
    static let beeBlack = Color(hex: "#1C1C1E")
    static let creamBase = Color(hex: "#FFF6E6")
    static let skyAccent = Color(hex: "#5AC8FA")
    static let slateText = Color(hex: "#1C1C1E")

    // Neutral Grays
    static let cardBackground = Color.white
    static let borderColor = Color(hex: "#E5E5EA")
    static let lightGray = Color(hex: "#F2F2F7")

    // Semantic Colors
    static let error = Color(hex: "#FF3B30")
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

// MARK: - Typography
struct HiveTypography {
    // Titles (SF Pro Display)
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 24, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    // Body (SF Pro Text)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .medium, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    // Captions
    static let caption = Font.system(size: 13, weight: .medium, design: .default)
    static let caption2 = Font.system(size: 11, weight: .medium, design: .default)
    // Mono for numbers (optional)
    static let streakNumber = Font.system(size: 36, weight: .bold, design: .monospaced)
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
    static let small: CGFloat = 6
    static let medium: CGFloat = 12
    static let large: CGFloat = 16   // cards
    static let xlarge: CGFloat = 24
    static let modal: CGFloat = 28   // modals
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
