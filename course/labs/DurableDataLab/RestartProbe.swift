import Foundation

// Run seed and replay as separate OS processes against the same isolated directory.
@main struct RestartProbe {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { fatalError("seed|replay DIRECTORY") }
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let outbox = try DurableOutbox(io: AtomicDisk(url: root.appendingPathComponent("outbox.json")))
        let ticket = try await outbox.activate("restart-account")
        let server = try SyntheticServer(io: AtomicDisk(url: root.appendingPathComponent("server.json")))
        switch CommandLine.arguments[1] {
        case "seed":
            try await outbox.enqueue(Command(id: "stable-restart-op", record: "draft", value: "survives exit",
                                             baseRevision: 0), ticket: ticket)
            try await replay(outbox: outbox, server: server, ticket: ticket, loseFirstResponse: true)
            guard try await outbox.pending(ticket: ticket).first?.delivery == .ambiguous else {
                throw StoreFailure.corrupt
            }
            print("PASS seed: effect committed, response lost, ambiguous intent persisted; process exits")
        case "replay":
            guard try await outbox.pending(ticket: ticket).count == 1 else { throw StoreFailure.corrupt }
            try await replay(outbox: outbox, server: server, ticket: ticket)
            guard try await outbox.pending(ticket: ticket).isEmpty, await server.effects() == 1 else {
                throw StoreFailure.corrupt
            }
            print("PASS separate process: reloaded intent and receipts, same key, one effect, durable acknowledgment")
        default: fatalError("Unknown mode")
        }
    }
}
