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
        XCTAssertEqual(board.togglePin(id: "blue"), .toggled)
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

    func testExhaustedSavePreservesEveryPublishedFieldAndDraft() throws {
        var board = try Board(cards: [
            BoardCard(id: "blue", title: "Blue notebook", minutes: 15, pinned: true, revision: Int.max),
            BoardCard(id: "green", title: "Green notebook", minutes: 25)
        ])
        var draft = CardDraft(card: board.cards[0])
        draft.title = "Edited title"
        draft.minutesText = "20"
        let publishedBefore = board.cards
        let draftBefore = draft

        for _ in 0..<2 {
            XCTAssertEqual(board.save(draft), .revisionExhausted)
            XCTAssertEqual(board.cards, publishedBefore)
            XCTAssertEqual(board.totalMinutes, 40)
            XCTAssertEqual(draft, draftBefore)
        }
    }

    func testExhaustedPinPreservesEntireBoardInBothDirections() throws {
        for pinned in [false, true] {
            var board = try Board(cards: [
                BoardCard(id: "blue", title: "Blue notebook", minutes: 15, pinned: pinned, revision: Int.max),
                BoardCard(id: "green", title: "Green notebook", minutes: 25)
            ])
            let publishedBefore = board.cards
            for _ in 0..<2 {
                XCTAssertEqual(board.togglePin(id: "blue"), .revisionExhausted)
                XCTAssertEqual(board.cards, publishedBefore)
                XCTAssertEqual(board.totalMinutes, 40)
            }
        }
    }

    func testLastRevisionStepSucceedsThenBothActionsRejectWithoutMutation() throws {
        for saveFirst in [false, true] {
            var board = try Board(cards: [
                BoardCard(id: "blue", title: "Blue notebook", minutes: 15, revision: Int.max - 1),
                BoardCard(id: "green", title: "Green notebook", minutes: 25)
            ])
            var oldDraft = CardDraft(card: board.cards[0])
            oldDraft.minutesText = "20"
            if saveFirst {
                XCTAssertEqual(board.save(oldDraft), .saved)
                XCTAssertEqual(board.totalMinutes, 45)
            } else {
                XCTAssertEqual(board.togglePin(id: "blue"), .toggled)
                XCTAssertTrue(board.cards[0].pinned)
                XCTAssertEqual(board.totalMinutes, 40)
            }
            XCTAssertEqual(board.cards[0].revision, Int.max)
            let publishedBefore = board.cards
            XCTAssertEqual(board.save(oldDraft), .conflict)
            var currentDraft = CardDraft(card: board.cards[0])
            currentDraft.title = "Another edit"
            currentDraft.minutesText = "30"
            XCTAssertEqual(board.save(currentDraft), .revisionExhausted)
            XCTAssertEqual(board.togglePin(id: "blue"), .revisionExhausted)
            XCTAssertEqual(board.cards, publishedBefore)
        }
    }

    func testMissingPinReturnsAnOutcomeWithoutChangingAnyCard() {
        var board = Board.sample
        let publishedBefore = board.cards
        XCTAssertEqual(board.togglePin(id: "absent"), .missing)
        XCTAssertEqual(board.cards, publishedBefore)
        XCTAssertEqual(board.totalMinutes, 40)
    }
}
