import Testing
import SwiftLanguageLab

@Suite("Single-use event gates", .timeLimit(.minutes(1)))
struct GateTests {
    @Test func successSignalsStartAndResolvesExactlyOnce() async throws {
        let gate = CompletionGate<Int>()
        await #expect(throws: GateFailure.notStarted) { try await gate.succeed(1) }
        let task = Task { try await gate.run() }
        await gate.waitUntilStarted()
        try await gate.succeed(42)
        await gate.waitUntilResolved()
        #expect(try await task.value == 42)
        // Observing an event after it occurred must return immediately too.
        await gate.waitUntilStarted()
        await gate.waitUntilResolved()
        await #expect(throws: GateFailure.alreadyResolved) { try await gate.succeed(99) }
        await #expect(throws: GateFailure.alreadyStarted) { try await gate.run() }
    }

    @Test func ordinaryErrorIsPreserved() async throws {
        let gate = CompletionGate<Int>()
        let task = Task { try await gate.run() }
        await gate.waitUntilStarted()
        try await gate.fail(GateFailure.synthetic("transport"))
        await #expect(throws: GateFailure.synthetic("transport")) { try await task.value }
    }

    @Test func cancellationAfterStartResumesCooperativeOperation() async {
        let gate = CompletionGate<Int>()
        let task = Task { try await gate.run() }
        await gate.waitUntilStarted()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        await gate.waitUntilResolved()
    }

    @Test func ignoringCancellationStillRequiresExplicitCompletion() async throws {
        let gate = CompletionGate<Int>(cancellationPolicy: .ignore)
        let task = Task { try await gate.run() }
        await gate.waitUntilStarted()
        task.cancel()
        try await gate.succeed(7)
        #expect(try await task.value == 7)
    }

    @Test func cancellationBeforeRunIsObserved() async throws {
        let entry = CompletionGate<Void>(cancellationPolicy: .ignore)
        let operation = CompletionGate<Int>()
        let task = Task {
            try await entry.run()
            return try await operation.run()
        }
        await entry.waitUntilStarted()
        task.cancel()
        try await entry.succeed(())
        await #expect(throws: CancellationError.self) { try await task.value }
        await operation.waitUntilStarted()
        await operation.waitUntilResolved()
    }
}
