import Foundation

public struct SidePot: Equatable, Codable, Sendable {
    public let amount: Int
    public let contributingSeatIDs: [Int]
    public let eligibleSeatIDs: [Int]

    public init(amount: Int, contributingSeatIDs: [Int], eligibleSeatIDs: [Int]) {
        self.amount = amount
        self.contributingSeatIDs = contributingSeatIDs.sorted()
        self.eligibleSeatIDs = eligibleSeatIDs.sorted()
    }
}

public struct PotAward: Equatable, Codable, Sendable {
    public let potIndex: Int
    public let potAmount: Int
    public let winningSeatIDs: [Int]
    public let sharesBySeatID: [Int: Int]
    public let winningHandLabel: String?

    public init(
        potIndex: Int,
        potAmount: Int,
        winningSeatIDs: [Int],
        sharesBySeatID: [Int: Int],
        winningHandLabel: String?
    ) {
        self.potIndex = potIndex
        self.potAmount = potAmount
        self.winningSeatIDs = winningSeatIDs.sorted()
        self.sharesBySeatID = sharesBySeatID
        self.winningHandLabel = winningHandLabel
    }
}

public enum SidePotCalculator {
    public static func buildPots(contributionsBySeatID: [Int: Int], liveSeatIDs: Set<Int>) -> [SidePot] {
        let positiveContributions = contributionsBySeatID.filter { $0.value > 0 }
        let levels = Array(Set(positiveContributions.values)).sorted()
        var previousLevel = 0
        var pots: [SidePot] = []

        for level in levels {
            let contributors = positiveContributions
                .filter { $0.value >= level }
                .map { $0.key }
                .sorted()
            let amount = (level - previousLevel) * contributors.count
            if amount > 0 {
                let eligible = contributors.filter { liveSeatIDs.contains($0) }
                pots.append(SidePot(amount: amount, contributingSeatIDs: contributors, eligibleSeatIDs: eligible))
            }
            previousLevel = level
        }

        return pots
    }

    public static func distribute(
        pots: [SidePot],
        handValuesBySeatID: [Int: HandValue]
    ) -> [PotAward] {
        pots.enumerated().compactMap { index, pot in
            let contenders = pot.eligibleSeatIDs.compactMap { seatID -> (Int, HandValue)? in
                guard let value = handValuesBySeatID[seatID] else { return nil }
                return (seatID, value)
            }
            guard let bestValue = contenders.map { $0.1 }.max() else {
                return nil
            }

            let winners = contenders
                .filter { $0.1 == bestValue }
                .map { $0.0 }
                .sorted()
            let baseShare = pot.amount / winners.count
            let remainder = pot.amount % winners.count
            var shares = Dictionary(uniqueKeysWithValues: winners.map { ($0, baseShare) })

            // Odd chips go to the lowest-numbered remaining seat for deterministic cash-game splits.
            for winner in winners.prefix(remainder) {
                shares[winner, default: 0] += 1
            }

            return PotAward(
                potIndex: index,
                potAmount: pot.amount,
                winningSeatIDs: winners,
                sharesBySeatID: shares,
                winningHandLabel: bestValue.label
            )
        }
    }
}
