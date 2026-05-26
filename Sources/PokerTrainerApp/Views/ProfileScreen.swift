#if canImport(SwiftUI)
import SwiftUI

struct ProfileScreen: View {
    @ObservedObject var store: PokerTrainerStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Local player")
                            .font(.title2.weight(.bold))
                        Text("No accounts. No real money. Everything stays on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

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
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Training goal")
                            .font(.headline)
                        Text("Spot stable opponent tendencies: punish Fish with thin value, respect Rock aggression, pressure TAGs carefully, and bluff-catch LAGs with evidence.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}
#endif
