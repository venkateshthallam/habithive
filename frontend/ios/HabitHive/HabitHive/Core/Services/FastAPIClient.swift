import Foundation
import Combine
import UIKit

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

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
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
    private let dayFormatter: DateFormatter
    private let sessionStorageKey = "fastapi.session"
    private let refreshTokenStorageKey = "fastapi.refreshToken"
    private let phoneStorageKey = "fastapi.phone"
    private let onboardingCompleteKey = "fastapi.onboardingComplete"

    private var accessTokenExpiry: Date?
    private var accessToken: String? {
        didSet {
            storeAccessToken(accessToken)
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
        dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"

        // Set up date formatting for your FastAPI backend
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = ISO8601DateFormatter.full.date(from: string) {
                return date
            }

            if let date = ISO8601DateFormatter.withoutFractional.date(from: string) {
                return date
            }

            if let date = DateFormats.apiDay.date(from: string) {
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

        applyAuthResponse(response)
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

        applyAuthResponse(response)
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

        applyAuthResponse(response)
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
            let resolvedPhone = profile.phone ?? persistedPhone
            savePhone(resolvedPhone)

            // Convert to User model (you may need to adjust this mapping)
            let user = User(
                id: profile.id,
                phone: resolvedPhone,
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

        let resolvedPhone = profile.phone ?? currentUser?.phone ?? ""
        savePhone(resolvedPhone)

        let user = User(
            id: profile.id,
            phone: resolvedPhone,
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
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let normalized = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let _ = try await updateProfile(ProfileUpdate(phone: normalized.isEmpty ? nil : normalized))
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
            print("🟡 Processing habit response: \(habitResponse.name) with \(habitResponse.recent_logs?.count ?? 0) logs")

            let recentLogs: [HabitLog] = habitResponse.recent_logs?.map { logResponse in
                let logDateString = dayFormatter.string(from: logResponse.log_date)
                print("🟡 Converting log: date=\(logResponse.log_date) -> dateString=\(logDateString), value=\(logResponse.value)")

                return HabitLog(
                    id: logResponse.id.uuidString,
                    habitId: logResponse.habit_id.uuidString,
                    userId: logResponse.user_id.uuidString,
                    logDate: logDateString,
                    value: logResponse.value,
                    source: logResponse.source,
                    createdAt: logResponse.created_at
                )
            } ?? []

            print("🟡 Final habit logs count: \(recentLogs.count)")
            recentLogs.forEach { log in
                print("🟡 Final log: id=\(log.id), date=\(log.logDate), value=\(log.value)")
            }

            var habitModel = Habit(
                id: habitResponse.id.uuidString,
                userId: habitResponse.user_id.uuidString,
                name: habitResponse.name,
                emoji: habitResponse.emoji,
                colorHex: habitResponse.color_hex,
                type: HabitType(rawValue: habitResponse.type.rawValue) ?? .checkbox,
                targetPerDay: habitResponse.target_per_day,
                scheduleDaily: habitResponse.schedule_daily,
                scheduleWeekmask: habitResponse.schedule_weekmask,
                reminderEnabled: habitResponse.reminder_enabled,
                reminderTime: habitResponse.reminder_time,
                isActive: habitResponse.is_active,
                createdAt: habitResponse.created_at,
                updatedAt: habitResponse.updated_at,
                recentLogs: recentLogs
            )

            habitModel.currentStreak = habitResponse.current_streak
            habitModel.completionRate = habitResponse.completion_rate
            return habitModel
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
            reminderEnabled: habitResponse.reminder_enabled,
            reminderTime: habitResponse.reminder_time,
            isActive: habitResponse.is_active,
            createdAt: habitResponse.created_at,
            updatedAt: habitResponse.updated_at
        )
    }

    func logHabit(habitId: String, value: Int, on date: Date? = nil) async throws -> HabitLog {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        let timestamp: Date
        if let date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone.current
            timestamp = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        } else {
            timestamp = Date()
        }

        let logDateString = date.map { dayFormatter.string(from: $0) }
        let logRequest = HabitLogCreateRequest(value: value, clientTimestamp: timestamp, logDate: logDateString)
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
            logDate: dayFormatter.string(from: logResponse.log_date),
            value: logResponse.value,
            source: logResponse.source,
            createdAt: logResponse.created_at
        )
    }

    func deleteHabitLog(habitId: String, logDate: Date? = nil) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/\(habitId)/log"
        if let logDate = logDate {
            let dateString = dayFormatter.string(from: logDate)
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

        var habit = Habit(
            id: habitResponse.id.uuidString,
            userId: habitResponse.user_id.uuidString,
            name: habitResponse.name,
            emoji: habitResponse.emoji,
            colorHex: habitResponse.color_hex,
            type: HabitType(rawValue: habitResponse.type.rawValue) ?? .checkbox,
            targetPerDay: habitResponse.target_per_day,
            scheduleDaily: habitResponse.schedule_daily,
            scheduleWeekmask: habitResponse.schedule_weekmask,
            reminderEnabled: habitResponse.reminder_enabled,
            reminderTime: habitResponse.reminder_time,
            isActive: habitResponse.is_active,
            createdAt: habitResponse.created_at,
            updatedAt: habitResponse.updated_at,
            recentLogs: habitResponse.recent_logs?.map { logResponse in
                HabitLog(
                    id: logResponse.id.uuidString,
                    habitId: logResponse.habit_id.uuidString,
                    userId: logResponse.user_id.uuidString,
                    logDate: dayFormatter.string(from: logResponse.log_date),
                    value: logResponse.value,
                    source: logResponse.source,
                    createdAt: logResponse.created_at
                )
            } ?? []
        )

        habit.currentStreak = habitResponse.current_streak
        habit.completionRate = habitResponse.completion_rate
        return habit
    }

    func getHabitLogs(habitId: String, startDate: Date? = nil, endDate: Date? = nil) async throws -> [HabitLog] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/habits/\(habitId)/logs"
        var queryItems: [String] = []

        if let startDate = startDate {
            let dateString = dayFormatter.string(from: startDate)
            queryItems.append("start_date=\(dateString)")
        }

        if let endDate = endDate {
            let dateString = dayFormatter.string(from: endDate)
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
                logDate: dayFormatter.string(from: logResponse.log_date),
                value: logResponse.value,
                source: logResponse.source,
                createdAt: logResponse.created_at
            )
        }
    }

    // MARK: - Hives

    func getHives() async throws -> HiveOverview {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let response: HiveOverviewResponseDTO = try await performRequest(
            path: "/api/hives/",
            method: .get,
            requiresAuth: true
        )
        return HiveOverview(
            hives: response.hives.map { $0.toDomain() },
            leaderboard: response.leaderboard.map { $0.toDomain() }
        )
    }

    func createHiveFromHabit(habitId: String, name: String?, backfillDays: Int) async throws -> Hive {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let request = CreateHiveFromHabitPayload(
            habitId: habitId,
            name: name,
            backfillDays: backfillDays
        )

        return try await performRequest(
            path: "/api/hives/from-habit",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func updateHive(hiveId: String, update: HiveUpdatePayload) async throws -> Hive {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        return try await performRequest(
            path: "/api/hives/\(hiveId)",
            method: .patch,
            body: update,
            requiresAuth: true
        )
    }

    func deleteHive(hiveId: String) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let _: EmptyResponse = try await performRequest(
            path: "/api/hives/\(hiveId)",
            method: .delete,
            requiresAuth: true
        )
    }

    func joinHive(code: String) async throws -> HiveJoinResult {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let request = JoinHivePayload(code: code)
        let response: JoinHiveResponse = try await performRequest(
            path: "/api/hives/join",
            method: .post,
            body: request,
            requiresAuth: true
        )

        return HiveJoinResult(success: response.success, hiveId: response.hiveId, message: response.message)
    }

    func leaveHive(hiveId: String) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let _: EmptyResponse = try await performRequest(
            path: "/api/hives/\(hiveId)/leave",
            method: .post,
            requiresAuth: true
        )
    }

    func getHiveDetail(hiveId: String) async throws -> HiveDetail {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let response: HiveDetailResponse = try await performRequest(
            path: "/api/hives/\(hiveId)",
            method: .get,
            requiresAuth: true
        )

        return response.toDomain()
    }

    func logHiveDay(hiveId: String, value: Int) async throws -> HiveMemberDay {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let request = LogHivePayload(value: value)
        return try await performRequest(
            path: "/api/hives/\(hiveId)/log",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func createHiveInvite(hiveId: String, ttlMinutes: Int = 10080, maxUses: Int = 20) async throws -> HiveInvite {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        let request = HiveInviteRequest(ttlMinutes: ttlMinutes, maxUses: maxUses)
        return try await performRequest(
            path: "/api/hives/\(hiveId)/invite",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func getActivityFeed(hiveId: String? = nil, limit: Int = 50) async throws -> [ActivityEvent] {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        var path = "/api/activity/feed?limit=\(limit)"
        if let hiveId {
            path += "&hive_id=\(hiveId)"
        }

        return try await performRequest(
            path: path,
            method: .get,
            requiresAuth: true
        )
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

    func getInsightsDashboard() async throws -> InsightsDashboard {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        return try await performRequest(
            path: "/api/habits/insights/dashboard",
            method: .get,
            requiresAuth: true
        )
    }

    func getYearOverview(year: Int? = nil) async throws -> YearOverviewModel {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        var path = "/api/activity/year-overview"
        if let year {
            path += "?year=\(year)"
        }

        return try await performRequest(
            path: path,
            method: .get,
            requiresAuth: true
        )
    }

    // MARK: - Contacts (Stub implementation)

    func uploadContacts(_ contacts: [ContactHashPayload]) async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }
        guard !contacts.isEmpty else { return }

        let payload = ContactUploadPayload(contacts: contacts)
        let _: EmptyResponse = try await performRequest(
            path: "/api/contacts/upload",
            method: .post,
            body: payload,
            requiresAuth: true
        )
    }

    // MARK: - Device Registration (Push Notifications)

    func registerDevice(apnsToken: String, environment: String = "prod") async throws {
        guard isAuthenticated else { throw FastAPIError.unauthorized }

        #if targetEnvironment(simulator)
        print("⚠️ Skipping device registration on simulator")
        return
        #endif

        let request = DeviceRegistrationRequest(
            apnsToken: apnsToken,
            environment: environment,
            deviceModel: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )

        let response: DeviceRegistrationResponse = try await performRequest(
            path: "/api/devices/register",
            method: .post,
            body: request,
            requiresAuth: true
        )

        print("✅ Device registered with OneSignal player ID: \(response.onesignalPlayerId ?? "none")")
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

    private func storeAccessToken(_ token: String?) {
        accessTokenExpiry = token.flatMap(decodeExpirationDate(from:))
        isAuthenticated = token != nil

        if let token {
            UserDefaults.standard.set(token, forKey: sessionStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        }
    }

    private func decodeExpirationDate(from token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let exp = json["exp"] as? TimeInterval {
            return Date(timeIntervalSince1970: exp)
        }
        if let expInt = json["exp"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(expInt))
        }
        return nil
    }

    private func ensureValidAccessToken() async throws {
        guard let token = accessToken else {
            throw FastAPIError.unauthorized
        }

        if accessTokenExpiry == nil {
            accessTokenExpiry = decodeExpirationDate(from: token)
        }

        if let expiry = accessTokenExpiry, expiry.timeIntervalSinceNow <= 60 {
            try await refreshAccessToken()
        }
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken else { throw FastAPIError.unauthorized }
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let response: AuthResponse = try await performRequest(
            path: "/api/auth/refresh",
            method: .post,
            body: request,
            requiresAuth: false,
            retrying: true
        )
        applyAuthResponse(response)
    }

    private func attemptRefreshAfterUnauthorized() async -> Bool {
        guard refreshToken != nil else { return false }
        do {
            try await refreshAccessToken()
            return true
        } catch {
            return false
        }
    }

    private func applyAuthResponse(_ response: AuthResponse) {
        accessToken = response.accessToken
        if let newRefresh = response.refreshToken {
            refreshToken = newRefresh.isEmpty ? nil : newRefresh
        }
    }

    private func performRequest<T: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = false,
        retrying: Bool = false
    ) async throws -> T {

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw FastAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        if requiresAuth {
            try await ensureValidAccessToken()
            guard let token = accessToken else { throw FastAPIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FastAPIError.networkError("Invalid response")
            }

            if httpResponse.statusCode == 401 {
                if requiresAuth && !retrying {
                    let refreshed = await attemptRefreshAfterUnauthorized()
                    if refreshed {
                        return try await performRequest(
                            path: path,
                            method: method,
                            body: body,
                            requiresAuth: requiresAuth,
                            retrying: true
                        )
                    }
                }

                logout()
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

private enum DateFormats {
    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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

// Response models that match your FastAPI backend
private struct ProfileRecord: Decodable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let phone: String?
    let timezone: String
    let dayStartHour: Int
    let theme: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case phone
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
    let reminder_enabled: Bool
    let reminder_time: String?
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
    let reminder_enabled: Bool
    let reminder_time: String?
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
    let clientTimestamp: Date
    let logDate: String?

    enum CodingKeys: String, CodingKey {
        case value
        case clientTimestamp = "client_timestamp"
        case logDate = "log_date"
    }
}

private struct HiveOverviewResponseDTO: Decodable {
    let hives: [HiveSummaryResponse]
    let leaderboard: [HiveLeaderboardResponse]
}

private struct HiveSummaryResponse: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let ownerId: UUID
    let emoji: String?
    let colorHex: String
    let type: HabitTypeResponse
    let targetPerDay: Int
    let rule: String
    let threshold: Int?
    let scheduleDaily: Bool
    let scheduleWeekmask: Int
    let isActive: Bool
    let inviteCode: String?
    let maxMembers: Int?
    let currentLength: Int?
    let currentStreak: Int?
    let longestStreak: Int?
    let lastAdvancedOn: Date?
    let createdAt: Date
    let updatedAt: Date?
    let memberCount: Int?
    let avgCompletion: Double?

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
        case maxMembers = "max_members"
        case currentLength = "current_length"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastAdvancedOn = "last_advanced_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case avgCompletion = "avg_completion"
    }

    func toDomain() -> Hive {
        Hive(
            id: id.uuidString,
            name: name,
            description: description,
            ownerId: ownerId.uuidString,
            emoji: emoji,
            colorHex: colorHex,
            type: HabitType(rawValue: type.rawValue) ?? .checkbox,
            targetPerDay: targetPerDay,
            rule: rule,
            threshold: threshold,
            scheduleDaily: scheduleDaily,
            scheduleWeekmask: scheduleWeekmask,
            isActive: isActive,
            inviteCode: inviteCode,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt,
            memberCount: memberCount,
            maxMembers: maxMembers,
            currentLength: currentLength,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastAdvancedOn: lastAdvancedOn.map { DateFormats.apiDay.string(from: $0) },
            avgCompletion: avgCompletion
        )
    }
}

private struct HiveLeaderboardResponse: Decodable {
    let userId: UUID
    let displayName: String
    let avatarUrl: String?
    let completedToday: Int
    let totalHives: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case completedToday = "completed_today"
        case totalHives = "total_hives"
    }

    func toDomain() -> HiveLeaderboardEntry {
        HiveLeaderboardEntry(
            userId: userId.uuidString,
            displayName: displayName,
            avatarUrl: avatarUrl,
            completedToday: completedToday,
            totalHives: totalHives
        )
    }
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

private struct CreateHiveFromHabitPayload: Encodable {
    let habitId: String
    let name: String?
    let backfillDays: Int

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case name
        case backfillDays = "backfill_days"
    }
}

struct HiveUpdatePayload: Encodable {
    var name: String?
    var description: String?
    var emoji: String?
    var colorHex: String?
    var targetPerDay: Int?
    var rule: String?
    var threshold: Int?
    var scheduleDaily: Bool?
    var scheduleWeekmask: Int?
    var maxMembers: Int?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case emoji
        case colorHex = "color_hex"
        case targetPerDay = "target_per_day"
        case rule
        case threshold
        case scheduleDaily = "schedule_daily"
        case scheduleWeekmask = "schedule_weekmask"
        case maxMembers = "max_members"
        case isActive = "is_active"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(targetPerDay, forKey: .targetPerDay)
        try container.encodeIfPresent(rule, forKey: .rule)
        try container.encodeIfPresent(threshold, forKey: .threshold)
        try container.encodeIfPresent(scheduleDaily, forKey: .scheduleDaily)
        try container.encodeIfPresent(scheduleWeekmask, forKey: .scheduleWeekmask)
        try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        try container.encodeIfPresent(isActive, forKey: .isActive)
    }
}

private struct JoinHivePayload: Encodable {
    let code: String
}

private struct LogHivePayload: Encodable {
    let value: Int
}

private struct HiveInviteRequest: Encodable {
    let ttlMinutes: Int
    let maxUses: Int

    enum CodingKeys: String, CodingKey {
        case ttlMinutes = "ttl_minutes"
        case maxUses = "max_uses"
    }
}

private struct JoinHiveResponse: Decodable {
    let success: Bool
    let hiveId: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case hiveId = "hive_id"
        case message
    }
}

private struct ContactUploadPayload: Encodable {
    let contacts: [ContactHashPayload]
}

// MARK: - Device Registration Models

private struct DeviceRegistrationRequest: Encodable {
    let apnsToken: String
    let environment: String
    let deviceModel: String?
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case apnsToken = "apns_token"
        case environment
        case deviceModel = "device_model"
        case appVersion = "app_version"
    }
}

