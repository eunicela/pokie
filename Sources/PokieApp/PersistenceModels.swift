#if canImport(SwiftData)
import Foundation
import SwiftData

@Model
final class PersistentPlayerStats {
    var sessionsPlayed: Int
    var handsPlayed: Int
    var vpipHands: Int
    var pfrHands: Int
    var betOrRaiseActions: Int
    var trackedActions: Int
    var netChips: Int

    init(
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

    var snapshot: PlayerStatsSnapshot {
        PlayerStatsSnapshot(
            sessionsPlayed: sessionsPlayed,
            handsPlayed: handsPlayed,
            vpipHands: vpipHands,
            pfrHands: pfrHands,
            betOrRaiseActions: betOrRaiseActions,
            trackedActions: trackedActions,
            netChips: netChips
        )
    }

    func apply(_ snapshot: PlayerStatsSnapshot) {
        sessionsPlayed = snapshot.sessionsPlayed
        handsPlayed = snapshot.handsPlayed
        vpipHands = snapshot.vpipHands
        pfrHands = snapshot.pfrHands
        betOrRaiseActions = snapshot.betOrRaiseActions
        trackedActions = snapshot.trackedActions
        netChips = snapshot.netChips
    }
}
#endif
