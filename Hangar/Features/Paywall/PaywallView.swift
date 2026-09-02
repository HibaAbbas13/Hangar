import SwiftUI
import RevenueCat
import UIKit

struct PaywallSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PaywallController()

    var body: some View {
        NavigationStack {
            ZStack {
                FDScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PREMIUM")
                                .font(FDFont.micro(11))
                                .tracking(4)
                                .foregroundStyle(theme.brass)
                            Text("Unlimited surfaces.")
                                .font(FDFont.display(34))
                                .foregroundStyle(theme.bone)
                            Text("Live Activities, Siri macros, team sync, and chained execution profiles. Start with a \(Constants.Monetization.freeTrialDays)-day free trial.")
                                .font(FDFont.ui(15))
                                .foregroundStyle(theme.fog)
                        }
                        VStack(spacing: 10) {
                            perk("Infinite decks and command pads", "square.grid.2x2")
                            perk("Lock screen Live Activity pipeline", "lock.display")
                            perk("Siri Shortcut macros", "mic")
                            perk("Team synchronization", "person.2")
                            perk("Automated execution profiles", "arrow.triangle.branch")
                        }
                        if controller.packages.isEmpty {
                            MetalCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Plans are not loading")
                                        .font(FDFont.ui(15, weight: .semibold))
                                        .foregroundStyle(theme.bone)
                                    Text(controller.store.loadFailure ?? "Still checking with the App Store.")
                                        .font(FDFont.ui(13))
                                        .foregroundStyle(theme.fog)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } else {
                            ForEach(controller.packages, id: \.identifier) { package in
                                Button {
                                    Task {
                                        if let userId = app.userId {
                                            await controller.purchase(package, userId: userId)
                                            if controller.showSuccess {
                                                app.applyPromoUnlock()
                                                dismiss()
                                            }
                                        }
                                    }
                                } label: {
                                    packageRow(package)
                                }
                                .disabled(controller.isWorking)
                            }
                        }

                        promoSection

                        if let error = controller.errorMessage {
                            Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
                        }
                        if let notice = controller.promoNotice {
                            Text(notice).font(FDFont.ui(13)).foregroundStyle(theme.moss)
                        }
                        Button("Restore purchases") {
                            Task {
                                if let userId = app.userId {
                                    await controller.restore(userId: userId)
                                    if controller.showSuccess {
                                        app.applyPromoUnlock()
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .font(FDFont.ui(14, weight: .medium))
                        .foregroundStyle(theme.fog)
                        .frame(maxWidth: .infinity)

                        subscriptionTerms
                    }
                    .padding(22)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await controller.store.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await controller.store.refresh()
                    if JudgePromoStore.isUnlocked || controller.store.isPremium {
                        app.applyPromoUnlock()
                    }
                }
            }
        }
    }

    private func packageRow(_ package: Package) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(package.storeProduct.localizedTitle)
                        .font(FDFont.ui(16, weight: .semibold))
                        .foregroundStyle(theme.bone)
                    if controller.isBestValue(package),
                       let saving = controller.annualSavingPercent {
                        FDBadge(text: "Save \(saving)%", tone: .moss)
                    }
                }
                Text(controller.trialCaption(for: package))
                    .font(FDFont.ui(12, weight: .medium))
                    .foregroundStyle(theme.brass)
                Text(package.storeProduct.localizedDescription)
                    .font(FDFont.ui(12))
                    .foregroundStyle(theme.fog)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Text(package.localizedPriceString)
                .font(FDFont.mono(14, weight: .bold))
                .foregroundStyle(theme.brass)
        }
        .padding(16)
        .background(theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    controller.isBestValue(package) ? theme.brass.opacity(0.55) : theme.hairline,
                    lineWidth: controller.isBestValue(package) ? 1.5 : 1
                )
        )
    }

    private var promoSection: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 12) {
                FDSectionLabel(text: "Have a code?")
                FDField(
                    title: "Promo code",
                    text: $controller.promoCode,
                    placeholder: "HANGAR-JUDGE",
                    autocapitalization: .characters
                )
                FDPrimaryButton(title: "Redeem code", isLoading: controller.isWorking) {
                    Task {
                        guard let userId = app.userId else { return }
                        await controller.redeemJudgePromo(userId: userId)
                        if controller.showSuccess {
                            app.applyPromoUnlock()
                            dismiss()
                        }
                    }
                }
                Button("Redeem App Store offer code") {
                    controller.redeemAppStoreOfferCode()
                }
                .font(FDFont.ui(13, weight: .medium))
                .foregroundStyle(theme.brass)
            }
        }
    }

    
    
    private var subscriptionTerms: some View {
        VStack(spacing: 10) {
            Text("Any unused portion of a free trial is forfeited when you purchase. Payment is charged to your Apple Account at confirmation (or after the trial). The subscription renews automatically unless auto-renew is turned off at least 24 hours before the period ends. Manage or cancel in Settings → Apple Account → Subscriptions.")
                .font(FDFont.ui(11))
                .foregroundStyle(theme.fog)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                NavigationLink { LegalView(document: LegalText.terms) } label: {
                    Text("Terms of Use")
                        .font(FDFont.ui(12, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
                NavigationLink { LegalView(document: LegalText.privacy) } label: {
                    Text("Privacy Policy")
                        .font(FDFont.ui(12, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
            }
        }
        .padding(.top, 6)
    }

    private func perk(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(theme.brass)
                .frame(width: 28)
            Text(title)
                .font(FDFont.ui(15))
                .foregroundStyle(theme.bone)
            Spacer()
        }
    }
}
