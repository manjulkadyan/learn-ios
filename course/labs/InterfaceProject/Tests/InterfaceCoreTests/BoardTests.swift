import XCTest
import InterfaceCore

final class BoardTests: XCTestCase {
    func testInvalidDraftKeepsPublishedBoard() {
        var board = Board.sample
        var draft = CardDraft(card: board.cards[0])
        draft.title = " \n "
        XCTAssertEqual(board.save(draft), .invalid(.title))
        XCTAssertEqual(board.totalMinutes, 40)
        draft.title = "Edited"
        draft.minutesText = "241"
        XCTAssertEqual(board.save(draft), .invalid(.minutes))
        XCTAssertEqual(board.cards[0].title, "Blue notebook")
        draft.minutesText = "20"
        XCTAssertEqual(board.save(draft), .saved)
        XCTAssertEqual(board.totalMinutes, 45)
        XCTAssertEqual(board.cards[0].revision, 1)
    }

    func testStaleDraftCannotUndoNewPinAndDeleteMakesRouteMissing() {
        var board = Board.sample
        let old = CardDraft(card: board.cards[0])
        board.togglePin(id: "blue")
        XCTAssertEqual(board.save(old), .conflict)
        XCTAssertTrue(board.cards[0].pinned)
        board.remove(id: "blue")
        XCTAssertNil(board.card(id: "blue"))
        XCTAssertEqual(board.save(old), .missing)
    }

    func testDuplicateIdentityRejected() {
        let card = Board.sample.cards[0]
        XCTAssertThrowsError(try Board(cards: [card, card])) {
            XCTAssertEqual($0 as? BoardError, .duplicateID)
        }
    }

    func testAdaptiveAndGestureBoundaries() {
        XCTAssertEqual(InteractionPolicy.columns(width: 599, accessibilityText: false), 1)
        XCTAssertEqual(InteractionPolicy.columns(width: 600, accessibilityText: false), 2)
        XCTAssertEqual(InteractionPolicy.columns(width: 800, accessibilityText: true), 1)
        XCTAssertFalse(InteractionPolicy.shouldTogglePin(dx: 79, dy: 0))
        XCTAssertFalse(InteractionPolicy.shouldTogglePin(dx: 100, dy: 70))
        XCTAssertFalse(InteractionPolicy.shouldTogglePin(dx: 80, dy: 40))
        XCTAssertTrue(InteractionPolicy.shouldTogglePin(dx: -80, dy: 0))
    }
}
