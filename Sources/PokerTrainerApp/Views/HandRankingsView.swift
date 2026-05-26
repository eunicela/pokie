#if canImport(SwiftUI)
import SwiftUI

struct HandRankingsView: View {
    private let categories = HandRankCategory.allCases.sorted(by: >)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 42, height: 5)
                            .padding(.top, 8)

                        ForEach(categories, id: \.self) { category in
                            RankingRow(category: category)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Hand Rankings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct RankingRow: View {
    let category: HandRankCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            CardRowView(cards: HandEvaluator.representativeCards(for: category), compact: true)
            Text(category.teachingDescription)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
