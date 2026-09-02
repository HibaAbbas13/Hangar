import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @StateObject private var console = ConsoleController()
    @State private var showPaywall = false

    var body: some View {
        Group {
            switch app.selectedTab {
            case .decks:
                DeckHomeView(showPaywall: $showPaywall)
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
            FDTabBar(selection: $app.selectedTab)
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
            }
        }
        .onChange(of: app.userId) { _, userId in
            if let userId {
                decks.start(userId: userId)
                console.start(userId: userId)
            }
        }
    }
}

struct Greeting {
    static func line(name: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let handle = name.isEmpty ? "operator" : name
        switch hour {
        case 5..<12: return "Morning, \(handle)"
        case 12..<17: return "Afternoon, \(handle)"
        case 17..<21: return "Evening, \(handle)"
        default: return "Night watch, \(handle)"
        }
    }
}
