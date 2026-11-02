import Foundation

// Single-process, bounded fixture. Synchronous encoding/IO occupies the actor's
// cooperative executor; this is not a production blocking-IO design. See lesson
// 088 for a dedicated bounded blocking worker and revalidation at the commit.
// Atomic replacement is not an fsync/power-loss guarantee.
enum StoreFailure: Error, Equatable {
    case corrupt, unsupported(Int), staleAccount, protectedData, injectedDisk
    case duplicateOperation, identityReuse
    case notConflicted, dependentCommands, invalidRevision
}
protocol SnapshotIO: Sendable {
    func read() throws -> Data?
    func write(_ data: Data) throws
}
struct AtomicDisk: SnapshotIO {
    let url: URL
    func read() throws -> Data? {
        do { return try Data(contentsOf: url) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError { return nil }
    }
    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
struct RejectingDisk: SnapshotIO {
    let disk: AtomicDisk
    func read() throws -> Data? { try disk.read() }
    func write(_ data: Data) throws { throw StoreFailure.injectedDisk }
}
struct Ticket: Codable, Equatable, Sendable { let account: String; let epoch: UUID }
enum Delivery: String, Codable, Sendable { case pending, ambiguous, conflict }
struct Command: Codable, Equatable, Sendable {
    let id: String
    let record: String
    let value: String? // nil is a durable delete command, not omitted intent.
    let baseRevision: Int
    var delivery: Delivery = .pending
}
struct AccountState: Codable, Sendable {
    var records: [String: String] = [:]
    var commands: [Command] = []
}
struct Journal: Codable, Sendable {
    var version = 2
    var epoch = UUID()
    var active: String?
    var accounts: [String: AccountState] = [:]
}
struct OldJournal: Codable {
    let version: Int
    let account: String
    let drafts: [String: String]
}
func decodeJournal(_ data: Data) throws -> Journal {
    struct Header: Decodable { let version: Int }
    let decoder = JSONDecoder()
    let version: Int
    do { version = try decoder.decode(Header.self, from: data).version }
    catch { throw StoreFailure.corrupt }
    switch version {
    case 1:
        do {
            let old = try decoder.decode(OldJournal.self, from: data)
            return Journal(accounts: [old.account: AccountState(records: old.drafts)])
        } catch { throw StoreFailure.corrupt }
    case 2:
        do {
            let journal = try decoder.decode(Journal.self, from: data)
            for state in journal.accounts.values {
                guard Set(state.commands.map(\.id)).count == state.commands.count else {
                    throw StoreFailure.corrupt
                }
            }
            return journal
        } catch { throw StoreFailure.corrupt }
    default: throw StoreFailure.unsupported(version)
    }
}
actor DurableOutbox {
    private let io: any SnapshotIO
    private var journal: Journal
    private var available = true
    init(io: any SnapshotIO) throws {
        self.io = io
        journal = try io.read().map(decodeJournal) ?? Journal()
    }
    private func commit(_ next: Journal) throws {
        guard available else { throw StoreFailure.protectedData }
        try io.write(JSONEncoder().encode(next))
        journal = next // Only advance memory after the disk acknowledgment.
    }
    func setAvailable(_ value: Bool) { available = value } // Fake platform input.
    func activate(_ account: String) throws -> Ticket {
        try Task.checkCancellation()
        var next = journal
        next.epoch = UUID() // Fences A -> B -> A and explicit restart activation.
        next.active = account
        if next.accounts[account] == nil { next.accounts[account] = AccountState() }
        try commit(next)
        return Ticket(account: account, epoch: next.epoch)
    }
    func logout() throws {
        var next = journal
        next.active = nil
        next.epoch = UUID()
        try commit(next) // Failure means the durable transition did not commit.
    }
    private func validate(_ ticket: Ticket) throws {
        guard available else { throw StoreFailure.protectedData }
        guard journal.active == ticket.account, journal.epoch == ticket.epoch else {
            throw StoreFailure.staleAccount
        }
    }
    func enqueue(_ command: Command, ticket: Ticket) throws {
        try Task.checkCancellation()
        try validate(ticket)
        var next = journal
        var account = next.accounts[ticket.account] ?? AccountState()
        guard !account.commands.contains(where: { $0.id == command.id }) else {
            throw StoreFailure.duplicateOperation
        }
        account.records[command.record] = command.value
        account.commands.append(command)
        next.accounts[ticket.account] = account
        try commit(next) // Local mutation and durable intent share one snapshot.
    }
    func pending(ticket: Ticket) throws -> [Command] {
        try validate(ticket)
        return journal.accounts[ticket.account]?.commands ?? []
    }
    func records(ticket: Ticket) throws -> [String: String] {
        try validate(ticket)
        return journal.accounts[ticket.account]?.records ?? [:]
    }
    // Bounded resolution: one pending command for this record. Dependent edits
    // need a separate atomic reconciliation plan; never move this intent behind them.
    func resolveConflict(commandID: String, replacementID: String, value: String?,
                         currentRevision: Int, ticket: Ticket) throws {
        try Task.checkCancellation()
        try validate(ticket)
        guard currentRevision >= 0 else { throw StoreFailure.invalidRevision }
        var next = journal
        guard var account = next.accounts[ticket.account],
              let index = account.commands.firstIndex(where: { $0.id == commandID }),
              account.commands[index].delivery == .conflict else { throw StoreFailure.notConflicted }
        let conflict = account.commands[index]
        guard account.commands.filter({ $0.record == conflict.record }).count == 1 else {
            throw StoreFailure.dependentCommands
        }
        guard replacementID != conflict.id else { throw StoreFailure.identityReuse }
        guard !account.commands.contains(where: { $0.id == replacementID }) else {
            throw StoreFailure.duplicateOperation
        }
        account.commands[index] = Command(id: replacementID, record: conflict.record,
                                           value: value, baseRevision: currentRevision)
        account.records[conflict.record] = value
        next.accounts[ticket.account] = account
        try commit(next)
    }
    func record(_ outcome: Outcome, commandID: String, ticket: Ticket) throws {
        try validate(ticket) // Same actor turn as disk mutation; no intervening await.
        var next = journal
        guard var account = next.accounts[ticket.account],
              let index = account.commands.firstIndex(where: { $0.id == commandID }) else { return }
        switch outcome {
        case .accepted: account.commands.remove(at: index)
        case .ambiguous: account.commands[index].delivery = .ambiguous
        case .conflict: account.commands[index].delivery = .conflict
        }
        next.accounts[ticket.account] = account
        try commit(next)
    }
}
enum Outcome: String, Codable, Sendable { case accepted, ambiguous, conflict }
struct ServerRecord: Codable, Sendable { var revision: Int; var value: String? }
struct Receipt: Codable, Sendable { let command: Command; let outcome: Outcome }
struct ServerState: Codable, Sendable {
    var records: [String: [String: ServerRecord]] = [:]
    var receipts: [String: [String: Receipt]] = [:]
    var effects = 0
}
actor SyntheticServer {
    private let io: any SnapshotIO
    private var state: ServerState
    init(io: any SnapshotIO) throws {
        self.io = io
        state = try io.read().map { try JSONDecoder().decode(ServerState.self, from: $0) } ?? ServerState()
    }
    func apply(_ command: Command, account: String, loseResponse: Bool = false) throws -> Outcome {
        if let prior = state.receipts[account]?[command.id] {
            // Delivery bookkeeping is not part of the immutable request payload.
            guard prior.command.record == command.record, prior.command.value == command.value,
                  prior.command.baseRevision == command.baseRevision else { throw StoreFailure.identityReuse }
            return prior.outcome
        }
        var next = state
        var records = next.records[account] ?? [:]
        let revision = records[command.record]?.revision ?? 0
        let result: Outcome
        if revision != command.baseRevision { result = .conflict }
        else {
            records[command.record] = ServerRecord(revision: revision + 1, value: command.value)
            next.records[account] = records
            next.effects += 1
            result = .accepted
        }
        var receipts = next.receipts[account] ?? [:]
        receipts[command.id] = Receipt(command: command, outcome: result)
        next.receipts[account] = receipts
        try io.write(JSONEncoder().encode(next))
        state = next
        return loseResponse ? .ambiguous : result
    }
    func effects() -> Int { state.effects }
    func value(account: String, record: String) -> String? { state.records[account]?[record]?.value }
}
// A deterministic one-pass scheduler: conflict pauses the account FIFO.
func replay(outbox: DurableOutbox, server: SyntheticServer, ticket: Ticket,
            loseFirstResponse: Bool = false) async throws {
    for (index, command) in try await outbox.pending(ticket: ticket).enumerated() {
        try Task.checkCancellation()
        if command.delivery == .conflict { break }
        let result = try await server.apply(command, account: ticket.account,
                                            loseResponse: loseFirstResponse && index == 0)
        // Cancellation may occur after a remote effect; keep the durable command.
        try Task.checkCancellation()
        try await outbox.record(result, commandID: command.id, ticket: ticket)
        if result != .accepted { break }
    }
}
