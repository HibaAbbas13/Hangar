import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import Combine

enum SessionState: Equatable {
    case launching
    case needsFirebase
    case onboarding
    case unauthenticated
    case ready
}

@MainActor
final class AppController: ObservableObject {
    @Published var session: SessionState = .launching
    @Published var profile: UserProfile?
    @Published var isPremium = !Constants.Monetization.paywallEnabled || TierOverrideStore.current == .premium
    @Published var selectedTab: AppTab = .decks
    @Published var reducedMotion = false

    let auth = AuthService.shared
    let users = UserRepository()
    let revenueCat = RevenueCatService.shared

    private var userListener: Any?
    private var authHandle: AuthStateDidChangeListenerHandle?

    var userId: String? { profile?.id ?? auth.userId }
    var executionMode: ExecutionMode { profile?.executionMode ?? .onDevice }
    var themePreference: ThemePreference { profile?.themePreference ?? .night }

    func bootstrap() {
        reducedMotion = UIAccessibility.isReduceMotionEnabled
        guard FirebaseApp.app() != nil else {
            session = .needsFirebase
            return
        }
        WebhookService.shared.persistBaseURL()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.handleAuth(user)
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reducedMotion = UIAccessibility.isReduceMotionEnabled
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "fd.onboarded")
        session = auth.currentUser() == nil ? .unauthenticated : session
        if auth.currentUser() != nil {
            session = .ready
        }
    }

    func skipToSampleHangar() {
        UserDefaults.standard.set(true, forKey: Constants.Demo.autoHangarFlag)
        completeOnboarding()
    }

    func refreshPremiumFromStore() async {
        await revenueCat.refresh()
        applyPremiumFlag()
        guard Constants.Monetization.paywallEnabled, let userId else { return }
        if Constants.Access.isAlwaysPremium(profile?.email) {
            if profile?.tier != .premium {
                try? await users.setTier(userId: userId, tier: .premium)
            }
            return
        }
        guard TierOverrideStore.current == .none, revenueCat.entitlementResolved else { return }
        if revenueCat.isPremium, profile?.tier != .premium {
            try? await users.setTier(userId: userId, tier: .premium)
        } else if !revenueCat.isPremium, profile?.tier == .premium {
            try? await users.setTier(userId: userId, tier: .free)
        }
    }

    func signOut() {
        try? auth.signOut()
        profile = nil
        WidgetSyncService.clear()
        applyPremiumFlag()
        session = .unauthenticated
    }

    private func handleAuth(_ user: User?) async {
        guard let user else {
            userListener = nil
            profile = nil
            if UserDefaults.standard.bool(forKey: "fd.onboarded") {
                session = .unauthenticated
            } else {
                session = .onboarding
            }
            return
        }

        await auth.persistToken()
        revenueCat.configure(appUserId: user.uid)
        let display = user.displayName ?? auth.pendingDisplayName ?? "Operator"
        let email = user.email ?? ""
        do {
            let ensured = try await users.ensureProfile(userId: user.uid, displayName: display, email: email)
            profile = ensured
            applyPremiumFlag()
            userListener = users.observe(userId: user.uid) { [weak self] profile in
                Task { @MainActor in
                    if let profile {
                        self?.profile = profile
                        self?.applyPremiumFlag()
                    }
                }
            }
            await refreshPremiumFromStore()
            if UserDefaults.standard.bool(forKey: "fd.onboarded") == false {
                session = .onboarding
            } else {
                session = .ready
            }
        } catch {
            profile = UserProfile.new(id: user.uid, displayName: display, email: email)
            applyPremiumFlag()
            if UserDefaults.standard.bool(forKey: "fd.onboarded") == false {
                session = .onboarding
            } else {
                session = .ready
            }
        }
    }

    private func applyPremiumFlag() {
        // Accounts on the allowlist are premium everywhere, so reviewing and
        // testing never hinge on a sandbox purchase completing.
        if Constants.Access.isAlwaysPremium(profile?.email) {
            isPremium = true
            return
        }
        guard Constants.Monetization.paywallEnabled else {
            isPremium = true
            return
        }
        switch TierOverrideStore.current {
        case .premium:
            isPremium = true
        case .free:
            isPremium = false
        case .none:
            isPremium = revenueCat.isPremium
        }
    }

    
    func reapplyTier() {
        applyPremiumFlag()
    }

    func applyPromoUnlock() {
        if var profile {
            profile.tier = .premium
            self.profile = profile
        }
        applyPremiumFlag()
    }
}
