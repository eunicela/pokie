#if canImport(SwiftUI)
import SwiftUI
import Foundation

struct StatsScreen: View {
    let stats: PlayerStatsSnapshot
    @State private var helpText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        RadarCard(stats: stats)

                        StatCard(title: "VPIP", value: percent(stats.vpip), help: StatsTeachingCopy.vpip, helpText: $helpText)
                        StatCard(title: "PFR", value: percent(stats.pfr), help: StatsTeachingCopy.pfr, helpText: $helpText)
                        StatCard(title: "AFq", value: percent(stats.aggressionFrequency), help: StatsTeachingCopy.aggression, helpText: $helpText)
                        StatCard(title: "Hands", value: "\(stats.handsPlayed)", help: "Activity shows how much evidence your stats have. Reads get more reliable as the sample grows.", helpText: $helpText)
                        StatCard(title: "Win rate", value: String(format: "%+.1f chips/hand", stats.winRatePerHand), help: StatsTeachingCopy.winRate, helpText: $helpText)
                    }
                    .padding()
                }
            }
            .navigationTitle("Stats")
            .alert("Poker stat", isPresented: Binding(get: { helpText != nil }, set: { if !$0 { helpText = nil } })) {
                Button("Got it", role: .cancel) { helpText = nil }
            } message: {
                Text(helpText ?? "")
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct RadarCard: View {
    let stats: PlayerStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playstyle radar")
                .font(.headline)
            PlaystyleRadar(looseness: stats.looseness, aggression: stats.aggression)
                .frame(height: 260)
            Text("Tight to loose is driven by VPIP. Passive to aggressive is driven by AFq.")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PlaystyleRadar: View {
    let looseness: Double
    let aggression: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let point = CGPoint(
                x: center.x + (looseness - 0.5) * size * 0.72,
                y: center.y - (aggression - 0.5) * size * 0.72
            )

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.55), .orange.opacity(0.42), .cyan.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Color.black.opacity(0.42))

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: 18))
                    path.addLine(to: CGPoint(x: center.x, y: proxy.size.height - 18))
                    path.move(to: CGPoint(x: 18, y: center.y))
                    path.addLine(to: CGPoint(x: proxy.size.width - 18, y: center.y))
                }
                .stroke(Color.white.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5]))

                quadrant("TAG", x: proxy.size.width * 0.25, y: proxy.size.height * 0.25)
                quadrant("LAG", x: proxy.size.width * 0.75, y: proxy.size.height * 0.25)
                quadrant("Rock", x: proxy.size.width * 0.25, y: proxy.size.height * 0.75)
                quadrant("Fish", x: proxy.size.width * 0.75, y: proxy.size.height * 0.75)

                Text("Passive").font(.caption2).foregroundStyle(.white.opacity(0.75)).position(x: center.x, y: proxy.size.height - 10)
                Text("Aggressive").font(.caption2).foregroundStyle(.white.opacity(0.75)).position(x: center.x, y: 10)
                Text("Tight").font(.caption2).foregroundStyle(.white.opacity(0.75)).position(x: 24, y: center.y)
                Text("Loose").font(.caption2).foregroundStyle(.white.opacity(0.75)).position(x: proxy.size.width - 25, y: center.y)

                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .white.opacity(0.6), radius: 10)
                    .position(point)
            }
        }
    }

    private func quadrant(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.headline.weight(.black))
            .foregroundStyle(.white.opacity(0.9))
            .position(x: x, y: y)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let help: String
    @Binding var helpText: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.title3.weight(.bold))
            }
            Spacer()
            Button {
                helpText = help
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding()
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
