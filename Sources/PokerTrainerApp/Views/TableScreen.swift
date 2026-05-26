#if canImport(SwiftUI)
import SwiftUI

struct TableScreen: View {
    @ObservedObject var store: PokerTrainerStore
    @State private var showingRankings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        tableHeader
                        opponentGrid
                        boardView
                        humanPanel
                        actionPanel
                    }
                    .padding()
                }
            }
            .navigationTitle("Poker Trainer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingRankings = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingRankings) {
                HandRankingsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $store.isShowingShowdown) {
                ShowdownView(store: store)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var tableHeader: some View {
        HStack {
            MetricPill(title: "Pot", value: "\(store.state.pot)")
            MetricPill(title: "To call", value: "\(store.callAmount)")
            Spacer()
            Text(turnText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.09), in: Capsule())
        }
    }

    private var opponentGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(store.state.seats.filter { !$0.isHuman }) { seat in
                SeatTile(seat: seat, isDealer: store.state.dealerSeatID == seat.id, isActing: store.state.currentActorSeatID == seat.id)
            }
        }
    }

    private var boardView: some View {
        VStack(spacing: 12) {
            Text(streetText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    PlayingCardView(card: index < store.state.board.count ? store.state.board[index] : nil)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var humanPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You")
                        .font(.headline)
                    Text("Stack \(store.humanSeat.stack)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                if store.state.dealerSeatID == store.humanSeat.id {
                    DealerButton()
                }
            }
            HStack {
                PlayingCardView(card: store.humanSeat.holeCards.first)
                PlayingCardView(card: store.humanSeat.holeCards.dropFirst().first)
                Spacer()
                if store.canRecharge {
                    Button("Add free chips") {
                        store.addFreeChips()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var actionPanel: some View {
        if store.state.phase == .handOver {
            Button("Next hand") {
                store.isShowingShowdown = false
                store.startNextHand()
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if store.isHumanTurn {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button("Fold") { store.perform(.fold) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(!store.engine.legalActionsForCurrentActor.contains(.fold))

                    Button(store.callAmount == 0 ? "Check" : "Call \(store.callAmount)") {
                        store.perform(store.callAmount == 0 ? .check : .call)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                betControls
            }
        } else {
            Text("AI opponents are acting...")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var betControls: some View {
        let range = store.legalBetRange()
        return VStack(spacing: 10) {
            HStack {
                Text(store.callAmount == 0 ? "Bet" : "Raise to")
                    .foregroundStyle(.gray)
                Spacer()
                Text("\(store.selectedBetAmount)")
                    .font(.headline)
            }

            Slider(
                value: Binding(
                    get: { Double(store.selectedBetAmount) },
                    set: { store.selectedBetAmount = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 5
            )

            HStack(spacing: 8) {
                PresetButton("1/2 pot") { store.setPresetBet(fractionOfPot: 0.5) }
                PresetButton("2/3 pot") { store.setPresetBet(fractionOfPot: 0.66) }
                PresetButton("Pot") { store.setPresetBet(fractionOfPot: 1) }
                PresetButton("All-in") { store.setAllInPreset() }
            }

            Button(store.callAmount == 0 ? "Bet \(store.selectedBetAmount)" : "Raise to \(store.selectedBetAmount)") {
                if store.callAmount == 0 {
                    store.perform(.bet(store.selectedBetAmount))
                } else {
                    store.perform(.raise(to: store.selectedBetAmount))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!(store.engine.legalActionsForCurrentActor.contains(.bet) || store.engine.legalActionsForCurrentActor.contains(.raise)))
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var streetText: String {
        switch store.state.phase {
        case .waiting: return "Waiting"
        case .preflop: return "Preflop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .showdown, .handOver: return "Showdown"
        }
    }

    private var turnText: String {
        guard let actorID = store.state.currentActorSeatID,
              let seat = store.state.seats.first(where: { $0.id == actorID }) else {
            return store.state.phase == .handOver ? "Hand complete" : "Dealing"
        }
        return "\(seat.name) to act"
    }
}

private struct SeatTile: View {
    let seat: PlayerSeat
    let isDealer: Bool
    let isActing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(seat.name)
                    .font(.subheadline.weight(.bold))
                if isDealer { DealerButton() }
                Spacer()
                Text(seat.status.rawValue.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActing ? .white : .gray)
            }
            Text("Stack \(seat.stack)")
                .font(.caption)
                .foregroundStyle(.gray)
            Text(seat.archetype?.summary ?? "")
                .font(.caption2)
                .foregroundStyle(.gray)
                .lineLimit(2)
        }
        .padding()
        .background(isActing ? Color.white.opacity(0.14) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DealerButton: View {
    var body: some View {
        Text("D")
            .font(.caption2.weight(.black))
            .foregroundStyle(.black)
            .frame(width: 20, height: 20)
            .background(.white, in: Circle())
    }
}

private struct PresetButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.white.opacity(0.75) : Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
#endif
