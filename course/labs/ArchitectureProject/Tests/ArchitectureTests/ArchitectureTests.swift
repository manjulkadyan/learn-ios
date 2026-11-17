import Foundation
import Testing
import NoteDomain
import NoteData
import BrowseFeature
import SavedFeature
import AppShell

private let first = Note(id: "n1", title: "Bridge sketch")
private let second = Note(id: "n2", title: "Garden plan")

private actor GateReader: NoteReading {
    private var calls: [String] = []
    private var pending: [Int: CheckedContinuation<[Note], any Error>] = [:]
    private var watchers: [(Int, CheckedContinuation<Void, Never>)] = []
    // Intentionally ignores task cancellation: test the consumer's commit checks.
    func load(account: String) async throws -> [Note] {
        let index = calls.count
        calls.append(account)
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            let ready = watchers.filter { calls.count >= $0.0 }
            watchers.removeAll { calls.count >= $0.0 }
            for (_, watcher) in ready { watcher.resume() }
        }
    }
    func waitForCalls(_ count: Int) async {
        if calls.count >= count { return }
        await withCheckedContinuation { watchers.append((count, $0)) }
    }
    func release(_ index: Int, _ result: Result<[Note], any Error>) {
        guard let waiter = pending.removeValue(forKey: index) else { preconditionFailure("Unknown request") }
        waiter.resume(with: result)
    }
    func count() -> Int { calls.count }
    func accounts() -> [String] { calls }
}

