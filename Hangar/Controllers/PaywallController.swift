import Foundation
import RevenueCat

@MainActor
final class PaywallController: ObservableObject {
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var promoCode = ""
    @Published var promoNotice: String?

    let store = RevenueCatService.shared
    private let users = UserRepository()

    var packages: [Package] {
        var result: [Package] = []
        if let annual = store.annual { result.append(annual) }
        if let monthly = store.monthly { result.append(monthly) }
        if result.isEmpty {
            result = store.offerings?.current?.availablePackages ?? []
        }
        return result
    }

    
    
    var annualSavingPercent: Int? {
        guard let monthly = store.monthly?.storeProduct.price,
              let annual = store.annual?.storeProduct.price,
              monthly > 0 else { return nil }
        let twelve = monthly * 12
        guard twelve > annual else { return nil }
        let saving = ((twelve - annual) / twelve) * 100
        return Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
    }

    func isBestValue(_ package: Package) -> Bool {
        package.identifier == store.annual?.identifier && annualSavingPercent != nil
    }

    func trialCaption(for package: Package) -> String {
        store.trialCaption(for: package) ?? SubscriptionOfferCopy.plannedTrialBadge
    }

    func purchase(_ package: Package, userId: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let premium = try await store.purchase(package)
            if premium {
                try await users.setTier(userId: userId, tier: .premium)
                showSuccess = true
                HapticService.success()
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func restore(userId: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let premium = try await store.restore()
            if premium {
                try await users.setTier(userId: userId, tier: .premium)
                showSuccess = true
            } else if JudgePromoStore.isUnlocked {
                try await users.setTier(userId: userId, tier: .premium)
                showSuccess = true
            } else {
                errorMessage = "No active premium entitlement found."
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    func redeemJudgePromo(userId: String) async {
        errorMessage = nil
        promoNotice = nil
        guard JudgePromoStore.matches(promoCode) else {
            errorMessage = "That code is not valid."
            HapticService.error()
            return
        }
        isWorking = true
        defer { isWorking = false }
        JudgePromoStore.unlock()
        do {
            try await users.setTier(userId: userId, tier: .premium)
        } catch {
            
            promoNotice = "Pro unlocked on this device. Cloud sync will retry."
        }
        await store.refresh()
        showSuccess = true
        if promoNotice == nil {
            promoNotice = "Hangar Pro unlocked."
        }
        HapticService.success()
        promoCode = ""
    }

    func redeemAppStoreOfferCode() {
        errorMessage = nil
        store.presentOfferCodeRedemption()
    }
}
