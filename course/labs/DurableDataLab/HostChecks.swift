import Foundation

func require(_ condition: Bool, _ name: String) throws {
    if !condition { throw NSError(domain: "DurableDataLab.Check", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: name]) }
}
func expect(_ expected: StoreFailure, _ action: @Sendable () async throws -> Void) async throws {
    do { try await action(); throw NSError(domain: "ExpectedStoreFailure", code: 1) }
    catch let error as StoreFailure { try require(error == expected, "wrong store failure") }
}
func expectAuth(_ expected: AuthFailure, _ action: @Sendable () async throws -> Void) async throws {
    do { try await action(); throw NSError(domain: "ExpectedAuthFailure", code: 1) }
    catch let error as AuthFailure { try require(error == expected, "wrong auth failure") }
}
@main struct HostChecks {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an isolated temp directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let disk = AtomicDisk(url: root.appendingPathComponent("outbox.json"))
        let serverDisk = AtomicDisk(url: root.appendingPathComponent("server.json"))
        let old = OldJournal(version: 1, account: "A", drafts: ["draft": "preserve me"])
        try disk.write(JSONEncoder().encode(old))
        let store = try DurableOutbox(io: disk)
        let a = try await store.activate("A")
        try require(try await store.records(ticket: a)["draft"] == "preserve me", "file upgrade preservation")
        let first = Command(id: "op-1", record: "card", value: "alpha", baseRevision: 0)
        try await store.enqueue(first, ticket: a)
        let reload = try DurableOutbox(io: disk)
        let restartedA = try await reload.activate("A")
        try require(try await reload.pending(ticket: restartedA).count == 1, "reload pending intent")
        let server = try SyntheticServer(io: serverDisk)
        try await replay(outbox: reload, server: server, ticket: restartedA, loseFirstResponse: true)
        try require(try await reload.pending(ticket: restartedA).first?.delivery == .ambiguous, "ambiguous retained")
        let secondProcessStore = try DurableOutbox(io: disk)
        let newA = try await secondProcessStore.activate("A")
        let secondProcessServer = try SyntheticServer(io: serverDisk)
        try await replay(outbox: secondProcessStore, server: secondProcessServer, ticket: newA)
        try require(await secondProcessServer.effects() == 1, "one remote effect after receipt reload")
        try require(try await secondProcessStore.pending(ticket: newA).isEmpty, "ack persisted")
        // Reordered response after account A -> B -> A must not commit.
        let b = try await secondProcessStore.activate("B")
        try require(try await secondProcessStore.records(ticket: b).isEmpty, "account B isolation")
        let againA = try await secondProcessStore.activate("A")
        try await expect(.staleAccount) {
            try await secondProcessStore.record(.accepted, commandID: "op-1", ticket: newA)
        }
        try await secondProcessStore.enqueue(Command(id: "op-delete", record: "card", value: nil,
                                                    baseRevision: 1), ticket: againA)
        let deletedReload = try DurableOutbox(io: disk)
        let deleteTicket = try await deletedReload.activate("A")
        try require(try await deletedReload.records(ticket: deleteTicket)["card"] == nil, "local delete survived")
        try await replay(outbox: deletedReload, server: secondProcessServer, ticket: deleteTicket)
        try require(await secondProcessServer.value(account: "A", record: "card") == nil, "remote delete")
        try await deletedReload.enqueue(Command(id: "op-conflict", record: "card", value: "stale",
                                               baseRevision: 0), ticket: deleteTicket)
        try await replay(outbox: deletedReload, server: secondProcessServer, ticket: deleteTicket)
        try require(try await deletedReload.pending(ticket: deleteTicket).first?.delivery == .conflict, "conflict paused")
        try await expect(.identityReuse) {
            _ = try await secondProcessServer.apply(Command(id: "op-1", record: "card", value: "changed",
                                                           baseRevision: 0), account: "A")
        }
        let before = try disk.read()
        let failed = try DurableOutbox(io: RejectingDisk(disk: disk))
        try await expect(.injectedDisk) { _ = try await failed.activate("B") }
        try require(try disk.read() == before, "failed write preserved bytes")
        try require(try await failed.records(ticket: deleteTicket)["card"] == "stale", "failed write preserved memory")
        await deletedReload.setAvailable(false)
        try await expect(.protectedData) { _ = try await deletedReload.activate("B") }
        await deletedReload.setAvailable(true)
        try require(try disk.read() == before, "protected-data failure preserved bytes")
        let corrupt = AtomicDisk(url: root.appendingPathComponent("corrupt.json"))
        try corrupt.write(Data("{invalid".utf8))
        try await expect(.corrupt) { _ = try DurableOutbox(io: corrupt) }
        try require(try corrupt.read() == Data("{invalid".utf8), "corrupt bytes retained")
        let future = AtomicDisk(url: root.appendingPathComponent("future.json"))
        try future.write(Data("{\"version\":99}".utf8))
        try await expect(.unsupported(99)) { _ = try DurableOutbox(io: future) }
        try require(try future.read() == Data("{\"version\":99}".utf8), "future bytes retained")
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await deletedReload.enqueue(Command(id: "cancel", record: "x", value: "x",
                                                   baseRevision: 0), ticket: deleteTicket)
        }
        do { try await cancelled.value; throw NSError(domain: "ExpectedCancellation", code: 1) }
        catch is CancellationError {}
        try require(try disk.read() == before, "cancellation before commit preserved bytes")
        try await rebaseChecks(root: root)
        try await authChecks()
        print("PASS host: file upgrade, disk reload, durable receipt replay, delete, conflict, A-B-A,")
        print("disk rejection, protected-data fake, corrupt/future preservation, cancellation, synthetic OAuth/vault")
    }
    static func rebaseChecks(root: URL) async throws {
        let disk = AtomicDisk(url: root.appendingPathComponent("rebase-outbox.json"))
        let serverDisk = AtomicDisk(url: root.appendingPathComponent("rebase-server.json"))
        let store = try DurableOutbox(io: disk)
        let ticket = try await store.activate("A")
        let server = try SyntheticServer(io: serverDisk)
        _ = try await server.apply(Command(id: "remote-seed", record: "card",
                                            value: "remote", baseRevision: 0), account: "A")
        let rejected = Command(id: "rejected-edit", record: "card", value: "stale", baseRevision: 0)
        try await store.enqueue(rejected, ticket: ticket)
        try await replay(outbox: store, server: server, ticket: ticket)
        let before = try disk.read()
        let failed = try DurableOutbox(io: RejectingDisk(disk: disk))
        try await expect(.identityReuse) {
            try await failed.resolveConflict(commandID: rejected.id, replacementID: rejected.id,
                value: "chosen", currentRevision: 1, ticket: ticket)
        }
        try await expect(.injectedDisk) {
            try await failed.resolveConflict(commandID: rejected.id, replacementID: "rebased-edit",
                value: "chosen", currentRevision: 1, ticket: ticket)
        }
        try require(try disk.read() == before, "failed rebase preserves before-image")
        try require(try await failed.pending(ticket: ticket).first?.delivery == .conflict,
                    "failed rebase preserves in-memory conflict")
        try await store.resolveConflict(commandID: rejected.id, replacementID: "rebased-edit",
            value: "chosen", currentRevision: 1, ticket: ticket)
        try require(try await store.pending(ticket: ticket).first?.id == "rebased-edit",
                    "replacement occupies original queue slot")
        try await replay(outbox: store, server: server, ticket: ticket)
        try require(await server.value(account: "A", record: "card") == "chosen", "rebase applied")
        try require(await server.effects() == 2, "one additional rebase effect")
        try require(try await server.apply(rejected, account: "A") == .conflict,
                    "original rejected receipt remains immutable")

        let dependentDisk = AtomicDisk(url: root.appendingPathComponent("dependent-outbox.json"))
        let dependent = try DurableOutbox(io: dependentDisk)
        let current = try await dependent.activate("A")
        try await dependent.enqueue(Command(id: "dependent-head", record: "card",
            value: "earlier", baseRevision: 0), ticket: current)
        try await dependent.enqueue(Command(id: "dependent-next", record: "card",
            value: "later", baseRevision: 2), ticket: current)
        try await replay(outbox: dependent, server: server, ticket: current)
        let queued = try await dependent.pending(ticket: current)
        let unchanged = try dependentDisk.read()
        try await expect(.dependentCommands) {
            try await dependent.resolveConflict(commandID: "dependent-head", replacementID: "unsafe-rebase",
                value: "earlier rebased", currentRevision: 2, ticket: current)
        }
        try require(try await dependent.pending(ticket: current) == queued,
                    "dependent edits retain their complete order and preconditions")
        try require(try dependentDisk.read() == unchanged, "unsupported dependency resolution preserves bytes")
        try require(await server.effects() == 2, "dependent FIFO stays paused without remote effects")
        print("PASS rebase: original-slot replacement, immutable receipt, failed-write preservation, dependent-edit rejection")
    }
    static func authChecks() async throws {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        try require(s256(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC7636 S256 vector")
        let provider = MockProvider()
        let session = AuthSession()
        let attempt = await session.begin(state: "synthetic-state", verifier: verifier)
        let code = await provider.authorize(challenge: attempt.challenge)
        let wrong = URL(string: "durablelab://oauth/callback?state=wrong&code=\(code)")!
        try await expectAuth(.state) { _ = try await session.acceptCallback(wrong, attempt: attempt) }
        let duplicate = URL(string: "durablelab://oauth/callback?state=synthetic-state&state=synthetic-state&code=\(code)")!
        try await expectAuth(.state) { _ = try await session.acceptCallback(duplicate, attempt: attempt) }
        let valid = URL(string: "durablelab://oauth/callback?state=synthetic-state&code=\(code)")!
        try await session.login(url: valid, attempt: attempt, provider: provider)
        try require(await session.credential() != nil, "login installed")
        try await expectAuth(.stale) { _ = try await session.acceptCallback(valid, attempt: attempt) }
        let prior = await session.credential()
        try await session.refresh(provider: provider)
        try require(await session.credential()?.refresh != prior?.refresh, "refresh rotated")
        // Manually gate a late provider completion; no timing/sleep assumption.
        let delayed = await session.begin(state: "late", verifier: verifier)
        let lateCode = await provider.authorize(challenge: delayed.challenge)
        let lateValue = try await provider.exchange(code: lateCode, verifier: verifier)
        await session.setVault(locked: false, deletionDenied: true)
        try await expectAuth(.denied) { try await session.logout() }
        try require(await session.credential() == nil, "failed deletion still closes authorization")
        try require(await session.needsCleanup(), "cleanup obligation retained")
        try await expectAuth(.stale) { try await session.install(lateValue, epoch: delayed.epoch) }
        await session.setVault(locked: false)
        try await session.retryCleanup()
        let locked = await session.begin(state: "locked", verifier: verifier)
        await session.setVault(locked: true)
        try await expectAuth(.locked) { try await session.install(lateValue, epoch: locked.epoch) }
        try require(await session.credential() == nil, "vault failure does not publish credentials")
        try await expectAuth(.denied) { _ = try await provider.exchange(code: code, verifier: verifier) }
        await session.setVault(locked: false)
        let recovery = await session.begin(state: "rotation", verifier: verifier)
        let recoveryCode = await provider.authorize(challenge: recovery.challenge)
        try await session.login(url: URL(string: "durablelab://oauth/callback?state=rotation&code=\(recoveryCode)")!,
                                attempt: recovery, provider: provider)
        let beforeRotation = await session.credential()
        await session.setVault(locked: true)
        // Server consumes the refresh token, then the local vault rejects new bytes.
        try await expectAuth(.locked) { try await session.refresh(provider: provider) }
        try require(await session.credential() == beforeRotation, "failed rotated-token storage retains old view")
        await session.setVault(locked: false)
        try await expectAuth(.denied) { try await session.refresh(provider: provider) }
        try await session.logout()
        let reauth = await session.begin(state: "reauth", verifier: verifier)
        let reauthCode = await provider.authorize(challenge: reauth.challenge)
        try await session.login(url: URL(string: "durablelab://oauth/callback?state=reauth&code=\(reauthCode)")!,
                                attempt: reauth, provider: provider)
        try require(await session.credential()?.refresh != beforeRotation?.refresh, "explicit reauthentication recovers")
    }
}
