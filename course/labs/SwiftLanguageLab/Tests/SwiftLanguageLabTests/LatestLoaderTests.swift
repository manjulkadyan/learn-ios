import Testing
import SwiftLanguageLab

@Suite("Latest request and account ownership", .timeLimit(.minutes(1)))
struct LatestLoaderTests {
    @Test("B commits before an old A success or error", arguments: [false, true])
    func oldCompletionCannotReplaceB(oldError: Bool) async throws {
        // Disable the optimization so freshness guards are tested without cancellation helping.
        let loader = LatestLoader(account: "A", cancelSuperseded: false)
        let a = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let b = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let first = try await loader.start(using: a)
        await a.waitUntilStarted()
        let second = try await loader.start(using: b)
        await b.waitUntilStarted()
        try await b.succeed(["B"])
        await second.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: ["B"]))
        if oldError { try await a.fail(GateFailure.synthetic("old A")) }
        else { try await a.succeed(["A"]) }
        await first.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: ["B"]))
        #expect(await loader.snapshot().activeWork == 0)
    }

    @Test("An old completion cannot clear B's loading state", arguments: [false, true])
    func oldCompletionCannotClearNewLoading(oldError: Bool) async throws {
        let loader = LatestLoader(account: "A", cancelSuperseded: false)
        let a = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let b = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let first = try await loader.start(using: a)
        await a.waitUntilStarted()
        let second = try await loader.start(using: b)
        await b.waitUntilStarted()
        if oldError { try await a.fail(GateFailure.synthetic("old A")) }
        else { try await a.succeed(["old A"]) }
        await first.wait()
        #expect(await loader.snapshot().phase == .loading(second.ticket))
        try await b.succeed(["B"])
        await second.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: ["B"]))
    }

    @Test("A to B to A uses an epoch even when request numbers repeat", arguments: [false, true])
    func accountCycleRejectsEarlierA(oldError: Bool) async throws {
        let loader = LatestLoader(account: "A")
        let oldA = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let first = try await loader.start(using: oldA)
        await oldA.waitUntilStarted()
        await loader.changeAccount(to: "B")
        #expect(await loader.snapshot().phase == .idle)
        await loader.changeAccount(to: "A")
        let newA = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let second = try await loader.start(using: newA)
        await newA.waitUntilStarted()
        #expect(first.ticket.account == second.ticket.account)
        #expect(first.ticket.generation == second.ticket.generation)
        #expect(first.ticket.epoch != second.ticket.epoch)
        if oldError { try await oldA.fail(GateFailure.synthetic("old account")) }
        else { try await oldA.succeed(["old account"]) }
        await first.wait()
        #expect(await loader.snapshot().phase == .loading(second.ticket))
        try await newA.succeed(["new account"])
        await second.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: ["new account"]))
    }

    @Test("Cancelling the current request rejects late success and failure", arguments: [false, true])
    func explicitCancellationInvalidatesOwnership(oldError: Bool) async throws {
        let loader = LatestLoader(account: "A")
        let gate = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let handle = try await loader.start(using: gate)
        await gate.waitUntilStarted()
        await loader.cancel(handle.ticket)
        #expect(await loader.snapshot().phase == .idle)
        #expect(await loader.snapshot().activeWork == 1)
        if oldError { try await gate.fail(GateFailure.synthetic("after cancellation")) }
        else { try await gate.succeed(["after cancellation"]) }
        await handle.wait()
        #expect(await loader.snapshot().phase == .idle)
        #expect(await loader.snapshot().activeWork == 0)
    }

    @Test func cooperativeCancellationJoinsWork() async throws {
        let loader = LatestLoader(account: "A")
        let gate = CompletionGate<[String]>()
        let handle = try await loader.start(using: gate)
        await gate.waitUntilStarted()
        await loader.cancel(handle.ticket)
        await handle.wait()
        #expect(await loader.snapshot().phase == .idle)
        #expect(await loader.snapshot().activeWork == 0)
    }

    @Test func newestErrorAndEmptySuccessAreObservable() async throws {
        let loader = LatestLoader(account: "A")
        let failure = CompletionGate<[String]>()
        let first = try await loader.start(using: failure)
        await failure.waitUntilStarted()
        try await failure.fail(GateFailure.synthetic("newest"))
        await first.wait()
        #expect(await loader.snapshot().phase == .failed(account: "A", message: String(describing: GateFailure.synthetic("newest"))))
        let success = CompletionGate<[String]>()
        let second = try await loader.start(using: success)
        await success.waitUntilStarted()
        try await success.succeed([])
        await second.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: []))
    }

    @Test func cancelledUncooperativeWorkStillConsumesCapacity() async throws {
        let loader = LatestLoader(account: "A", maximumActiveWork: 2)
        let a = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let b = CompletionGate<[String]>(cancellationPolicy: .ignore)
        let c = CompletionGate<[String]>()
        let first = try await loader.start(using: a)
        await a.waitUntilStarted()
        let second = try await loader.start(using: b)
        await b.waitUntilStarted()
        let before = await loader.snapshot()
        await #expect(throws: WorkLimitError.capacityReached) { try await loader.start(using: c) }
        #expect(await loader.snapshot() == before)
        try await b.succeed(["B"])
        await second.wait()
        let third = try await loader.start(using: c)
        await c.waitUntilStarted()
        try await c.succeed(["C"])
        await third.wait()
        try await a.succeed(["old A"])
        await first.wait()
        #expect(await loader.snapshot().phase == .loaded(account: "A", values: ["C"]))
        #expect(await loader.snapshot().activeWork == 0)
        #expect(await loader.snapshot().peakActiveWork == 2)
    }
}
