import Foundation

public enum TablePosition: String, CaseIterable, Sendable {
    case utg
    case mp
    case co
    case btn
    case sb
    case bb
}

public struct PreflopHand: Hashable, Sendable {
    public let highRank: Rank
    public let lowRank: Rank
    public let isSuited: Bool
    public let isPair: Bool

    public init(cards: [Card]) {
        precondition(cards.count == 2)
        let r0 = cards[0].rank
        let r1 = cards[1].rank
        if r0.rawValue >= r1.rawValue {
            highRank = r0
            lowRank = r1
        } else {
            highRank = r1
            lowRank = r0
        }
        isPair = r0 == r1
        isSuited = !isPair && cards[0].suit == cards[1].suit
    }

    public init(highRank: Rank, lowRank: Rank, suited: Bool) {
        self.highRank = highRank
        self.lowRank = lowRank
        self.isPair = highRank == lowRank
        self.isSuited = isPair ? false : suited
    }

    public var notation: String {
        if isPair { return "\(highRank.shortName)\(lowRank.shortName)" }
        return "\(highRank.shortName)\(lowRank.shortName)\(isSuited ? "s" : "o")"
    }

    public static let all169: [PreflopHand] = {
        var hands: [PreflopHand] = []
        let ranks = Rank.allCases.reversed() as [Rank]
        for i in ranks.indices {
            for j in i..<ranks.count {
                if i == j {
                    hands.append(PreflopHand(highRank: ranks[i], lowRank: ranks[j], suited: false))
                } else {
                    hands.append(PreflopHand(highRank: ranks[i], lowRank: ranks[j], suited: true))
                    hands.append(PreflopHand(highRank: ranks[i], lowRank: ranks[j], suited: false))
                }
            }
        }
        return hands
    }()
}

public struct PreflopActionFrequencies: Sendable {
    public let foldPct: Double
    public let callPct: Double
    public let raisePct: Double

    public init(fold: Double, call: Double, raise: Double) {
        let total = fold + call + raise
        if total > 0 {
            self.foldPct = fold / total
            self.callPct = call / total
            self.raisePct = raise / total
        } else {
            self.foldPct = 1; self.callPct = 0; self.raisePct = 0
        }
    }

    public static let alwaysFold = PreflopActionFrequencies(fold: 1, call: 0, raise: 0)
    public static let alwaysRaise = PreflopActionFrequencies(fold: 0, call: 0, raise: 1)
}

public enum PreflopScenario: Hashable, Sendable {
    case rfi
    case facingRaise
    case blindDefense
}

// MARK: - Chart Lookup

public enum PreflopCharts {

    public static func frequencies(
        for hand: PreflopHand,
        position: TablePosition,
        scenario: PreflopScenario
    ) -> PreflopActionFrequencies {
        let key = hand.notation
        switch scenario {
        case .rfi:
            return rfiRanges[position]?[key] ?? .alwaysFold
        case .facingRaise:
            return facingRaiseRanges[position]?[key] ?? .alwaysFold
        case .blindDefense:
            return blindDefenseRanges[key] ?? .alwaysFold
        }
    }

    public static func resolveScenario(
        from context: AIDecisionContext,
        position: TablePosition
    ) -> PreflopScenario {
        let bb = GameEngine.defaultBigBlind
        if context.toCall <= bb && position != .bb {
            return .rfi
        }
        if position == .bb && context.toCall == 0 {
            return .rfi
        }
        if position == .bb {
            return .blindDefense
        }
        return .facingRaise
    }

    // MARK: - RFI (Raise First In) Ranges — 20bb 6-max

    private static let rfiRanges: [TablePosition: [String: PreflopActionFrequencies]] = [
        .utg: rfiUTG, .mp: rfiMP, .co: rfiCO, .btn: rfiBTN, .sb: rfiSB, .bb: [:]
    ]

    private static let rfiUTG: [String: PreflopActionFrequencies] = {
        var r: [String: PreflopActionFrequencies] = [:]
        let always = PreflopActionFrequencies.alwaysRaise
        let mix70 = PreflopActionFrequencies(fold: 0.3, call: 0, raise: 0.7)
        let mix50 = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        // Pairs
        for pair in ["AA","KK","QQ","JJ","TT","99","88","77"] { r[pair] = always }
        for pair in ["66","55"] { r[pair] = mix70 }
        r["44"] = mix50
        // Suited broadways
        for h in ["AKs","AQs","AJs","ATs","KQs","KJs","QJs","JTs"] { r[h] = always }
        r["KTs"] = mix70; r["QTs"] = mix50; r["T9s"] = mix50
        // Suited aces
        r["A5s"] = mix70; r["A4s"] = mix50
        // Offsuit broadways
        r["AKo"] = always; r["AQo"] = always; r["AJo"] = mix70
        r["KQo"] = mix70; r["ATo"] = mix50
        return r
    }()

