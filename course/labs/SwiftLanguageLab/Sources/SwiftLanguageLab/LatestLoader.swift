public enum WorkLimitError: Error, Equatable, Sendable { case capacityReached }

public struct RequestTicket: Hashable, Sendable {
    public let account: String
    public let epoch: Int
    public let generation: Int
}

public enum LoadPhase: Equatable, Sendable {
    case idle
    case loading(RequestTicket)
    case loaded(account: String, values: [String])
    case failed(account: String, message: String)
}

public struct LoaderSnapshot: Equatable, Sendable {
    public let account: String
    public let epoch: Int
    public let phase: LoadPhase
    public let activeWork: Int
    public let peakActiveWork: Int
}

public struct LoadHandle: Sendable {
    public let ticket: RequestTicket
    private let task: Task<Void, Never>

    fileprivate init(ticket: RequestTicket, task: Task<Void, Never>) {
        self.ticket = ticket
        self.task = task
    }

    /// This joins the owner's work; cancelling a separate waiting task is not owner cancellation.
    public func wait() async { await task.value }
}

/// Owns retained tasks, visible state, and freshness. This is not a durable cache.
public actor LatestLoader {
    private var account: String
    private var epoch = 0
    private var generation = 0
    private var current: RequestTicket?
    private var phase: LoadPhase = .idle
    private var tasks: [RequestTicket: Task<Void, Never>] = [:]
    private var peakActiveWork = 0
    private let maximumActiveWork: Int
    private let cancelSuperseded: Bool

    public init(account: String, maximumActiveWork: Int = 2, cancelSuperseded: Bool = true) {
        precondition(maximumActiveWork > 0)
        self.account = account
        self.maximumActiveWork = maximumActiveWork
        self.cancelSuperseded = cancelSuperseded
    }

    public func start(using gate: CompletionGate<[String]>) throws -> LoadHandle {
        // Cancellation requests do not free slots. Rejected work changes no visible state.
        guard tasks.count < maximumActiveWork else { throw WorkLimitError.capacityReached }
        generation += 1
        let ticket = RequestTicket(account: account, epoch: epoch, generation: generation)
        current = ticket
        phase = .loading(ticket)
        if cancelSuperseded { for task in tasks.values { task.cancel() } }

        let task = Task {
            let result: Result<[String], any Error>
            do { result = .success(try await gate.run()) }
            catch { result = .failure(error) }
            finish(ticket, result: result)
        }
        tasks[ticket] = task
        peakActiveWork = max(peakActiveWork, tasks.count)
        return LoadHandle(ticket: ticket, task: task)
    }

    public func changeAccount(to newAccount: String) {
        epoch += 1
        generation = 0
        account = newAccount
        current = nil
        phase = .idle
        for task in tasks.values { task.cancel() }
    }

    public func cancel(_ ticket: RequestTicket) {
        if current == ticket {
            current = nil
            phase = .idle
        }
        tasks[ticket]?.cancel()
    }

    public func snapshot() -> LoaderSnapshot {
        LoaderSnapshot(account: account, epoch: epoch, phase: phase,
                       activeWork: tasks.count, peakActiveWork: peakActiveWork)
    }

    private func finish(_ ticket: RequestTicket, result: Result<[String], any Error>) {
        tasks.removeValue(forKey: ticket)
        // The same guard protects both success and catch. No suspension before the commit.
        guard current == ticket, ticket.account == account, ticket.epoch == epoch else { return }
        current = nil
        switch result {
        case .success(let values): phase = .loaded(account: account, values: values)
        case .failure(is CancellationError): phase = .idle
        case .failure(let error): phase = .failed(account: account, message: String(describing: error))
        }
    }
}
