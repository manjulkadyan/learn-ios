public enum GateFailure: Error, Equatable, Sendable {
    case synthetic(String)
    case alreadyStarted
    case notStarted
    case alreadyResolved
}

/// Single-use fake operation. Observers wait for events, never elapsed time.
public actor CompletionGate<Value: Sendable> {
    public enum CancellationPolicy: Sendable { case cooperative, ignore }

    private let cancellationPolicy: CancellationPolicy
    private var started = false
    private var result: Result<Value, any Error>?
    private var operation: CheckedContinuation<Value, any Error>?
    private var startObservers: [CheckedContinuation<Void, Never>] = []
    private var resolutionObservers: [CheckedContinuation<Void, Never>] = []

    public init(cancellationPolicy: CancellationPolicy = .cooperative) {
        self.cancellationPolicy = cancellationPolicy
    }

    public func run() async throws -> Value {
        guard !started else { throw GateFailure.alreadyStarted }
        started = true
        let observers = startObservers
        startObservers.removeAll()
        for observer in observers { observer.resume() }

        if cancellationPolicy == .cooperative && Task.isCancelled {
            resolve(.failure(CancellationError()))
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let result { continuation.resume(with: result) }
                else { operation = continuation }
            }
        } onCancel: {
            Task { await self.cancelIfCooperative() }
        }
    }

    public func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startObservers.append($0) }
    }

    public func waitUntilResolved() async {
        if result != nil { return }
        await withCheckedContinuation { resolutionObservers.append($0) }
    }

    public func succeed(_ value: Value) throws { try complete(.success(value)) }
    public func fail(_ error: any Error) throws { try complete(.failure(error)) }

    private func complete(_ result: Result<Value, any Error>) throws {
        guard started else { throw GateFailure.notStarted }
        guard self.result == nil else { throw GateFailure.alreadyResolved }
        resolve(result)
    }

    private func cancelIfCooperative() {
        guard cancellationPolicy == .cooperative, result == nil else { return }
        resolve(.failure(CancellationError()))
    }

    private func resolve(_ result: Result<Value, any Error>) {
        self.result = result
        let continuation = operation
        operation = nil
        continuation?.resume(with: result)
        let observers = resolutionObservers
        resolutionObservers.removeAll()
        for observer in observers { observer.resume() }
    }
}
