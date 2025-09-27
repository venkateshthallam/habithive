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
    let ownerId: String
    var colorHex: String
    var type: HabitType
    var targetPerDay: Int
    let rule: String
    var threshold: Int?
    var scheduleDaily: Bool
    var scheduleWeekmask: Int
    var currentLength: Int
    var lastAdvancedOn: String?
    let createdAt: Date
    var memberCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case rule
        case threshold
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case currentLength = "current_length"
        case lastAdvancedOn = "last_advanced_on"
        case createdAt = "created_at"
        case memberCount = "member_count"
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Hive Detail
struct HiveDetail: Codable {
    let id: String
    let name: String
    let ownerId: String
    var colorHex: String
    var type: HabitType
    var targetPerDay: Int
    let rule: String
    var threshold: Int?
    var scheduleDaily: Bool
    var scheduleWeekmask: Int
    var currentLength: Int
    var lastAdvancedOn: String?
    let createdAt: Date
    var memberCount: Int?
    var members: [HiveMember]
    var todayStatus: TodayStatus
    var recentActivity: [ActivityEvent]

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case rule, threshold
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case currentLength = "current_length"
        case lastAdvancedOn = "last_advanced_on"
        case createdAt = "created_at"
        case memberCount = "member_count"
        case members
        case todayStatus = "today_status"
        case recentActivity = "recent_activity"
    }
}

struct TodayStatus: Codable {
    let completeCount: Int
    let requiredCount: Int
    let membersDone: [String]

    enum CodingKeys: String, CodingKey {
        case completeCount = "complete_count"
        case requiredCount = "required_count"
        case membersDone = "members_done"
    }
}

// MARK: - Hive Member
struct HiveMember: Codable, Identifiable {
    let hiveId: String
    let userId: String
    let role: String
    let joinedAt: Date
    var displayName: String?
    var avatarUrl: String?
    
    var id: String { "\(hiveId)-\(userId)" }
    
    enum CodingKeys: String, CodingKey {
        case hiveId = "hive_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
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
    
    enum CodingKeys: String, CodingKey {
        case name
        case emoji
        case colorHex = "color_hex"
        case type
        case targetPerDay = "target_per_day"
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
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
    let timezone: String?
    let dayStartHour: Int?
    let theme: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case dayStartHour = "day_start_hour"
        case theme
    }

    init(displayName: String? = nil,
         avatarUrl: String? = nil,
         timezone: String? = nil,
         dayStartHour: Int? = nil,
         theme: String? = nil) {
        self.displayName = displayName
        self.avatarUrl = avatarUrl
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

struct JoinHiveRequest: Codable {
    let code: String
}
