import Foundation
import SwiftUI

// MARK: - User & Profile
struct User: Codable, Identifiable {
    let id: String
    var phone: String
    var displayName: String
    var avatarUrl: String?
    var timezone: String
    var dayStartHour: Int
    var theme: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case dayStartHour = "day_start_hour"
        case theme
    }
}

// MARK: - Auth
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let userId: String
    let phone: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case phone
    }
}

// MARK: - Habit
enum HabitType: String, Codable, CaseIterable {
    case checkbox = "checkbox"
    case counter = "counter"
}

struct Habit: Codable, Identifiable {
    let id: String
    let userId: String
    var name: String
    var emoji: String?
    var colorHex: String
    var type: HabitType
    var targetPerDay: Int
    var scheduleDaily: Bool
    var scheduleWeekmask: Int
    var reminderEnabled: Bool = false
    var reminderTime: String?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
    
    // Additional properties for UI
    var recentLogs: [HabitLog]?
    var currentStreak: Int?
    var completionRate: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case reminderEnabled = "reminder_enabled"
        case reminderTime = "reminder_time"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case recentLogs = "recent_logs"
        case currentStreak = "current_streak"
        case completionRate = "completion_rate"
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Habit Log
struct HabitLog: Codable, Identifiable {
    let id: String
    let habitId: String
    let userId: String
    let logDate: String
    var value: Int
    let source: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case logDate = "log_date"
        case value
        case source
        case createdAt = "created_at"
    }
}

// MARK: - Hive (Group)
struct Hive: Codable, Identifiable {
    let id: String
    let name: String
    var description: String?
    let ownerId: String
    var emoji: String?
    var colorHex: String
    var type: HabitType
    var targetPerDay: Int
    let rule: String
    var threshold: Int?
    var scheduleDaily: Bool
    var scheduleWeekmask: Int
    var isActive: Bool
    var inviteCode: String?
    let createdAt: Date
    var updatedAt: Date?
    var memberCount: Int?
    var maxMembers: Int?
    var currentLength: Int?
    var currentStreak: Int?
    var longestStreak: Int?
    var lastAdvancedOn: String?
    var avgCompletion: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerId = "owner_id"
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case rule
        case threshold
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case isActive = "is_active"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case currentLength = "current_length"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastAdvancedOn = "last_advanced_on"
        case avgCompletion = "avg_completion"
    }

    var color: Color { Color(hex: colorHex) }
    var groupStreak: Int { currentStreak ?? currentLength ?? 0 }
}

// MARK: - Hive Detail
struct HiveHeatmapDay: Codable, Identifiable {
    var id: String { date.ISO8601Format() }
    let date: Date
    let completionRatio: Double
    let completedCount: Int
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case date
        case completionRatio = "completion_ratio"
        case completedCount = "completed_count"
        case totalCount = "total_count"
    }
}

struct HiveDetail: Codable {
    let id: String
    let name: String
    let ownerId: String
    var description: String?
    var emoji: String?
    var colorHex: String
    var type: HabitType
    var targetPerDay: Int
    let rule: String
    var threshold: Int?
    var scheduleDaily: Bool
    var scheduleWeekmask: Int
    var isActive: Bool
    var inviteCode: String?
    var maxMembers: Int?
    var currentLength: Int?
    var currentStreak: Int?
    var longestStreak: Int?
    var lastAdvancedOn: String?
    let createdAt: Date
    var updatedAt: Date?
    var memberCount: Int?
    var avgCompletion: Double
    var todaySummary: HiveTodaySummary
    var members: [HiveMemberStatus]
    var recentActivity: [ActivityEvent]
    var heatmap: [HiveHeatmapDay]

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
        case description
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case rule, threshold
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case isActive = "is_active"
        case inviteCode = "invite_code"
        case maxMembers = "max_members"
        case currentLength = "current_length"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastAdvancedOn = "last_advanced_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case avgCompletion = "avg_completion"
        case todaySummary = "today_summary"
        case members
        case recentActivity = "recent_activity"
        case heatmap
    }
}

