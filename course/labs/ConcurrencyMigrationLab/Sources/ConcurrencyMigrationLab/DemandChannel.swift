public enum ChannelFailure: Error, Equatable { case closed, overlappingSend, overlappingNext }

/// Zero-buffer rendezvous; one pending producer and one pending consumer only.
/// A send acknowledges receipt, not completion of downstream processing.
public actor DemandChannel<Element: Sendable> {
    private struct Sender {
        let id: UInt64
        let element: Element
        let continuation: CheckedContinuation<Void, any Error>
    }
    private struct Receiver {
        let id: UInt64
        let continuation: CheckedContinuation<Element?, any Error>
    }
    private var sender: Sender?
    private var receiver: Receiver?
    private var closed = false
    private var serial: UInt64 = 0
    // Harness observers only; they observe registration, not elapsed time.
    private var sendObservers: [CheckedContinuation<Void, Never>] = []
    private var nextObservers: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func send(_ element: Element) async throws {
        try Task.checkCancellation()
        guard !closed else { throw ChannelFailure.closed }
        guard sender == nil else { throw ChannelFailure.overlappingSend }
        serial += 1
        let id = serial
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                // Cancellation can occur before onCancel's actor message arrives.
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                if let waiting = receiver {
                    receiver = nil
                    waiting.continuation.resume(returning: element)
                    continuation.resume()
                } else {
                    sender = Sender(id: id, element: element, continuation: continuation)
                    let observers = sendObservers
                    sendObservers.removeAll()
                    observers.forEach { $0.resume() }
                }
            }
        } onCancel: { Task { await self.cancelSend(id) } }
    }

    public func next() async throws -> Element? {
        try Task.checkCancellation()
        guard receiver == nil else { throw ChannelFailure.overlappingNext }
        if closed { return nil }
        serial += 1
        let id = serial
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                if let waiting = sender {
                    sender = nil
                    continuation.resume(returning: waiting.element)
                    waiting.continuation.resume()
                } else {
                    receiver = Receiver(id: id, continuation: continuation)
                    let observers = nextObservers
                    nextObservers.removeAll()
                    observers.forEach { $0.resume() }
                }
            }
        } onCancel: { Task { await self.cancelNext(id) } }
    }

    public func finish() {
        guard !closed else { return }
        closed = true
        let oldSender = sender
        let oldReceiver = receiver
        sender = nil
        receiver = nil
        oldSender?.continuation.resume(throwing: ChannelFailure.closed)
        oldReceiver?.continuation.resume(returning: nil)
    }

    private func cancelSend(_ id: UInt64) {
        guard sender?.id == id else { return } // A match/finish may have already won.
        let old = sender
        sender = nil
        old?.continuation.resume(throwing: CancellationError())
    }
    private func cancelNext(_ id: UInt64) {
        guard receiver?.id == id else { return }
        let old = receiver
        receiver = nil
        old?.continuation.resume(throwing: CancellationError())
    }

    public func waitForPendingSend() async {
        if sender != nil { return }
        await withCheckedContinuation { sendObservers.append($0) }
    }
    public func waitForPendingNext() async {
        if receiver != nil { return }
        await withCheckedContinuation { nextObservers.append($0) }
    }
}
