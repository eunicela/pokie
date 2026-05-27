import Foundation

public enum EquityCalculator {

    public static func equity<R: RandomNumberGenerator>(
        holeCards: [Card],
        board: [Card],
        opponentCount: Int,
        rollouts: Int = 2000,
        using random: inout R
    ) -> Double {
        guard holeCards.count == 2, opponentCount > 0 else { return 0 }

        let dead = Set(holeCards + board)
        var stub = Card.fullDeck.filter { !dead.contains($0) }
        let boardRemaining = 5 - board.count
        let cardsNeeded = boardRemaining + opponentCount * 2

        guard stub.count >= cardsNeeded else { return 0 }

        var wins = 0.0
        for _ in 0..<rollouts {
            stub.shuffle(using: &random)

            let runout = board + stub.prefix(boardRemaining)
            let heroValue = HandEvaluator.evaluate(holeCards + runout)

            var heroWins = true
            var tie = false
            var offset = boardRemaining
            for _ in 0..<opponentCount {
                let oppCards = [stub[offset], stub[offset + 1]]
                offset += 2
                let oppValue = HandEvaluator.evaluate(oppCards + runout)
                if oppValue > heroValue {
                    heroWins = false
                    tie = false
                    break
                } else if oppValue == heroValue {
                    tie = true
                }
            }
            if heroWins {
                wins += tie ? 0.5 : 1.0
            }
        }
        return wins / Double(rollouts)
    }
}

extension Card {
    static let fullDeck: [Card] = {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(rank, suit))
            }
        }
        return cards
    }()
}
