import Foundation
import RevenueCat

enum SubscriptionOfferCopy {
    
    static func trialCaption(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial else { return nil }
        let period = periodPhrase(discount.subscriptionPeriod)
        let price = package.localizedPriceString
        let cadence: String
        switch package.packageType {
        case .monthly: cadence = "\(price)/mo"
        case .annual: cadence = "\(price)/yr"
        default: cadence = price
        }
        return "\(period) free, then \(cadence)"
    }

    static func periodPhrase(_ period: SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day:
            return value == 1 ? "1-day" : "\(value)-day"
        case .week:
            return value == 1 ? "1-week" : "\(value)-week"
        case .month:
            return value == 1 ? "1-month" : "\(value)-month"
        case .year:
            return value == 1 ? "1-year" : "\(value)-year"
        @unknown default:
            return "\(value)-period"
        }
    }

    
    static var plannedTrialBadge: String {
        "\(Constants.Monetization.freeTrialDays)-day free trial"
    }
}
