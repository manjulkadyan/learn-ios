import Foundation

@main struct Checks {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Supply an isolated output directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = Workload.inputs(), expected = Workload.expected()
        for indexed in [false, true] {
            let actual = try Workload.unique(fixture, indexed: indexed, cancelled: { false })
            let empty = try Workload.unique([], indexed: indexed, cancelled: { false })
            precondition(actual == expected)
            precondition(empty.isEmpty)
            var polls = 0
            do {
                _ = try Workload.unique(fixture, indexed: indexed, cancelled: { polls += 1; return polls == 2 })
                fatalError("Cancellation was ignored")
            } catch LabError.cancelled { precondition(polls == 2) }
        }
        let image = root.appendingPathComponent("square.png")
        try Workload.prepareImage(at: image)
        let full = try Workload.decode(at: image, thumbnail: false)
        let thumb = try Workload.decode(at: image, thumbnail: true)
        precondition(full.width == 2048 && full.height == 2048)
        precondition(thumb.width == 240 && thumb.height == 240)
        let corrupt = root.appendingPathComponent("corrupt.png")
        try Data("invalid".utf8).write(to: corrupt)
        do { _ = try Workload.decode(at: corrupt, thumbnail: true); fatalError("Corruption accepted") }
        catch LabError.image { }
        let output = root.appendingPathComponent("rows.json")
        try Workload.roundTrip(expected, at: output, cancelled: { false })
        precondition(!FileManager.default.fileExists(atPath: output.path))
        do { try Workload.roundTrip(expected, at: output, cancelled: { true }); fatalError("Cancelled write accepted") }
        catch LabError.cancelled { }
        var owner: RetentionProbe? = RetentionProbe()
        weak var witness = owner
        owner?.hold(); owner = nil
        precondition(witness != nil)
        witness?.stop(); precondition(witness == nil)
        for p in [Pressure.serious, .critical] {
            precondition(Admission.limit(requested: 4, pressure: p, lowPower: false, speculative: true) == 0)
            precondition(Admission.limit(requested: 4, pressure: p, lowPower: false, speculative: false) == 1)
        }
        precondition(Admission.limit(requested: 4, pressure: .fair, lowPower: false, speculative: false) == 2)
        precondition(Admission.limit(requested: 4, pressure: .nominal, lowPower: true, speculative: true) == 0)
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1; queue.isSuspended = true
        let completed = DispatchGroup()
        let operations = (0..<4).map { _ -> ProfileOperation in
            completed.enter()
            return ProfileOperation { operation in
                precondition(operation.cancellationRequested)
                completed.leave()
            }
        }
        queue.addOperations(operations, waitUntilFinished: false)
        operations.forEach { $0.requestCancellation() }
        queue.isSuspended = false
        precondition(completed.wait(timeout: .now() + 10) == .success)
        queue.waitUntilAllOperationsAreFinished()
        precondition(operations.allSatisfy { $0.isFinished && !$0.isCancelled })
        print("PASS: ordered parity, empty input, cooperative cancellation, full/thumbnail dimensions, corruption, file round-trip/cleanup, callback ownership, pressure policy")
        print("PASS: four queued cooperative cancellations drain and preserve attempt callbacks")
        print("Host correctness only; no elapsed values, device traces, presentation or energy claims.")
    }
}
