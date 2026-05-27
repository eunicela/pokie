#if canImport(SwiftUI)
import SwiftUI

struct HandRankingsView: View {
    private let categories = HandRankCategory.allCases.sorted(by: >)

    var body: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("Hand Rankings")
                .font(.subheadline.weight(.bold))
                .padding(.bottom, 2)

            ForEach(categories, id: \.self) { category in
                RankingRow(category: category)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.hidden)
    }
}

private struct RankingRow: View {
    let category: HandRankCategory

    var body: some View {
        HStack(spacing: 10) {
            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 100, alignment: .leading)

            CardRowView(cards: HandEvaluator.representativeCards(for: category), cardWidth: 28, cardHeight: 40)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
#endif
