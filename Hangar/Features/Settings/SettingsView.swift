import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Binding var showPaywall: Bool
    @StateObject private var controller = SettingsController()
    @State private var tierOverride = TierOverrideStore.current
    @State private var versionTaps = 0
    @State private var showTestingCard = false
    @ObservedObject private var sound = SoundService.shared

    var body: some View {
        NavigationStack {
            FDScreen {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        FDPageHeader(eyebrow: "Account", title: "Account & rails", horizontalPadding: 0)
                        accountCard
                        MetalCard {
                            VStack(alignment: .leading, spacing: 14) {
                                FDSectionLabel(text: "Appearance")
                                ForEach(ThemePreference.allCases) { item in
                                    chooser(title: item.title, selected: app.themePreference == item) {
                                        Task {
                                            if let profile = app.profile {
                                                app.profile = await controller.updateTheme(item, profile: profile)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        MetalCard {
                            VStack(alignment: .leading, spacing: 14) {
                                FDSectionLabel(text: "Execution")
                                ForEach(ExecutionMode.allCases) { item in
                                    chooser(title: item.title, subtitle: item.subtitle, selected: app.executionMode == item) {
                                        Task {
                                            if let profile = app.profile {
                                                app.profile = await controller.updateMode(item, profile: profile)
                                            }
                                        }
                                    }
                                }
                                Text("Hangar Cloud keeps webhook secrets off the device for widgets and Siri. If Cloud Functions are not deployed, switch back to On device.")
                                    .font(FDFont.ui(12))
                                    .foregroundStyle(theme.fog)
                                if let error = controller.errorMessage {
                                    Text(error)
                                        .font(FDFont.ui(13))
                                        .foregroundStyle(theme.rust)
                                }
                            }
                        }
                        MetalCard {
                            VStack(alignment: .leading, spacing: 12) {
                                FDSectionLabel(text: "Team")
                                TeamView(showPaywall: $showPaywall)
                            }
                        }
                        soundCard
                        permissionsCard
                        if showTestingCard {
                            testingCard
                        }
                        aboutCard
                        FDGhostButton(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                            app.signOut()
                        }
                        Text("Hangar \(appVersion)  ·  com.dev.flightdeck")
                            .font(FDFont.mono(11))
                            .foregroundStyle(theme.fog)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                
                                
                                guard Constants.Debug.isInternalBuild,
                                      Constants.Monetization.paywallEnabled else { return }
                                versionTaps += 1
                                if versionTaps >= 7 {
                                    versionTaps = 0
                                    withAnimation(FDMotion.snappy) { showTestingCard.toggle() }
                                    HapticService.warning()
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var accountCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink {
                    ProfileView(showPaywall: $showPaywall)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(theme.brass.opacity(0.16))
                                .frame(width: 46, height: 46)
                                .overlay(Circle().stroke(theme.brass.opacity(0.4), lineWidth: 1))
                            Text(initials)
                                .font(FDFont.ui(16, weight: .bold))
                                .foregroundStyle(theme.brass)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.profile?.displayName ?? "Operator")
                                .font(FDFont.ui(18, weight: .semibold))
                                .foregroundStyle(theme.bone)
                            Text(app.profile?.email ?? "")
                                .font(FDFont.mono(12))
                                .foregroundStyle(theme.fog)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 8)
                        FDBadge.tier(isPremium: app.isPremium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.fog)
                    }
                    .contentShape(Rectangle())
                }
                if !Constants.Monetization.paywallEnabled {
                    Text("Test build — every feature is unlocked for all testers. Nothing is for sale and nothing is charged.")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                        .fixedSize(horizontal: false, vertical: true)
                } else if Constants.Debug.isTestFlight, tierOverride == .premium {
                    Text("TestFlight build — every rail is unlocked for testers. You are not being charged.")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                        .fixedSize(horizontal: false, vertical: true)
                } else if tierOverride != .none {
                    Text("Testing override active — \(tierOverride.title). This build is not billing through RevenueCat.")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !app.isPremium {
                    FDPrimaryButton(title: "Upgrade Hangar") { showPaywall = true }
                }
            }
        }
    }

    private var testingCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "Testing · not shipped")
                Text("Forces a tier so both sides of the paywall can be exercised without a working purchase. Has no effect on an App Store build.")
                    .font(FDFont.ui(12))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(TierOverride.allCases) { item in
                    chooser(title: item.title, subtitle: item.subtitle, selected: tierOverride == item) {
                        tierOverride = item
                        TierOverrideStore.current = item
                        app.reapplyTier()
                        HapticService.select()
                    }
                }
                Text(Constants.Debug.isTestFlight ? "TestFlight build" : "Debug build")
                    .font(FDFont.mono(11))
                    .foregroundStyle(theme.fog)
            }
        }
    }

    private var soundCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "Sound")
                Toggle(isOn: $sound.isEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command cues")
                            .font(FDFont.ui(15, weight: .medium))
                            .foregroundStyle(theme.bone)
                        Text("A short cue on press, and on the result. Mixes with your music and follows the silent switch.")
                            .font(FDFont.ui(12))
                            .foregroundStyle(theme.fog)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(theme.brass)
                .onChange(of: sound.isEnabled) { _, on in
                    if on { sound.preview(.success) }
                }

                FDHairline()

                HStack(spacing: 10) {
                    ForEach(SoundService.Cue.allCases, id: \.rawValue) { cue in
                        Button {
                            sound.preview(cue)
                            HapticService.light()
                        } label: {
                            Text(cueName(cue))
                                .font(FDFont.micro(10))
                                .tracking(1.1)
                                .foregroundStyle(theme.brass)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(theme.inset, in: Capsule())
                                .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
                        }
                        .buttonStyle(FDPressStyle(depth: 1))
                        .accessibilityLabel("Play \(cueName(cue).lowercased()) cue")
                    }
                }
            }
        }
    }

    private func cueName(_ cue: SoundService.Cue) -> String {
        switch cue {
        case .press: return "Press"
        case .success: return "Accepted"
        case .fault: return "Fault"
        }
    }

    private var permissionsCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "Permissions")
                Text("iOS keeps these behind switches only you can turn on. Tap one to see what it does and jump to Settings.")
                    .font(FDFont.ui(12))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(PermissionService.Permission.allCases) { permission in
                    PermissionRow(permission: permission) {
                        PermissionService.shared.explain(permission)
                    }
                }
            }
        }
    }

    private var aboutCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "About")
                Button {
                    ReviewService.openWriteReview()
                } label: {
                    LegalLinkRow(title: "Rate Hangar", systemImage: "star")
                }
                FDHairline()
                NavigationLink { LegalView(document: LegalText.privacy) } label: {
                    LegalLinkRow(title: "Privacy Policy", systemImage: "hand.raised")
                }
                FDHairline()
                NavigationLink { LegalView(document: LegalText.terms) } label: {
                    LegalLinkRow(title: "Terms of Use", systemImage: "doc.text")
                }
                FDHairline()
                Link(destination: URL(string: "mailto:\(Constants.Legal.supportEmail)")!) {
                    LegalLinkRow(title: "Contact support", systemImage: "envelope")
                }
            }
        }
    }

    private var initials: String {
        let parts = (app.profile?.displayName ?? "Operator").split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "FD" : letters.uppercased()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func chooser(title: String, subtitle: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FDFont.ui(15, weight: .medium))
                        .foregroundStyle(theme.bone)
                    if let subtitle {
                        Text(subtitle)
                            .font(FDFont.ui(12))
                            .foregroundStyle(theme.fog)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.brass : theme.fog)
            }
        }
    }
}
