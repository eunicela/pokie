#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
final class PokerTrainerStore: ObservableObject {
    @Published private(set) var engine = GameEngine()
    @Published var stats = PlayerStatsSnapshot()
    @Published var selectedBetAmount = GameEngine.defaultBigBlind
    @Published var isShowingShowdown = false

    private var random = SystemRandomNumberGenerator()
    private var loadedPersistedStats = false

    var state: GameState { engine.state }
    var humanSeat: PlayerSeat { engine.humanSeat }

    var isHumanTurn: Bool {
        state.currentActorSeatID == humanSeat.id && state.phase != .handOver
    }

    var callAmount: Int {
        guard let actor = state.seats.first(where: { $0.id == state.currentActorSeatID }) else { return 0 }
        return max(0, state.currentBet - actor.currentStreetBet)
    }

    var canRecharge: Bool {
        humanSeat.stack < GameEngine.defaultStartingStack
    }

    init() {
        stats.sessionsPlayed += 1
        startNextHand()
    }

    func load(stats persisted: PlayerStatsSnapshot) {
        guard !loadedPersistedStats else { return }
        loadedPersistedStats = true
        var copy = persisted
        copy.sessionsPlayed += 1
        stats = copy
    }

    func startNextHand() {
        if humanSeat.stack < GameEngine.defaultBigBlind {
            engine.addFreeChips(toHuman: GameEngine.defaultStartingStack)
        }
        engine.startNewHand(using: &random)
        selectedBetAmount = max(GameEngine.defaultBigBlind, min(engine.humanSeat.stack, state.pot / 2))
        runAIUntilHumanTurnOrHandEnds()
    }

    func addFreeChips() {
        engine.addFreeChips(toHuman: GameEngine.defaultStartingStack)
        objectWillChange.send()
    }

    func perform(_ action: PlayerAction) {
        guard let actorID = state.currentActorSeatID else { return }
        do {
            try engine.apply(action, from: actorID)
            finishHandIfNeeded()
            runAIUntilHumanTurnOrHandEnds()
        } catch {
            // Illegal UI states should be prevented by legal action checks; ignore stale taps.
        }
    }

    func setPresetBet(fractionOfPot fraction: Double) {
        let legal = legalBetRange()
        let amount = max(legal.lowerBound, Int(Double(max(state.pot, GameEngine.defaultBigBlind)) * fraction))
        selectedBetAmount = min(legal.upperBound, amount)
    }

    func setAllInPreset() {
        selectedBetAmount = legalBetRange().upperBound
    }

    func legalBetRange() -> ClosedRange<Int> {
        guard let actor = state.seats.first(where: { $0.id == state.currentActorSeatID }) else {
            return GameEngine.defaultBigBlind...GameEngine.defaultBigBlind
        }
        let maxTarget = max(GameEngine.defaultBigBlind, actor.currentStreetBet + actor.stack)
        let minTarget: Int
        if state.currentBet == 0 {
            minTarget = min(maxTarget, GameEngine.defaultBigBlind)
        } else {
            minTarget = engine.minimumRaiseToForCurrentActor() ?? maxTarget
        }
        return min(minTarget, maxTarget)...maxTarget
    }

    private func runAIUntilHumanTurnOrHandEnds() {
        var safetyCounter = 0
        while safetyCounter < 80,
              let actorID = engine.state.currentActorSeatID,
              let seat = engine.state.seats.first(where: { $0.id == actorID }),
              !seat.isHuman,
              engine.state.phase != .handOver {
            safetyCounter += 1
            guard let archetype = seat.archetype, let context = engine.aiDecisionContext(for: actorID) else { break }
            let ai = ArchetypeAIPlayer(archetype: archetype)
            let action = ai.chooseAction(in: context, using: &random)
            try? engine.apply(action, from: actorID)
            finishHandIfNeeded()
        }
        selectedBetAmount = min(max(selectedBetAmount, legalBetRange().lowerBound), legalBetRange().upperBound)
        objectWillChange.send()
    }

    private func finishHandIfNeeded() {
        guard engine.state.phase == .handOver, let event = engine.state.lastResult?.humanStatsEvent else { return }
        if !isShowingShowdown {
            stats.record(event)
            isShowingShowdown = true
        }
    }
}
#endif
