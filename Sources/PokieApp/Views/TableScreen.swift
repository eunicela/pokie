#if canImport(SwiftUI)
import SwiftUI

private let accentBlue = Color(red: 45/255, green: 48/255, blue: 145/255)

struct TableScreen: View {
    @ObservedObject var store: PokieStore
    @State private var showingRankings = false
    @State private var showingRaiseControls = false
    @State private var boardRevealFlags: [Bool] = Array(repeating: false, count: 5)
    @State private var holeCardsDealt = false
    @State private var foldDragOffset: CGFloat = 0
    @State private var didFold = false
    @State private var ghostCardsRevealed = false
    @State private var chipsSweeping = false
    @Namespace private var actionNamespace

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)
                opponentsRow
                Spacer(minLength: 16)
                boardSection
                boardInfoRow
                Spacer(minLength: 16)
                actionSection
                    .frame(minHeight: 100, alignment: .bottom)
                playerSection
            }
            .padding(.horizontal)

            Button {
                showingRankings = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.black.opacity(0.3))
                    .padding(16)
            }
        }
        .sheet(isPresented: $showingRankings) {
            HandRankingsView()
        }
        .onAppear {
            if store.humanSeat.holeCards.count >= 2 {
                holeCardsDealt = true
            }
            for i in 0..<min(store.state.board.count, 5) {
                boardRevealFlags[i] = true
            }
        }
        .onChange(of: store.handNumber) { _, _ in
            holeCardsDealt = false
            didFold = false
            foldDragOffset = 0
            ghostCardsRevealed = false
            boardRevealFlags = Array(repeating: false, count: 5)
            let hand = store.handNumber
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard self.store.handNumber == hand else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    holeCardsDealt = true
                }
            }
        }
        .onChange(of: store.state.board.count) { oldCount, newCount in
            guard newCount > oldCount else { return }
            let hand = store.handNumber
            for i in oldCount..<newCount {
                let delay = Double(i - oldCount) * 0.2
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard self.store.handNumber == hand else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        boardRevealFlags[i] = true
                    }
                }
            }
        }
        .onChange(of: store.collectingBets) { _, newValue in
            if !newValue.isEmpty {
                chipsSweeping = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        chipsSweeping = true
                    }
                }
            } else {
                chipsSweeping = false
            }
        }
    }

    // MARK: - Opponents

    private var opponents: [PlayerSeat] {
        store.state.seats.filter { !$0.isHuman }
    }

    private var opponentsRow: some View {
        HStack(spacing: 0) {
            ForEach(opponents) { seat in
                let folded = seat.status == .folded
                let isActive = store.state.currentActorSeatID == seat.id && store.state.phase != .handOver
                let hasAction = store.lastActions[seat.id] != nil && !folded
                let justActed = store.recentlyActed.contains(seat.id) && !folded
                VStack(spacing: 2) {
                    ZStack(alignment: .bottomTrailing) {
                        PokieAvatarView(kind: .tableKind(for: seat), size: 52)
                            .opacity(folded ? 0.3 : (justActed ? 0.4 : 1))
                            .frame(width: 52, height: 52)
                            .overlay(alignment: .top) {
                                if isActive {
                                    Circle()
                                        .fill(accentBlue)
                                        .frame(width: 8, height: 8)
                                        .offset(y: -6)
                                }
                            }
                            .overlay {
                                if hasAction {
                                    Text(store.lastActions[seat.id] ?? "")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                            }

                        if store.state.dealerSeatID == seat.id {
                            DealerChip()
                        }
                    }

                    Text("\(seat.stack)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(folded ? .black.opacity(0.25) : .black)

                    showdownOrBetRow(for: seat)
                        .frame(height: 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.state.currentActorSeatID)
        .animation(.easeInOut(duration: 0.2), value: store.lastActions)
    }

    @ViewBuilder
    private func showdownOrBetRow(for seat: PlayerSeat) -> some View {
        if store.state.phase == .handOver {
            if store.revealedOpponents.contains(seat.id),
               let cards = store.state.lastResult?.revealedHandsBySeatID[seat.id],
               cards.count >= 2 {
                HStack(spacing: 2) {
                    PlayingCardView(card: cards[0], cardWidth: 24, cardHeight: 34)
                    PlayingCardView(card: cards[1], cardWidth: 24, cardHeight: 34)
                }
            } else if seat.status != .folded {
                Button {
                    store.toggleReveal(seatID: seat.id)
                } label: {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.3))
                        .frame(width: 52, height: 34)
                }
            } else {
                Color.clear
            }
        } else if seat.currentStreetBet > 0 && seat.status != .folded {
            BetChip(amount: seat.currentStreetBet)
        } else if let amount = store.collectingBets[seat.id] {
            BetChip(amount: amount)
                .offset(y: chipsSweeping ? 30 : 0)
                .opacity(chipsSweeping ? 0 : 1)
                .scaleEffect(chipsSweeping ? 0.5 : 1)
        } else {
            Color.clear
        }
    }

    // MARK: - Board

    private var bestHandCards: Set<Card> {
        guard store.state.phase == .handOver,
              let result = store.state.lastResult,
              let humanValue = result.handValuesBySeatID[store.humanSeat.id] else {
            return []
        }
        return Set(humanValue.bestCards)
    }

    private var boardSection: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let isRevealed = index < store.state.board.count && boardRevealFlags[index]
                let card: Card? = isRevealed ? store.state.board[index] : nil
                let isHighlighted = card.map { bestHandCards.isEmpty || bestHandCards.contains($0) } ?? true
                PlayingCardView(
                    card: card,
                    faceDown: !isRevealed,
                    highlighted: isHighlighted,
                    cardWidth: 72,
                    cardHeight: 100
                )
                .id(isRevealed)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
    }

    private var boardInfoRow: some View {
        HStack {
            if store.isShowingShowdown, let result = store.state.lastResult {
                let netChips = result.humanStatsEvent.netChips
                let won = netChips > 0
                VStack(alignment: .leading, spacing: 2) {
                    Text(won ? "You Win" : (netChips == 0 ? "Split Pot" : "You Lose"))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(won ? .green : (netChips == 0 ? .orange : .red.opacity(0.7)))
                    if let label = result.awards.first?.winningHandLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                Spacer()
                Text(won ? "+\(netChips)" : "\(netChips)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(won ? .green : .red.opacity(0.7))
            } else {
                Spacer()
                Text("\(store.state.pot)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
            }
        }
        .padding(.top, 8)
        .frame(height: 44, alignment: .leading)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        if store.state.phase == .handOver {
            Button("Next hand") {
                store.startNextHand()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.vertical, 12)
        } else if store.humanHasFolded {
            Button("Next hand") {
                store.skipToShowdown()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 10) {
                HStack {
                    if store.humanSeat.currentStreetBet > 0 {
                        BetChip(amount: store.humanSeat.currentStreetBet)
                    } else if let amount = store.collectingBets[store.humanSeat.id] {
                        BetChip(amount: amount)
                            .offset(y: chipsSweeping ? -30 : 0)
                            .opacity(chipsSweeping ? 0 : 1)
                            .scaleEffect(chipsSweeping ? 0.5 : 1)
                    }
                    Spacer()
                }

                actionButtons
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showingRaiseControls)
            }
            .padding(.vertical, 8)
            .opacity(store.isHumanTurn ? 1 : 0.3)
            .disabled(!store.isHumanTurn)
            .animation(.easeInOut(duration: 0.2), value: store.isHumanTurn)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        let canRaise = store.engine.legalActionsForCurrentActor.contains(.bet)
            || store.engine.legalActionsForCurrentActor.contains(.raise)
        let range = store.legalBetRange()

        VStack(spacing: 10) {
            if showingRaiseControls {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption.weight(.bold))
                        Text("\(store.selectedBetAmount)")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(width: 70, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { Double(store.selectedBetAmount) },
                            set: { store.selectedBetAmount = Int($0) }
                        ),
                        in: Double(range.lowerBound)...Double(range.upperBound),
                        step: 25
                    )
                    .tint(accentBlue)

                    Button {
                        if store.callAmount == 0 {
                            store.perform(.bet(store.selectedBetAmount))
                        } else {
                            store.perform(.raise(to: store.selectedBetAmount))
                        }
                        showingRaiseControls = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                    }
                }
                .transition(.asymmetric(
                    insertion: .modifier(
                        active: SliderRevealModifier(progress: 0),
                        identity: SliderRevealModifier(progress: 1)
                    ),
                    removal: .modifier(
                        active: SliderRevealModifier(progress: 0),
                        identity: SliderRevealModifier(progress: 1)
                    )
                ))
            }

            HStack(spacing: 8) {
                if showingRaiseControls {
                    Button("1 BB") {
                        store.selectedBetAmount = max(range.lowerBound, min(range.upperBound, GameEngine.defaultBigBlind))
                    }
                    .buttonStyle(TableActionButtonStyle())
                    .matchedGeometryEffect(id: "btn-left", in: actionNamespace)

                    Button("1/2 Pot") {
                        store.setPresetBet(fractionOfPot: 0.5)
                    }
                    .buttonStyle(TableActionButtonStyle())
                    .matchedGeometryEffect(id: "btn-mid", in: actionNamespace)

                    Button("Pot") {
                        store.setPresetBet(fractionOfPot: 1)
                    }
                    .buttonStyle(TableActionButtonStyle())
                    .matchedGeometryEffect(id: "btn-right", in: actionNamespace)
                } else {
                    Button(store.callAmount == 0 ? "Check" : "Call \(store.callAmount)") {
                        store.perform(store.callAmount == 0 ? .check : .call)
                    }
                    .buttonStyle(TableActionButtonStyle())
                    .matchedGeometryEffect(id: "btn-left", in: actionNamespace)

                    let minBet = store.legalBetRange().lowerBound
                    Button(store.callAmount == 0 ? "Bet \(minBet)" : "Raise \(minBet)") {
                        if store.callAmount == 0 {
                            store.perform(.bet(minBet))
                        } else {
                            store.perform(.raise(to: minBet))
                        }
                    }
                    .buttonStyle(TableActionButtonStyle())
                    .matchedGeometryEffect(id: "btn-mid", in: actionNamespace)
                    .disabled(!canRaise)
                }

                Button {
                    showingRaiseControls.toggle()
                } label: {
                    Image(systemName: showingRaiseControls ? "xmark" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .contentTransition(.symbolEffect(.replace.offUp))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .matchedGeometryEffect(id: "btn-toggle", in: actionNamespace)
                .disabled(!canRaise)
            }
        }
    }

    // MARK: - Player

    private var holeCardsPair: some View {
        HStack(spacing: 8) {
            PlayingCardView(
                card: store.humanSeat.holeCards.count > 0 ? store.humanSeat.holeCards[0] : nil,
                cardWidth: 86,
                cardHeight: 120
            )
            PlayingCardView(
                card: store.humanSeat.holeCards.count > 1 ? store.humanSeat.holeCards[1] : nil,
                faceDown: store.humanSeat.holeCards.count <= 1,
                cardWidth: 86,
                cardHeight: 120
            )
        }
    }

    private var playerSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack {
                holeCardsPair
                    .opacity(ghostCardsRevealed ? 0.25 : 0)
                    .offset(y: ghostCardsRevealed ? 0 : 40)

                if !didFold && !store.humanHasFolded {
                    holeCardsPair
                        .offset(y: foldDragOffset)
                        .opacity(1.0 + Double(foldDragOffset) / 120.0)
                }
            }
            .offset(y: holeCardsDealt ? 0 : 30)
            .opacity(holeCardsDealt ? 1 : 0)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard store.isHumanTurn,
                              store.engine.legalActionsForCurrentActor.contains(.fold) else { return }
                        let vertical = value.translation.height
                        if vertical < 0 {
                            foldDragOffset = vertical * 0.6
                        }
                    }
                    .onEnded { value in
                        guard store.isHumanTurn,
                              store.engine.legalActionsForCurrentActor.contains(.fold) else {
                            foldDragOffset = 0
                            return
                        }
                        if value.translation.height < -60 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                foldDragOffset = -200
                                didFold = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showingRaiseControls = false
                                foldDragOffset = 0
                                store.perform(.fold)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    ghostCardsRevealed = true
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                foldDragOffset = 0
                            }
                        }
                    }
            )

            Spacer()

            VStack(spacing: 6) {
                Text(store.humanHandRank)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.6))
                PokieAvatarView(kind: .tableKind(for: store.humanSeat), size: 44)
                Text("\(store.humanSeat.stack)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 110, height: 120)
            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if store.isHumanTurn {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accentBlue, lineWidth: 2.5)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isHumanTurn)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Transitions

private struct SliderRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(Double(progress))
            .clipShape(
                UnevenRoundedRectangle(cornerRadii: .init())
                    .scale(x: progress, y: 1, anchor: .trailing)
            )
    }
}

// MARK: - Table Components

private struct DealerChip: View {
    var body: some View {
        Text("D")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(.black, in: Circle())
            .offset(x: 4, y: 4)
    }
}

private struct BetChip: View {
    let amount: Int

    var body: some View {
        Text("\(amount)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(accentBlue)
            .frame(width: 28, height: 28)
            .background(Color.black.opacity(0.07), in: Circle())
    }
}

private struct TableActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                configuration.isPressed ? Color.black.opacity(0.75) : Color.black,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }
}
#endif
