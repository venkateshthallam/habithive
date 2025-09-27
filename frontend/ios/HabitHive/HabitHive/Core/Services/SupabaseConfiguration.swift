import Foundation

enum SupabaseConfiguration {
    private static let urlKey = "SUPABASE_URL"
    private static let anonKeyKey = "SUPABASE_ANON_KEY"
    private static let contactPepperKey = "SUPABASE_CONTACT_PEPPER"
    private static let authUrlKey = "SUPABASE_AUTH_URL"
    private static let restUrlKey = "SUPABASE_REST_URL"

    static var url: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        if let raw = ProcessInfo.processInfo.environment[urlKey],
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        // FastAPI backend URL - using actual machine IP for iOS simulator
        return URL(string: "http://192.168.4.121:8002")!
    }

    static var anonKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: anonKeyKey) as? String, !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment[anonKeyKey], !key.isEmpty {
            return key
        }
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6bHJ1YWN3eGd0Y3Vub3h0dHRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4NjcwNjUsImV4cCI6MjA3MzQ0MzA2NX0.4jmP_rZGm0-3nxQNOXEmis2dFrOCJ9XpuCrM9mGrMvY"
    }

    static var contactPepper: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: contactPepperKey) as? String, !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment[contactPepperKey], !key.isEmpty {
            return key
        }
        return "dev_contact_pepper"
    }

    static var restUrl: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: restUrlKey) as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        if let raw = ProcessInfo.processInfo.environment[restUrlKey],
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        // FastAPI backend URL
        return url
    }

    static var authUrl: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: authUrlKey) as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        if let raw = ProcessInfo.processInfo.environment[authUrlKey],
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        // FastAPI backend URL for auth
        return url
    }

    private static func projectRefFromAnonKey() -> String? {
        let key = anonKey
        let segments = key.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = String(segments[1])
        guard let data = decodeBase64URL(payloadSegment) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let ref = json["ref"] as? String
        else {
            return nil
        }

        return ref
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }

        return Data(base64Encoded: base64)
    }
}
