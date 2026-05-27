import Foundation

public struct PlayerStatsSnapshot: Codable, Equatable, Sendable {
    public var sessionsPlayed: Int
    public var handsPlayed: Int
    public var vpipHands: Int
    public var pfrHands: Int
    public var betOrRaiseActions: Int
    public var trackedActions: Int
    public var netChips: Int

    public init(
        sessionsPlayed: Int = 0,
        handsPlayed: Int = 0,
        vpipHands: Int = 0,
        pfrHands: Int = 0,
        betOrRaiseActions: Int = 0,
        trackedActions: Int = 0,
        netChips: Int = 0
    ) {
        self.sessionsPlayed = sessionsPlayed
        self.handsPlayed = handsPlayed
        self.vpipHands = vpipHands
        self.pfrHands = pfrHands
        self.betOrRaiseActions = betOrRaiseActions
        self.trackedActions = trackedActions
        self.netChips = netChips
    }

    public var vpip: Double {
        percentage(vpipHands, handsPlayed)
    }

    public var pfr: Double {
        percentage(pfrHands, handsPlayed)
    }

    public var aggressionFrequency: Double {
        percentage(betOrRaiseActions, trackedActions)
    }

    public var winRatePerHand: Double {
        guard handsPlayed > 0 else { return 0 }
        return Double(netChips) / Double(handsPlayed)
    }

    public var looseness: Double {
        min(1, max(0, vpip / 60))
    }

    public var aggression: Double {
        min(1, max(0, aggressionFrequency / 65))
    }

    private func percentage(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) * 100 / Double(denominator)
    }
}

public struct HandStatsEvent: Codable, Equatable, Sendable {
    public var voluntarilyPutMoneyInPreflop: Bool
    public var raisedPreflop: Bool
    public var betOrRaiseActions: Int
    public var trackedActions: Int
    public var netChips: Int

    public init(
        voluntarilyPutMoneyInPreflop: Bool,
        raisedPreflop: Bool,
        betOrRaiseActions: Int,
        trackedActions: Int,
        netChips: Int
    ) {
        self.voluntarilyPutMoneyInPreflop = voluntarilyPutMoneyInPreflop
        self.raisedPreflop = raisedPreflop
        self.betOrRaiseActions = betOrRaiseActions
        self.trackedActions = trackedActions
        self.netChips = netChips
    }
}

public enum StatsTeachingCopy {
    public static let vpip = "VPIP is how often you voluntarily put chips in preflop. Very high VPIP usually means too loose; very low means opponents can steal from you."
    public static let pfr = "PFR is how often you raise preflop. A healthy gap between VPIP and PFR means you are entering pots aggressively instead of only calling."
    public static let aggression = "AFq is bets plus raises divided by all tracked actions. Passive players miss value; reckless aggression turns into expensive bluffs."
    public static let winRate = "Win rate is net chips per hand. Use it with VPIP, PFR, and AFq to diagnose whether wins come from solid decisions or short-term cards."
}

public extension PlayerStatsSnapshot {
    mutating func record(_ event: HandStatsEvent) {
        handsPlayed += 1
        if event.voluntarilyPutMoneyInPreflop {
            vpipHands += 1
        }
        if event.raisedPreflop {
            pfrHands += 1
        }
        betOrRaiseActions += event.betOrRaiseActions
        trackedActions += event.trackedActions
        netChips += event.netChips
    }
}
