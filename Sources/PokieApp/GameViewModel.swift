#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
final class PokieStore: ObservableObject {
    @Published private(set) var engine = GameEngine()
    @Published var stats = PlayerStatsSnapshot()
    @Published var selectedBetAmount = GameEngine.defaultBigBlind
    @Published var isShowingShowdown = false
    @Published var lastActions: [Int: String] = [:]
    @Published var revealedOpponents: Set<Int> = []
    @Published var isAIActing = false
    @Published var humanHasFolded = false
    @Published private(set) var handNumber = 0
    @Published var collectingBets: [Int: Int] = [:]

    private var aiTask: Task<Void, Never>?
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
        aiTask?.cancel()
        lastActions = [:]
        revealedOpponents = []
        isShowingShowdown = false
        humanHasFolded = false
        collectingBets = [:]

        handNumber += 1

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
        let prevPhase = state.phase
        let preBets = betSnapshot()
        do {
            lastActions[actorID] = Self.actionDisplayLabel(action)
            try engine.apply(action, from: actorID)
            if action == .fold {
                humanHasFolded = true
            }
            if state.phase != prevPhase && state.phase != .handOver {
                collectingBets = preBets
                lastActions = [:]
            }
            finishHandIfNeeded()
            runAIUntilHumanTurnOrHandEnds()
        } catch {
        }
    }

    private func betSnapshot() -> [Int: Int] {
        var snap: [Int: Int] = [:]
        for seat in engine.state.seats where seat.currentStreetBet > 0 {
            snap[seat.id] = seat.currentStreetBet
        }
        return snap
    }

    func skipToShowdown() {
        aiTask?.cancel()
        aiTask = nil
        isAIActing = false

        var safetyCounter = 0
        while safetyCounter < 200,
              let actorID = engine.state.currentActorSeatID,
              engine.state.phase != .handOver {
            safetyCounter += 1

            guard let seat = engine.state.seats.first(where: { $0.id == actorID }),
                  let archetype = seat.archetype,
                  let context = engine.aiDecisionContext(for: actorID) else { break }
            let ai = ArchetypeAIPlayer(archetype: archetype)
            let action = ai.chooseAction(in: context, using: &random)
            try? engine.apply(action, from: actorID)
        }
        finishHandIfNeeded()
        objectWillChange.send()
    }

    var humanHandRank: String {
        let allCards = humanSeat.holeCards + state.board
        guard allCards.count >= 5 else { return "" }
        return HandEvaluator.evaluate(allCards).category.title
    }

    func toggleReveal(seatID: Int) {
        if revealedOpponents.contains(seatID) {
            revealedOpponents.remove(seatID)
        } else {
            revealedOpponents.insert(seatID)
        }
    }

    private static func actionDisplayLabel(_ action: PlayerAction) -> String {
        switch action {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call"
        case .bet: return "Bet"
        case .raise: return "Raise"
        case .allIn: return "All-in"
        }
    }

    func setPresetBet(fractionOfPot fraction: Double) {
        let legal = legalBetRange()
        let raw = max(legal.lowerBound, Int(Double(max(state.pot, GameEngine.defaultBigBlind)) * fraction))
        let rounded = (raw / 25) * 25
        let amount = max(legal.lowerBound, rounded)
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
        aiTask?.cancel()
        aiTask = Task {
            isAIActing = true
            var safetyCounter = 0
            var previousPhase = engine.state.phase

            if !collectingBets.isEmpty {
                objectWillChange.send()
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { isAIActing = false; return }
                collectingBets = [:]
                objectWillChange.send()
            }

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { isAIActing = false; return }

            while safetyCounter < 80,
                  let actorID = engine.state.currentActorSeatID,
                  let seat = engine.state.seats.first(where: { $0.id == actorID }),
                  !seat.isHuman,
                  engine.state.phase != .handOver {
                safetyCounter += 1

                if engine.state.phase != previousPhase {
                    lastActions = [:]
                    previousPhase = engine.state.phase
                    objectWillChange.send()
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { break }
                }

                objectWillChange.send()
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { break }

                let preBets = betSnapshot()

                guard let archetype = seat.archetype,
                      let context = engine.aiDecisionContext(for: actorID) else { break }
                let ai = ArchetypeAIPlayer(archetype: archetype)
                let action = ai.chooseAction(in: context, using: &random)
                lastActions[actorID] = Self.actionDisplayLabel(action)
                try? engine.apply(action, from: actorID)

                if engine.state.phase != previousPhase && engine.state.phase != .handOver {
                    collectingBets = preBets
                    objectWillChange.send()
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { break }
                    collectingBets = [:]
                    lastActions = [:]
                    previousPhase = engine.state.phase
                    objectWillChange.send()
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { break }
                }

                finishHandIfNeeded()
                objectWillChange.send()
            }
            selectedBetAmount = min(max(selectedBetAmount, legalBetRange().lowerBound), legalBetRange().upperBound)
            isAIActing = false
            objectWillChange.send()
        }
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
