import Foundation
import Combine

enum FastAPIError: LocalizedError {
    case invalidURL
    case unauthorized
    case decodingError(String)
    case networkError(String)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
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
        }
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

// Request models for FastAPI backend
private struct AuthRequest: Encodable {
    let phone: String
}

private struct VerifyOTPRequest: Encodable {
    let phone: String
    let otp: String
}

private struct AppleSignInRequest: Encodable {
    let idToken: String
    let nonce: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case nonce
    }
}


@MainActor
final class FastAPIClient: ObservableObject {
    static let shared = FastAPIClient()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var requiresProfileSetup = false
    @Published private(set) var hasLoadedProfile = false
    @Published private(set) var isLoadingProfile = false

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let sessionStorageKey = "fastapi.session"
    private let refreshTokenStorageKey = "fastapi.refreshToken"
    private let phoneStorageKey = "fastapi.phone"
    private let onboardingCompleteKey = "fastapi.onboardingComplete"

    private var accessToken: String? {
        didSet {
            isAuthenticated = accessToken != nil
            UserDefaults.standard.set(accessToken, forKey: sessionStorageKey)
        }
    }

    private var refreshToken: String? {
        didSet {
            if let refreshToken = refreshToken {
                UserDefaults.standard.set(refreshToken, forKey: refreshTokenStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: refreshTokenStorageKey)
            }
        }
    }

    private var baseURL: URL {
        SupabaseConfiguration.url
    }

    nonisolated private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()

        // Set up date formatting for your FastAPI backend
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let iso8601WithFractional = ISO8601DateFormatter()
            iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601WithFractional.date(from: string) {
                return date
            }

