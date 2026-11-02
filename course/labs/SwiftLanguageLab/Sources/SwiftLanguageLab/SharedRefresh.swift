public struct RefreshSnapshot: Equatable, Sendable {
    public let activeFlights: Int
    public let waiters: Int
    public let startedFlights: Int
    public let peakActiveFlights: Int
}

/// One owner's refresh with independently cancellable callers. One instance = one scope.
/// This is not an authentication, account cache, or retry implementation.
public actor SharedRefresh<Value: Sendable> {
    private struct Flight {
        let task: Task<Void, Never>
        var waiters: [Int: CheckedContinuation<Value, any Error>]
    }

    private var flights: [Int: Flight] = [:]
    private var currentFlight: Int?
    private var nextWaiter = 0
    private var nextFlight = 0
    private var peak = 0
    private let maximumActiveFlights: Int
    private var waiterObservers: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var activityObservers: [(maximum: Int, continuation: CheckedContinuation<Void, Never>)] = []

    public init(maximumActiveFlights: Int = 1) {
        precondition(maximumActiveFlights > 0)
        self.maximumActiveFlights = maximumActiveFlights
    }

    /// A joining caller uses the existing flight; its supplied gate is not started.
    /// Cancellation/completion races are linearized by this actor's handling order.
    public func refresh(using gate: CompletionGate<Value>) async throws -> Value {
        try Task.checkCancellation()
        nextWaiter += 1
        let waiterID = nextWaiter
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if let id = currentFlight, var flight = flights[id] {
                    flight.waiters[waiterID] = continuation
                    flights[id] = flight
                } else {
                    guard flights.count < maximumActiveFlights else {
                        continuation.resume(throwing: WorkLimitError.capacityReached)
                        return
                    }
                    nextFlight += 1
                    let id = nextFlight
                    let task = Task {
                        let result: Result<Value, any Error>
                        do { result = .success(try await gate.run()) }
                        catch { result = .failure(error) }
                        finish(id, result: result)
                    }
                    flights[id] = Flight(task: task, waiters: [waiterID: continuation])
                    currentFlight = id
                    peak = max(peak, flights.count)
                }
                notifyWaiterObservers()
            }
        } onCancel: {
            Task { await self.cancelWaiter(waiterID) }
        }
    }

    public func snapshot() -> RefreshSnapshot {
        RefreshSnapshot(activeFlights: flights.count, waiters: waiterCount,
                        startedFlights: nextFlight, peakActiveFlights: peak)
    }

    /// Test observation only: waits for at least this many registered waiters.
    /// Event observers do not implement caller cancellation or timeouts.
    public func waitUntilWaiterCount(_ count: Int) async {
        precondition(count > 0)
        if waiterCount >= count { return }
        await withCheckedContinuation { waiterObservers.append((count, $0)) }
    }

    public func waitUntilIdle() async {
        await waitUntilActiveFlights(atMost: 0)
    }

    /// One-shot observation of completed accounting, not a reservation of capacity.
    public func waitUntilActiveFlights(atMost maximum: Int) async {
        precondition(maximum >= 0)
        if flights.count <= maximum { return }
        await withCheckedContinuation { activityObservers.append((maximum, $0)) }
    }

    private var waiterCount: Int { flights.values.reduce(0) { $0 + $1.waiters.count } }

    private func cancelWaiter(_ waiterID: Int) {
        for id in Array(flights.keys) {
            guard var flight = flights[id], let waiter = flight.waiters.removeValue(forKey: waiterID) else {
                continue
            }
            flights[id] = flight
            if flight.waiters.isEmpty {
                if currentFlight == id { currentFlight = nil }
                // Keep this flight counted until the underlying operation actually exits.
                flight.task.cancel()
            }
            waiter.resume(throwing: CancellationError())
            return
        }
    }

    private func finish(_ id: Int, result: Result<Value, any Error>) {
        guard let flight = flights.removeValue(forKey: id) else { return }
        if currentFlight == id { currentFlight = nil }
        for waiter in flight.waiters.values { waiter.resume(with: result) }
        let ready = activityObservers.filter { flights.count <= $0.maximum }
        activityObservers.removeAll { flights.count <= $0.maximum }
        for observer in ready { observer.continuation.resume() }
    }

    private func notifyWaiterObservers() {
        let count = waiterCount
        let ready = waiterObservers.filter { count >= $0.count }
        waiterObservers.removeAll { count >= $0.count }
        for observer in ready { observer.continuation.resume() }
    }
}
