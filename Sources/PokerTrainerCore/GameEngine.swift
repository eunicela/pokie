import Foundation

public enum GamePhase: String, Codable, Sendable {
    case waiting
    case preflop
    case flop
    case turn
    case river
    case showdown
    case handOver
}

public enum SeatStatus: String, Codable, Sendable {
    case active
    case folded
    case allIn
    case sittingOut
}

public enum PlayerAction: Equatable, Codable, Sendable {
    case fold
    case check
    case call
    case bet(Int)
    case raise(to: Int)
    case allIn

    public enum Kind: String, Codable, Sendable {
        case fold
        case check
        case call
        case bet
        case raise
        case allIn
    }

    public var kind: Kind {
        switch self {
        case .fold: return .fold
        case .check: return .check
        case .call: return .call
        case .bet: return .bet
        case .raise: return .raise
        case .allIn: return .allIn
        }
    }
}

public struct PlayerSeat: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public var name: String
    public var isHuman: Bool
    public var archetype: PlayerArchetype?
    public var stack: Int
    public var holeCards: [Card]
    public var status: SeatStatus
    public var currentStreetBet: Int
    public var totalContribution: Int

    public init(id: Int, name: String, isHuman: Bool, archetype: PlayerArchetype?, stack: Int) {
        self.id = id
        self.name = name
        self.isHuman = isHuman
        self.archetype = archetype
        self.stack = stack
        self.holeCards = []
        self.status = stack > 0 ? .active : .sittingOut
        self.currentStreetBet = 0
        self.totalContribution = 0
    }
}

public struct HandResult: Codable, Equatable, Sendable {
    public let board: [Card]
    public let revealedHandsBySeatID: [Int: [Card]]
    public let handValuesBySeatID: [Int: HandValue]
    public let pots: [SidePot]
    public let awards: [PotAward]
    public let explanationLines: [String]
    public let humanStatsEvent: HandStatsEvent
}

public struct GameState: Codable, Equatable, Sendable {
    public var seats: [PlayerSeat]
    public var board: [Card]
    public var phase: GamePhase
    public var dealerSeatID: Int
    public var smallBlindSeatID: Int?
    public var bigBlindSeatID: Int?
    public var currentActorSeatID: Int?
    public var currentBet: Int
    public var minRaise: Int
    public var handNumber: Int
    public var lastResult: HandResult?

    public var pot: Int {
        seats.reduce(0) { $0 + $1.totalContribution }
    }
}

public enum GameEngineError: Error, Equatable {
    case noActiveHand
    case notPlayersTurn
    case illegalAction(String)
}

public struct GameEngine: Sendable {
    public static let defaultStartingStack = 1_000
    public static let defaultSmallBlind = 10
    public static let defaultBigBlind = 20

    public private(set) var state: GameState
    private var deck: Deck
    private var actedThisRound: Set<Int>
    private var humanHandTracker: HumanHandTracker

    public init(startingStack: Int = GameEngine.defaultStartingStack) {
        let archetypes: [PlayerArchetype] = [.tag, .lag, .rock, .fish, .tag]
        let seats = (0..<6).map { index in
            if index == 0 {
                return PlayerSeat(id: index, name: "You", isHuman: true, archetype: nil, stack: startingStack)
            }
            return PlayerSeat(
                id: index,
                name: archetypes[index - 1].rawValue,
                isHuman: false,
                archetype: archetypes[index - 1],
                stack: startingStack
            )
        }
        self.state = GameState(
            seats: seats,
            board: [],
            phase: .waiting,
            dealerSeatID: 5,
            smallBlindSeatID: nil,
            bigBlindSeatID: nil,
            currentActorSeatID: nil,
            currentBet: 0,
            minRaise: GameEngine.defaultBigBlind,
            handNumber: 0,
            lastResult: nil
        )
        self.deck = Deck(orderedCards: [])
        self.actedThisRound = []
        self.humanHandTracker = HumanHandTracker()
    }

    public var humanSeat: PlayerSeat {
        state.seats.first { $0.isHuman }!
    }

