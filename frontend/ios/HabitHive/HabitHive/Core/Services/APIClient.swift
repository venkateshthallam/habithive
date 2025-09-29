import Foundation
import Combine

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIError: LocalizedError {
    case invalidConfiguration
    case invalidURL
    case unauthorized
    case decodingError(String)
    case networkError(String)
    case serverError(Int, String)
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Missing Supabase configuration."
        case .invalidURL:
            return "Invalid request URL."
        case .unauthorized:
            return "Please sign in again."
        case .decodingError(let message):
            return "Failed to decode server response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let status, let message):
            return "Server error (\(status)): \(message)"
        case .notImplemented:
            return "This feature is not yet implemented."
        }
    }
}

private struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case user
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date, user: SupabaseAuthUser) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        user = try container.decode(SupabaseAuthUser.self, forKey: .user)

        if let expiresAtSeconds = try container.decodeIfPresent(Int.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtSeconds))
        } else {
            let expiresIn = try container.decode(Int.self, forKey: .expiresIn)
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(Int(expiresAt.timeIntervalSince1970), forKey: .expiresAt)
        try container.encode(user, forKey: .user)
    }
}

struct SupabaseAuthUser: Codable {
    let id: String
    let email: String?
    let phone: String?
    let userMetadata: [String: SupabaseJSONValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case userMetadata = "user_metadata"
    }
}

struct SupabaseJSONValue: Codable {
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
        } else if let array = try? container.decode([SupabaseJSONValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: SupabaseJSONValue].self) {
            value = dict.mapValues { $0.value }
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
            try container.encode(array.map { SupabaseJSONValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { SupabaseJSONValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

private struct AppleTokenExchangePayload: Encodable {
    let idToken: String
    let nonce: String?
    let provider: String = "apple"

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case nonce
        case provider
    }
}

private struct RefreshTokenPayload: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct UpdateUserMetadataPayload: Encodable {
    let data: [String: String]
}

private struct LogHabitPayload: Encodable {
    let p_habit_id: String
    let p_value: Int
}

private struct CreateHiveFromHabitPayload: Encodable {
    let p_habit_id: String
    let p_name: String?
    let p_backfill_days: Int
}

private struct JoinHivePayload: Encodable {
    let p_code: String
}

private struct LogHiveTodayPayload: Encodable {
    let p_hive_id: String
    let p_value: Int
}

private struct CreateHiveInvitePayload: Encodable {
    let p_hive_id: String
    let p_ttl_minutes: Int
    let p_max_uses: Int
}

private struct UserLocalDatePayload: Encodable {
    let p_user: String
}

struct ContactHashPayload: Encodable {
    let user_id: String
    let contact_hash: String
    let display_name: String?
}

private struct SingleStringResponse: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
}

private struct UUIDResponse: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
}

private struct HiveListRow: Decodable {
    struct MembersCount: Decodable { let count: Int }

    let id: String
    let name: String
    let description: String?
    let ownerId: String
    let emoji: String?
    let colorHex: String
    let type: HabitType
    let targetPerDay: Int
    let rule: String
    let threshold: Int?
    let scheduleDaily: Bool
    let scheduleWeekmask: Int
    let maxMembers: Int
    let currentStreak: Int
    let longestStreak: Int
    let lastAdvancedOn: String?
    let isActive: Bool
    let inviteCode: String
    let createdAt: Date
    let updatedAt: Date
    let hiveMembers: MembersCount?

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
        case maxMembers = "max_members"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastAdvancedOn = "last_advanced_on"
        case isActive = "is_active"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hiveMembers = "hive_members"
    }
}

private struct HiveMemberRow: Decodable {
    struct ProfilePreview: Decodable {
        let displayName: String?
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
        }
    }

    let hiveId: String
    let userId: String
    let role: String
    let joinedAt: Date
    let leftAt: Date?
    let isActive: Bool?
    let profile: ProfilePreview?

    enum CodingKeys: String, CodingKey {
        case hiveId = "hive_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case leftAt = "left_at"
        case isActive = "is_active"
        case profile = "profiles"
    }
}

