import Foundation

public enum HandRankCategory: Int, CaseIterable, Codable, Comparable, Sendable {
    case highCard = 1
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush
    case royalFlush

    public var title: String {
        switch self {
        case .royalFlush: return "Royal Flush"
        case .straightFlush: return "Straight Flush"
        case .fourOfAKind: return "Four of a Kind"
        case .fullHouse: return "Full House"
        case .flush: return "Flush"
        case .straight: return "Straight"
        case .threeOfAKind: return "Three of a Kind"
        case .twoPair: return "Two Pair"
        case .onePair: return "One Pair"
        case .highCard: return "High Card"
        }
    }

    public var teachingDescription: String {
        switch self {
        case .royalFlush: return "A, K, Q, J, 10 all in the same suit."
        case .straightFlush: return "Five consecutive cards in the same suit."
        case .fourOfAKind: return "Four cards of the same rank."
        case .fullHouse: return "Three of one rank plus a pair."
        case .flush: return "Any five cards of the same suit."
        case .straight: return "Five consecutive cards of mixed suits."
        case .threeOfAKind: return "Three cards of the same rank."
        case .twoPair: return "Two different pairs plus a kicker."
        case .onePair: return "One pair plus three kickers."
        case .highCard: return "No made hand; highest cards decide."
        }
    }

    public static func < (lhs: HandRankCategory, rhs: HandRankCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct HandValue: Comparable, Codable, Sendable {
    public let category: HandRankCategory
    public let tiebreakers: [Int]
    public let bestCards: [Card]

    public init(category: HandRankCategory, tiebreakers: [Int], bestCards: [Card]) {
        self.category = category
        self.tiebreakers = tiebreakers
        self.bestCards = bestCards.sorted(by: >)
    }

    public var label: String {
        switch category {
        case .royalFlush:
            return "Royal Flush"
        case .straightFlush:
            return "Straight Flush, \(rankName(tiebreakers[0])) High"
        case .fourOfAKind:
            return "Four of a Kind, \(pluralRankName(tiebreakers[0]))"
        case .fullHouse:
            return "Full House, \(pluralRankName(tiebreakers[0])) over \(pluralRankName(tiebreakers[1]))"
        case .flush:
            return "Flush, \(rankName(tiebreakers[0])) High"
        case .straight:
            return "Straight, \(rankName(tiebreakers[0])) High"
        case .threeOfAKind:
            return "Three of a Kind, \(pluralRankName(tiebreakers[0]))"
        case .twoPair:
            return "Two Pair, \(pluralRankName(tiebreakers[0])) and \(pluralRankName(tiebreakers[1]))"
        case .onePair:
            return "One Pair, \(pluralRankName(tiebreakers[0]))"
        case .highCard:
            return "High Card, \(rankName(tiebreakers[0]))"
        }
    }

    public static func < (lhs: HandValue, rhs: HandValue) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }
        return lhs.tiebreakers.lexicographicallyPrecedes(rhs.tiebreakers)
    }

    private func rankName(_ rawValue: Int) -> String {
        Rank(rawValue: rawValue)?.singularName ?? "\(rawValue)"
    }

    private func pluralRankName(_ rawValue: Int) -> String {
        Rank(rawValue: rawValue)?.pluralName ?? "\(rawValue)s"
    }
}

public enum HandEvaluator {
    public static func evaluate(_ cards: [Card]) -> HandValue {
        precondition((5...7).contains(cards.count), "Texas Hold'em evaluation needs 5 to 7 cards")

        var best: HandValue?
        for fiveCards in combinations(of: cards, choosing: 5) {
            let value = evaluateExactlyFive(fiveCards)
            if best == nil || value > best! {
                best = value
            }
        }
        return best!
    }

    public static func compare(_ lhs: [Card], _ rhs: [Card]) -> ComparisonResult {
        let left = evaluate(lhs)
        let right = evaluate(rhs)
        if left == right { return .orderedSame }
        return left < right ? .orderedAscending : .orderedDescending
    }