    public var legalActionsForCurrentActor: [PlayerAction.Kind] {
        guard let actorID = state.currentActorSeatID, let seat = seat(for: actorID), seat.status == .active else {
            return []
        }
        let toCall = max(0, state.currentBet - seat.currentStreetBet)
        var actions: [PlayerAction.Kind] = []
        if toCall > 0 {
            actions.append(.fold)
            actions.append(.call)
            if seat.stack > toCall {
                actions.append(.raise)
            }
        } else {
            actions.append(.check)
            if seat.stack > 0 {
                actions.append(.bet)
            }
        }
        if seat.stack > 0 {
            actions.append(.allIn)
        }
        return actions
    }

    public func minimumRaiseToForCurrentActor() -> Int? {
        guard let actorID = state.currentActorSeatID, let seat = seat(for: actorID), seat.stack > 0 else {
            return nil
        }
        if state.currentBet == 0 {
            return min(seat.stack, GameEngine.defaultBigBlind)
        }
        let toCall = state.currentBet - seat.currentStreetBet
        guard seat.stack > toCall else { return nil }
        return min(seat.currentStreetBet + seat.stack, state.currentBet + state.minRaise)
    }

    public mutating func addFreeChips(toHuman amount: Int = GameEngine.defaultStartingStack) {
        guard let index = state.seats.firstIndex(where: { $0.isHuman }) else { return }
        state.seats[index].stack += amount
        if state.seats[index].status == .sittingOut {
            state.seats[index].status = .active
        }
    }

    public mutating func startNewHand<R: RandomNumberGenerator>(using random: inout R) {
        state.lastResult = nil
        state.handNumber += 1
        state.board = []
        state.phase = .preflop
        state.currentBet = 0
        state.minRaise = GameEngine.defaultBigBlind
        actedThisRound = []
        humanHandTracker = HumanHandTracker(startingStack: humanSeat.stack)
        deck = Deck(shuffledUsing: &random)

        for index in state.seats.indices where !state.seats[index].isHuman && state.seats[index].stack < GameEngine.defaultBigBlind {
            state.seats[index].stack = GameEngine.defaultStartingStack
        }

        for index in state.seats.indices {
            state.seats[index].holeCards = []
            state.seats[index].currentStreetBet = 0
            state.seats[index].totalContribution = 0
            state.seats[index].status = state.seats[index].stack > 0 ? .active : .sittingOut
        }

        state.dealerSeatID = nextSeat(after: state.dealerSeatID, requiringChips: true) ?? state.dealerSeatID
        let smallBlind = nextSeat(after: state.dealerSeatID, requiringChips: true)!
        let bigBlind = nextSeat(after: smallBlind, requiringChips: true)!
        state.smallBlindSeatID = smallBlind
        state.bigBlindSeatID = bigBlind

        postBlind(seatID: smallBlind, amount: GameEngine.defaultSmallBlind)
        postBlind(seatID: bigBlind, amount: GameEngine.defaultBigBlind)
        state.currentBet = state.seats.first { $0.id == bigBlind }?.currentStreetBet ?? GameEngine.defaultBigBlind

        for _ in 0..<2 {
            for seatID in actingOrder(startingAfter: state.dealerSeatID) {
                if let index = state.seats.firstIndex(where: { $0.id == seatID }), state.seats[index].status != .sittingOut {
                    state.seats[index].holeCards.append(deck.draw())
                }
            }
        }

        state.currentActorSeatID = nextActionSeat(after: bigBlind)
        advancePastCompletedForcedBetsIfNeeded()
    }

