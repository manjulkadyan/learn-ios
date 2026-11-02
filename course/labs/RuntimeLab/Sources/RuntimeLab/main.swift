import Foundation
import Dispatch
import CoreFoundation
import Synchronization
import os

enum LabError: Error { case failed(String), fixture }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw LabError.failed(message) }
}

// The unchecked promise is limited to one private field; every access uses lock.
final class LockedValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func update<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
    func snapshot() -> Value { update { $0 } }
}

func checkQueues() throws {
    let serial = DispatchQueue(label: "runtime.serial", qos: .utility)
    let events = LockedValue<[Int]>([])
    let group = DispatchGroup()
    for index in 0..<40 {
        serial.async(group: group) { events.update { $0.append(index) } }
    }
    try require(group.wait(timeout: .now() + 5) == .success, "serial timeout")
    try require(events.snapshot() == Array(0..<40), "serial submission order")

    let readers = DispatchQueue(label: "runtime.barrier", attributes: .concurrent)
    let value = LockedValue(0)
    readers.async(flags: .barrier) { value.update { $0 = 17 } }
    let observed = readers.sync { value.snapshot() }
    try require(observed == 17, "post-barrier read")

    let cancelledEffects = LockedValue(0)
    let work = DispatchWorkItem { cancelledEffects.update { $0 += 1 } }
    work.cancel() // Deterministically cancelled BEFORE submission, not mid-body.
    serial.async(execute: work)
    serial.sync {} // Drain from the host caller, never from serial itself.
    try require(work.isCancelled && cancelledEffects.snapshot() == 0,
                "pre-submission work-item cancellation")

    let sourceQueue = DispatchQueue(label: "runtime.source")
    let source = DispatchSource.makeUserDataAddSource(queue: sourceQueue)
    let delivered = DispatchSemaphore(value: 0)
    let cancelled = DispatchSemaphore(value: 0)
    let payload = LockedValue<UInt>(0)
    source.setEventHandler { payload.update { $0 += source.data }; delivered.signal() }
    source.setCancelHandler { cancelled.signal() }
    source.activate()
    source.add(data: 3)
    try require(delivered.wait(timeout: .now() + 5) == .success, "source timeout")
    source.cancel()
    try require(cancelled.wait(timeout: .now() + 5) == .success, "cancel handler timeout")
    source.setEventHandler(handler: nil) // Break source -> handler -> source ownership.
    try require(payload.snapshot() == 3, "source aggregate payload")
}

func checkOperations() throws {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 2
    let result = LockedValue<Result<Int, LabError>?>(nil)
    let events = LockedValue<[String]>([])
    let finished = DispatchSemaphore(value: 0)
    let producer = BlockOperation {
        result.update { $0 = .failure(.fixture) }
        events.update { $0.append("produce") }
    }
    let consumer = BlockOperation {
        if case .failure? = result.snapshot() {
            events.update { $0.append("recover") }
        }
    }
    consumer.addDependency(producer)
    consumer.completionBlock = { finished.signal() }
    queue.addOperations([consumer, producer], waitUntilFinished: false)
    try require(finished.wait(timeout: .now() + 5) == .success, "operation timeout")
    try require(events.snapshot() == ["produce", "recover"], "dependency and error policy")

    let effects = LockedValue(0)
    let stopped = DispatchSemaphore(value: 0)
    let cancelled = BlockOperation { effects.update { $0 += 1 } }
    cancelled.completionBlock = { stopped.signal() }
    cancelled.cancel()
    queue.addOperation(cancelled)
    try require(stopped.wait(timeout: .now() + 5) == .success, "cancelled operation timeout")
    try require(effects.snapshot() == 0 && cancelled.isFinished,
                "cancelled operation finishes without executing body")
}

func checkLocks() throws {
    let classic = LockedValue(0)
    let modern = Mutex(0)
    let unfair = OSAllocatedUnfairLock(initialState: 0)
    DispatchQueue.concurrentPerform(iterations: 2_000) { _ in
        classic.update { $0 += 1 }
        modern.withLock { $0 += 1 }
        unfair.withLock { $0 += 1 }
    }
    try require(classic.snapshot() == 2_000, "NSLock lost updates")
    try require(modern.withLock { $0 } == 2_000, "Mutex lost updates")
    try require(unfair.withLock { $0 } == 2_000, "allocated unfair lock lost updates")
    do { try classic.update { _ in throw LabError.fixture } }
    catch LabError.fixture { }
    try require(classic.snapshot() == 2_000, "throwing path unlock")
}

