import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var console = ConsoleController()
    @StateObject private var tutorial = TutorialController()
    @State private var showPaywall = false

    var body: some View {
        Group {
            switch app.selectedTab {
            case .decks:
                DeckHomeView(showPaywall: $showPaywall, console: console)
            case .console:
                ConsoleView(controller: console)
            case .flows:
                AutomationsView(showPaywall: $showPaywall)
            case .hangar:
                SettingsView(showPaywall: $showPaywall)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                RunHUDOverlay()
                    .padding(.horizontal, 16)
                FDTabBar(selection: $app.selectedTab)
            }
        }
        // Sits above both the screen and the tab bar so a step can point at either.
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                TutorialOverlay(
                    controller: tutorial,
                    frames: anchors.mapValues { proxy[$0] }
                )
            }
            .ignoresSafeArea()
        }
        .onChange(of: decks.buttons.count) { _, count in
            guard let userId = app.userId else { return }
            tutorial.startIfNeeded(userId: userId, hasContent: count > 0)
        }
        .sheet(isPresented: Binding(
            get: { showPaywall && Constants.Monetization.paywallEnabled },
            set: { showPaywall = $0 }
        )) {
            PaywallSheet()
        }
        .onAppear {
            if let userId = app.userId {
                decks.start(userId: userId)
                console.start(userId: userId)
                decks.syncWidgetsToExtension()
            }
        }
        .onChange(of: app.userId) { _, userId in
            if let userId {
                decks.start(userId: userId)
                console.start(userId: userId)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                decks.syncWidgetsToExtension()
            }
        }
    }
}
