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
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .frame(width: cardWidth, height: cardHeight)
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    private var cardFill: Color {
        if faceDown || card == nil {
            return Color(red: 45/255, green: 48/255, blue: 145/255)
        }
        return highlighted ? .white : Color(white: 0.85)
    }

    @ViewBuilder
    private var content: some View {
        if faceDown || card == nil {
            OrnateCardBackView(cornerRadius: cr)
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

private struct OrnateCardBackView: View {
    let cornerRadius: CGFloat

    private let blue = Color(red: 45/255, green: 48/255, blue: 145/255)
    private let cream = Color(red: 248/255, green: 244/255, blue: 229/255)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let lineWidth = max(1, width * 0.035)
            let inset = width * 0.10

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(blue)

                RoundedRectangle(cornerRadius: max(2, cornerRadius * 0.62), style: .continuous)
                    .stroke(cream, lineWidth: lineWidth)
                    .padding(inset)

                RoundedRectangle(cornerRadius: max(2, cornerRadius * 0.42), style: .continuous)
                    .stroke(cream.opacity(0.55), lineWidth: max(0.7, lineWidth * 0.42))
                    .padding(inset * 1.55)

                ForEach(0..<4, id: \.self) { index in
                    CornerFlourish()
                        .stroke(cream, style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round, lineJoin: .round))
                        .frame(width: width * 0.34, height: height * 0.22)
                        .rotationEffect(.degrees(Double(index) * 90))
                        .position(cornerPosition(index: index, width: width, height: height))
                }

                HStack(spacing: width * 0.09) {
                    OvalMedallion()
                    OvalMedallion()
                }
                .foregroundStyle(cream)
                .frame(width: width * 0.72, height: height * 0.20)
                .position(x: width / 2, y: height * 0.36)

                HStack(spacing: width * 0.09) {
                    OvalMedallion()
                    OvalMedallion()
                }
                .foregroundStyle(cream)
                .frame(width: width * 0.72, height: height * 0.20)
                .rotationEffect(.degrees(180))
                .position(x: width / 2, y: height * 0.64)

                DiamondShape()
                    .stroke(cream, lineWidth: lineWidth * 0.8)
                    .frame(width: width * 0.30, height: width * 0.30)
                    .position(x: width / 2, y: height * 0.17)

                DiamondShape()
                    .stroke(cream, lineWidth: lineWidth * 0.8)
                    .frame(width: width * 0.30, height: width * 0.30)
                    .position(x: width / 2, y: height * 0.83)

                FloralStarShape(petals: 8)
                    .fill(cream.opacity(0.13))
                    .frame(width: width * 0.43, height: width * 0.43)
                    .position(x: width / 2, y: height / 2)

                FloralStarShape(petals: 8)
                    .stroke(cream, lineWidth: lineWidth * 0.62)
                    .frame(width: width * 0.46, height: width * 0.46)
                    .position(x: width / 2, y: height / 2)

                VerticalVine()
                    .stroke(cream, style: StrokeStyle(lineWidth: lineWidth * 0.62, lineCap: .round, lineJoin: .round))
                    .frame(width: width * 0.32, height: height * 0.52)
                    .position(x: width / 2, y: height / 2)

                DotGrid()
                    .fill(cream.opacity(0.72))
                    .frame(width: width * 0.62, height: height * 0.56)
                    .position(x: width / 2, y: height / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private func cornerPosition(index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: width * 0.25, y: height * 0.16)
        case 1: return CGPoint(x: width * 0.84, y: height * 0.25)
        case 2: return CGPoint(x: width * 0.75, y: height * 0.84)
        default: return CGPoint(x: width * 0.16, y: height * 0.75)
        }
    }
}

private struct CornerFlourish: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.78))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.16),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.10),
            control2: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.58),
            control1: CGPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.26),
            control2: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.60)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.30),
            control1: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.56),
            control2: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.34)
        )

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.72))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.76),
            control1: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.98),
            control2: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.94)
        )

        return path
    }
}

private struct OvalMedallion: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let oval = CGRect(
            x: rect.midX - rect.width * 0.18,
            y: rect.midY - rect.height * 0.34,
            width: rect.width * 0.36,
            height: rect.height * 0.68
        )
        path.addEllipse(in: oval)
        return path
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct FloralStarShape: Shape {
    let petals: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for index in 0..<petals {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(petals) - .pi / 2
            let nextAngle = angle + 2 * .pi / CGFloat(petals)
            let midAngle = (angle + nextAngle) / 2
            let start = CGPoint(x: center.x + cos(angle) * radius * 0.24, y: center.y + sin(angle) * radius * 0.24)
            let tip = CGPoint(x: center.x + cos(midAngle) * radius, y: center.y + sin(midAngle) * radius)
            let end = CGPoint(x: center.x + cos(nextAngle) * radius * 0.24, y: center.y + sin(nextAngle) * radius * 0.24)

            if index == 0 {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: tip)
        }

        path.closeSubpath()
        return path
    }
}

private struct VerticalVine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.32),
            control2: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.68)
        )

        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY - rect.height * 0.12),
            control1: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.10),
            control2: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY - rect.height * 0.26)
        )

        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.midY + rect.height * 0.12),
            control1: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY + rect.height * 0.10),
            control2: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.midY + rect.height * 0.26)
        )

        return path
    }
}

private struct DotGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columns = 5
        let rows = 7
        let dot = min(rect.width, rect.height) * 0.035

        for row in 0..<rows {
            for column in 0..<columns {
                guard (row + column).isMultiple(of: 2) else { continue }
                let x = rect.minX + CGFloat(column) * rect.width / CGFloat(columns - 1)
                let y = rect.minY + CGFloat(row) * rect.height / CGFloat(rows - 1)
                path.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
            }
        }

        return path
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
