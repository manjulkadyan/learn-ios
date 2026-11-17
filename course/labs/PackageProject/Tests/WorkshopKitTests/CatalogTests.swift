import Foundation
import XCTest
import WorkshopKit

final class CatalogTests: XCTestCase {
    func testBundledResourceThroughPublicAPI() throws {
        let catalog = try Catalog.bundled()
        XCTAssertEqual(catalog.cards.map(\.id), ["blue", "green"])
        XCTAssertEqual(catalog.totalMinutes(), 40)
        XCTAssertNil(catalog.card(id: "absent"))
    }

    func testDuplicateIdentityRejectsWholeCandidate() {
        let duplicate = [WorkshopCard(id: "blue", title: "One", minutes: 10),
                         WorkshopCard(id: "blue", title: "Two", minutes: 20)]
        XCTAssertThrowsError(try Catalog(cards: duplicate)) {
            XCTAssertEqual($0 as? CatalogError, .duplicateID("blue"))
        }
    }

    func testCorruptAndOutOfRangeAreDifferentFailures() {
        XCTAssertThrowsError(try Catalog.decode(Data("broken".utf8))) {
            XCTAssertEqual($0 as? CatalogError, .invalidJSON)
        }
        let bad = Data(#"[{"id":"red","title":"Red","minutes":241}]"#.utf8)
        XCTAssertThrowsError(try Catalog.decode(bad)) {
            XCTAssertEqual($0 as? CatalogError, .invalidCard("red"))
        }
    }

    func testLimitsAndValueCopies() throws {
        let first = try Catalog(cards: [WorkshopCard(id: "edge", title: "Edge", minutes: 240)])
        var copy = first.cards
        copy.append(WorkshopCard(id: "new", title: "New", minutes: 1))
        XCTAssertEqual(first.cards.count, 1)
        XCTAssertEqual(try Catalog(cards: copy).totalMinutes(), 241)
        XCTAssertThrowsError(try Catalog(cards: [WorkshopCard(id: " ", title: "", minutes: 0)]))
    }
}
