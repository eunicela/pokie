import Foundation

public struct GTOAIPlayer: AIPlayer, Sendable {
    public let archetype: PlayerArchetype
    private let deviation: ArchetypeDeviation

    public init(archetype: PlayerArchetype) {
        self.archetype = archetype
        self.deviation = ArchetypeDeviation.deviation(for: archetype)
    }

    public func chooseAction<R: RandomNumberGenerator>(
        in context: AIDecisionContext,
        using random: inout R
    ) -> PlayerAction {
        if context.phase == .preflop {
            return preflopAction(in: context, using: &random)
        }
        return postflopAction(in: context, using: &random)
    }

    // MARK: - Preflop

    private func preflopAction<R: RandomNumberGenerator>(
        in context: AIDecisionContext,
        using random: inout R
    ) -> PlayerAction {
        guard let position = context.position else {
            return fallbackAction(in: context, using: &random)
        }

        let hand = PreflopHand(cards: context.holeCards)
        let scenario = PreflopCharts.resolveScenario(from: context, position: position)
        let gtoFreq = PreflopCharts.frequencies(for: hand, position: position, scenario: scenario)
        let freq = deviation.applyPreflop(gtoFreq)

        let roll = Double.random(in: 0..<1, using: &random)

        if roll < freq.foldPct {
            return context.legalActions.contains(.fold) ? .fold : .check
        }
        if roll < freq.foldPct + freq.callPct {
            return context.toCall > 0 ? .call : .check
        }

        return raiseAction(in: context)
    }

    // MARK: - Postflop

    private func postflopAction<R: RandomNumberGenerator>(
        in context: AIDecisionContext,
        using random: inout R
    ) -> PlayerAction {
        let equity = EquityCalculator.equity(
            holeCards: context.holeCards,
            board: context.board,
            opponentCount: max(1, context.activeOpponentCount),
            rollouts: 2000,
            using: &random
        )

        let gtoFreq = PostflopStrategy.frequencies(
            equity: equity,
            potSize: context.pot,
            toCall: context.toCall,
            stack: context.stack,
            opponentCount: context.activeOpponentCount,
            phase: context.phase
        )

        let freq = deviation.applyPostflop(gtoFreq, equity: equity)
        let roll = Double.random(in: 0..<1, using: &random)

        if roll < freq.foldPct {
            return context.legalActions.contains(.fold) ? .fold : .check
        }
        if roll < freq.foldPct + freq.checkCallPct {
            return context.toCall > 0 ? .call : .check
        }

        return betOrRaise(in: context, equity: equity)
    }

    // MARK: - Sizing

    private func raiseAction(in context: AIDecisionContext) -> PlayerAction {
        if context.toCall >= context.stack {
            return .allIn
        }
        if let minRaiseTo = context.minRaiseTo, context.legalActions.contains(.raise) {
            let target = Int(Double(minRaiseTo) * deviation.sizingMultiplier)
            let clamped = min(context.currentStreetBet + context.stack, max(minRaiseTo, target))
            return .raise(to: clamped)
        }
        if context.legalActions.contains(.bet) {
            let size = PostflopStrategy.betSize(
                equity: 0.7,
                potSize: max(context.pot, GameEngine.defaultBigBlind),
                stack: context.stack,
                phase: context.phase
            )
            let adjusted = Int(Double(size) * deviation.sizingMultiplier)
            return .bet(min(context.stack, max(GameEngine.defaultBigBlind, adjusted)))
        }
        return context.toCall > 0 ? .call : .check
    }

    private func betOrRaise(in context: AIDecisionContext, equity: Double) -> PlayerAction {
        let size = PostflopStrategy.betSize(
            equity: equity,
            potSize: context.pot,
            stack: context.stack,
            phase: context.phase
        )
        let adjusted = Int(Double(size) * deviation.sizingMultiplier)
        let clamped = min(context.stack, max(GameEngine.defaultBigBlind, adjusted))

        if context.toCall == 0 && context.legalActions.contains(.bet) {
            return .bet(clamped)
        }
        if context.legalActions.contains(.raise), let minRaiseTo = context.minRaiseTo {
            let raiseTarget = context.currentStreetBet + clamped
            let final = min(context.currentStreetBet + context.stack, max(minRaiseTo, raiseTarget))
            return .raise(to: final)
        }
        return context.toCall > 0 ? .call : .check
    }

    // MARK: - Fallback

    private func fallbackAction<R: RandomNumberGenerator>(
        in context: AIDecisionContext,
        using random: inout R
    ) -> PlayerAction {
        let legacy = ArchetypeAIPlayer(archetype: archetype)
        return legacy.chooseAction(in: context, using: &random)
    }
}
