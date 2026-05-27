import Foundation

public enum PlayerArchetype: String, CaseIterable, Codable, Identifiable, Sendable {
    case tag = "TAG"
    case lag = "LAG"
    case rock = "Rock"
    case fish = "Fish"

    public var id: String { rawValue }

    public var summary: String {
        switch self {
        case .tag: return "Tight-aggressive: folds junk, applies pressure with real strength."
        case .lag: return "Loose-aggressive: plays many hands and bluffs often."
        case .rock: return "Tight-passive: only enters with premiums and rarely raises."
        case .fish: return "Loose-passive: calls too much and pays off value bets."
        }
    }
}

public struct ArchetypeConfig: Codable, Equatable, Sendable {
    public let vpipTarget: Double
    public let aggression: Double
    public let bluffFrequency: Double
    public let callThreshold: Double
    public let raiseThreshold: Double
    public let preferredBetPotFraction: Double

    public static func config(for archetype: PlayerArchetype) -> ArchetypeConfig {
        switch archetype {
        case .tag:
            return ArchetypeConfig(vpipTarget: 0.23, aggression: 0.78, bluffFrequency: 0.08, callThreshold: 0.42, raiseThreshold: 0.68, preferredBetPotFraction: 0.66)
        case .lag:
            return ArchetypeConfig(vpipTarget: 0.47, aggression: 0.88, bluffFrequency: 0.24, callThreshold: 0.30, raiseThreshold: 0.55, preferredBetPotFraction: 0.92)
        case .rock:
            return ArchetypeConfig(vpipTarget: 0.13, aggression: 0.24, bluffFrequency: 0.02, callThreshold: 0.55, raiseThreshold: 0.82, preferredBetPotFraction: 0.45)
        case .fish:
            return ArchetypeConfig(vpipTarget: 0.58, aggression: 0.18, bluffFrequency: 0.04, callThreshold: 0.20, raiseThreshold: 0.78, preferredBetPotFraction: 0.50)
        }
    }
}

public struct AIDecisionContext: Sendable {
    public let phase: GamePhase
    public let holeCards: [Card]
    public let board: [Card]
    public let pot: Int
    public let toCall: Int
    public let minRaiseTo: Int?
    public let currentStreetBet: Int
    public let stack: Int
    public let activeOpponentCount: Int
    public let legalActions: [PlayerAction.Kind]
    public let position: TablePosition?

    public init(
        phase: GamePhase,
        holeCards: [Card],
        board: [Card],
        pot: Int,
        toCall: Int,
        minRaiseTo: Int?,
        currentStreetBet: Int,
        stack: Int,
        activeOpponentCount: Int,
        legalActions: [PlayerAction.Kind],
        position: TablePosition? = nil
    ) {
        self.phase = phase
        self.holeCards = holeCards
        self.board = board
        self.pot = pot
        self.toCall = toCall
        self.minRaiseTo = minRaiseTo
        self.currentStreetBet = currentStreetBet
        self.stack = stack
        self.activeOpponentCount = activeOpponentCount
        self.legalActions = legalActions
        self.position = position
    }
}

public protocol AIPlayer {
    func chooseAction<R: RandomNumberGenerator>(in context: AIDecisionContext, using random: inout R) -> PlayerAction
}

public struct ArchetypeAIPlayer: AIPlayer, Sendable {
    public let archetype: PlayerArchetype
    public let config: ArchetypeConfig

    public init(archetype: PlayerArchetype) {
        self.archetype = archetype
        self.config = ArchetypeConfig.config(for: archetype)
    }

    public func chooseAction<R: RandomNumberGenerator>(in context: AIDecisionContext, using random: inout R) -> PlayerAction {
        let strength = estimatedStrength(in: context)
        let potOddsPressure = context.toCall == 0 ? 0 : Double(context.toCall) / Double(max(1, context.pot + context.toCall))
        let randomWobble = Double.random(in: -0.06...0.06, using: &random)
        let bluffing = Double.random(in: 0...1, using: &random) < config.bluffFrequency
        let adjustedStrength = min(1, max(0, strength + randomWobble + (bluffing ? 0.24 : 0)))

        if context.toCall > 0 {
            if canRaise(context), adjustedStrength >= config.raiseThreshold {
                return .raise(to: raiseTarget(in: context))
            }
            if adjustedStrength + potOddsPressure >= config.callThreshold {
                return .call
            }
            return .fold
        }

        if canBet(context), adjustedStrength >= config.raiseThreshold || bluffing {
            return .bet(betSize(in: context))
        }
        return .check
    }

    private func canBet(_ context: AIDecisionContext) -> Bool {
        context.legalActions.contains(.bet)
    }

    private func canRaise(_ context: AIDecisionContext) -> Bool {
        context.legalActions.contains(.raise)
    }

    private func betSize(in context: AIDecisionContext) -> Int {
        let raw = max(GameEngine.defaultBigBlind, Int(Double(max(context.pot, GameEngine.defaultBigBlind)) * config.preferredBetPotFraction))
        let rounded = (raw / 25) * 25
        let target = max(GameEngine.defaultBigBlind, rounded)
        return min(context.stack, target)
    }

    private func raiseTarget(in context: AIDecisionContext) -> Int {
        guard let minRaiseTo = context.minRaiseTo else {
            return context.currentStreetBet + context.stack
        }
        let raw = context.currentStreetBet + max(context.toCall, Int(Double(max(context.pot, GameEngine.defaultBigBlind)) * config.preferredBetPotFraction))
        let rounded = ((raw + 24) / 25) * 25
        let pressureRaise = max(minRaiseTo, rounded)
        return min(context.currentStreetBet + context.stack, pressureRaise)
    }

    private func estimatedStrength(in context: AIDecisionContext) -> Double {
        if context.phase == .preflop {
            return preflopStrength(context.holeCards)
        }
        guard context.board.count >= 3 else {
            return preflopStrength(context.holeCards)
        }

        let value = HandEvaluator.evaluate(context.holeCards + context.board)
        let categoryComponent = Double(value.category.rawValue - 1) / Double(HandRankCategory.royalFlush.rawValue - 1)
        let kickerComponent = Double(value.tiebreakers.first ?? 2) / Double(Rank.ace.rawValue) * 0.12
        let multiwayPenalty = Double(max(0, context.activeOpponentCount - 1)) * 0.04
        return min(1, max(0, categoryComponent + kickerComponent - multiwayPenalty))
    }

    private func preflopStrength(_ cards: [Card]) -> Double {
        guard cards.count == 2 else { return 0 }
        let high = max(cards[0].rank.rawValue, cards[1].rank.rawValue)
        let low = min(cards[0].rank.rawValue, cards[1].rank.rawValue)
        let pairBonus = high == low ? 0.34 : 0
        let suitedBonus = cards[0].suit == cards[1].suit ? 0.05 : 0
        let connectedBonus = abs(high - low) <= 1 ? 0.04 : 0
        let gapPenalty = Double(max(0, abs(high - low) - 3)) * 0.015
        let broadwayBonus = low >= Rank.ten.rawValue ? 0.08 : 0
        let raw = Double(high + low) / 28 + pairBonus + suitedBonus + connectedBonus + broadwayBonus - gapPenalty
        return min(1, max(0, raw))
    }
}