    public mutating func apply(_ action: PlayerAction, from seatID: Int) throws {
        guard state.phase != .waiting && state.phase != .handOver else {
            throw GameEngineError.noActiveHand
        }
        guard seatID == state.currentActorSeatID else {
            throw GameEngineError.notPlayersTurn
        }
        guard let seatIndex = state.seats.firstIndex(where: { $0.id == seatID }) else {
            throw GameEngineError.notPlayersTurn
        }

        let legalKinds = legalActionsForCurrentActor
        guard legalKinds.contains(action.kind) else {
            throw GameEngineError.illegalAction("Action \(action.kind.rawValue) is not legal now")
        }

        let previousBet = state.currentBet
        let previousActorBet = state.seats[seatIndex].currentStreetBet
        switch action {
        case .fold:
            state.seats[seatIndex].status = .folded
            actedThisRound.insert(seatID)
        case .check:
            guard state.currentBet == state.seats[seatIndex].currentStreetBet else {
                throw GameEngineError.illegalAction("Cannot check facing a bet")
            }
            actedThisRound.insert(seatID)
        case .call:
            let toCall = max(0, state.currentBet - state.seats[seatIndex].currentStreetBet)
            commitChips(seatIndex: seatIndex, amount: min(toCall, state.seats[seatIndex].stack))
            actedThisRound.insert(seatID)
        case .bet(let amount):
            guard state.currentBet == 0 else {
                throw GameEngineError.illegalAction("Use raise after a bet exists")
            }
            let actualAmount = min(max(0, amount), state.seats[seatIndex].stack)
            guard actualAmount >= GameEngine.defaultBigBlind || actualAmount == state.seats[seatIndex].stack else {
                throw GameEngineError.illegalAction("Bet must be at least the big blind unless all-in")
            }
            commitChips(seatIndex: seatIndex, amount: actualAmount)
            state.currentBet = state.seats[seatIndex].currentStreetBet
            state.minRaise = max(GameEngine.defaultBigBlind, state.currentBet)
            actedThisRound = [seatID]
        case .raise(let target):
            guard state.currentBet > 0 else {
                throw GameEngineError.illegalAction("Use bet when opening the action")
            }
            let maxTarget = previousActorBet + state.seats[seatIndex].stack
            let actualTarget = min(target, maxTarget)
            guard actualTarget > state.currentBet else {
                throw GameEngineError.illegalAction("Raise target must exceed current bet")
            }
            let raiseSize = actualTarget - state.currentBet
            guard raiseSize >= state.minRaise || actualTarget == maxTarget else {
                throw GameEngineError.illegalAction("Minimum raise is \(state.minRaise)")
            }
            commitChips(seatIndex: seatIndex, amount: actualTarget - previousActorBet)
            state.currentBet = max(state.currentBet, state.seats[seatIndex].currentStreetBet)
            if raiseSize >= state.minRaise {
                state.minRaise = raiseSize
                actedThisRound = [seatID]
            } else {
                actedThisRound.insert(seatID)
            }
        case .allIn:
            let allInTarget = previousActorBet + state.seats[seatIndex].stack
            commitChips(seatIndex: seatIndex, amount: state.seats[seatIndex].stack)
            if allInTarget > state.currentBet {
                let raiseSize = allInTarget - previousBet
                state.currentBet = allInTarget
                if raiseSize >= state.minRaise {
                    state.minRaise = raiseSize
                    actedThisRound = [seatID]
                } else {
                    actedThisRound.insert(seatID)
                }
            } else {
                actedThisRound.insert(seatID)
            }
        }

        if state.phase == .preflop, seatID == humanSeat.id {
            humanHandTracker.recordPreflop(action: action, contributionDelta: state.seats[seatIndex].currentStreetBet - previousActorBet)
        }
        if seatID == humanSeat.id {
            humanHandTracker.recordAction(action)
        }

        advanceAfterAction(from: seatID)
    }

    public func aiDecisionContext(for seatID: Int) -> AIDecisionContext? {
        guard let seat = seat(for: seatID) else { return nil }
        return AIDecisionContext(
            phase: state.phase,
            holeCards: seat.holeCards,
            board: state.board,
            pot: state.pot,
            toCall: max(0, state.currentBet - seat.currentStreetBet),
            minRaiseTo: minimumRaiseToForCurrentActor(),
            currentStreetBet: seat.currentStreetBet,
            stack: seat.stack,
            activeOpponentCount: state.seats.filter { $0.id != seatID && ($0.status == .active || $0.status == .allIn) }.count,
            legalActions: legalActionsForCurrentActor
        )
    }

    private mutating func postBlind(seatID: Int, amount: Int) {
        guard let index = state.seats.firstIndex(where: { $0.id == seatID }) else { return }
        commitChips(seatIndex: index, amount: min(amount, state.seats[index].stack))
    }

    @discardableResult
    private mutating func commitChips(seatIndex: Int, amount: Int) -> Int {
        let committed = min(max(0, amount), state.seats[seatIndex].stack)
        state.seats[seatIndex].stack -= committed
        state.seats[seatIndex].currentStreetBet += committed
        state.seats[seatIndex].totalContribution += committed
        if state.seats[seatIndex].stack == 0 {
            state.seats[seatIndex].status = .allIn
        }
        return committed
    }

