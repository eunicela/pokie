#if canImport(SwiftUI)
import SwiftUI

struct PlayingCardView: View {
    let card: Card?
    var faceDown = false
    var highlighted = true
    var compact = false

    var body: some View {
        RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
            .fill(faceDown || card == nil ? Color.white.opacity(0.08) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                    .stroke(Color.white.opacity(highlighted ? 0.12 : 0.04), lineWidth: 1)
            )
            .overlay(content)
            .opacity(highlighted ? 1 : 0.28)
            .frame(width: compact ? 38 : 54, height: compact ? 54 : 76)
    }

    @ViewBuilder
    private var content: some View {
        if faceDown || card == nil {
            Image(systemName: "circle.grid.cross")
                .foregroundStyle(.white.opacity(0.35))
                .font(.system(size: compact ? 16 : 24, weight: .semibold))
        } else if let card {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.rank.shortName)
                    .font(.system(size: compact ? 12 : 16, weight: .bold))
                Spacer()
                Text(card.suit.symbol)
                    .font(.system(size: compact ? 22 : 32, weight: .bold))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding(compact ? 6 : 8)
            .foregroundStyle(card.suit.isRed ? Color.red : Color.black.opacity(0.88))
        }
    }
}

struct CardRowView: View {
    let cards: [Card]
    var highlightedCards: Set<Card> = []
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(cards, id: \.self) { card in
                PlayingCardView(
                    card: card,
                    highlighted: highlightedCards.isEmpty || highlightedCards.contains(card),
                    compact: compact
                )
            }
        }
    }
}
#endif
