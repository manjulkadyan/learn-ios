/// All values in this module are synthetic learning fixtures.
public struct Reading: Equatable, Sendable {
    public let topic: String
    public let minutes: Int

    public init(topic: String, minutes: Int) {
        self.topic = topic
        self.minutes = minutes
    }
}

public enum LanguageExamples {
    /// Keep input order, omit nonpositive entries, and transform the survivors.
    public static func labels(for readings: [Reading]) -> [String] {
        readings.filter { $0.minutes > 0 }.map { "\($0.topic): \($0.minutes)" }
    }

    /// Dictionary iteration order is not the display contract; sort at the boundary.
    public static func totalsByTopic(_ readings: [Reading]) -> [(topic: String, minutes: Int)] {
        var totals: [String: Int] = [:]
        for reading in readings where reading.minutes > 0 {
            totals[reading.topic, default: 0] += reading.minutes
        }
        return totals.keys.sorted().map { ($0, totals[$0, default: 0]) }
    }

    public static func distinctTopics(_ readings: [Reading]) -> [String] {
        Set(readings.map(\.topic)).sorted()
    }

    /// compactMap deliberately drops malformed input; this is not a validation API.
    public static func parsePresentIntegers(_ text: [String]) -> [Int] {
        text.compactMap(Int.init)
    }

    /// Lazy iteration can stop early. It does not cache a computed result.
    public static func firstEvenSquare(in numbers: [Int]) -> Int? {
        numbers.lazy.filter { $0.isMultiple(of: 2) }.map { $0 * $0 }.first
    }

    public static func transfer(_ amount: Int, from source: inout Int, to destination: inout Int) {
        precondition(amount >= 0 && source >= amount)
        source -= amount
        destination += amount
    }
}

public struct ReadingPlan: Equatable, Sendable {
    public private(set) var topics: [String]

    public init(topics: [String] = []) { self.topics = topics }

    public mutating func append(_ topic: String) { topics.append(topic) }
}

/// A value containing a reference still shares that referenced object's identity.
/// This deliberately mutable reference is NOT Sendable.
public final class ReferenceCounter {
    public var value: Int
    public init(_ value: Int) { self.value = value }
}

public struct CounterEnvelope {
    public let counter: ReferenceCounter
    public init(counter: ReferenceCounter) { self.counter = counter }
}

public struct Stack<Element: Sendable>: Sendable {
    private var storage: [Element] = []
    public init() {}
    public var count: Int { storage.count }
    public mutating func push(_ element: Element) { storage.append(element) }
    public mutating func pop() -> Element? { storage.popLast() }
}

public protocol LessonLabel: Sendable {
    var text: String { get }
}

public struct TopicLabel: LessonLabel, Equatable {
    public let text: String
    public init(text: String) { self.text = text }
}

/// A generic keeps the caller's concrete type available to this operation.
public func renderedLabel<T: LessonLabel>(_ label: T) -> String { label.text }

/// An opaque result hides one fixed implementation type, not an arbitrary runtime choice.
public func makeLabel(_ text: String) -> some LessonLabel { TopicLabel(text: text) }

/// An existential collection permits different conforming concrete types.
public func renderLabels(_ labels: [any LessonLabel]) -> [String] { labels.map(\.text) }
