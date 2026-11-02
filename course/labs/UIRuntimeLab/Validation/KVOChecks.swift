import Foundation

@main
enum KVOChecks {
    static func main() {
        let record = CounterRecord()
        var changes: [Int] = []
        let token = record.observe(\.count, options: [.initial, .new]) { _, change in
            precondition(Thread.isMainThread)
            if let value = change.newValue { changes.append(value) }
        }
        precondition(changes == [0])
        record.count = 2
        precondition(changes == [0, 2])
        token.invalidate()
        token.invalidate()
        record.count = 3
        precondition(changes == [0, 2])
        print("PASS: synchronous initial/new KVO values and idempotent invalidation on macOS")
    }
}
