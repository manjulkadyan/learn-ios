import Foundation
import Security

// Constructs dictionaries only. It never calls SecItem or changes a keychain.
func syntheticKeychainIdentity(account: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "example.course.DurableDataLab.synthetic",
     kSecAttrAccount as String: account,
     kSecAttrSynchronizable as String: false]
}
func syntheticAddQuery(account: String, bytes: Data) -> [String: Any] {
    var query = syntheticKeychainIdentity(account: account)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    query[kSecValueData as String] = bytes
    return query
}
enum KeychainDecision: Equatable { case success, absent, deferUntilAvailable, duplicate, configuration, other(OSStatus) }
func classify(_ status: OSStatus) -> KeychainDecision {
    switch status {
    case errSecSuccess: return .success
    case errSecItemNotFound: return .absent
    case errSecInteractionNotAllowed, errSecNotAvailable: return .deferUntilAvailable
    case errSecDuplicateItem: return .duplicate
    case errSecMissingEntitlement, errSecParam: return .configuration
    default: return .other(status)
    }
}
#if os(iOS)
import UIKit
// Target-required seam. The scratch app owns notifications and actual file I/O.
@MainActor final class ProtectedDataGate {
    private let app: UIApplication
    init(app: UIApplication = .shared) { self.app = app }
    func mayAttemptOpen() -> Bool { app.isProtectedDataAvailable }
    func protectedFileOptions() -> Data.WritingOptions { [.atomic, .completeFileProtection] }
}
#endif
