#if canImport(SwiftUI)
import SwiftUI

struct ShowdownView: View {
    @ObservedObject var store: PokerTrainerStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 42, height: 5)
                            .padding(.top, 8)

                        if let result = store.state.lastResult {
                            awardSummary(result)
                            revealedHands(result)
                            coachingLines(result)
                        }

                        Button("Play next hand") {
                            store.isShowingShowdown = false
                            store.startNextHand()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                }
            }
            .navigationTitle("Showdown")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func awardSummary(_ result: HandResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pot awards")
                .font(.headline)
            ForEach(result.awards, id: \.potIndex) { award in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pot \(award.potIndex + 1): \(award.potAmount)")
                        .font(.subheadline.weight(.bold))
                    Text(award.sharesBySeatID.sorted(by: { $0.key < $1.key }).map { "Seat \($0.key + 1) +\($0.value)" }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(.gray)
                    if let label = award.winningHandLabel {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func revealedHands(_ result: HandResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revealed hands")
                .font(.headline)

            ForEach(result.revealedHandsBySeatID.keys.sorted(), id: \.self) { seatID in
                let seat = store.state.seats.first { $0.id == seatID }
                let holeCards = result.revealedHandsBySeatID[seatID] ?? []
                let value = result.handValuesBySeatID[seatID]
                let highlighted = Set(value?.bestCards ?? [])
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(seat?.name ?? "Seat \(seatID + 1)")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(value?.label ?? "")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    CardRowView(cards: holeCards + result.board, highlightedCards: highlighted, compact: true)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func coachingLines(_ result: HandResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reads to remember")
                .font(.headline)
            ForEach(Array(result.explanationLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