struct HiveTodaySummary: Codable {
    let completed: Int
    let partial: Int
    let pending: Int
    let total: Int
    let completionRate: Double

    enum CodingKeys: String, CodingKey {
        case completed
        case partial
        case pending
        case total
        case completionRate = "completion_rate"
    }

    var completedFraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var partialFraction: Double {
        guard total > 0 else { return 0 }
        return Double(partial) / Double(total)
    }

    var pendingFraction: Double {
        guard total > 0 else { return 0 }
        return Double(pending) / Double(total)
    }
}

enum HiveMemberStatusState: String, Codable {
    case completed
    case partial
    case pending
}

// MARK: - Hive Member
struct HiveMemberStatus: Codable, Identifiable {
    let hiveId: String
    let userId: String
    let role: String
    let joinedAt: Date
    var leftAt: Date?
    var isActive: Bool
    var displayName: String?
    var avatarUrl: String?
    let status: HiveMemberStatusState
    let value: Int
    let targetPerDay: Int
    
    var id: String { "\(hiveId)-\(userId)" }
    
    enum CodingKeys: String, CodingKey {
        case hiveId = "hive_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case leftAt = "left_at"
        case isActive = "is_active"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case status
        case value
        case targetPerDay = "target_per_day"
    }
}

struct HiveMemberDay: Codable {
    let hiveId: String
    let userId: String
    let dayDate: String
    let value: Int
    let done: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case hiveId = "hive_id"
        case userId = "user_id"
        case dayDate = "day_date"
        case value
        case done
        case createdAt = "created_at"
    }
}

// MARK: - Hive Invite
struct HiveInvite: Codable, Identifiable {
    let id: String
    let hiveId: String
    let code: String
    let createdBy: String
    let expiresAt: Date
    let maxUses: Int
    var useCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case hiveId = "hive_id"
        case code
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case useCount = "use_count"
        case createdAt = "created_at"
    }
}

struct HiveLeaderboardEntry: Codable, Identifiable {
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let completedToday: Int
    let totalHives: Int

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case completedToday = "completed_today"
        case totalHives = "total_hives"
    }

    var completionPercentage: Int {
        guard totalHives > 0 else { return 0 }
        return Int(round((Double(completedToday) / Double(totalHives)) * 100))
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return String(displayName.prefix(1)).uppercased()
    }

    var avatarColor: Color {
        let colors = HiveColors.habitColors
        guard !colors.isEmpty else { return HiveColors.honeyGradientEnd }
        let index = abs(userId.hashValue) % colors.count
        return colors[index]
    }
}

struct HiveOverview: Codable {
    let hives: [Hive]
    let leaderboard: [HiveLeaderboardEntry]
}

// MARK: - Activity
enum ActivityType: String, Codable {
    case habitCompleted = "habit_completed"
    case streakMilestone = "streak_milestone"
    case hiveJoined = "hive_joined"
    case hiveAdvanced = "hive_advanced"
    case hiveBroken = "hive_broken"
}

struct ActivityEvent: Codable, Identifiable {
    let id: String
    let actorId: String
    let hiveId: String?
    let habitId: String?
    let type: ActivityType
    let data: [String: AnyCodable]
    let createdAt: Date
    var actorName: String?
    var actorAvatar: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case actorId = "actor_id"
        case hiveId = "hive_id"
        case habitId = "habit_id"
        case type
        case data
        case createdAt = "created_at"
        case actorName = "actor_name"
        case actorAvatar = "actor_avatar"
    }
}

// MARK: - Helper Types
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Request Models
struct CreateHabitRequest: Codable {
    let name: String
    let emoji: String?
    let colorHex: String
    let type: HabitType
    let targetPerDay: Int
    let scheduleDaily: Bool
    let scheduleWeekmask: Int
    let reminderEnabled: Bool
    let reminderTime: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case reminderEnabled = "reminder_enabled"
        case reminderTime = "reminder_time"
    }
}

struct LogHabitRequest: Codable {
    let value: Int
}

struct CreateHiveFromHabitRequest: Codable {
    let habitId: String
    let name: String?
    let backfillDays: Int
    
    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case name
        case backfillDays = "backfill_days"
    }
}

