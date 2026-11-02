import Testing
import SwiftLanguageLab

@Suite("Shared refresh caller contracts", .timeLimit(.minutes(1)))
struct SharedRefreshTests {
    @Test("Either waiter can cancel without cancelling the other", arguments: [false, true])
    func waitersCancelIndependently(cancelFirst: Bool) async throws {
        let refresh = SharedRefresh<String>()
        let gate = CompletionGate<String>()
        let first = Task { try await refresh.refresh(using: gate) }
        await gate.waitUntilStarted()
        let second = Task { try await refresh.refresh(using: gate) }
        await refresh.waitUntilWaiterCount(2)
        let cancelled = cancelFirst ? first : second
        let survivor = cancelFirst ? second : first
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await refresh.snapshot().waiters == 1)
        #expect(await refresh.snapshot().startedFlights == 1)
        try await gate.succeed("shared result")
        #expect(try await survivor.value == "shared result")
        await refresh.waitUntilIdle()
        #expect(await refresh.snapshot().activeFlights == 0)
    }

    @Test func oneFailureIsDeliveredToBothWaiters() async throws {
        let refresh = SharedRefresh<String>()
        let gate = CompletionGate<String>()
        let first = Task { try await refresh.refresh(using: gate) }
        await gate.waitUntilStarted()
        let second = Task { try await refresh.refresh(using: gate) }
        await refresh.waitUntilWaiterCount(2)
        try await gate.fail(GateFailure.synthetic("shared failure"))
        await #expect(throws: GateFailure.synthetic("shared failure")) { try await first.value }
        await #expect(throws: GateFailure.synthetic("shared failure")) { try await second.value }
        await refresh.waitUntilIdle()
        #expect(await refresh.snapshot().startedFlights == 1)
    }

    @Test func cancellingAllWaitersCancelsCooperativeFlight() async {
        let refresh = SharedRefresh<String>()
        let gate = CompletionGate<String>()
        let first = Task { try await refresh.refresh(using: gate) }
        await gate.waitUntilStarted()
        let second = Task { try await refresh.refresh(using: gate) }
        await refresh.waitUntilWaiterCount(2)
        first.cancel()
        second.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        await #expect(throws: CancellationError.self) { try await second.value }
        await refresh.waitUntilIdle()
        #expect(await refresh.snapshot().waiters == 0)
        #expect(await refresh.snapshot().activeFlights == 0)
    }

    @Test func abandonedUncooperativeFlightRemainsCountedUntilExit() async throws {
        let refresh = SharedRefresh<String>(maximumActiveFlights: 1)
        let old = CompletionGate<String>(cancellationPolicy: .ignore)
        let first = Task { try await refresh.refresh(using: old) }
        await old.waitUntilStarted()
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await refresh.snapshot().waiters == 0)
        #expect(await refresh.snapshot().activeFlights == 1)
        let next = CompletionGate<String>()
        await #expect(throws: WorkLimitError.capacityReached) { try await refresh.refresh(using: next) }
        #expect(await refresh.snapshot().startedFlights == 1)
        try await old.succeed("abandoned result")
        await refresh.waitUntilIdle()
        let second = Task { try await refresh.refresh(using: next) }
        await next.waitUntilStarted()
        try await next.succeed("new result")
        #expect(try await second.value == "new result")
        await refresh.waitUntilIdle()
        #expect(await refresh.snapshot().startedFlights == 2)
        #expect(await refresh.snapshot().peakActiveFlights == 1)
    }

    @Test("Late abandoned success and error cannot finish the replacement", arguments: [false, true])
    func lateAbandonedCompletionDoesNotFinishTheReplacementFlight(oldError: Bool) async throws {
        let refresh = SharedRefresh<String>(maximumActiveFlights: 2)
        let old = CompletionGate<String>(cancellationPolicy: .ignore)
        let first = Task { try await refresh.refresh(using: old) }
        await old.waitUntilStarted()
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        let next = CompletionGate<String>()
        let second = Task { try await refresh.refresh(using: next) }
        await next.waitUntilStarted()
        if oldError { try await old.fail(GateFailure.synthetic("abandoned")) }
        else { try await old.succeed("abandoned") }
        await refresh.waitUntilActiveFlights(atMost: 1)
        #expect(await refresh.snapshot().waiters == 1)
        #expect(await refresh.snapshot().activeFlights == 1)
        try await next.succeed("replacement")
        #expect(try await second.value == "replacement")
        await refresh.waitUntilIdle()
        #expect(await refresh.snapshot().startedFlights == 2)
        #expect(await refresh.snapshot().peakActiveFlights == 2)
    }

    @Test func precancelledCallerDoesNotCreateAFlight() async throws {
        let refresh = SharedRefresh<String>()
        let entry = CompletionGate<Void>(cancellationPolicy: .ignore)
        let unused = CompletionGate<String>()
        let caller = Task {
            try await entry.run()
            return try await refresh.refresh(using: unused)
        }
        await entry.waitUntilStarted()
        caller.cancel()
        try await entry.succeed(())
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await refresh.snapshot().startedFlights == 0)
    }
}
