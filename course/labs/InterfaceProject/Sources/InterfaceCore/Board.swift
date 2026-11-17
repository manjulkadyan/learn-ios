import Foundation

public struct BoardCard: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var minutes: Int
    public var pinned: Bool
    public var revision: Int

    public init(id: String, title: String, minutes: Int, pinned: Bool = false, revision: Int = 0) {
        self.id = id; self.title = title; self.minutes = minutes
        self.pinned = pinned; self.revision = revision
    }
}

public struct CardDraft: Equatable, Sendable {
    public let id: String
    public let baseRevision: Int
    public var title: String
    public var minutesText: String

    public init(card: BoardCard) {
        id = card.id; baseRevision = card.revision
        title = card.title; minutesText = String(card.minutes)
    }
}

public enum Field: String, Hashable, Sendable { case title, minutes }
public enum SaveOutcome: Equatable, Sendable {
    case saved
    case invalid(Field)
    case missing
    case conflict
    case revisionExhausted
}
public enum PinOutcome: Equatable, Sendable {
    case toggled
    case missing
    case revisionExhausted
}
public enum BoardError: Error, Equatable { case duplicateID, invalidCard }

public struct Board: Sendable {
    public private(set) var cards: [BoardCard]

    public init(cards: [BoardCard]) throws {
        guard Set(cards.map(\.id)).count == cards.count else { throw BoardError.duplicateID }
        guard cards.allSatisfy({ !$0.id.isEmpty && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...240).contains($0.minutes) && $0.revision >= 0 }) else {
            throw BoardError.invalidCard
        }
        self.cards = cards
    }

    public static var sample: Board {
        // Known fixture; production input must use the throwing initializer.
        try! Board(cards: [BoardCard(id: "blue", title: "Blue notebook", minutes: 15),
                          BoardCard(id: "green", title: "Green notebook", minutes: 25)])
    }

    public func card(id: String) -> BoardCard? { cards.first { $0.id == id } }
    public var totalMinutes: Int { cards.reduce(0) { $0 + $1.minutes } }

    public mutating func save(_ draft: CardDraft) -> SaveOutcome {
        guard let index = cards.firstIndex(where: { $0.id == draft.id }) else { return .missing }
        guard cards[index].revision == draft.baseRevision else { return .conflict }
        let (nextRevision, overflow) = cards[index].revision.addingReportingOverflow(1)
        guard !overflow else { return .revisionExhausted }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .invalid(.title) }
        guard let minutes = Int(draft.minutesText), (1...240).contains(minutes) else { return .invalid(.minutes) }
        var candidate = cards[index]
        candidate.title = title
        candidate.minutes = minutes
        candidate.revision = nextRevision
        cards[index] = candidate
        return .saved
    }

    public mutating func togglePin(id: String) -> PinOutcome {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return .missing }
        let (nextRevision, overflow) = cards[index].revision.addingReportingOverflow(1)
        guard !overflow else { return .revisionExhausted }
        var candidate = cards[index]
        candidate.pinned.toggle()
        candidate.revision = nextRevision
        cards[index] = candidate
        return .toggled
    }
    public mutating func remove(id: String) { cards.removeAll { $0.id == id } }
}

public enum InteractionPolicy {
    /// This product uses one column for large text or a narrow available region.
    public static func columns(width: Double, accessibilityText: Bool) -> Int {
        width >= 600 && !accessibilityText ? 2 : 1
    }
    /// Trigger one pin action only at the end of a deliberate horizontal movement.
    public static func shouldTogglePin(dx: Double, dy: Double) -> Bool {
        abs(dx) >= 80 && abs(dx) > 2 * abs(dy)
    }
}
