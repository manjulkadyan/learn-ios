import Foundation

public struct WorkshopCard: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let minutes: Int

    public init(id: String, title: String, minutes: Int) {
        self.id = id
        self.title = title
        self.minutes = minutes
    }
}

public enum CatalogError: Error, Equatable, Sendable {
    case missingResource
    case invalidJSON
    case invalidCard(String)
    case duplicateID(String)
}

public struct Catalog: Sendable {
    public let cards: [WorkshopCard]

    /// Validates the whole candidate before publishing a catalog.
    public init(cards: [WorkshopCard]) throws {
        var seen: Set<String> = []
        for card in cards {
            guard !card.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...240).contains(card.minutes) else {
                throw CatalogError.invalidCard(card.id)
            }
            guard seen.insert(card.id).inserted else {
                throw CatalogError.duplicateID(card.id)
            }
        }
        self.cards = cards
    }

    public static func decode(_ data: Data) throws -> Catalog {
        let candidate: [WorkshopCard]
        do { candidate = try JSONDecoder().decode([WorkshopCard].self, from: data) }
        catch { throw CatalogError.invalidJSON }
        return try Catalog(cards: candidate)
    }

    public static func bundled() throws -> Catalog {
        guard let url = Bundle.module.url(forResource: "cards", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        // A read error remains an IO error; it must not masquerade as valid empty data.
        return try decode(Data(contentsOf: url))
    }

    public func totalMinutes() -> Int { cards.reduce(0) { $0 + $1.minutes } }
    public func card(id: String) -> WorkshopCard? { cards.first { $0.id == id } }
}
