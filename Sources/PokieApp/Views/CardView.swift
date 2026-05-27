#if canImport(SwiftUI)
import SwiftUI

struct PlayingCardView: View {
    let card: Card?
    var faceDown = false
    var highlighted = true
    var cardWidth: CGFloat = 54
    var cardHeight: CGFloat = 76

    private var cr: CGFloat { min(cardWidth, cardHeight) * 0.16 }

    var body: some View {
        RoundedRectangle(cornerRadius: cr, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
            )
            .overlay(content)
            .frame(width: cardWidth, height: cardHeight)
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    private var cardFill: Color {
        if faceDown || card == nil {
            return Color.gray.opacity(0.12)
        }
        return highlighted ? .white : Color(white: 0.85)
    }

    @ViewBuilder
    private var content: some View {
        if faceDown || card == nil {
            Image(systemName: "circle.grid.cross")
                .foregroundStyle(.gray.opacity(0.4))
                .font(.system(size: min(cardWidth, cardHeight) * 0.32, weight: .semibold))
        } else if let card {
            VStack(alignment: .leading, spacing: 0) {
                Text(card.rank.shortName)
                    .font(.system(size: cardWidth * 0.32, weight: .bold))
                Spacer()
                Text(card.suit.symbol)
                    .font(.system(size: cardWidth * 0.42, weight: .bold))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding(max(4, cardWidth * 0.1))
            .foregroundStyle(card.suit.isRed ? Color.red : Color.black.opacity(0.88))
        }
    }
}

struct CardRowView: View {
    let cards: [Card]
    var highlightedCards: Set<Card> = []
    var cardWidth: CGFloat = 54
    var cardHeight: CGFloat = 76

    var body: some View {
        HStack(spacing: 8) {
            ForEach(cards, id: \.self) { card in
                PlayingCardView(
                    card: card,
                    highlighted: highlightedCards.isEmpty || highlightedCards.contains(card),
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
            }
        }
    }
}
#endif
