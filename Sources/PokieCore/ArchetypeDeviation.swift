import Foundation

public struct ArchetypeDeviation: Sendable {
    public let rangeWidening: Double
    public let preflopAggBoost: Double
    public let equityCallBias: Double
    public let aggressionBoost: Double
    public let bluffBoost: Double
    public let sizingMultiplier: Double

    public static func deviation(for archetype: PlayerArchetype) -> ArchetypeDeviation {
        switch archetype {
        case .tag:
            return ArchetypeDeviation(
                rangeWidening: -0.05,
                preflopAggBoost: 0.05,
                equityCallBias: -0.02,
                aggressionBoost: 0.05,
                bluffBoost: 0.0,
                sizingMultiplier: 1.0
            )
        case .lag:
            return ArchetypeDeviation(
                rangeWidening: 0.20,
                preflopAggBoost: 0.15,
                equityCallBias: 0.05,
                aggressionBoost: 0.20,
                bluffBoost: 0.15,
                sizingMultiplier: 1.3
            )
        case .rock:
            return ArchetypeDeviation(
                rangeWidening: -0.15,
                preflopAggBoost: -0.10,
                equityCallBias: -0.08,
                aggressionBoost: -0.20,
                bluffBoost: -0.05,
                sizingMultiplier: 0.7
            )
        case .fish:
            return ArchetypeDeviation(
                rangeWidening: 0.30,
                preflopAggBoost: -0.15,
                equityCallBias: 0.20,
                aggressionBoost: -0.15,
                bluffBoost: -0.03,
                sizingMultiplier: 0.8
            )
        }
    }

    public func applyPreflop(_ gto: PreflopActionFrequencies) -> PreflopActionFrequencies {
        var fold = gto.foldPct - rangeWidening
        var call = gto.callPct - preflopAggBoost
        var raise = gto.raisePct + rangeWidening + preflopAggBoost

        fold = max(0, fold)
        call = max(0, call)
        raise = max(0, raise)
        return PreflopActionFrequencies(fold: fold, call: call, raise: raise)
    }

    public func applyPostflop(_ gto: PostflopActionFrequencies, equity: Double) -> PostflopActionFrequencies {
        var fold = gto.foldPct - equityCallBias
        var passive = gto.checkCallPct - aggressionBoost
        var aggressive = gto.betRaisePct + aggressionBoost + equityCallBias

        if equity < 0.35 {
            aggressive += bluffBoost
            fold -= bluffBoost
        }

        fold = max(0, fold)
        passive = max(0, passive)
        aggressive = max(0, aggressive)
        return PostflopActionFrequencies(fold: fold, checkCall: passive, betRaise: aggressive)
    }
}