private struct HiveDayRow: Decodable {
    let hiveId: String
    let userId: String
    let dayDate: String
    let value: Int
    let done: Bool

    enum CodingKeys: String, CodingKey {
        case hiveId = "hive_id"
        case userId = "user_id"
        case dayDate = "day_date"
        case value
        case done
    }
}

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var requiresProfileSetup = false

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let sessionStorageKey = "supabase.session"

    private var session: SupabaseSession? {
        didSet {
            persistSession(session)
            isAuthenticated = session != nil
        }
    }

    private init() {
        decoder = APIClient.makeDecoder()
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let saved = loadPersistedSession() {
            session = saved
            isAuthenticated = true
            Task { await loadCurrentUser(force: true) }
        }
    }

    // MARK: - Authentication

    func signInWithApple(idToken: String, nonce: String?) async throws {
        let payload = AppleTokenExchangePayload(idToken: idToken, nonce: nonce)
        let session: SupabaseSession = try await performAuthRequest(
            path: "/auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: payload
        )
        self.session = session
        try await refreshSessionIfNeeded()
        await loadCurrentUser(force: true)
    }

    func refreshSessionIfNeeded() async throws {
        guard let session else { throw APIError.unauthorized }
        let timeToExpiry = session.expiresAt.timeIntervalSinceNow
        if timeToExpiry > 60 { return }
        try await refreshSession()
    }

    func refreshSession() async throws {
        guard let session else { throw APIError.unauthorized }
        let payload = RefreshTokenPayload(refreshToken: session.refreshToken)
        let newSession: SupabaseSession = try await performAuthRequest(
            path: "/auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: payload
        )
        self.session = newSession
    }

    func logout() {
        session = nil
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
    }

    // MARK: - Profile

    func loadCurrentUser(force: Bool = false) async {
        guard let session else { return }
        if !force, let current = currentUser, current.id == session.user.id { return }
        do {
            let profile = try await fetchProfile(userId: session.user.id)
            let phone = profilePhone(from: session)
            let user = User(
                id: profile.id,
                phone: phone,
                displayName: profile.displayName,
                avatarUrl: profile.avatarUrl,
                timezone: profile.timezone,
                dayStartHour: profile.dayStartHour,
                theme: profile.theme
            )
            currentUser = user
            evaluateProfileSetup(for: user)
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    func getMyProfile() async throws -> User {
        try await ensureAuthenticated()
        await loadCurrentUser(force: true)
        guard let currentUser else { throw APIError.serverError(404, "Profile not found") }
        return currentUser
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> User {
        try await ensureAuthenticated()
        let userId = try requireUserId()
        var query = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        var request = try buildRequest(
            path: "/rest/v1/profiles",
            method: .patch,
            queryItems: &query,
            body: update
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let profiles: [ProfileRecord] = try await performRequest(request)
        guard let profile = profiles.first else { throw APIError.serverError(404, "Profile missing") }
        let phone = currentUser?.phone ?? profilePhone(from: session!)
        let user = User(
            id: profile.id,
            phone: phone,
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            timezone: profile.timezone,
            dayStartHour: profile.dayStartHour,
            theme: profile.theme
        )
        currentUser = user
        evaluateProfileSetup(for: user)
        return user
    }

    func updatePhoneNumber(_ phoneNumber: String) async throws {
        try await ensureAuthenticated()
        var emptyQuery: [URLQueryItem] = []
        var request = try buildRequest(
            path: "/auth/v1/user",
            method: .patch,
            queryItems: &emptyQuery,
            body: UpdateUserMetadataPayload(data: ["phone_number": phoneNumber])
        )
        request.setValue(nil, forHTTPHeaderField: "Prefer")
        _ = try await performRequest(request) as SupabaseAuthUser
        if var user = currentUser {
            user.phone = phoneNumber
            currentUser = user
            evaluateProfileSetup(for: user)
        } else {
            await loadCurrentUser(force: true)
        }
    }

    func markProfileSetupComplete() {
        requiresProfileSetup = false
    }

    // MARK: - Habits

    func getHabits(includeLogs: Bool = false, days: Int = 30) async throws -> [Habit] {
        try await ensureAuthenticated()
        var query: [URLQueryItem] = [
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        if includeLogs {
            let select = "*,recent_logs:habit_logs(log_date,value,created_at)"
            query.append(URLQueryItem(name: "select", value: select))
            let sinceDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            query.append(URLQueryItem(name: "habit_logs.log_date", value: "gte.\(DateFormatter.hiveAPIDayFormatter.string(from: sinceDate))"))
        }
        let request = try buildRequest(path: "/rest/v1/habits", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        return try await performRequest(request)
    }

    func getHabit(habitId: String, includeLogs: Bool = true) async throws -> Habit {
        try await ensureAuthenticated()
        var query: [URLQueryItem] = [URLQueryItem(name: "id", value: "eq.\(habitId)")]
        if includeLogs {
            let select = "*,recent_logs:habit_logs(log_date,value,created_at)"
            query.append(URLQueryItem(name: "select", value: select))
        }
        let request = try buildRequest(path: "/rest/v1/habits", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        let habits: [Habit] = try await performRequest(request)
        guard let habit = habits.first else { throw APIError.serverError(404, "Habit not found") }
        return habit
    }

    func createHabit(_ habit: CreateHabitRequest) async throws -> Habit {
        try await ensureAuthenticated()
        var emptyQuery: [URLQueryItem] = []
        var request = try buildRequest(path: "/rest/v1/habits", method: .post, queryItems: &emptyQuery, body: habit)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let habits: [Habit] = try await performRequest(request)
        guard let habit = habits.first else { throw APIError.serverError(422, "Habit creation failed") }
        return habit
    }

    func logHabit(habitId: String, value: Int) async throws -> HabitLog {
        try await ensureAuthenticated()
        let payload = LogHabitPayload(p_habit_id: habitId, p_value: value)
        var emptyQuery: [URLQueryItem] = []
        let request = try buildRequest(path: "/rest/v1/rpc/log_habit", method: .post, queryItems: &emptyQuery, body: payload)
        return try await performRequest(request)
    }

    func deleteHabitLog(habitId: String, logDate: Date? = nil) async throws {
        try await ensureAuthenticated()
        var queryItems = [URLQueryItem]()

        if let logDate = logDate {
            let dateString = DateFormatter.hiveDayFormatter.string(from: logDate)
            queryItems.append(URLQueryItem(name: "log_date", value: dateString))
        }

        let request = try buildRequest(path: "/habits/\(habitId)/log", method: .delete, queryItems: &queryItems, body: Optional<EmptyCodable>.none)
        _ = try await performRequest(request) as EmptyResponse
    }

    func deleteHabit(habitId: String) async throws {
        try await ensureAuthenticated()
        var query = [URLQueryItem(name: "id", value: "eq.\(habitId)")]
        let request = try buildRequest(path: "/rest/v1/habits", method: .delete, queryItems: &query, body: Optional<EmptyCodable>.none)
        _ = try await performRequest(request) as EmptyResponse
    }

    func getHabitLogs(habitId: String, startDate: Date? = nil, endDate: Date? = nil) async throws -> [HabitLog] {
        try await ensureAuthenticated()
        var query: [URLQueryItem] = [
            URLQueryItem(name: "habit_id", value: "eq.\(habitId)"),
            URLQueryItem(name: "order", value: "log_date.desc")
        ]
        if let startDate {
            query.append(URLQueryItem(name: "log_date", value: "gte.\(DateFormatter.hiveAPIDayFormatter.string(from: startDate))"))
        }
        if let endDate {
            query.append(URLQueryItem(name: "log_date", value: "lte.\(DateFormatter.hiveAPIDayFormatter.string(from: endDate))"))
        }
        let request = try buildRequest(path: "/rest/v1/habit_logs", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        return try await performRequest(request)
    }

    // MARK: - Hives

    func getHives() async throws -> HiveOverview {
        throw APIError.notImplemented
    }

    func createHiveFromHabit(habitId: String, name: String?, backfillDays: Int) async throws -> Hive {
        throw APIError.notImplemented
    }

    func joinHive(code: String) async throws -> Hive {
        throw APIError.notImplemented
    }

    func createHiveInvite(hiveId: String, ttlMinutes: Int = 10080, maxUses: Int = 20) async throws -> HiveInvite {
        throw APIError.notImplemented
    }

    func logHiveDay(hiveId: String, value: Int) async throws -> HiveMemberDay {
        throw APIError.notImplemented
    }

    func deleteHive(hiveId: String) async throws {
        throw APIError.notImplemented
    }

    func getHiveDetail(hiveId: String) async throws -> HiveDetail {
        try await ensureAuthenticated()
        let hive = try await getHiveSummary(hiveId: hiveId)
        let memberRows = try await fetchHiveMemberRows(hiveId: hiveId)
        let dayMap = try await fetchMemberDayMap(hiveId: hiveId)
        let activity = try await fetchHiveActivity(hiveId: hiveId)
        let target = max(hive.targetPerDay, 1)

        var completed = 0
        var partial = 0
        var pending = 0
        var completionAccumulator = 0.0

        let members: [HiveMemberStatus] = memberRows.map { row in
            let entry = dayMap[row.userId] ?? .init(value: 0)
            let value = entry.value

            let status: HiveMemberStatusState
            if value >= target {
                status = .completed
                completed += 1
            } else if value > 0 {
                status = .partial
                partial += 1
            } else {
                status = .pending
                pending += 1
            }

            completionAccumulator += min(Double(value) / Double(target), 1.0)

            return HiveMemberStatus(
                hiveId: row.hiveId,
                userId: row.userId,
                role: row.role,
                joinedAt: row.joinedAt,
                leftAt: row.leftAt,
                isActive: row.isActive ?? true,
                displayName: row.profile?.displayName,
                avatarUrl: row.profile?.avatarUrl,
                status: status,
                value: value,
                targetPerDay: target
            )
        }

        let memberCount = members.count
        let completionRate = memberCount > 0 ? (completionAccumulator / Double(memberCount)) * 100 : 0
        let todaySummary = HiveTodaySummary(
            completed: completed,
            partial: partial,
            pending: pending,
            total: memberCount,
            completionRate: completionRate
        )

        return HiveDetail(
            id: hive.id,
            name: hive.name,
            ownerId: hive.ownerId,
            description: hive.description,
            emoji: hive.emoji,
            colorHex: hive.colorHex,
            type: hive.type,
            targetPerDay: hive.targetPerDay,
            rule: hive.rule,
            threshold: hive.threshold,
            scheduleDaily: hive.scheduleDaily,
            scheduleWeekmask: hive.scheduleWeekmask,
            isActive: hive.isActive,
            inviteCode: hive.inviteCode,
            maxMembers: hive.maxMembers,
            currentLength: hive.currentLength,
            currentStreak: hive.currentStreak,
            longestStreak: hive.longestStreak,
            lastAdvancedOn: hive.lastAdvancedOn,
            createdAt: hive.createdAt,
            updatedAt: hive.updatedAt,
            memberCount: memberCount,
            avgCompletion: completionRate,
            todaySummary: todaySummary,
            members: members,
            recentActivity: activity
        )
    }

    func getActivityFeed(hiveId: String?, limit: Int = 50) async throws -> [ActivityEvent] {
        try await ensureAuthenticated()
        var query = [URLQueryItem(name: "order", value: "created_at.desc"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        if let hiveId {
            query.append(URLQueryItem(name: "hive_id", value: "eq.\(hiveId)"))
        }
        let request = try buildRequest(path: "/rest/v1/activity_events", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        return try await performRequest(request)
    }

    // MARK: - Insights

    func getInsightsSummary() async throws -> InsightsSummary {
        let habits = try await getHabits(includeLogs: true)
        return InsightsSummary(habits: habits)
    }

    // MARK: - Contacts

    func uploadContacts(_ contacts: [ContactHashPayload]) async throws {
        guard !contacts.isEmpty else { return }
        try await ensureAuthenticated()
        var emptyQuery: [URLQueryItem] = []
        var request = try buildRequest(path: "/rest/v1/contact_hashes", method: .post, queryItems: &emptyQuery, body: contacts)
        request.setValue("resolution=ignore-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await performRequest(request) as EmptyResponse
    }

    // MARK: - Internal Helpers

    private func ensureAuthenticated() async throws {
        guard session != nil else { throw APIError.unauthorized }
        try await refreshSessionIfNeeded()
    }

    private func requireUserId() throws -> String {
        guard let id = session?.user.id else { throw APIError.unauthorized }
        return id
    }

    private func profilePhone(from session: SupabaseSession) -> String {
        if let phone = session.user.phone, !phone.isEmpty { return phone }
        if let metadata = session.user.userMetadata,
           let value = metadata["phone_number"]?.value as? String {
            return value
        }
        return ""
    }

    private func evaluateProfileSetup(for user: User) {
        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsName = trimmedName.isEmpty || trimmedName.lowercased() == "new bee" || trimmedName.hasPrefix("Bee ")
        let needsPhone = user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        requiresProfileSetup = needsName || needsPhone
    }

    private func fetchProfile(userId: String) async throws -> ProfileRecord {
        var query = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        let request = try buildRequest(path: "/rest/v1/profiles", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        let profiles: [ProfileRecord] = try await performRequest(request)
        guard let profile = profiles.first else { throw APIError.serverError(404, "Profile missing") }
        return profile
    }

    private func getHiveSummary(hiveId: String) async throws -> Hive {
        var query = [URLQueryItem(name: "id", value: "eq.\(hiveId)")]
        let request = try buildRequest(path: "/rest/v1/hives", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        let rows: [Hive] = try await performRequest(request)
        guard let hive = rows.first else { throw APIError.serverError(404, "Hive not found") }
        return hive
    }

    private func fetchHiveMemberRows(hiveId: String) async throws -> [HiveMemberRow] {
        var query = [
            URLQueryItem(name: "hive_id", value: "eq.\(hiveId)"),
            URLQueryItem(name: "select", value: "hive_id,user_id,role,joined_at,profiles(display_name,avatar_url)")
        ]
        let request = try buildRequest(path: "/rest/v1/hive_members", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        return try await performRequest(request)
    }

    private struct HiveMemberDayStatus { let value: Int }

    private func fetchMemberDayMap(hiveId: String) async throws -> [String: HiveMemberDayStatus] {
        let date = try await userLocalDateForCurrentUser()
        var query = [
            URLQueryItem(name: "hive_id", value: "eq.\(hiveId)"),
            URLQueryItem(name: "day_date", value: "eq.\(date)")
        ]
        let request = try buildRequest(path: "/rest/v1/hive_member_days", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        let rows: [HiveDayRow] = try await performRequest(request)
        var map: [String: HiveMemberDayStatus] = [:]
        for row in rows {
            map[row.userId] = HiveMemberDayStatus(value: row.value)
        }
        return map
    }

    private func userLocalDateForCurrentUser() async throws -> String {
        let userId = try requireUserId()
        let payload = UserLocalDatePayload(p_user: userId)
        var emptyQuery: [URLQueryItem] = []
        let request = try buildRequest(path: "/rest/v1/rpc/user_local_date", method: .post, queryItems: &emptyQuery, body: payload)
        let response: SingleStringResponse = try await performRequest(request)
        return response.value
    }

    private func fetchHiveActivity(hiveId: String) async throws -> [ActivityEvent] {
        var query = [
            URLQueryItem(name: "hive_id", value: "eq.\(hiveId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "20")
        ]
        let request = try buildRequest(path: "/rest/v1/activity_events", method: .get, queryItems: &query, body: Optional<EmptyCodable>.none)
        return try await performRequest(request)
    }

    private func performAuthRequest<T: Decodable>(path: String,
                                                  method: HTTPMethod,
                                                  queryItems: [URLQueryItem],
                                                  body: Encodable) async throws -> T {
        var request = try buildRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuth: false,
            baseURL: SupabaseConfiguration.authUrl
        )
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        return try await performRequest(request)
    }

    private func buildRequest(path: String,
                              method: HTTPMethod,
                              queryItems: inout [URLQueryItem],
                              body: Encodable?,
                              baseURL: URL = SupabaseConfiguration.restUrl) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? ""
        let normalizedBasePath = basePath == "/" ? "" : basePath
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        components?.path = normalizedBasePath + normalizedPath
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        if let accessToken = session?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return request
    }

    private func buildRequest(path: String,
                              method: HTTPMethod,
                              queryItems: inout [URLQueryItem],
                              body: Optional<EmptyCodable>,
                              baseURL: URL = SupabaseConfiguration.restUrl) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? ""
        let normalizedBasePath = basePath == "/" ? "" : basePath
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        components?.path = normalizedBasePath + normalizedPath
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        if let accessToken = session?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func buildRequest(path: String,
                              method: HTTPMethod,
                              queryItems: [URLQueryItem]?,
                              body: Encodable?,
                              requiresAuth: Bool,
                              baseURL: URL = SupabaseConfiguration.restUrl) throws -> URLRequest {
        var mutableQuery = queryItems ?? []
        var request = try buildRequest(path: path, method: method, queryItems: &mutableQuery, body: body, baseURL: baseURL)
        if !requiresAuth {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }

            if httpResponse.statusCode == 204 {
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: Data("{}".utf8))
            }

            if httpResponse.statusCode == 401 {
                logout()
                throw APIError.unauthorized
            }

            if httpResponse.statusCode >= 400 {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, message)
            }

            if data.isEmpty, T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    private func persistSession(_ session: SupabaseSession?) {
        guard let session else {
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
            return
        }
        do {
            let data = try encoder.encode(session)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
        } catch {
            print("Failed to persist session: \(error)")
        }
    }

    private func loadPersistedSession() -> SupabaseSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SupabaseSession.self, from: data)
        } catch {
            print("Failed to decode session: \(error)")
            return nil
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.full.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.withoutFractional.date(from: string) {
                return date
            }
            if let date = DateFormatter.hiveAPIDayFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(string)")
        }
        return decoder
    }
}

private struct EmptyCodable: Encodable {}

private struct EmptyResponse: Decodable {
    init() {}
}

private struct AnyEncodable: Encodable {
    private let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct ProfileRecord: Decodable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let timezone: String
    let dayStartHour: Int
    let theme: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case dayStartHour = "day_start_hour"
        case theme
    }
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static let hiveAPIDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension InsightsSummary {
    init(habits: [Habit]) {
        let logs = habits.flatMap { $0.recentLogs ?? [] }
        let completedToday = logs.filter { Calendar.current.isDateInToday($0.dateValue) }.count
        self.init(
            overallCompletion: Double(logs.count),
            activeHabits: habits.count,
            completedToday: completedToday,
            weeklyProgress: Array(repeating: 0, count: 7),
            currentStreaks: [],
            yearComb: [:],
            bestPerforming: nil
        )
    }
}

private extension HabitLog {
    var dateValue: Date {
        DateFormatter.hiveAPIDayFormatter.date(from: logDate) ?? Date()
    }
}
