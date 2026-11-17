import Foundation

enum TodoError: Error, Equatable {
    case emptyTitle, titleTooLong, nonCanonicalTitle, duplicateID, unknownID, invalidMove
    case unsupportedVersion(Int), unsavedChanges
}

struct Todo: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    private(set) var title: String
    private(set) var isComplete: Bool

    init(id: UUID = UUID(), title: String, isComplete: Bool = false) throws {
        self.id = id
        self.title = try Self.normalizedTitle(title)
        self.isComplete = isComplete
    }

    static func normalizedTitle(_ input: String) throws -> String {
        let title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TodoError.emptyTitle }
        guard title.count <= 80 else { throw TodoError.titleTooLong }
        return title
    }

    mutating func rename(to input: String) throws { title = try Self.normalizedTitle(input) }
    mutating func toggle() { isComplete.toggle() }

    static func validate(_ items: [Todo]) throws {
        var seen = Set<UUID>()
        for item in items {
            guard seen.insert(item.id).inserted else { throw TodoError.duplicateID }
            guard try normalizedTitle(item.title) == item.title else { throw TodoError.nonCanonicalTitle }
        }
    }
}

// Destination is a boundary in the ORIGINAL array, as in SwiftUI's onMove.
// No SwiftUI import is needed for this deterministic domain operation.
func movedTodos(_ items: [Todo], from offsets: IndexSet, to destination: Int) throws -> [Todo] {
    guard (0...items.count).contains(destination),
          offsets.allSatisfy({ items.indices.contains($0) }) else { throw TodoError.invalidMove }
    let moving = offsets.map { items[$0] }
    var remaining = items.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    let adjusted = destination - offsets.filter { $0 < destination }.count
    remaining.insert(contentsOf: moving, at: adjusted)
    return remaining
}
