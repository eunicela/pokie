import XCTest
@testable import PokieCore

final class SidePotCalculatorTests: XCTestCase {
    func testUnequalStackMultiwayAllInProducesCorrectSidePotsAndAwards() {
        let contributions = [
            0: 100,  // all-in, live
            1: 300,  // all-in, live
            2: 500,  // all-in, live
            3: 500   // called, then folded
        ]
        let pots = SidePotCalculator.buildPots(
            contributionsBySeatID: contributions,
            liveSeatIDs: [0, 1, 2]
        )

        XCTAssertEqual(pots, [
            SidePot(amount: 400, contributingSeatIDs: [0, 1, 2, 3], eligibleSeatIDs: [0, 1, 2]),
            SidePot(amount: 600, contributingSeatIDs: [1, 2, 3], eligibleSeatIDs: [1, 2]),
            SidePot(amount: 400, contributingSeatIDs: [2, 3], eligibleSeatIDs: [2])
        ])

        let board = [
            Card(.two, .clubs), Card(.seven, .diamonds), Card(.nine, .hearts),
            Card(.jack, .spades), Card(.king, .clubs)
        ]
        let handValues = [
            0: HandEvaluator.evaluate([Card(.ace, .clubs), Card(.ace, .diamonds)] + board),
            1: HandEvaluator.evaluate([Card(.queen, .clubs), Card(.queen, .diamonds)] + board),
            2: HandEvaluator.evaluate([Card(.three, .clubs), Card(.four, .diamonds)] + board)
        ]

        let awards = SidePotCalculator.distribute(pots: pots, handValuesBySeatID: handValues)

        XCTAssertEqual(awards.map(\.sharesBySeatID), [
            [0: 400],
            [1: 600],
            [2: 400]
        ])
        XCTAssertEqual(awards.map(\.winningSeatIDs), [[0], [1], [2]])
    }

    func testOddChipRemainderGoesToLowestSeat() {
        let pot = SidePot(amount: 101, contributingSeatIDs: [0, 1], eligibleSeatIDs: [0, 1])
        let sameHand = HandEvaluator.evaluate([
            Card(.ace, .clubs), Card(.king, .diamonds), Card(.queen, .hearts),
            Card(.jack, .spades), Card(.ten, .clubs)
        ])

        let awards = SidePotCalculator.distribute(pots: [pot], handValuesBySeatID: [0: sameHand, 1: sameHand])

        XCTAssertEqual(awards.first?.sharesBySeatID, [0: 51, 1: 50])
    }
}