    private mutating func advanceAfterAction(from seatID: Int) {
        if awardIfOnlyOnePlayerRemains() {
            return
        }

        if bettingRoundComplete {
            advanceStreetOrShowdown()
            return
        }

        state.currentActorSeatID = nextActionSeat(after: seatID)
    }

    private mutating func advanceStreetOrShowdown() {
        for index in state.seats.indices {
            state.seats[index].currentStreetBet = 0
        }
        state.currentBet = 0
        state.minRaise = GameEngine.defaultBigBlind
        actedThisRound = []

        let seatsStillAbleToBet = state.seats.filter { $0.status == .active }
        let allInOpponentsRemain = state.seats.contains { $0.status == .allIn }
        if seatsStillAbleToBet.isEmpty || (seatsStillAbleToBet.count == 1 && allInOpponentsRemain) {
            while state.board.count < 5 {
                dealNextBoardStreet()
            }
            finishWithShowdown()
            return
        }

        switch state.phase {
        case .preflop:
            state.phase = .flop
            state.board.append(contentsOf: deck.draw(3))
        case .flop:
            state.phase = .turn
            state.board.append(deck.draw())
        case .turn:
            state.phase = .river
            state.board.append(deck.draw())
        case .river:
            finishWithShowdown()
            return
        case .waiting, .showdown, .handOver:
            return
        }

        state.currentActorSeatID = nextActionSeat(after: state.dealerSeatID)
        advancePastCompletedForcedBetsIfNeeded()
    }

    private mutating func dealNextBoardStreet() {
        switch state.board.count {
        case 0:
            state.board.append(contentsOf: deck.draw(3))
        case 3, 4:
            state.board.append(deck.draw())
        default:
            break
        }
    }

    private mutating func finishWithShowdown() {
        state.phase = .showdown
        state.currentActorSeatID = nil
        let liveSeats = state.seats.filter { $0.status == .active || $0.status == .allIn }
        let liveIDs = Set(liveSeats.map(\.id))
        let handValues = Dictionary(uniqueKeysWithValues: liveSeats.map { ($0.id, HandEvaluator.evaluate($0.holeCards + state.board)) })
        let pots = SidePotCalculator.buildPots(
            contributionsBySeatID: Dictionary(uniqueKeysWithValues: state.seats.map { ($0.id, $0.totalContribution) }),
            liveSeatIDs: liveIDs
        )
        let awards = SidePotCalculator.distribute(pots: pots, handValuesBySeatID: handValues)
        applyAwards(awards)
        let revealed = Dictionary(uniqueKeysWithValues: liveSeats.map { ($0.id, $0.holeCards) })
        let humanNet = humanSeat.stack - humanHandTracker.startingStack
        let result = HandResult(
            board: state.board,
            revealedHandsBySeatID: revealed,
            handValuesBySeatID: handValues,
            pots: pots,
            awards: awards,
            explanationLines: explanationLines(for: awards, handValues: handValues),
            humanStatsEvent: humanHandTracker.event(netChips: humanNet)
        )
        state.lastResult = result
        state.phase = .handOver
    }

    private mutating func awardIfOnlyOnePlayerRemains() -> Bool {
        let liveSeats = state.seats.filter { $0.status == .active || $0.status == .allIn }
        guard liveSeats.count == 1, let winner = liveSeats.first else {
            return false
        }
        let pot = state.pot
        if let winnerIndex = state.seats.firstIndex(where: { $0.id == winner.id }) {
            state.seats[winnerIndex].stack += pot
        }
        let humanNet = humanSeat.stack - humanHandTracker.startingStack
        let result = HandResult(
            board: state.board,
            revealedHandsBySeatID: [:],
            handValuesBySeatID: [:],
            pots: [SidePot(amount: pot, contributingSeatIDs: state.seats.map(\.id), eligibleSeatIDs: [winner.id])],
            awards: [PotAward(potIndex: 0, potAmount: pot, winningSeatIDs: [winner.id], sharesBySeatID: [winner.id: pot], winningHandLabel: nil)],
            explanationLines: ["\(winner.name) won because every other player folded."],
            humanStatsEvent: humanHandTracker.event(netChips: humanNet)
        )
        state.lastResult = result
        state.phase = .handOver
        state.currentActorSeatID = nil
        return true
    }

    private mutating func applyAwards(_ awards: [PotAward]) {
        for award in awards {
            for (seatID, amount) in award.sharesBySeatID {
                if let index = state.seats.firstIndex(where: { $0.id == seatID }) {
                    state.seats[index].stack += amount
                }
            }
        }
    }