            let iso8601Basic = ISO8601DateFormatter()
            iso8601Basic.formatOptions = [.withInternetDateTime]
            if let date = iso8601Basic.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(string)")
        }
        encoder.dateEncodingStrategy = .iso8601

        // Load saved tokens
        if let saved = UserDefaults.standard.string(forKey: sessionStorageKey) {
            let savedRefresh = UserDefaults.standard.string(forKey: refreshTokenStorageKey)
            Task { @MainActor in
                accessToken = saved
                refreshToken = savedRefresh
                isAuthenticated = true
                await loadCurrentUser()
            }
        }
    }

    // MARK: - Authentication

    func sendOTP(to phoneNumber: String) async throws {
        let request = AuthRequest(phone: phoneNumber)
        let _: [String: String] = try await performRequest(
            path: "/api/auth/send-otp",
            method: .post,
            body: request
        )
    }

    func verifyOTP(phone: String, otp: String) async throws {
        let request = VerifyOTPRequest(phone: phone, otp: otp)
        let response: AuthResponse = try await performRequest(
            path: "/api/auth/verify-otp",
            method: .post,
            body: request
        )

        accessToken = response.accessToken
        refreshToken = response.refreshToken
        clearOnboardingCompletion()
        savePhone(response.phone)
        hasLoadedProfile = false
        await loadCurrentUser(force: true)
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        let request = AppleSignInRequest(idToken: idToken, nonce: nonce)
        let response: AuthResponse = try await performRequest(
            path: "/api/auth/apple-signin",
            method: .post,
            body: request
        )

        accessToken = response.accessToken
        refreshToken = response.refreshToken
        clearOnboardingCompletion()
        savePhone(response.phone)
        hasLoadedProfile = false
        await loadCurrentUser(force: true)
    }

    func signInWithPhone(phoneNumber: String) async throws {
        // Create a test user directly with the phone number
        // This simulates the OTP verification process
        let request = VerifyOTPRequest(phone: phoneNumber, otp: "123456")
        let response: AuthResponse = try await performRequest(
            path: "/api/auth/verify-otp",
            method: .post,
            body: request
        )

        accessToken = response.accessToken
        refreshToken = response.refreshToken
        clearOnboardingCompletion()
        savePhone(response.phone)
        hasLoadedProfile = false
        await loadCurrentUser(force: true)
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        hasLoadedProfile = false
        isLoadingProfile = false
        requiresProfileSetup = false
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenStorageKey)
        clearStoredPhone()
        clearOnboardingCompletion()
    }

    // MARK: - Profile

    func loadCurrentUser(force: Bool = false) async {
        guard isAuthenticated else { return }
        if isLoadingProfile && !force { return }

        isLoadingProfile = true
        defer {
            isLoadingProfile = false
            hasLoadedProfile = true
        }

        do {
            let profile: ProfileRecord = try await performRequest(
                path: "/api/profiles/me",
                method: .get,
                requiresAuth: true
            )

            let persistedPhone = storedPhone()

            // Convert to User model (you may need to adjust this mapping)
            let user = User(
                id: profile.id,
                phone: persistedPhone,
                displayName: profile.displayName,
                avatarUrl: profile.avatarUrl,
                timezone: profile.timezone,
                dayStartHour: profile.dayStartHour,
                theme: profile.theme
            )

            currentUser = user
            evaluateProfileSetup(for: user)
        } catch {
            print("Failed to load current user: \(error)")
        }
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> User {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let profile: ProfileRecord = try await performRequest(
            path: "/api/profiles/me",
            method: .patch,
            body: update,
            requiresAuth: true
        )

        let user = User(
            id: profile.id,
            phone: currentUser?.phone ?? "",
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
        // For now, just update locally since FastAPI backend handles phone in auth
        if var user = currentUser {
            user.phone = phoneNumber
            currentUser = user
            savePhone(phoneNumber)
            evaluateProfileSetup(for: user)
        }
    }

    func getMyProfile() async throws -> User {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        await loadCurrentUser()
        guard let currentUser else { throw FastAPIError.serverError(404, "Profile not found") }
        return currentUser
    }

    func markProfileSetupComplete() {
        requiresProfileSetup = false
        persistOnboardingCompletion()
    }

    func bootstrapIfNeeded() async {
        guard isAuthenticated, !hasLoadedProfile else { return }
        await loadCurrentUser()
    }

    func deleteAccount() async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let _: EmptyResponse = try await performRequest(
            path: "/api/auth/me",
            method: .delete,
            requiresAuth: true
        )

        logout()
    }

    // MARK: - Habits

    func getHabits(includeLogs: Bool = false, days: Int = 30) async throws -> [Habit] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/"
        if includeLogs {
            path += "?include_logs=true&days=\(days)"
        }

        let response: [HabitWithLogsResponse] = try await performRequest(
            path: path,
            method: .get,
            requiresAuth: true
        )

        return response.map { habitResponse in
            Habit(
                id: habitResponse.id.uuidString,
                userId: habitResponse.user_id.uuidString,
                name: habitResponse.name,
                emoji: habitResponse.emoji,
                colorHex: habitResponse.color_hex,
                type: HabitType(rawValue: habitResponse.type.rawValue) ?? .checkbox,
                targetPerDay: habitResponse.target_per_day,
                scheduleDaily: habitResponse.schedule_daily,
                scheduleWeekmask: habitResponse.schedule_weekmask,
                isActive: habitResponse.is_active,
                createdAt: habitResponse.created_at,
                updatedAt: habitResponse.updated_at,
                recentLogs: habitResponse.recent_logs?.map { logResponse in
                    HabitLog(
                        id: logResponse.id.uuidString,
                        habitId: logResponse.habit_id.uuidString,
                        userId: logResponse.user_id.uuidString,
                        logDate: ISO8601DateFormatter().string(from: logResponse.log_date),
                        value: logResponse.value,
                        source: logResponse.source,
                        createdAt: logResponse.created_at
                    )
                } ?? []
            )
        }
    }

    func createHabit(_ habit: CreateHabitRequest) async throws -> Habit {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let habitResponse: HabitResponse = try await performRequest(
            path: "/api/habits/",
            method: .post,
            body: habit,
            requiresAuth: true
        )

        return Habit(
            id: habitResponse.id.uuidString,
            userId: habitResponse.user_id.uuidString,
            name: habitResponse.name,
            emoji: habitResponse.emoji,
            colorHex: habitResponse.color_hex,
            type: HabitType(rawValue: habitResponse.type.rawValue) ?? .checkbox,
            targetPerDay: habitResponse.target_per_day,
            scheduleDaily: habitResponse.schedule_daily,
            scheduleWeekmask: habitResponse.schedule_weekmask,
            isActive: habitResponse.is_active,
            createdAt: habitResponse.created_at,
            updatedAt: habitResponse.updated_at
        )
    }

    func logHabit(habitId: String, value: Int) async throws -> HabitLog {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let logRequest = HabitLogCreateRequest(value: value)
        let logResponse: HabitLogResponse = try await performRequest(
            path: "/api/habits/\(habitId)/log",
            method: .post,
            body: logRequest,
            requiresAuth: true
        )

        return HabitLog(
            id: logResponse.id.uuidString,
            habitId: logResponse.habit_id.uuidString,
            userId: logResponse.user_id.uuidString,
            logDate: ISO8601DateFormatter().string(from: logResponse.log_date),
            value: logResponse.value,
            source: logResponse.source,
            createdAt: logResponse.created_at
        )
    }

    func deleteHabitLog(habitId: String, logDate: Date? = nil) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/\(habitId)/log"
        if let logDate = logDate {
            let dateString = ISO8601DateFormatter().string(from: logDate)
            path += "?log_date=\(dateString)"
        }

        let _: EmptyResponse = try await performRequest(
            path: path,
            method: .delete,
            requiresAuth: true
        )
    }

    func deleteHabit(habitId: String) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let _: EmptyResponse = try await performRequest(
            path: "/api/habits/\(habitId)",
            method: .delete,
            requiresAuth: true
        )
    }

    func getHabit(habitId: String, includeLogs: Bool = true) async throws -> Habit {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/\(habitId)"
        if includeLogs {
            path += "?include_logs=true"
        }

        let habitResponse: HabitWithLogsResponse = try await performRequest(
            path: path,
            method: .get,
            requiresAuth: true
        )

        return Habit(
            id: habitResponse.id.uuidString,
            userId: habitResponse.user_id.uuidString,
            name: habitResponse.name,
            emoji: habitResponse.emoji,
            colorHex: habitResponse.color_hex,
            type: HabitType(rawValue: habitResponse.type.rawValue) ?? .checkbox,
            targetPerDay: habitResponse.target_per_day,
            scheduleDaily: habitResponse.schedule_daily,
            scheduleWeekmask: habitResponse.schedule_weekmask,
            isActive: habitResponse.is_active,
            createdAt: habitResponse.created_at,
            updatedAt: habitResponse.updated_at,
            recentLogs: habitResponse.recent_logs?.map { logResponse in
                HabitLog(
                    id: logResponse.id.uuidString,
                    habitId: logResponse.habit_id.uuidString,
                    userId: logResponse.user_id.uuidString,
                    logDate: ISO8601DateFormatter().string(from: logResponse.log_date),
                    value: logResponse.value,
                    source: logResponse.source,
                    createdAt: logResponse.created_at
                )
            } ?? []
        )
    }

    func getHabitLogs(habitId: String, startDate: Date? = nil, endDate: Date? = nil) async throws -> [HabitLog] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/\(habitId)/logs"
        var queryItems: [String] = []

        if let startDate = startDate {
            let dateString = ISO8601DateFormatter().string(from: startDate)
            queryItems.append("start_date=\(dateString)")
        }

        if let endDate = endDate {
            let dateString = ISO8601DateFormatter().string(from: endDate)
            queryItems.append("end_date=\(dateString)")
        }

        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }

        let logsResponse: [HabitLogResponse] = try await performRequest(
            path: path,
            method: .get,
            requiresAuth: true
        )

        return logsResponse.map { logResponse in
            HabitLog(
                id: logResponse.id.uuidString,
                habitId: logResponse.habit_id.uuidString,
                userId: logResponse.user_id.uuidString,
                logDate: ISO8601DateFormatter().string(from: logResponse.log_date),
                value: logResponse.value,
                source: logResponse.source,
                createdAt: logResponse.created_at
            )
        }
    }

    // MARK: - Hives (Stub implementations - to be completed based on your backend)

    func getHives() async throws -> [Hive] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        return []
    }

    func createHiveFromHabit(habitId: String, name: String?, backfillDays: Int) async throws -> Hive {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func joinHive(code: String) async throws -> Hive {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func getHiveDetail(hiveId: String) async throws -> HiveDetail {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func logHiveDay(hiveId: String, value: Int) async throws -> HiveMemberDay {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func createHiveInvite(hiveId: String, ttlMinutes: Int = 10080, maxUses: Int = 20) async throws -> HiveInvite {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func deleteHive(hiveId: String) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when hives endpoint is ready
        throw FastAPIError.serverError(501, "Hives not implemented yet")
    }

    func getActivityFeed(hiveId: String? = nil, limit: Int = 50) async throws -> [ActivityEvent] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement when activity endpoint is ready
        return []
    }

    // MARK: - Insights

    func getInsightsSummary() async throws -> InsightsSummary {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let response: InsightsSummaryResponse = try await performRequest(
            path: "/api/habits/insights/summary",
            method: .get,
            requiresAuth: true
        )

        return InsightsSummary(
            overallCompletion: response.overall_completion,
            activeHabits: response.active_habits,
            completedToday: response.completed_today,
            weeklyProgress: response.weekly_progress,
            currentStreaks: response.current_streaks.map { streak in
                HabitStreakDisplay(
                    id: streak.habit_id,
                    name: streak.name,
                    emoji: streak.emoji,
                    streak: streak.streak
                )
            },
            yearComb: response.year_comb,
            bestPerforming: response.best_performing.map { perf in
                HabitPerformanceSummary(
                    id: perf.habit_id,
                    name: perf.name,
                    emoji: perf.emoji,
                    completionRate: perf.completion_rate
                )
            }
        )
    }

    // MARK: - Contacts (Stub implementation)

    func uploadContacts(_ contacts: [ContactHashPayload]) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        // TODO: Implement contacts upload endpoint
    }

    // MARK: - Private Helpers

    private func storedPhone() -> String {
        UserDefaults.standard.string(forKey: phoneStorageKey) ?? ""
    }

    private func savePhone(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearStoredPhone()
        } else {
            UserDefaults.standard.set(trimmed, forKey: phoneStorageKey)
        }
    }

    private func clearStoredPhone() {
        UserDefaults.standard.removeObject(forKey: phoneStorageKey)
    }

    private var hasStoredOnboardingCompletion: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }

    private func persistOnboardingCompletion() {
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
    }

    private func clearOnboardingCompletion() {
        UserDefaults.standard.removeObject(forKey: onboardingCompleteKey)
    }

    private func evaluateProfileSetup(for user: User) {
        if hasStoredOnboardingCompletion {
            requiresProfileSetup = false
            return
        }

        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsName = trimmedName.isEmpty || trimmedName.lowercased() == "new bee" || trimmedName.hasPrefix("Bee ")
        let needsPhone = user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        requiresProfileSetup = needsName || needsPhone
    }

    private func performRequest<T: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw FastAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FastAPIError.networkError("Invalid response")
            }

            if httpResponse.statusCode == 401 {
                await MainActor.run { logout() }
                throw FastAPIError.unauthorized
            }

            if httpResponse.statusCode >= 400 {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw FastAPIError.serverError(httpResponse.statusCode, message)
            }

            if data.isEmpty {
                // Handle empty responses for generic types
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: Data("{}".utf8))
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as FastAPIError {
            throw error
        } catch {
            throw FastAPIError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Helper types

private struct AnyEncodable: Encodable {
    private let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct EmptyResponse: Decodable {
    init() {}
}

// Response models that match your FastAPI backend
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

private struct HabitTypeResponse: Decodable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }
}

