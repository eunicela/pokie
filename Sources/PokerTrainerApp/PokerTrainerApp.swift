#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

@main
struct PokerTrainerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: PersistentPlayerStats.self)
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var persistedStats: [PersistentPlayerStats]
    @StateObject private var store = PokerTrainerStore()

    var body: some View {
        TabView {
            TableScreen(store: store)
                .tabItem { Label("Table", systemImage: "suit.club.fill") }

            StatsScreen(stats: store.stats)
                .tabItem { Label("Stats", systemImage: "chart.xyaxis.line") }

            ProfileScreen(store: store)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.white)
        .onAppear(perform: loadStatsIfNeeded)
        .onChange(of: store.stats) { _, newValue in
            let row = statsRow()
            row.apply(newValue)
            try? modelContext.save()
        }
    }

    private func loadStatsIfNeeded() {
        let row = statsRow()
        store.load(stats: row.snapshot)
    }

    private func statsRow() -> PersistentPlayerStats {
        if let existing = persistedStats.first {
            return existing
        }
        let row = PersistentPlayerStats()
        modelContext.insert(row)
        try? modelContext.save()
        return row
    }
}
#endif