// Bounded host probe: no nested application event loop and no UIKit claim.
func checkRunLoopMode() throws {
    let count = LockedValue(0)
    let mode = RunLoop.Mode("RuntimeLab.synthetic")
    let timer = Timer(fire: .distantPast, interval: 0, repeats: false) { _ in
        count.update { $0 += 1 }
    }
    RunLoop.current.add(timer, forMode: mode)
    defer { timer.invalidate() }
    _ = CFRunLoopRunInMode(.defaultMode, 0.01, true)
    try require(count.snapshot() == 0, "custom timer leaked into default mode")
    _ = CFRunLoopRunInMode(CFRunLoopMode(mode.rawValue as CFString), 0.1, true)
    try require(count.snapshot() == 1, "custom timer delivery")
}

@concurrent
func checksum(_ input: [Int]) async throws -> Int {
    var total = 0
    for (index, value) in input.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        total += value
    }
    try Task.checkCancellation()
    return total
}

func windowedChecksums(_ batches: [[Int]], width: Int) async throws -> [Int] {
    precondition(width > 0)
    return try await withThrowingTaskGroup(of: (Int, Int).self) { group in
        var next = 0
        var output = Array(repeating: 0, count: batches.count)
        func admit(_ index: Int) {
            let input = batches[index]
            group.addTask { (index, try await checksum(input)) }
        }
        while next < min(width, batches.count) {
            try Task.checkCancellation()
            admit(next)
            next += 1
        }
        while let (index, value) = try await group.next() {
            output[index] = value
            try Task.checkCancellation()
            if next < batches.count { admit(next); next += 1 }
        }
        return output
    }
}

// This bridge deliberately waits for an in-flight read after cancellation.
// Callers bound admission; maxConcurrentOperationCount alone does not bound backlog.
final class BlockingFileReader: Sendable {
    private let queue: OperationQueue
    init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .utility
    }
    func read(_ url: URL) async throws -> Data {
        try Task.checkCancellation()
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            queue.addOperation {
                do { continuation.resume(returning: try Data(contentsOf: url)) }
                catch { continuation.resume(throwing: error) }
            }
        }
        try Task.checkCancellation()
        return data
    }
}

actor StartGate {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        open = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

@main
struct RuntimeLab {
    static func main() async throws {
        // Synchronous probes run before the first suspension on this CLI host.
        try checkRunLoopMode()
        try checkQueues()
        try checkOperations()
        try checkLocks()
        let totals = try await windowedChecksums([[1, 2, 3], [4, 5], [], [6]], width: 2)
        try require(totals == [6, 9, 0, 6], "ordered bounded checksum values")
        let gate = StartGate()
        let task = Task { await gate.wait(); return try await checksum([1, 2, 3]) }
        task.cancel()
        await gate.release() // Always released; never deliberately starve executor.
        do { _ = try await task.value; throw LabError.failed("cancelled checksum succeeded") }
        catch is CancellationError { }

        guard let root = ProcessInfo.processInfo.environment["RUNTIME_LAB_TMP"] else {
            throw LabError.failed("Set RUNTIME_LAB_TMP to a unique /private/tmp directory")
        }
        let url = URL(fileURLWithPath: root).appendingPathComponent("fixture.txt")
        let fixture = Data("synthetic runtime fixture".utf8)
        try fixture.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let reader = BlockingFileReader()
        let read = try await reader.read(url)
        try require(read == fixture, "blocking bridge bytes")
        do {
            let missing = url.deletingLastPathComponent().appendingPathComponent("missing-file.txt")
            _ = try await reader.read(missing)
            throw LabError.failed("missing-file error lost")
        } catch let failure as LabError { throw failure }
          catch let failure as CocoaError {
            try require(failure.code == .fileReadNoSuchFile, "expected missing-file CocoaError")
        }
        print("PASS: run-loop mode, queue/group/barrier/source/work item, operations, three locks, bounded CPU values, cancellation, file success/error")
    }
}
