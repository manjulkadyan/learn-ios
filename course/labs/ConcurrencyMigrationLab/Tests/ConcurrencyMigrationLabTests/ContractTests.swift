import Testing
@testable import ConcurrencyMigrationLab

@Suite("Deterministic migration contracts", .timeLimit(.minutes(1)))
struct ContractTests {
    @Test func producerWaitsForDemand() async throws {
        let channel = DemandChannel<Int>()
        let sender = Task { try await channel.send(7) }
        await channel.waitForPendingSend()
        #expect(try await channel.next() == 7)
        try await sender.value
        await channel.finish()
        #expect(try await channel.next() == nil)
    }
    @Test func consumerWaitsForProducer() async throws {
        let channel = DemandChannel<Int>()
        let receiver = Task { try await channel.next() }
        await channel.waitForPendingNext()
        try await channel.send(9)
        #expect(try await receiver.value == 9)
    }
    @Test func canceledSenderDoesNotLeakItsElement() async throws {
        let channel = DemandChannel<Int>()
        let sender = Task { try await channel.send(1) }
        await channel.waitForPendingSend()
        sender.cancel()
        await #expect(throws: CancellationError.self) { try await sender.value }
        let replacement = Task { try await channel.send(2) }
        await channel.waitForPendingSend()
        #expect(try await channel.next() == 2)
        try await replacement.value
    }
    @Test func canceledReceiverDoesNotConsumeNextValue() async throws {
        let channel = DemandChannel<Int>()
        let receiver = Task { try await channel.next() }
        await channel.waitForPendingNext()
        receiver.cancel()
        await #expect(throws: CancellationError.self) { try await receiver.value }
        let sender = Task { try await channel.send(3) }
        await channel.waitForPendingSend()
        #expect(try await channel.next() == 3)
        try await sender.value
    }
    @Test func closeReleasesEitherWaiterAndIsIdempotent() async throws {
        let outgoing = DemandChannel<Int>()
        let sender = Task { try await outgoing.send(5) }
        await outgoing.waitForPendingSend()
        await outgoing.finish()
        await outgoing.finish()
        await #expect(throws: ChannelFailure.closed) { try await sender.value }
        await #expect(throws: ChannelFailure.closed) { try await outgoing.send(6) }
        let incoming = DemandChannel<Int>()
        let receiver = Task { try await incoming.next() }
        await incoming.waitForPendingNext()
        await incoming.finish()
        #expect(try await receiver.value == nil)
    }
    @Test func overlappingCallsAreRejected() async throws {
        let channel = DemandChannel<Int>()
        let sender = Task { try await channel.send(1) }
        await channel.waitForPendingSend()
        await #expect(throws: ChannelFailure.overlappingSend) { try await channel.send(2) }
        #expect(try await channel.next() == 1)
        try await sender.value
        let receiver = Task { try await channel.next() }
        await channel.waitForPendingNext()
        await #expect(throws: ChannelFailure.overlappingNext) { try await channel.next() }
        await channel.finish()
        _ = try await receiver.value
    }
    @Test func cancellationBeforeRegistrationIsObserved() async throws {
        let channel = DemandChannel<Int>()
        let sender = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await channel.send(1)
        }
        await #expect(throws: CancellationError.self) { try await sender.value }
        let receiver = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await channel.next()
        }
        await #expect(throws: CancellationError.self) { try await receiver.value }
        let replacement = Task { try await channel.send(2) }
        await channel.waitForPendingSend()
        #expect(try await channel.next() == 2)
        try await replacement.value
        let clock = ManualClock()
        let sleeper = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await clock.sleep(until: clock.now.advanced(by: .seconds(1)), tolerance: nil)
        }
        await #expect(throws: CancellationError.self) { try await sleeper.value }
        #expect(clock.pendingSleeps == 0)
    }
    @Test func matchWinsOverLaterCancellation() async throws {
        let channel = DemandChannel<Int>()
        let sender = Task { try await channel.send(4) }
        await channel.waitForPendingSend()
        #expect(try await channel.next() == 4)
        sender.cancel() // Receipt has already removed the sender from actor state.
        try await sender.value
        await channel.finish()
        #expect(try await channel.next() == nil)
    }
    @Test func virtualDeadlineAndCancellation() async throws {
        let clock = ManualClock()
        try await clock.sleep(until: clock.now, tolerance: nil)
        #expect(clock.pendingSleeps == 0)
        let task = Task { try await delayed(using: clock, delay: .seconds(5)) }
        await clock.waitForSleeper()
        clock.advance(by: .seconds(4))
        #expect(clock.pendingSleeps == 1)
        clock.advance(by: .seconds(1))
        #expect(try await task.value == "ready")
        let canceled = Task { try await delayed(using: clock, delay: .seconds(10)) }
        await clock.waitForSleeper()
        canceled.cancel()
        await #expect(throws: CancellationError.self) { try await canceled.value }
        #expect(clock.pendingSleeps == 0)
        clock.advance(by: .seconds(10)) // Must not resume a canceled continuation again.
    }
    @Test func contextInheritanceAndRestoration() async {
        #expect(RequestContext.trace == nil)
        await RequestContext.$trace.withValue("synthetic-trace") {
            async let child = readTrace()
            let unstructured = Task { RequestContext.trace }
            let detached = Task.detached { RequestContext.trace }
            #expect(await child == "synthetic-trace")
            #expect(await unstructured.value == "synthetic-trace")
            #expect(await detached.value == nil)
            RequestContext.$trace.withValue("nested") { #expect(RequestContext.trace == "nested") }
            #expect(RequestContext.trace == "synthetic-trace")
        }
        #expect(RequestContext.trace == nil)
    }
    private func readTrace() async -> String? { RequestContext.trace }

    @Test func transferAndIsolatedBatch() async {
        let inbox = DraftInbox()
        let draft = Draft("fixture")
        await inbox.install(draft)
        // No local access to draft after transfer; only Sendable snapshots return.
        #expect(await inbox.snapshot() == "fixture")
        #expect(await batch(Ledger()) == 5)
    }
    @Test func ownedPointerAndScopedAllocation() {
        let owned = OwnedInt(42)
        #expect(owned.read() == 42)
        #expect(owned.extract() == 42)
        #expect(scopedSum() == 8)
    }
    @Test func retainedContextBalancesOwnership() {
        weak var observed: CallbackBox?
        do {
            let box = CallbackBox(8)
            observed = box
            #expect(retainedRoundTrip(box) == 8)
        }
        #expect(observed == nil)
    }
}
