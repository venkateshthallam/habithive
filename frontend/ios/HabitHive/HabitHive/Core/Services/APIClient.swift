import Foundation
import Combine

// MARK: - Response Types for Generic Endpoints
struct SendOTPResponse: Codable {
    let success: Bool
    let message: String
    let testOtp: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case testOtp = "test_otp"
    }
}

struct GenericSuccessResponse: Codable {
    let success: Bool
    let message: String?
}

struct JoinHiveResponse: Codable {
    let success: Bool
    let hiveId: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case hiveId = "hive_id"
        case message
    }
}

struct LogHiveDayResponse: Codable {
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

struct UploadContactsResponse: Codable { let success: Bool; let inserted: Int }

struct RegisterDeviceResponse: Codable { let success: Bool; let id: String? }

// MARK: - API Configuration
struct APIConfig {
    static let baseURL = "http://192.168.4.121:8002/api"
    static let testMode = false // Disable test mode to use real Supabase auth
    static let testOTP = "123456"
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(String)
    case unauthorized
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// MARK: - API Client
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private var accessToken: String? {
        didSet {
            isAuthenticated = accessToken != nil
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try with microseconds first
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without microseconds
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try standard ISO8601
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private init() {
        // Load saved token if available
        if let token = UserDefaults.standard.string(forKey: "accessToken") {
            self.accessToken = token
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Request Builder
    private func buildRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        authenticated: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = body
        
        return request
    }

    // MARK: - Hive Detail
    func getHiveDetail(hiveId: String) -> AnyPublisher<HiveDetail, APIError> {
        do {
            let request = try buildRequest(path: "/hives/\(hiveId)")
            return performRequest(request, responseType: HiveDetail.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Base Request
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError("Invalid response")
                }
                
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
                
                return data
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError(error.localizedDescription)
                } else {
                    return APIError.networkError(error.localizedDescription)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Auth Endpoints
    func sendOTP(phone: String) -> AnyPublisher<Bool, APIError> {
        do {
            let body = try encoder.encode(["phone": phone])
            let request = try buildRequest(
                path: "/auth/send-otp",
                method: "POST",
                body: body,
                authenticated: false
            )
            
            return performRequest(request, responseType: SendOTPResponse.self)
                .map { _ in true }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func verifyOTP(phone: String, otp: String) -> AnyPublisher<AuthResponse, APIError> {
        do {
            let body = try encoder.encode(["phone": phone, "otp": otp])
            let request = try buildRequest(
                path: "/auth/verify-otp",
                method: "POST",
                body: body,
                authenticated: false
            )
            
            return performRequest(request, responseType: AuthResponse.self)
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.accessToken = response.accessToken
                    UserDefaults.standard.set(response.accessToken, forKey: "accessToken")
                    self?.isAuthenticated = true
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func logout() {
        accessToken = nil
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "accessToken")
    }
    
    // MARK: - Profile Endpoints
    func getMyProfile() -> AnyPublisher<User, APIError> {
        do {
            let request = try buildRequest(path: "/profiles/me")
            return performRequest(request, responseType: User.self)
                .handleEvents(receiveOutput: { [weak self] user in
                    self?.currentUser = user
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func updateProfile(_ update: ProfileUpdate) -> AnyPublisher<User, APIError> {
        do {
            let body = try encoder.encode(update)
            let request = try buildRequest(
                path: "/profiles/me",
                method: "PATCH",
                body: body
            )
            
            return performRequest(request, responseType: User.self)
                .handleEvents(receiveOutput: { [weak self] user in
                    self?.currentUser = user
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Habit Endpoints
    func getHabits(includeLogs: Bool = false, days: Int = 30) -> AnyPublisher<[Habit], APIError> {
        do {
            let path = "/habits/?include_logs=\(includeLogs)&days=\(days)"
            let request = try buildRequest(path: path)
            return performRequest(request, responseType: [Habit].self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func createHabit(_ habit: CreateHabitRequest) -> AnyPublisher<Habit, APIError> {
        do {
            let body = try encoder.encode(habit)
            let request = try buildRequest(
                path: "/habits/",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: Habit.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func logHabit(habitId: String, value: Int) -> AnyPublisher<HabitLog, APIError> {
        do {
            let body = try encoder.encode(LogHabitRequest(value: value))
            let request = try buildRequest(
                path: "/habits/\(habitId)/log",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: HabitLog.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func deleteHabit(habitId: String) -> AnyPublisher<Bool, APIError> {
        do {
            let request = try buildRequest(
                path: "/habits/\(habitId)",
                method: "DELETE"
            )
            
            return performRequest(request, responseType: GenericSuccessResponse.self)
                .map { _ in true }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Hive Endpoints
    func getHives() -> AnyPublisher<[Hive], APIError> {
        do {
            let request = try buildRequest(path: "/hives/")
            return performRequest(request, responseType: [Hive].self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func createHiveFromHabit(habitId: String, name: String?, backfillDays: Int = 30) -> AnyPublisher<Hive, APIError> {
        do {
            let body = try encoder.encode(
                CreateHiveFromHabitRequest(
                    habitId: habitId,
                    name: name,
                    backfillDays: backfillDays
                )
            )
            let request = try buildRequest(
                path: "/hives/from-habit",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: Hive.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func joinHive(code: String) -> AnyPublisher<JoinHiveResponse, APIError> {
        do {
            let body = try encoder.encode(JoinHiveRequest(code: code))
            let request = try buildRequest(
                path: "/hives/join",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: JoinHiveResponse.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func createHiveInvite(hiveId: String, ttlMinutes: Int = 10080, maxUses: Int = 20) -> AnyPublisher<HiveInvite, APIError> {
        do {
            let body = try JSONSerialization.data(withJSONObject: [
                "ttl_minutes": ttlMinutes,
                "max_uses": maxUses
            ])
            let request = try buildRequest(
                path: "/hives/\(hiveId)/invite",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: HiveInvite.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    func logHiveDay(hiveId: String, value: Int) -> AnyPublisher<LogHiveDayResponse, APIError> {
        do {
            let body = try JSONSerialization.data(withJSONObject: [
                "hive_id": hiveId,
                "value": value
            ])
            let request = try buildRequest(
                path: "/hives/\(hiveId)/log",
                method: "POST",
                body: body
            )
            
            return performRequest(request, responseType: LogHiveDayResponse.self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Activity Endpoints
    func getActivityFeed(hiveId: String? = nil, limit: Int = 50) -> AnyPublisher<[ActivityEvent], APIError> {
        do {
            var path = "/activity/feed?limit=\(limit)"
            if let hiveId = hiveId {
                path += "&hive_id=\(hiveId)"
            }
            let request = try buildRequest(path: path)
            return performRequest(request, responseType: [ActivityEvent].self)
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Insights
    func getInsightsSummary() -> AnyPublisher<InsightsSummary, APIError> {
        do {
            let request = try buildRequest(
                path: "/habits/insights/summary",
                method: "GET"
            )
            
            return performRequest(request, responseType: InsightsSummary.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Contacts
    struct ContactHash: Codable { let contact_hash: String; let display_name: String? }
    func uploadContacts(_ contacts: [ContactHash]) -> AnyPublisher<Bool, APIError> {
        do {
            let body = try encoder.encode(["contacts": contacts])
            let request = try buildRequest(
                path: "/contacts/upload",
                method: "POST",
                body: body
            )
            return performRequest(request, responseType: UploadContactsResponse.self)
                .map { $0.success }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Devices
    func registerDevice(apnsToken: String, environment: String = "prod", deviceModel: String? = nil, appVersion: String? = nil) -> AnyPublisher<Bool, APIError> {
        do {
            var payload: [String: Any] = [
                "apns_token": apnsToken,
                "environment": environment
            ]
            if let deviceModel = deviceModel { payload["device_model"] = deviceModel }
            if let appVersion = appVersion { payload["app_version"] = appVersion }
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = try buildRequest(
                path: "/devices/register",
                method: "POST",
                body: body
            )
            return performRequest(request, responseType: RegisterDeviceResponse.self)
                .map { $0.success }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? APIError ?? .networkError(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
}
