#if canImport(SwiftUI)
import SwiftUI
import PhotosUI

struct ProfileScreen: View {
    @ObservedObject var store: PokieStore
    @AppStorage("playerName") private var playerName = ""
    @State private var profileImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var helpText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileHeader
                statsSection
                bankrollSection
            }
            .padding()
        }
        .background(Color.white.ignoresSafeArea())
        .alert("Poker stat", isPresented: Binding(get: { helpText != nil }, set: { if !$0 { helpText = nil } })) {
            Button("Got it", role: .cancel) { helpText = nil }
        } message: {
            Text(helpText ?? "")
        }
        .onAppear { loadProfileImage() }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Group {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black.opacity(0.05)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                            )
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
            }
            .onChange(of: photoPickerItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = uiImage
                        saveProfileImage(data)
                    }
                }
            }

            TextField("Your name", text: $playerName)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .padding()
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 16) {
            RadarCard(stats: store.stats)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(title: "VPIP", value: percent(store.stats.vpip), help: StatsTeachingCopy.vpip, helpText: $helpText)
                StatCard(title: "PFR", value: percent(store.stats.pfr), help: StatsTeachingCopy.pfr, helpText: $helpText)
                StatCard(title: "AFq", value: percent(store.stats.aggressionFrequency), help: StatsTeachingCopy.aggression, helpText: $helpText)
                StatCard(title: "Hands", value: "\(store.stats.handsPlayed)", help: "Activity shows how much evidence your stats have. Reads get more reliable as the sample grows.", helpText: $helpText)
                StatCard(title: "Win rate", value: String(format: "%+.1f chips/hand", store.stats.winRatePerHand), help: StatsTeachingCopy.winRate, helpText: $helpText)
            }
        }
    }

    // MARK: - Bankroll

    private var bankrollSection: some View {
        VStack(spacing: 12) {
            Text("Bankroll")
                .font(.caption.weight(.bold))
                .foregroundStyle(.gray)
            Text("\(store.humanSeat.stack) chips")
                .font(.system(size: 42, weight: .black, design: .rounded))

            Button("Add free chips") {
                store.addFreeChips()
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("Free recharge is always available so study never stops.")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Helpers

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static var profileImageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }

    private func saveProfileImage(_ data: Data) {
        try? data.write(to: Self.profileImageURL)
    }

    private func loadProfileImage() {
        guard let data = try? Data(contentsOf: Self.profileImageURL),
              let image = UIImage(data: data) else { return }
        profileImage = image
    }
}

// MARK: - Stat Components

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
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
                Spacer()
                Button {
                    helpText = help
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.4))
                }
            }
            Text(value)
                .font(.title3.weight(.bold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
