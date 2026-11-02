// Foundation-only host checks, Swift 5.9+ on macOS 13+. No UIKit or Apple service calls.
import Foundation

struct DemoEntitlement {
    let verified: Bool
    let expiration: Date?
    let revocation: Date?

    func grants(at now: Date) -> Bool {
        verified && revocation == nil && (expiration.map { now < $0 } ?? true)
    }
}

func replaceWholeCharacters(_ text: String, range: NSRange, replacement: String) -> String? {
    guard range.location != NSNotFound,
          let converted = Range(range, in: text) else { return nil }
    let boundaries = Set(text.indices).union([text.endIndex])
    guard boundaries.contains(converted.lowerBound),
          boundaries.contains(converted.upperBound) else { return nil }
    return text.replacingCharacters(in: converted, with: replacement)
}

func mergeCard(
    base: [String: String],
    local: [String: String],
    server: [String: String]
) -> (values: [String: String], conflicts: Set<String>) {
    precondition(Set(base.keys) == Set(local.keys))
    precondition(Set(base.keys) == Set(server.keys))
    var values = server
    var conflicts: Set<String> = []
    for key in base.keys {
        if local[key] != base[key] {
            if server[key] != base[key] && local[key] != server[key] {
                conflicts.insert(key)
            } else {
                values[key] = local[key]
            }
        }
    }
    return (values, conflicts)
}

enum WatchDeliveryPlan: Equatable {
    case fallback, queueCommand, tryImmediate
}

func watchPlan(ready: Bool, optedIn: Bool, reachable: Bool) -> WatchDeliveryPlan {
    guard ready, optedIn else { return .fallback }
    return reachable ? .tryImmediate : .queueCommand
}

let text = "A👩🏽‍💻e\u{301}B"
let start = text.index(after: text.startIndex)
let end = text.index(after: start)
let emoji = NSRange(start..<end, in: text)
precondition(replaceWholeCharacters(text, range: emoji, replacement: "X") == "AXe\u{301}B")
precondition(replaceWholeCharacters(text, range: NSRange(location: 2, length: 1), replacement: "X") == nil)
precondition(replaceWholeCharacters(text, range: NSRange(location: 100, length: 1), replacement: "X") == nil)
precondition(replaceWholeCharacters(text, range: NSRange(location: NSNotFound, length: 0), replacement: "X") == nil)
let expires = Date(timeIntervalSince1970: 100)
precondition(DemoEntitlement(verified: true, expiration: expires, revocation: nil)
    .grants(at: Date(timeIntervalSince1970: 99)))
precondition(!DemoEntitlement(verified: true, expiration: expires, revocation: nil).grants(at: expires))
precondition(!DemoEntitlement(verified: false, expiration: nil, revocation: nil).grants(at: expires))
precondition(!DemoEntitlement(verified: true, expiration: nil, revocation: expires).grants(at: expires))
let base = ["title": "Draft", "note": "Blue"]
let independent = mergeCard(base: base, local: ["title": "A", "note": "Blue"],
                            server: ["title": "Draft", "note": "Green"])
precondition(independent.values == ["title": "A", "note": "Green"])
precondition(independent.conflicts.isEmpty)
let disputed = mergeCard(base: base, local: ["title": "A", "note": "Blue"],
                         server: ["title": "B", "note": "Blue"])
precondition(disputed.conflicts == ["title"])
precondition(watchPlan(ready: false, optedIn: true, reachable: true) == .fallback)
precondition(watchPlan(ready: true, optedIn: true, reachable: false) == .queueCommand)
precondition(watchPlan(ready: true, optedIn: true, reachable: true) == .tryImmediate)
print("PASS: synthetic entitlement, Unicode replacement, field merge and watch-plan checks")
