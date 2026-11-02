import Foundation
import CryptoKit

// Synthetic provider, fixed test entropy, fake vault. No HTTP or SecItem calls.
enum AuthFailure: Error, Equatable { case state, redirect, consumed, stale, locked, denied }
struct Credentials: Equatable, Sendable { let access: String; let refresh: String }
func s256(_ verifier: String) -> String {
    Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
struct AuthAttempt: Equatable, Sendable {
    let epoch: UUID
    let state: String
    let verifier: String
    var challenge: String { s256(verifier) }
}
struct FakeVault: Sendable {
    var locked = false
    var deletionDenied = false
    private(set) var credentials: Credentials?
    mutating func save(_ value: Credentials) throws {
        guard !locked else { throw AuthFailure.locked }
        credentials = value
    }
    mutating func clear() throws {
        guard !deletionDenied else { throw AuthFailure.denied }
        credentials = nil
    }
}
actor MockProvider {
    private var codes: [String: String] = [:]
    private var refreshes: Set<String> = []
    private var counter = 0
    func authorize(challenge: String) -> String {
        counter += 1
        let code = "synthetic-code-\(counter)"
        codes[code] = challenge
        return code
    }
    func exchange(code: String, verifier: String) throws -> Credentials {
        guard let challenge = codes[code], challenge == s256(verifier) else { throw AuthFailure.denied }
        codes[code] = nil
        let refresh = "synthetic-refresh-\(counter)-\(UUID())"
        refreshes.insert(refresh)
        return Credentials(access: "synthetic-access", refresh: refresh)
    }
    func refresh(_ token: String) throws -> Credentials {
        guard refreshes.remove(token) != nil else { throw AuthFailure.denied }
        let next = "synthetic-refresh-\(UUID())"
        refreshes.insert(next)
        return Credentials(access: "synthetic-refreshed-access", refresh: next)
    }
}
actor AuthSession {
    private var epoch = UUID()
    private var pending: AuthAttempt?
    private var vault = FakeVault()
    private var current: Credentials?
    private var cleanupPending = false
    // Production must inject cryptographically random state/verifier, never these constants.
    func begin(state: String, verifier: String) -> AuthAttempt {
        epoch = UUID()
        let attempt = AuthAttempt(epoch: epoch, state: state, verifier: verifier)
        pending = attempt
        return attempt
    }
    func acceptCallback(_ url: URL, attempt: AuthAttempt) throws -> String {
        guard pending == attempt, epoch == attempt.epoch else { throw AuthFailure.stale }
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "durablelab", parts.host == "oauth", parts.path == "/callback",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil else {
            throw AuthFailure.redirect
        }
        let items = parts.queryItems ?? []
        guard items.filter({ $0.name == "state" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == attempt.state else { throw AuthFailure.state }
        guard items.filter({ $0.name == "code" }).count == 1,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthFailure.consumed
        }
        pending = nil // One callback acceptance. Exchange may still fail.
        return code
    }
    func install(_ credentials: Credentials, epoch captured: UUID) throws {
        try Task.checkCancellation()
        guard epoch == captured, !cleanupPending else { throw AuthFailure.stale }
        try vault.save(credentials)
        current = credentials
    }
    func login(url: URL, attempt: AuthAttempt, provider: MockProvider) async throws {
        let code = try acceptCallback(url, attempt: attempt)
        let credentials = try await provider.exchange(code: code, verifier: attempt.verifier)
        try install(credentials, epoch: attempt.epoch)
    }
    func refresh(provider: MockProvider) async throws {
        // Intentionally single-caller; no coalescing. If rotation succeeds but
        // vault.save fails, the old refresh token is consumed. This mock has no
        // reconciliation endpoint: reauthenticate rather than blindly retry.
        guard let current else { throw AuthFailure.denied }
        let captured = epoch
        let next = try await provider.refresh(current.refresh)
        try install(next, epoch: captured)
    }
    func logout() throws {
        epoch = UUID()
        pending = nil
        current = nil // Local authorization closes even if vault deletion fails.
        cleanupPending = true
        try vault.clear()
        cleanupPending = false
    }
    func retryCleanup() throws { try vault.clear(); cleanupPending = false }
    func setVault(locked: Bool, deletionDenied: Bool = false) {
        vault.locked = locked; vault.deletionDenied = deletionDenied
    }
    func credential() -> Credentials? { current }
    func needsCleanup() -> Bool { cleanupPending }
}