    private func explanationLines(for awards: [PotAward], handValues: [Int: HandValue]) -> [String] {
        awards.flatMap { award in
            award.winningSeatIDs.map { seatID in
                let name = seat(for: seatID)?.name ?? "Seat \(seatID + 1)"
                let handLabel = handValues[seatID]?.label ?? "the best hand"
                let read = seat(for: seatID)?.archetype.map { archetypeRead($0) }
                return "\(name) won pot \(award.potIndex + 1) with \(handLabel). \(read ?? "")"
                    .trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private func archetypeRead(_ archetype: PlayerArchetype) -> String {
        switch archetype {
        case .tag:
            return "TAG pressure usually means strong made hands or premium draws."
        case .lag:
            return "LAG pressure can include bluffs, so watch sizing and showdown history."
        case .rock:
            return "A Rock putting in chips is a serious warning sign."
        case .fish:
            return "Fish call too wide; value-bet them and avoid fancy bluffs."
        }
    }

    private var bettingRoundComplete: Bool {
        let activeSeats = state.seats.filter { $0.status == .active }
        guard !activeSeats.isEmpty else { return true }
        return activeSeats.allSatisfy { seat in
            actedThisRound.contains(seat.id) && seat.currentStreetBet == state.currentBet
        }
    }

    private mutating func advancePastCompletedForcedBetsIfNeeded() {
        if state.currentActorSeatID == nil || bettingRoundComplete {
            if awardIfOnlyOnePlayerRemains() {
                return
            }
            if bettingRoundComplete {
                advanceStreetOrShowdown()
            }
        }
    }

    private func seat(for seatID: Int) -> PlayerSeat? {
        state.seats.first { $0.id == seatID }
    }

    private func nextSeat(after seatID: Int, requiringChips: Bool) -> Int? {
        let allIDs = state.seats.map(\.id).sorted()
        guard let start = allIDs.firstIndex(of: seatID) else { return nil }
        for offset in 1...allIDs.count {
            let candidate = allIDs[(start + offset) % allIDs.count]
            if !requiringChips || (seat(for: candidate)?.stack ?? 0) > 0 {
                return candidate
            }
        }
        return nil
    }

    private func nextActionSeat(after seatID: Int) -> Int? {
        let ids = state.seats.map(\.id).sorted()
        guard let start = ids.firstIndex(of: seatID) else { return nil }
        for offset in 1...ids.count {
            let candidateID = ids[(start + offset) % ids.count]
            if seat(for: candidateID)?.status == .active {
                return candidateID
            }
        }
        return nil
    }

    private func actingOrder(startingAfter seatID: Int) -> [Int] {
        let ids = state.seats.map(\.id).sorted()
        guard let start = ids.firstIndex(of: seatID) else { return ids }
        return (1...ids.count).map { ids[(start + $0) % ids.count] }
    }
}

private struct HumanHandTracker: Sendable {
    var startingStack: Int
    var vpip: Bool
    var pfr: Bool
    var betOrRaiseActions: Int
    var trackedActions: Int

    init(startingStack: Int = GameEngine.defaultStartingStack) {
        self.startingStack = startingStack
        self.vpip = false
        self.pfr = false
        self.betOrRaiseActions = 0
        self.trackedActions = 0
    }

    mutating func recordPreflop(action: PlayerAction, contributionDelta: Int) {
        switch action {
        case .call, .bet, .raise, .allIn:
            if contributionDelta > 0 {
                vpip = true
            }
        case .fold, .check:
            break
        }
        if case .raise = action {
            pfr = true
        }
        if case .bet = action {
            pfr = true
        }
        if case .allIn = action, contributionDelta > 0 {
            pfr = true
        }
    }

    mutating func recordAction(_ action: PlayerAction) {
        switch action {
        case .fold, .check, .call:
            trackedActions += 1
        case .bet, .raise, .allIn:
            trackedActions += 1
            betOrRaiseActions += 1
        }
    }

    func event(netChips: Int) -> HandStatsEvent {
        HandStatsEvent(
            voluntarilyPutMoneyInPreflop: vpip,
            raisedPreflop: pfr,
            betOrRaiseActions: betOrRaiseActions,
            trackedActions: trackedActions,
            netChips: netChips
        )
    }
}
