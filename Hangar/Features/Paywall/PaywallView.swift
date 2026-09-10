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
                    VStack(alignment: .leading, spacing: FDSpace.gutter) {
                        VStack(alignment: .leading, spacing: FDSpace.snug) {
                            Text("HANGAR PREMIUM")
                                .font(FDFont.micro(11))
                                .tracking(4)
                                .foregroundStyle(theme.brass)
                            Text("Your whole stack, one thumb.")
                                .font(FDFont.display(32))
                                .foregroundStyle(theme.bone)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Free gives you one service and three commands. Premium turns Hangar into the control deck for everything you ship.")
                                .font(FDFont.ui(15))
                                .foregroundStyle(theme.fog)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // The trial is the offer, so it gets its own block
                        // instead of being the last clause of a paragraph.
                        HStack(spacing: FDSpace.snug) {
                            Image(systemName: "gift")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.brass)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Constants.Monetization.freeTrialDays) days free")
                                    .font(FDFont.ui(15, weight: .semibold))
                                    .foregroundStyle(theme.bone)
                                Text("Cancel any time before it ends and you pay nothing.")
                                    .font(FDFont.ui(12))
                                    .foregroundStyle(theme.fog)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(FDSpace.snug)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.brass.opacity(0.1), in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                                .stroke(theme.brass.opacity(0.28), lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)

                        VStack(alignment: .leading, spacing: FDSpace.snug) {
                            perk("Unlimited services and commands",
                                 "Free stops at \(Constants.Limits.freeDeckCount) service and \(Constants.Limits.freeButtonCount) commands.",
                                 "square.grid.2x2")
                            perk("Flows",
                                 "Chain commands with waits between them — one press runs the lot.",
                                 "arrow.triangle.branch")
                            perk("Live Activities",
                                 "Watch a deploy land from the Lock Screen.",
                                 "bolt.badge.clock")
                            perk("Siri and Shortcuts",
                                 "“Hey Siri, roll back production.”",
                                 "mic")
                            perk("Team sync",
                                 "Teammates join with a code and press the same commands.",
                                 "person.2")
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

                        offerCodeSection

                        if let error = controller.errorMessage {
                            Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
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
                    if controller.store.isPremium {
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

    private var offerCodeSection: some View {
        Button("Redeem App Store offer code") {
            controller.redeemAppStoreOfferCode()
        }
        .font(FDFont.ui(14, weight: .medium))
        .foregroundStyle(theme.brass)
        .frame(maxWidth: .infinity)
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

    /// A perk says what it is *and* what it gets you. A bare list of nouns
    /// ("Team sync", "Live Activities") asks the reader to already know what
    /// they are worth.
    private func perk(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: FDSpace.snug) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.brass)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FDFont.ui(15, weight: .medium))
                    .foregroundStyle(theme.bone)
                Text(detail)
                    .font(FDFont.ui(12))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