    private static let rfiMP: [String: PreflopActionFrequencies] = {
        var r = rfiUTG
        let always = PreflopActionFrequencies.alwaysRaise
        let mix70 = PreflopActionFrequencies(fold: 0.3, call: 0, raise: 0.7)
        let mix50 = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        r["66"] = always; r["55"] = always; r["44"] = mix70; r["33"] = mix50
        r["KTs"] = always; r["QTs"] = mix70; r["T9s"] = mix70; r["98s"] = mix50
        r["A9s"] = mix70; r["A5s"] = always; r["A4s"] = mix70; r["A3s"] = mix50
        r["AJo"] = always; r["ATo"] = mix70; r["KQo"] = always; r["KJo"] = mix50
        return r
    }()

    private static let rfiCO: [String: PreflopActionFrequencies] = {
        var r = rfiMP
        let always = PreflopActionFrequencies.alwaysRaise
        let mix70 = PreflopActionFrequencies(fold: 0.3, call: 0, raise: 0.7)
        let mix50 = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        for pair in ["44","33","22"] { r[pair] = always }
        for h in ["A9s","A8s","A7s","A6s","A4s","A3s","A2s"] { r[h] = always }
        for h in ["K9s","Q9s","J9s","T9s","98s","87s","76s","65s"] { r[h] = always }
        r["QTs"] = always; r["J8s"] = mix70; r["T8s"] = mix70; r["97s"] = mix70
        r["54s"] = mix50
        r["ATo"] = always; r["KJo"] = always; r["KTo"] = mix70; r["QJo"] = mix70
        return r
    }()

    private static let rfiBTN: [String: PreflopActionFrequencies] = {
        var r = rfiCO
        let always = PreflopActionFrequencies.alwaysRaise
        let mix70 = PreflopActionFrequencies(fold: 0.3, call: 0, raise: 0.7)
        let mix50 = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        for h in ["J8s","T8s","97s","86s","75s","64s","54s","53s"] { r[h] = always }
        r["43s"] = mix70; r["42s"] = mix50; r["32s"] = mix50
        r["KTo"] = always; r["QJo"] = always; r["QTo"] = always
        r["JTo"] = always; r["J9o"] = mix70; r["T9o"] = mix70
        r["K9o"] = mix50; r["Q9o"] = mix50
        return r
    }()

    private static let rfiSB: [String: PreflopActionFrequencies] = {
        var r: [String: PreflopActionFrequencies] = [:]
        let always = PreflopActionFrequencies.alwaysRaise
        let mix70 = PreflopActionFrequencies(fold: 0.3, call: 0, raise: 0.7)
        let mix50 = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        for pair in ["AA","KK","QQ","JJ","TT","99","88","77","66","55"] { r[pair] = always }
        for pair in ["44","33"] { r[pair] = mix70 }
        r["22"] = mix50
        for h in ["AKs","AQs","AJs","ATs","A9s","A8s","A7s","A6s","A5s","A4s","A3s","A2s"] { r[h] = always }
        for h in ["KQs","KJs","KTs","K9s","K8s"] { r[h] = always }
        r["K7s"] = mix70; r["K6s"] = mix50
        for h in ["QJs","QTs","Q9s"] { r[h] = always }
        r["Q8s"] = mix70
        for h in ["JTs","J9s","J8s"] { r[h] = always }
        for h in ["T9s","T8s","98s","97s","87s","76s","65s","54s"] { r[h] = always }
        r["86s"] = mix70; r["75s"] = mix70; r["64s"] = mix50
        r["AKo"] = always; r["AQo"] = always; r["AJo"] = always; r["ATo"] = always
        r["A9o"] = mix70; r["A8o"] = mix50
        r["KQo"] = always; r["KJo"] = always; r["KTo"] = mix70
        r["QJo"] = mix70; r["QTo"] = mix50; r["JTo"] = mix50
        return r
    }()

    // MARK: - Facing Raise Ranges

    private static let facingRaiseRanges: [TablePosition: [String: PreflopActionFrequencies]] = [
        .utg: [:], // UTG can't face a raise in RFI scenario
        .mp: facingRaiseIP,
        .co: facingRaiseIP,
        .btn: facingRaiseBTN,
        .sb: facingRaiseSB,
        .bb: [:] // BB uses blindDefense
    ]

