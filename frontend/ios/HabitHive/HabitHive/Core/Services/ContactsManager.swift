import Foundation
import Contacts
import CryptoKit

struct ContactsManager {
    static let shared = ContactsManager()
    private init() {}

    func requestAccess(completion: @escaping (Bool) -> Void) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func fetchPhoneHashes(pepper: String = SupabaseConfiguration.contactPepper, defaultRegion: String = "US") -> [String] {
        let store = CNContactStore()
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var hashes: [String] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                for phone in contact.phoneNumbers {
                    let raw = phone.value.stringValue
                    if let e164 = normalizeToE164(raw: raw, region: defaultRegion) {
                        let hashed = sha256Hex(pepper + e164)
                        hashes.append(hashed)
                    }
                }
            }
        } catch {
            return []
        }
        return Array(Set(hashes))
    }

    private func normalizeToE164(raw: String, region: String) -> String? {
        // Lightweight normalization: strip non-digits, add + if missing, assume region country code if needed.
        // For production, prefer PhoneNumberKit or libPhoneNumber.
        let digits = raw.filter({ "0123456789+".contains($0) })
        if digits.hasPrefix("+") {
            return digits
        }
        // Assume US if no country code
        if region.uppercased() == "US" {
            let onlyDigits = digits.filter({ $0.isNumber })
            if onlyDigits.count == 10 { return "+1" + onlyDigits }
        }
        return nil
    }

    private func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