private struct DeviceRegistrationResponse: Decodable {
    let success: Bool
    let id: String?
    let onesignalPlayerId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case id
        case onesignalPlayerId = "onesignal_player_id"
    }
}

// MARK: - Hive Detail Responses

private struct HiveTodaySummaryResponse: Decodable {
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
}

private struct HiveMemberStatusResponse: Decodable {
    let hiveId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date
    let leftAt: Date?
    let isActive: Bool
    let displayName: String?
    let avatarUrl: String?
    let status: HiveMemberStatusState
    let value: Int
    let targetPerDay: Int

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

private struct HiveDetailResponse: Decodable {
    let id: UUID
    let name: String
    let ownerId: UUID
    let description: String?
    let emoji: String?
    let colorHex: String
    let type: HabitTypeResponse
    let targetPerDay: Int
    let rule: String
    let threshold: Int?
    let scheduleDaily: Bool
    let scheduleWeekmask: Int
    let isActive: Bool
    let inviteCode: String?
    let maxMembers: Int?
    let currentLength: Int?
    let currentStreak: Int?
    let longestStreak: Int?
    let lastAdvancedOn: Date?
    let createdAt: Date
    let updatedAt: Date?
    let memberCount: Int?
    let avgCompletion: Double
    let todaySummary: HiveTodaySummaryResponse
    let members: [HiveMemberStatusResponse]
    let recentActivity: [ActivityEvent]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case description
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
    }

