public enum RequestContext {
    @TaskLocal public static var trace: String?
}

public final class Draft {
    public var text: String
    public init(_ text: String) { self.text = text }
}
public actor DraftInbox {
    private var draft: Draft?
    public init() {}
    public func install(_ draft: sending Draft) { self.draft = draft }
    public func snapshot() -> String? { draft?.text }
}
public actor Ledger {
    public private(set) var total = 0
    public init() {}
    public func add(_ amount: Int) { total += amount }
}
public func batch(_ ledger: isolated Ledger) -> Int {
    ledger.add(2)
    ledger.add(3)
    return ledger.total
}

/// One allocation owner, no pointer exposed or retained across an await.
public struct OwnedInt: ~Copyable {
    private let storage: UnsafeMutablePointer<Int>
    public init(_ value: Int) {
        storage = .allocate(capacity: 1)
        storage.initialize(to: value)
    }
    public borrowing func read() -> Int { storage.pointee }
    public consuming func extract() -> Int { storage.pointee }
    deinit { storage.deinitialize(count: 1); storage.deallocate() }
}

public func scopedSum() -> Int {
    let pointer = UnsafeMutablePointer<Int>.allocate(capacity: 2)
    pointer.initialize(repeating: 4, count: 2)
    defer { pointer.deinitialize(count: 2); pointer.deallocate() }
    return pointer[0] + pointer[1]
}

public final class CallbackBox {
    public let value: Int
    public init(_ value: Int) { self.value = value }
}
/// Synchronous simulation of a C API returning an owned (+1) context exactly once.
/// This is not an asynchronous callback adapter.
public func retainedRoundTrip(_ box: CallbackBox) -> Int {
    let context = Unmanaged.passRetained(box).toOpaque()
    let recovered = Unmanaged<CallbackBox>.fromOpaque(context).takeRetainedValue()
    return recovered.value
}
