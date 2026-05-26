import XCTest
@testable import PokerTrainerCore

final class HandEvaluatorTests: XCTestCase {
    func testRoyalFlushBeatsStraightFlush() {
        let royal = HandEvaluator.evaluate([
            Card(.ace, .hearts), Card(.king, .hearts),
            Card(.queen, .hearts), Card(.jack, .hearts),
            Card(.ten, .hearts), Card(.two, .clubs),
            Card(.three, .spades)
        ])
        let straightFlush = HandEvaluator.evaluate([
            Card(.nine, .clubs), Card(.eight, .clubs),
            Card(.seven, .clubs), Card(.six, .clubs),
            Card(.five, .clubs), Card(.ace, .diamonds),
            Card(.king, .spades)
        ])

        XCTAssertEqual(royal.category, .royalFlush)
        XCTAssertEqual(straightFlush.category, .straightFlush)
        XCTAssertGreaterThan(royal, straightFlush)
    }

    func testWheelStraightUsesFiveHighKicker() {
        let value = HandEvaluator.evaluate([
            Card(.ace, .spades), Card(.two, .diamonds),
            Card(.three, .clubs), Card(.four, .hearts),
            Card(.five, .spades), Card(.king, .clubs),
            Card(.queen, .hearts)
        ])

        XCTAssertEqual(value.category, .straight)
        XCTAssertEqual(value.tiebreakers, [5])
    }

    func testKickersBreakPairTies() {
        let aceQueenKicker = HandEvaluator.evaluate([
            Card(.ace, .spades), Card(.ace, .clubs),
            Card(.queen, .diamonds), Card(.nine, .hearts),
            Card(.seven, .clubs), Card(.four, .spades),
            Card(.two, .diamonds)
        ])
        let aceJackKicker = HandEvaluator.evaluate([
            Card(.ace, .diamonds), Card(.ace, .hearts),
            Card(.jack, .diamonds), Card(.nine, .clubs),
            Card(.seven, .spades), Card(.four, .clubs),
            Card(.two, .hearts)
        ])

        XCTAssertGreaterThan(aceQueenKicker, aceJackKicker)
    }
}