    func toDomain() -> HiveDetail {
        HiveDetail(
            id: id.uuidString,
            name: name,
            ownerId: ownerId.uuidString,
            description: description,
            emoji: emoji,
            colorHex: colorHex,
            type: HabitType(rawValue: type.rawValue) ?? .checkbox,
            targetPerDay: targetPerDay,
            rule: rule,
            threshold: threshold,
            scheduleDaily: scheduleDaily,
            scheduleWeekmask: scheduleWeekmask,
            isActive: isActive,
            inviteCode: inviteCode,
            maxMembers: maxMembers,
            currentLength: currentLength,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastAdvancedOn: lastAdvancedOn.map { ISO8601DateFormatter().string(from: $0) },
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt,
            memberCount: memberCount,
            avgCompletion: avgCompletion,
            todaySummary: HiveTodaySummary(
                completed: todaySummary.completed,
                partial: todaySummary.partial,
                pending: todaySummary.pending,
                total: todaySummary.total,
                completionRate: todaySummary.completionRate
            ),
            members: members.map { response in
                HiveMemberStatus(
                    hiveId: response.hiveId.uuidString,
                    userId: response.userId.uuidString,
                    role: response.role,
                    joinedAt: response.joinedAt,
                    leftAt: response.leftAt,
                    isActive: response.isActive,
                    displayName: response.displayName,
                    avatarUrl: response.avatarUrl,
                    status: response.status,
                    value: response.value,
                    targetPerDay: response.targetPerDay
                )
            },
            recentActivity: recentActivity ?? []
        )
    }
}