// MARK: - Profile Update
struct ProfileUpdate: Codable {
    let displayName: String?
    let avatarUrl: String?
    let phone: String?
    let timezone: String?
    let dayStartHour: Int?
    let theme: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case phone
        case timezone
        case dayStartHour = "day_start_hour"
        case theme
    }

    init(displayName: String? = nil,
         avatarUrl: String? = nil,
         phone: String? = nil,
         timezone: String? = nil,
         dayStartHour: Int? = nil,
         theme: String? = nil) {
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phone = phone
        self.timezone = timezone
        self.dayStartHour = dayStartHour
        self.theme = theme
    }
}

// MARK: - Insights Summary
struct InsightsSummary: Codable {
    let overallCompletion: Double
    let activeHabits: Int
    let completedToday: Int
    let weeklyProgress: [Int]
    let currentStreaks: [HabitStreakDisplay]
    let yearComb: [String: Int]
    let bestPerforming: HabitPerformanceSummary?

    enum CodingKeys: String, CodingKey {
        case overallCompletion = "overall_completion"
        case activeHabits = "active_habits"
        case completedToday = "completed_today"
        case weeklyProgress = "weekly_progress"
        case currentStreaks = "current_streaks"
        case yearComb = "year_comb"
        case bestPerforming = "best_performing"
    }
}

struct HabitStreakDisplay: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String?
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case id = "habit_id"
        case name
        case emoji
        case streak
    }
}

struct HabitPerformanceSummary: Codable {
    let id: UUID
    let name: String
    let emoji: String?
    let completionRate: Double

    enum CodingKeys: String, CodingKey {
        case id = "habit_id"
        case name
        case emoji
        case completionRate = "completion_rate"
    }
}

enum InsightRange: String, CaseIterable, Codable {
    case week
    case month
    case year

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

struct HabitPerformanceDetailModel: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String?
    let colorHex: String
    let type: HabitType
    let targetPerDay: Int
    let completionRate: Double
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case id = "habit_id"
        case name
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case completionRate = "completion_rate"
        case streak
    }

    var color: Color { Color(hex: colorHex) }
}

struct InsightsRangeStatsModel: Codable {
    let averageCompletion: Double
    let currentStreak: Int
    let habitPerformance: [HabitPerformanceDetailModel]

    enum CodingKeys: String, CodingKey {
        case averageCompletion = "average_completion"
        case currentStreak = "current_streak"
        case habitPerformance = "habit_performance"
    }
}

struct InsightsDashboard: Codable {
    let ranges: [String: InsightsRangeStatsModel]
    let yearOverview: [String: Int]

    enum CodingKeys: String, CodingKey {
        case ranges
        case yearOverview = "year_overview"
    }

    func stats(for range: InsightRange) -> InsightsRangeStatsModel? {
        ranges[range.rawValue]
    }
}

struct HabitHeatmapSeriesModel: Codable, Identifiable {
    let habitId: String
    let name: String
    let emoji: String?
    let colorHex: String
    let counts: [String: Int]

    var id: String { habitId }

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case name
        case emoji
        case colorHex = "color_hex"
        case counts
    }
}

struct YearOverviewModel: Codable {
    let startDate: Date
    let endDate: Date
    let totals: [String: Int]
    let maxTotal: Int
    let habits: [HabitHeatmapSeriesModel]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case totals
        case maxTotal = "max_total"
        case habits
    }
}

struct JoinHiveRequest: Codable {
    let code: String
}

struct HiveJoinResult {
    let success: Bool
    let hiveId: String?
    let message: String?
}

extension String {
    /// Returns true when the string is empty, the default "New Bee" label,
    /// or the auto-generated "Bee <UUID prefix>" used for brand-new accounts.
    var isDefaultHiveDisplayName: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        if trimmed.caseInsensitiveCompare("New Bee") == .orderedSame {
            return true
        }

        let prefix = "Bee "
        guard trimmed.hasPrefix(prefix) else { return false }

        let suffix = trimmed.dropFirst(prefix.count)
        guard suffix.count == 6 else { return false }

        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return suffix.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
