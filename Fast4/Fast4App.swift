import SwiftUI

@main
struct Fast4App: App {
    @State private var store = MatchStore()

    init() {
        PixelFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                // The whole app is dark-on-green, so the status bar goes light.
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(MatchStore.self) private var store

    var body: some View {
        if let match = store.match {
            ScoreboardView(match: match)
        } else {
            SetupView(config: store.lastConfig)
                .id(store.lastConfig)   // fresh setup state after each match
        }
    }
}
