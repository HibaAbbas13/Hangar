import Foundation
import RevenueCat

@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published private(set) var isPremium = false
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isConfigured = false
    @Published private(set) var entitlementResolved = false
    @Published private(set) var loadFailure: String?

    private var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: Constants.RevenueCat.infoPlistKey) as? String) ?? ""
    }

    func configure(appUserId: String) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("YOUR_REVENUECAT") else {
            loadFailure = "No RevenueCat key in this build. Set REVENUECAT_API_KEY in Config/Secrets.xcconfig."
            return
        }
        if isConfigured {
            Task { _ = try? await Purchases.shared.logIn(appUserId) }
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key, appUserID: appUserId)
        isConfigured = true
        Task { await refresh() }
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[Constants.RevenueCat.entitlementId]?.isActive == true
            entitlementResolved = true
            let loaded = try await Purchases.shared.offerings()
            offerings = loaded

            if loaded.current == nil {
                loadFailure = loaded.all.isEmpty
                    ? "RevenueCat has no offerings yet. Create one and mark it Current."
                    : "No offering is marked Current in RevenueCat."
            } else if loaded.current?.availablePackages.isEmpty ?? true {
                
                loadFailure = """
                App Store products are not ready yet. In App Store Connect, open each subscription \
                (com.dev.hangar.supporter / com.dev.hangar.groundcrew) and finish: localization, \
                price for all territories, and a Review Information screenshot. Status must become \
                Ready to Submit — RevenueCat Missing Metadata clears after that. Then test on a \
                real device with a Sandbox Apple Account (Simulator cannot fetch real products).
                """
            } else {
                loadFailure = nil
            }
        } catch {
            loadFailure = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        isPremium = result.customerInfo.entitlements[Constants.RevenueCat.entitlementId]?.isActive == true
        entitlementResolved = true
        return isPremium
    }

    func restore() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        isPremium = info.entitlements[Constants.RevenueCat.entitlementId]?.isActive == true
        entitlementResolved = true
        return isPremium
    }

    
    func presentOfferCodeRedemption() {
        Purchases.shared.presentCodeRedemptionSheet()
    }

    func trialCaption(for package: Package) -> String? {
        SubscriptionOfferCopy.trialCaption(for: package)
    }

    var monthly: Package? {
        offerings?.current?.monthly ?? offerings?.current?.availablePackages.first
    }

    var annual: Package? {
        offerings?.current?.annual
    }
}
