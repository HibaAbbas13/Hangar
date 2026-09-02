import SwiftUI
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct HangarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController()
    @StateObject private var deckController = DeckController()
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appController)
                .environmentObject(deckController)
                .environment(\.fdTheme, FDThemeResolver.palette(
                    preference: appController.themePreference,
                    system: systemScheme
                ))
                .preferredColorScheme(preferredScheme)
                .onAppear { appController.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await AuthService.shared.persistToken() }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch appController.themePreference {
        case .night: return .dark
        case .day: return .light
        case .system: return nil
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == Constants.urlScheme else { return }
        appController.selectedTab = .decks
    }
}
