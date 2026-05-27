import Foundation

public enum Suit: String, CaseIterable, Codable, Comparable, Sendable {
    case clubs = "c"
    case diamonds = "d"
    case hearts = "h"
    case spades = "s"

    public var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    public var isRed: Bool {
        self == .diamonds || self == .hearts
    }

    public static func < (lhs: Suit, rhs: Suit) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Rank: Int, CaseIterable, Codable, Comparable, Sendable {
    case two = 2
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine
    case ten
    case jack
    case queen
    case king
    case ace

    public var shortName: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }

    public var singularName: String {
        switch self {
        case .two: return "Two"
        case .three: return "Three"
        case .four: return "Four"
        case .five: return "Five"
        case .six: return "Six"
        case .seven: return "Seven"
        case .eight: return "Eight"
        case .nine: return "Nine"
        case .ten: return "Ten"
        case .jack: return "Jack"
        case .queen: return "Queen"
        case .king: return "King"
        case .ace: return "Ace"
        }
    }

    public var pluralName: String {
        switch self {
        case .six: return "Sixes"
        default: return singularName + "s"
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Card: Hashable, Codable, Comparable, CustomStringConvertible, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(_ rank: Rank, _ suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var description: String {
        "\(rank.shortName)\(suit.symbol)"
    }

    public static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        return lhs.suit < rhs.suit
    }
}

public struct Deck: Sendable {
    private var cards: [Card]

    public init(shuffledUsing random: inout some RandomNumberGenerator) {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in Card(rank, suit) }
        }
        cards.shuffle(using: &random)
    }

    public init(orderedCards: [Card]) {
        self.cards = orderedCards
    }

    public var remainingCount: Int { cards.count }

    public mutating func draw() -> Card {
        precondition(!cards.isEmpty, "Cannot draw from an empty deck")
        return cards.removeLast()
    }

    public mutating func draw(_ count: Int) -> [Card] {
        (0..<count).map { _ in draw() }
    }
}