private struct HabitResponse: Decodable {
    let id: UUID
    let user_id: UUID
    let name: String
    let emoji: String?
    let color_hex: String
    let type: HabitTypeResponse
    let target_per_day: Int
    let schedule_daily: Bool
    let schedule_weekmask: Int
    let is_active: Bool
    let created_at: Date
    let updated_at: Date
}

private struct HabitWithLogsResponse: Decodable {
    let id: UUID
    let user_id: UUID
    let name: String
    let emoji: String?
    let color_hex: String
    let type: HabitTypeResponse
    let target_per_day: Int
    let schedule_daily: Bool
    let schedule_weekmask: Int
    let is_active: Bool
    let created_at: Date
    let updated_at: Date
    let recent_logs: [HabitLogResponse]?
    let current_streak: Int?
    let completion_rate: Double?
}

private struct HabitLogResponse: Decodable {
    let id: UUID
    let habit_id: UUID
    let user_id: UUID
    let log_date: Date
    let value: Int
    let source: String
    let created_at: Date
}

private struct HabitLogCreateRequest: Encodable {
    let value: Int
}

// Insights Response Models
private struct InsightsSummaryResponse: Decodable {
    let overall_completion: Double
    let active_habits: Int
    let completed_today: Int
    let weekly_progress: [Int]
    let current_streaks: [HabitStreakResponse]
    let year_comb: [String: Int]
    let best_performing: HabitPerformanceResponse?
}

private struct HabitStreakResponse: Decodable {
    let habit_id: UUID
    let name: String
    let emoji: String?
    let streak: Int
}

private struct HabitPerformanceResponse: Decodable {
    let habit_id: UUID
    let name: String
    let emoji: String?
    let completion_rate: Double
}
