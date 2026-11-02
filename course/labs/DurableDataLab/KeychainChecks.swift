import Foundation
import Security

@main struct KeychainChecks {
    static func main() throws {
        let query = syntheticAddQuery(account: "synthetic-A", bytes: Data("fake-token".utf8))
        guard query[kSecAttrService as String] as? String == "example.course.DurableDataLab.synthetic",
              query[kSecAttrAccount as String] as? String == "synthetic-A",
              query[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
              classify(errSecItemNotFound) == .absent,
              classify(errSecInteractionNotAllowed) == .deferUntilAvailable,
              classify(errSecMissingEntitlement) == .configuration,
              classify(errSecDuplicateItem) == .duplicate else {
            throw NSError(domain: "KeychainDictionaryCheck", code: 1)
        }
        print("PASS Keychain: isolated synthetic identity, accessibility dictionary and OSStatus policy; no SecItem calls")
    }
}