    public static func representativeCards(for category: HandRankCategory) -> [Card] {
        switch category {
        case .royalFlush:
            return [.init(.ace, .hearts), .init(.king, .hearts), .init(.queen, .hearts), .init(.jack, .hearts), .init(.ten, .hearts)]
        case .straightFlush:
            return [.init(.nine, .spades), .init(.eight, .spades), .init(.seven, .spades), .init(.six, .spades), .init(.five, .spades)]
        case .fourOfAKind:
            return [.init(.queen, .clubs), .init(.queen, .diamonds), .init(.queen, .hearts), .init(.queen, .spades), .init(.three, .clubs)]
        case .fullHouse:
            return [.init(.ten, .clubs), .init(.ten, .diamonds), .init(.ten, .spades), .init(.four, .hearts), .init(.four, .clubs)]
        case .flush:
            return [.init(.ace, .diamonds), .init(.jack, .diamonds), .init(.eight, .diamonds), .init(.six, .diamonds), .init(.two, .diamonds)]
        case .straight:
            return [.init(.eight, .clubs), .init(.seven, .diamonds), .init(.six, .hearts), .init(.five, .spades), .init(.four, .clubs)]
        case .threeOfAKind:
            return [.init(.king, .clubs), .init(.king, .hearts), .init(.king, .spades), .init(.nine, .diamonds), .init(.two, .clubs)]
        case .twoPair:
            return [.init(.jack, .clubs), .init(.jack, .hearts), .init(.four, .diamonds), .init(.four, .spades), .init(.ace, .clubs)]
        case .onePair:
            return [.init(.ace, .clubs), .init(.ace, .diamonds), .init(.queen, .spades), .init(.seven, .clubs), .init(.three, .hearts)]
        case .highCard:
            return [.init(.ace, .spades), .init(.jack, .diamonds), .init(.nine, .clubs), .init(.six, .hearts), .init(.two, .spades)]
        }
    }

    private static func evaluateExactlyFive(_ cards: [Card]) -> HandValue {
        let rankValues = cards.map(\.rank.rawValue).sorted(by: >)
        let counts = Dictionary(grouping: rankValues, by: { $0 }).mapValues(\.count)
        let groups = counts
            .map { (rank: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.rank > $1.rank
            }

        let isFlush = Set(cards.map(\.suit)).count == 1
        let straightHigh = straightHighCard(from: rankValues)

        if isFlush, let straightHigh {
            let category: HandRankCategory = straightHigh == Rank.ace.rawValue ? .royalFlush : .straightFlush
            return HandValue(category: category, tiebreakers: [straightHigh], bestCards: straightOrderedCards(cards, high: straightHigh))
        }

        if groups[0].count == 4 {
            let quad = groups[0].rank
            let kicker = rankValues.first { $0 != quad }!
            return HandValue(category: .fourOfAKind, tiebreakers: [quad, kicker], bestCards: cards)
        }

        if groups[0].count == 3, groups[1].count == 2 {
            return HandValue(category: .fullHouse, tiebreakers: [groups[0].rank, groups[1].rank], bestCards: cards)
        }

        if isFlush {
            return HandValue(category: .flush, tiebreakers: rankValues, bestCards: cards)
        }

        if let straightHigh {
            return HandValue(category: .straight, tiebreakers: [straightHigh], bestCards: straightOrderedCards(cards, high: straightHigh))
        }

        if groups[0].count == 3 {
            let trip = groups[0].rank
            let kickers = rankValues.filter { $0 != trip }
            return HandValue(category: .threeOfAKind, tiebreakers: [trip] + kickers, bestCards: cards)
        }

        if groups[0].count == 2, groups[1].count == 2 {
            let pairs = groups.prefix(2).map { $0.rank }.sorted(by: >)
            let kicker = rankValues.first { !pairs.contains($0) }!
            return HandValue(category: .twoPair, tiebreakers: pairs + [kicker], bestCards: cards)
        }

        if groups[0].count == 2 {
            let pair = groups[0].rank
            let kickers = rankValues.filter { $0 != pair }
            return HandValue(category: .onePair, tiebreakers: [pair] + kickers, bestCards: cards)
        }

        return HandValue(category: .highCard, tiebreakers: rankValues, bestCards: cards)
    }

    private static func straightHighCard(from ranks: [Int]) -> Int? {
        var unique = Array(Set(ranks)).sorted(by: >)
        if unique.contains(Rank.ace.rawValue) {
            unique.append(1)
        }

        guard unique.count >= 5 else { return nil }
        for start in 0...(unique.count - 5) {
            let window = Array(unique[start..<(start + 5)])
            if zip(window, window.dropFirst()).allSatisfy({ $0 - 1 == $1 }) {
                return window[0] == 1 ? Rank.five.rawValue : window[0]
            }
        }
        return nil
    }

    private static func straightOrderedCards(_ cards: [Card], high: Int) -> [Card] {
        let neededRanks: [Int]
        if high == Rank.five.rawValue {
            neededRanks = [5, 4, 3, 2, 14]
        } else {
            neededRanks = Array(stride(from: high, through: high - 4, by: -1))
        }

        return neededRanks.compactMap { rank in
            cards.first { $0.rank.rawValue == rank }
        }
    }

    private static func combinations(of cards: [Card], choosing count: Int) -> [[Card]] {
        guard count > 0 else { return [[]] }
        guard cards.count >= count else { return [] }
        if cards.count == count { return [cards] }

        var results: [[Card]] = []
        func build(start: Int, partial: [Card]) {
            if partial.count == count {
                results.append(partial)
                return
            }
            let remainingNeeded = count - partial.count
            guard cards.count - start >= remainingNeeded else { return }
            for index in start..<cards.count {
                build(start: index + 1, partial: partial + [cards[index]])
            }
        }
        build(start: 0, partial: [])
        return results
    }
}