private actor TestClock: ProjectClock {
    private var time = Duration.zero
    private var sleeps: [UUID: (Duration, CheckedContinuation<Void, any Error>)] = [:]
    private var observers: [CheckedContinuation<Void, Never>] = []
    func now() -> Duration { time }
    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        guard duration > .zero else { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                sleeps[id] = (time + duration, continuation)
                let waiting = observers; observers.removeAll()
                for observer in waiting { observer.resume() }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }
    private func cancel(_ id: UUID) {
        sleeps.removeValue(forKey: id)?.1.resume(throwing: CancellationError())
    }
    func waitForSleep() async {
        if !sleeps.isEmpty { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func advance(by duration: Duration) {
        precondition(duration >= .zero)
        time += duration
        let ready = sleeps.filter { $0.value.0 <= time }
        for (id, value) in ready { sleeps[id] = nil; value.1.resume() }
    }
    func pendingCount() -> Int { sleeps.count }
}

private struct SavedFailureAccess: NoteAccess {
    let gate: GateReader
    func notes(_ freshness: Freshness) async throws -> [Note] { [first] }
    func saved() async throws -> [Note] { try await gate.load(account: "saved") }
    func toggleSaved(id: String) async throws { _ = try await gate.load(account: "toggle") }
    func detail(id: String) async throws -> Note { first }
    func invalidate() async {}
}

@Test @MainActor func resetSuppressesLateSavedErrors() async {
    for toggle in [false, true] {
        let gate = GateReader()
        let model = SavedModel(repository: SavedFailureAccess(gate: gate))
        let operation = Task {
            if toggle { await model.toggle(id: "n1") } else { await model.reload() }
        }
        await gate.waitForCalls(1)
        model.reset()
        await gate.release(0, .failure(NoteFailure.offline))
        await operation.value
        #expect(model.notes.isEmpty && !model.failed)
    }
}

@Test @MainActor func savedFailureDoesNotChangeBrowseState() async {
    let gate = GateReader(), clock = TestClock()
    let access = SavedFailureAccess(gate: gate)
    let browse = BrowseModel(repository: access, clock: clock)
    let saved = SavedModel(repository: access)
    await browse.refresh()
    let operation = Task { await saved.reload() }
    await gate.waitForCalls(1); await gate.release(0, .failure(NoteFailure.offline))
    await operation.value
    #expect(saved.failed && saved.notes.isEmpty)
    #expect(browse.state == .ready([first]))
}

@Test func duplicateAndInvalidRecords() throws {
    #expect(throws: NoteFailure.duplicateID) { try validated([first, first]) }
    #expect(throws: NoteFailure.invalidRecord) { try validated([Note(id: "n3", title: "  ")]) }
    #expect(try validated([]) == [])
}

@Test func cacheExpiresAtExactDeadline() async throws {
    let reader = GateReader(), clock = TestClock()
    let repo = NoteRepository(account: "demo-a", reader: reader, clock: clock)
    let load = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(1); await reader.release(0, .success([first]))
    #expect(try await load.value == [first])
    await clock.advance(by: .seconds(4))
    #expect(try await repo.notes(.cacheAllowed) == [first])
    #expect(await reader.count() == 1)
    await clock.advance(by: .seconds(1))
    let expired = Task { try await repo.notes(.cacheAllowed) }
    await reader.waitForCalls(2); await reader.release(1, .success([second]))
    #expect(try await expired.value == [second])
}

@Test func olderCompletionCannotReplaceNewerCache() async throws {
    let reader = GateReader()
    let scheduled = NoteRepository(account: "demo-a", reader: reader, clock: TestClock())
    let old = Task { try await scheduled.notes(.reload) }
    await reader.waitForCalls(1)
    let new = Task { try await scheduled.notes(.reload) }
    await reader.waitForCalls(2)
    await reader.release(1, .success([second])); _ = try await new.value
    await reader.release(0, .success([first]))
    await #expect(throws: NoteFailure.staleRequest) { try await old.value }
    #expect(try await scheduled.notes(.cacheAllowed) == [second])
}

@Test func failureAndMalformedRefreshPreserveLastGoodCache() async throws {
    let reader = GateReader(), clock = TestClock()
    let repo = NoteRepository(account: "demo-a", reader: reader, clock: clock)
    let initial = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(1); await reader.release(0, .success([first])); _ = try await initial.value
    let malformed = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(2); await reader.release(1, .success([second, second]))
    await #expect(throws: NoteFailure.duplicateID) { try await malformed.value }
    let offline = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(3); await reader.release(2, .failure(NoteFailure.offline))
    await #expect(throws: NoteFailure.offline) { try await offline.value }
    #expect(try await repo.notes(.cacheAllowed) == [first])
}

@Test func logoutRevokesIgnoringCancellationReader() async throws {
    let reader = GateReader()
    let scoped = NoteRepository(account: "demo-a", reader: reader, clock: TestClock())
    let old = Task { try await scoped.notes(.reload) }
    await reader.waitForCalls(1); await scoped.invalidate()
    await reader.release(0, .success([first]))
    await #expect(throws: NoteFailure.expiredAccount) { try await old.value }
    await #expect(throws: NoteFailure.expiredAccount) { try await scoped.saved() }
}

@Test func canceledReadCannotCommit() async throws {
    let reader = GateReader()
    let repo = NoteRepository(account: "demo-a", reader: reader, clock: TestClock())
    let operation = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(1); operation.cancel(); await reader.release(0, .success([first]))
    await #expect(throws: CancellationError.self) { try await operation.value }
    await #expect(throws: NoteFailure.missingRecord) { try await repo.detail(id: first.id) }
}

@Test @MainActor func oldSuccessAndFailureCannotOverwriteBrowse() async throws {
    for fails in [false, true] {
        let reader = GateReader()
        let repo = NoteRepository(account: "demo-a", reader: reader, clock: TestClock())
        let model = BrowseModel(repository: repo, clock: TestClock())
        let old = Task { await model.refresh() }; await reader.waitForCalls(1)
        let new = Task { await model.refresh() }; await reader.waitForCalls(2)
        await reader.release(1, .success([second])); await new.value
        await reader.release(0, fails ? .failure(NoteFailure.offline) : .success([first])); await old.value
        #expect(model.state == .ready([second]))
    }
}

@Test @MainActor func injectedClockControlsDebounceAndCancellation() async {
    let reader = GateReader(), clock = TestClock()
    let repo = NoteRepository(account: "demo-a", reader: reader, clock: clock)
    let model = BrowseModel(repository: repo, clock: clock)
    let firstTask = Task { await model.refresh(delay: .seconds(2)) }
    await clock.waitForSleep(); await clock.advance(by: .seconds(1))
    #expect(await reader.count() == 0)
    await clock.advance(by: .seconds(1)); await reader.waitForCalls(1)
    await reader.release(0, .success([first])); await firstTask.value
    #expect(model.state == .ready([first]))
    let canceled = Task { await model.refresh(delay: .seconds(2)) }
    await clock.waitForSleep(); canceled.cancel(); await canceled.value
    #expect(await clock.pendingCount() == 0)
    #expect(await reader.count() == 1)
    #expect(model.state == .idle)
}

@Test @MainActor func verticalSliceSavedDetailAndAccountSwitch() async throws {
    let shell = Shell(clock: TestClock())
    shell.refresh(); await shell.waitForRefresh()
    shell.open(id: "n1")
    let route = try #require(shell.path.first)
    #expect(try await shell.resolve(route).id == "n1")
    await shell.toggleSaved(route)
    #expect(shell.saved.notes.map(\.id) == ["n1"])
    await shell.switchAccount(to: "demo-b")
    #expect(shell.path.isEmpty && shell.saved.notes.isEmpty)
    shell.refresh(); await shell.waitForRefresh()
    await shell.toggleSaved(route)
    #expect(shell.saved.notes.isEmpty)
    await #expect(throws: NoteFailure.expiredAccount) { try await shell.resolve(route) }
    #expect(try await shell.resolve(.detail(session: shell.sessionID, account: "demo-b", id: "n1")).title == "demo-b: Bridge sketch")
    await #expect(throws: NoteFailure.missingRecord) { try await shell.resolve(.detail(session: shell.sessionID, account: "demo-b", id: "absent")) }
    await shell.switchAccount(to: "demo-a")
    shell.refresh(); await shell.waitForRefresh()
    await shell.toggleSaved(route)
    #expect(shell.saved.notes.isEmpty)
    await #expect(throws: NoteFailure.expiredAccount) { try await shell.resolve(route) }
}

@Test func deletionReconcilesSavedIDs() async throws {
    let reader = GateReader()
    let repo = NoteRepository(account: "demo-a", reader: reader, clock: TestClock())
    let firstLoad = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(1); await reader.release(0, .success([first, second])); _ = try await firstLoad.value
    try await repo.toggleSaved(id: "n1")
    let refresh = Task { try await repo.notes(.reload) }
    await reader.waitForCalls(2); await reader.release(1, .success([second])); _ = try await refresh.value
    #expect(try await repo.saved().isEmpty)
    await #expect(throws: NoteFailure.missingRecord) { try await repo.detail(id: "n1") }
}
