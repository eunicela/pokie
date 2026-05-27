#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

@main
struct PokieApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: PersistentPlayerStats.self)
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var persistedStats: [PersistentPlayerStats]
    @StateObject private var store = PokieStore()

    var body: some View {
        TabView {
            TableScreen(store: store)
                .tabItem { Image(systemName: "suit.club.fill") }

            ProfileScreen(store: store)
                .tabItem { Image(systemName: "person.crop.circle") }
        }
        .tint(Color(red: 45/255, green: 48/255, blue: 145/255))
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
