import Foundation

public struct Note: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
}

public enum NoteFailure: Error, Equatable, Sendable {
    case invalidRecord, duplicateID, staleRequest, expiredAccount, offline, missingRecord
}

public enum Freshness: Sendable { case cacheAllowed, reload }

public protocol NoteReading: Sendable {
    func load(account: String) async throws -> [Note]
}

// A deliberately narrow time seam, not a conformance to Swift.Clock.
public protocol ProjectClock: Sendable {
    func now() async -> Duration
    func sleep(for duration: Duration) async throws
}

public protocol NoteAccess: Sendable {
    func notes(_ freshness: Freshness) async throws -> [Note]
    func toggleSaved(id: String) async throws
    func saved() async throws -> [Note]
    func detail(id: String) async throws -> Note
    func invalidate() async
}

public func validated(_ notes: [Note]) throws -> [Note] {
    var ids = Set<String>()
    for note in notes {
        guard !note.id.isEmpty, !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteFailure.invalidRecord
        }
        guard ids.insert(note.id).inserted else { throw NoteFailure.duplicateID }
    }
    return notes
}
