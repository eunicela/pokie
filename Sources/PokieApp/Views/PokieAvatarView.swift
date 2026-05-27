#if canImport(SwiftUI)
import SwiftUI

enum PokieAvatarKind: CaseIterable {
    case playerStars
    case dottedStar
    case shootingStar
    case moonStar
    case birdStar
    case spiral
    case sun

    static func tableKind(for seat: PlayerSeat) -> PokieAvatarKind {
        if seat.isHuman {
            return .playerStars
        }

        switch seat.id {
        case 1: return .dottedStar
        case 2: return .shootingStar
        case 3: return .moonStar
        case 4: return .birdStar
        case 5: return .spiral
        default: return .sun
        }
    }
}

struct PokieAvatarView: View {
    let kind: PokieAvatarKind
    var size: CGFloat = 52
    var color = Color(red: 45/255, green: 48/255, blue: 145/255)

    var body: some View {
        ZStack {
            switch kind {
            case .playerStars:
                playerStars
            case .dottedStar:
                dottedStar
            case .shootingStar:
                shootingStar
            case .moonStar:
                moonStar
            case .birdStar:
                birdStar
            case .spiral:
                spiral
            case .sun:
                sun
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var playerStars: some View {
        ZStack {
            StarShape(points: 8, innerRatio: 0.35)
                .fill(color)
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: -size * 0.12, y: -size * 0.10)
            StarShape(points: 7, innerRatio: 0.34)
                .fill(color)
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(x: size * 0.16, y: -size * 0.16)
            StarShape(points: 6, innerRatio: 0.36)
                .fill(color)
                .frame(width: size * 0.52, height: size * 0.52)
                .offset(x: size * 0.05, y: size * 0.20)
        }
    }

    private var dottedStar: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(Double(index) * 22.5))
            }
            StarShape(points: 5, innerRatio: 0.42)
                .fill(color)
                .frame(width: size * 0.34, height: size * 0.34)
        }
    }

    private var shootingStar: some View {
        ZStack {
            TailShape()
                .fill(color)
                .frame(width: size * 0.92, height: size * 0.34)
                .offset(x: size * 0.14, y: size * 0.02)
            StarShape(points: 5, innerRatio: 0.42)
                .fill(color)
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(x: -size * 0.28, y: -size * 0.08)
                .rotationEffect(.degrees(-14))
        }
    }

    private var moonStar: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.48, height: size * 0.48)
                .offset(x: -size * 0.08)
            Circle()
                .fill(color)
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(x: -size * 0.02)
            StarShape(points: 8, innerRatio: 0.20)
                .fill(color)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(x: size * 0.18)
        }
    }

    private var birdStar: some View {
        ZStack {
            BirdShape()
                .fill(color)
                .frame(width: size * 0.92, height: size * 0.68)
                .offset(x: -size * 0.02)
            StarShape(points: 5, innerRatio: 0.42)
                .fill(color)
                .frame(width: size * 0.20, height: size * 0.20)
                .offset(x: size * 0.20, y: size * 0.03)
        }
    }

    private var spiral: some View {
        SpiralShape()
            .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.055), lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.86, height: size * 0.62)
    }

    private var sun: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.055, height: size * 0.22)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.46, height: size * 0.46)
        }
    }
}

private struct StarShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        var path = Path()

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.30))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.20))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY - rect.height * 0.10))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.midY - rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY),
            control2: CGPoint(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.midY + rect.height * 0.18),
            control1: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.midY + rect.height * 0.06),
            control2: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.midY + rect.height * 0.16)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY + rect.height * 0.18))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY - rect.height * 0.10),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY + rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY - rect.height * 0.04)
        )

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.midY + rect.height * 0.02))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY - rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.60, y: rect.midY - rect.height * 0.22),
            control2: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.midY - rect.height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.midY + rect.height * 0.22),
            control1: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.midY + rect.height * 0.04),
            control2: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.midY + rect.height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.midY + rect.height * 0.02),
            control1: CGPoint(x: rect.minX + rect.width * 0.49, y: rect.midY + rect.height * 0.16),
            control2: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.midY + rect.height * 0.08)
        )
        return path
    }
}

private struct SpiralShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) * 0.46
        var path = Path()

        for index in 0...150 {
            let progress = CGFloat(index) / 150
            let angle = progress * .pi * 7.5
            let radius = maxRadius * progress
            let point = CGPoint(
                x: center.x + cos(angle) * radius * 1.45,
                y: center.y + sin(angle) * radius * 0.82
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}
#endif
