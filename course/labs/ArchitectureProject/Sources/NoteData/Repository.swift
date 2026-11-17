import Foundation
import NoteDomain

public struct LiveClock: ProjectClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    public init() { origin = ContinuousClock().now }
    public func now() async -> Duration { origin.duration(to: clock.now) }
    public func sleep(for duration: Duration) async throws { try await clock.sleep(for: duration) }
}

public struct SyntheticReader: NoteReading {
    public init() {}
    public func load(account: String) async throws -> [Note] {
        try Task.checkCancellation()
        return [Note(id: "n1", title: "\(account): Bridge sketch"),
                Note(id: "n2", title: "\(account): Garden plan")]
    }
}

public actor NoteRepository: NoteAccess {
    private let account: String
    private let reader: any NoteReading
    private let clock: any ProjectClock
    private let ttl: Duration
    private var active = true
    private var generation = 0
    private var cache: (notes: [Note], time: Duration)?
    private var savedIDs = Set<String>()

    public init(account: String, reader: any NoteReading, clock: any ProjectClock, ttl: Duration = .seconds(5)) {
        precondition(ttl > .zero)
        self.account = account; self.reader = reader; self.clock = clock; self.ttl = ttl
    }

    public func notes(_ freshness: Freshness) async throws -> [Note] {
        try requireActive()
        let now = await clock.now()
        try requireActive()
        if case .cacheAllowed = freshness, let cache, now - cache.time < ttl {
            return cache.notes
        }
        generation += 1
        let ticket = generation
        let loaded = try await reader.load(account: account)
        let time = await clock.now()
        try requireActive()
        guard ticket == generation else { throw NoteFailure.staleRequest }
        let checked = try validated(loaded)
        // No suspension between the final authority checks and commit.
        cache = (checked, time)
        savedIDs.formIntersection(Set(checked.map(\.id)))
        return checked
    }

    public func toggleSaved(id: String) throws {
        try requireActive()
        guard cache?.notes.contains(where: { $0.id == id }) == true else { throw NoteFailure.missingRecord }
        if !savedIDs.insert(id).inserted { savedIDs.remove(id) }
    }

    public func saved() throws -> [Note] {
        try requireActive()
        return (cache?.notes ?? []).filter { savedIDs.contains($0.id) }
    }

    public func detail(id: String) throws -> Note {
        try requireActive()
        guard let note = cache?.notes.first(where: { $0.id == id }) else { throw NoteFailure.missingRecord }
        return note
    }

    public func invalidate() {
        active = false; generation += 1; cache = nil; savedIDs.removeAll()
    }

    private func requireActive() throws {
        try Task.checkCancellation()
        guard active else { throw NoteFailure.expiredAccount }
    }
}
