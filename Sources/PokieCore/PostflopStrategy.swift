import Foundation

public struct PostflopActionFrequencies: Sendable {
    public let foldPct: Double
    public let checkCallPct: Double
    public let betRaisePct: Double

    public init(fold: Double, checkCall: Double, betRaise: Double) {
        let total = fold + checkCall + betRaise
        if total > 0 {
            self.foldPct = fold / total
            self.checkCallPct = checkCall / total
            self.betRaisePct = betRaise / total
        } else {
            self.foldPct = 1; self.checkCallPct = 0; self.betRaisePct = 0
        }
    }
}

public enum PostflopStrategy {

    public static func frequencies(
        equity: Double,
        potSize: Int,
        toCall: Int,
        stack: Int,
        opponentCount: Int,
        phase: GamePhase
    ) -> PostflopActionFrequencies {
        if toCall > 0 {
            return facingBetFrequencies(equity: equity, potSize: potSize, toCall: toCall, stack: stack, opponentCount: opponentCount)
        }
        return checkingFrequencies(equity: equity, potSize: potSize, stack: stack, opponentCount: opponentCount, phase: phase)
    }

    public static func betSize(
        equity: Double,
        potSize: Int,
        stack: Int,
        phase: GamePhase
    ) -> Int {
        let fraction: Double
        switch phase {
        case .flop:
            fraction = equity > 0.75 ? 0.66 : 0.33
        case .turn:
            fraction = equity > 0.75 ? 0.75 : equity > 0.5 ? 0.50 : 0.33
        case .river:
            fraction = equity > 0.80 ? 1.0 : equity > 0.6 ? 0.66 : 0.33
        default:
            fraction = 0.5
        }

        let raw = max(GameEngine.defaultBigBlind, Int(Double(max(potSize, GameEngine.defaultBigBlind)) * fraction))
        let rounded = (raw / 25) * 25
        return min(stack, max(GameEngine.defaultBigBlind, rounded))
    }

    // MARK: - Private

    private static func facingBetFrequencies(
        equity: Double,
        potSize: Int,
        toCall: Int,
        stack: Int,
        opponentCount: Int
    ) -> PostflopActionFrequencies {
        let potOdds = Double(toCall) / Double(max(1, potSize + toCall))
        let multiwayPenalty = Double(max(0, opponentCount - 1)) * 0.04

        let effectiveEquity = equity - multiwayPenalty

        if effectiveEquity < potOdds * 0.6 {
            return PostflopActionFrequencies(fold: 1, checkCall: 0, betRaise: 0)
        }

        if effectiveEquity > 0.70 {
            let raiseFreq = min(1.0, (effectiveEquity - 0.70) / 0.30)
            return PostflopActionFrequencies(fold: 0, checkCall: 1 - raiseFreq, betRaise: raiseFreq)
        }

        if effectiveEquity >= potOdds {
            let callStrength = (effectiveEquity - potOdds * 0.6) / max(0.01, 0.70 - potOdds * 0.6)
            return PostflopActionFrequencies(fold: max(0, 1 - callStrength), checkCall: callStrength, betRaise: 0)
        }

        let foldFreq = 1 - effectiveEquity / max(0.01, potOdds)
        return PostflopActionFrequencies(fold: foldFreq, checkCall: 1 - foldFreq, betRaise: 0)
    }

    private static func checkingFrequencies(
        equity: Double,
        potSize: Int,
        stack: Int,
        opponentCount: Int,
        phase: GamePhase
    ) -> PostflopActionFrequencies {
        let multiwayPenalty = Double(max(0, opponentCount - 1)) * 0.04
        let effectiveEquity = equity - multiwayPenalty

        let valueBetThreshold: Double = phase == .river ? 0.55 : 0.50
        let bluffThreshold: Double = 0.20

        if effectiveEquity >= valueBetThreshold {
            let betFreq = min(1.0, (effectiveEquity - valueBetThreshold) / (1.0 - valueBetThreshold) * 0.8 + 0.3)
            return PostflopActionFrequencies(fold: 0, checkCall: 1 - betFreq, betRaise: betFreq)
        }

        if effectiveEquity < bluffThreshold {
            let betSizeFraction = betSize(equity: effectiveEquity, potSize: potSize, stack: stack, phase: phase)
            let gtoBluffFreq = Double(betSizeFraction) / Double(max(1, betSizeFraction + potSize))
            return PostflopActionFrequencies(fold: 0, checkCall: 1 - gtoBluffFreq, betRaise: gtoBluffFreq)
        }

        return PostflopActionFrequencies(fold: 0, checkCall: 1, betRaise: 0)
    }
}
