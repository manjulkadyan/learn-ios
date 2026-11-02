import Foundation
import Synchronization

/// Test clock. Mutex supports Clock's synchronous now requirement; no lock spans await.
/// Requires the macOS 15 SDK/runtime (Synchronization), independent of Swift syntax.
public final class ManualClock: Clock, Sendable {
    public struct Instant: InstantProtocol {
        public typealias Duration = Swift.Duration
        fileprivate let offset: Duration
        public func advanced(by duration: Duration) -> Instant { .init(offset: offset + duration) }
        public func duration(to other: Instant) -> Duration { other.offset - offset }
        public static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }
    private struct Sleep {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }
    private struct State {
        var now = Instant(offset: .zero)
        var sleeps: [UUID: Sleep] = [:]
        var observers: [CheckedContinuation<Void, Never>] = []
    }
    private let state = Mutex(State())
    public init() {}
    public var now: Instant { state.withLock { $0.now } }
    public var minimumResolution: Duration { .nanoseconds(1) }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome = state.withLock { state -> (Bool, Bool, [CheckedContinuation<Void, Never>]) in
                    if Task.isCancelled { return (true, false, []) }
                    if deadline <= state.now { return (false, true, []) }
                    state.sleeps[id] = Sleep(deadline: deadline, continuation: continuation)
                    let observers = state.observers
                    state.observers.removeAll()
                    return (false, false, observers)
                }
                if outcome.0 { continuation.resume(throwing: CancellationError()) }
                else if outcome.1 { continuation.resume() }
                outcome.2.forEach { $0.resume() }
            }
        } onCancel: {
            let sleep = self.state.withLock { $0.sleeps.removeValue(forKey: id) }
            sleep?.continuation.resume(throwing: CancellationError())
        }
    }

    public func advance(by duration: Duration) {
        precondition(duration >= .zero)
        let ready = state.withLock { state -> [Sleep] in
            state.now = state.now.advanced(by: duration)
            let ids = state.sleeps.filter { $0.value.deadline <= state.now }.map(\.key)
            return ids.compactMap { state.sleeps.removeValue(forKey: $0) }
        }
        ready.forEach { $0.continuation.resume() }
    }

    /// Harness barrier; caller must arrange at least one future sleep.
    public func waitForSleeper() async {
        await withCheckedContinuation { continuation in
            let immediate = state.withLock { state in
                if !state.sleeps.isEmpty { return true }
                state.observers.append(continuation)
                return false
            }
            if immediate { continuation.resume() }
        }
    }
    public var pendingSleeps: Int { state.withLock { $0.sleeps.count } }
}

public func delayed<C: Clock>(using clock: C, delay: C.Duration) async throws -> String {
    try Task.checkCancellation()
    let deadline = clock.now.advanced(by: delay)
    try await clock.sleep(until: deadline, tolerance: nil)
    try Task.checkCancellation()
    return "ready"
}