    private static let facingRaiseIP: [String: PreflopActionFrequencies] = {
        var r: [String: PreflopActionFrequencies] = [:]
        let threebet = PreflopActionFrequencies(fold: 0, call: 0, raise: 1)
        let call = PreflopActionFrequencies(fold: 0, call: 1, raise: 0)
        let mix3b = PreflopActionFrequencies(fold: 0, call: 0.4, raise: 0.6)
        let mixCall = PreflopActionFrequencies(fold: 0.3, call: 0.7, raise: 0)
        // Premium 3-bets
        for h in ["AA","KK","QQ"] { r[h] = threebet }
        r["AKs"] = threebet; r["AKo"] = threebet
        // Mixed 3-bet/call
        r["JJ"] = mix3b; r["TT"] = mix3b
        r["AQs"] = mix3b; r["AQo"] = mix3b
        // Flatting range
        for h in ["99","88","77"] { r[h] = call }
        for h in ["AJs","ATs","KQs","KJs","QJs","JTs","T9s"] { r[h] = call }
        // Marginal calls
        for h in ["66","55"] { r[h] = mixCall }
        r["KTs"] = mixCall; r["QTs"] = mixCall; r["98s"] = mixCall
        r["AJo"] = mixCall; r["KQo"] = mixCall
        return r
    }()

    private static let facingRaiseBTN: [String: PreflopActionFrequencies] = {
        var r = facingRaiseIP
        let call = PreflopActionFrequencies(fold: 0, call: 1, raise: 0)
        let mixCall = PreflopActionFrequencies(fold: 0.3, call: 0.7, raise: 0)
        r["66"] = call; r["55"] = call; r["44"] = mixCall
        for h in ["A9s","A8s","K9s","Q9s","J9s","87s","76s","65s"] { r[h] = mixCall }
        r["KTs"] = call; r["QTs"] = call; r["98s"] = call
        return r
    }()

    private static let facingRaiseSB: [String: PreflopActionFrequencies] = {
        var r: [String: PreflopActionFrequencies] = [:]
        let threebet = PreflopActionFrequencies(fold: 0, call: 0, raise: 1)
        let mix3b = PreflopActionFrequencies(fold: 0, call: 0.3, raise: 0.7)
        let mixFold = PreflopActionFrequencies(fold: 0.5, call: 0, raise: 0.5)
        for h in ["AA","KK","QQ","AKs","AKo"] { r[h] = threebet }
        for h in ["JJ","TT","AQs","AQo"] { r[h] = mix3b }
        for h in ["99","AJs","ATs","KQs"] { r[h] = mixFold }
        r["A5s"] = mixFold
        return r
    }()

    // MARK: - BB Defense vs Raise

    private static let blindDefenseRanges: [String: PreflopActionFrequencies] = {
        var r: [String: PreflopActionFrequencies] = [:]
        let threebet = PreflopActionFrequencies(fold: 0, call: 0, raise: 1)
        let call = PreflopActionFrequencies(fold: 0, call: 1, raise: 0)
        let mix3b = PreflopActionFrequencies(fold: 0, call: 0.5, raise: 0.5)
        let mixCall = PreflopActionFrequencies(fold: 0.3, call: 0.7, raise: 0)
        let wideCall = PreflopActionFrequencies(fold: 0.5, call: 0.5, raise: 0)
        // 3-bet value
        for h in ["AA","KK","QQ","AKs","AKo"] { r[h] = threebet }
        // Mixed 3-bet
        for h in ["JJ","TT","AQs","AQo","A5s","A4s"] { r[h] = mix3b }
        // Call
        for h in ["99","88","77","66","55","44"] { r[h] = call }
        for h in ["AJs","ATs","A9s","A8s","A7s","A6s","A3s","A2s"] { r[h] = call }
        for h in ["KQs","KJs","KTs","K9s","K8s","K7s"] { r[h] = call }
        for h in ["QJs","QTs","Q9s","Q8s"] { r[h] = call }
        for h in ["JTs","J9s","J8s","T9s","T8s","98s","97s","87s","76s","65s","54s"] { r[h] = call }
        // Marginal calls
        for h in ["33","22"] { r[h] = mixCall }
        for h in ["AJo","ATo","KQo","KJo","QJo","JTo"] { r[h] = mixCall }
        for h in ["K6s","Q7s","J7s","T7s","96s","86s","75s","64s","53s","43s"] { r[h] = wideCall }
        r["A9o"] = wideCall; r["KTo"] = wideCall; r["QTo"] = wideCall
        return r
    }()
}
