import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var showPaywall: Bool
    @StateObject private var controller = ProfileController()

    var body: some View {
        FDScreen {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    FDIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                    FDPageHeader(eyebrow: "Operator", title: "Profile", horizontalPadding: 0)
                    identityCard
                    statsCard
                    callsignCard
                    legalCard
                    dangerCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.load(app.profile) }
        .alert("Delete this hangar?", isPresented: confirmBinding) {
            Button("Cancel", role: .cancel) { controller.cancelDelete() }
            Button("Delete everything", role: .destructive) {
                Task {
                    guard let userId = app.userId else { return }
                    if await controller.confirmDelete(userId: userId) {
                        decks.stop()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Your decks, buttons, automations, activity log, and account are erased. This cannot be undone.")
        }
        .sheet(isPresented: passwordBinding) {
            reauthSheet
        }
    }

    

    private var identityCard: some View {
        MetalCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.brass.opacity(0.16))
                        .frame(width: 64, height: 64)
                        .overlay(Circle().stroke(theme.brass.opacity(0.4), lineWidth: 1))
                    Text(initials)
                        .font(FDFont.display(24, weight: .bold))
                        .foregroundStyle(theme.brass)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.profile?.displayName ?? "Operator")
                        .font(FDFont.ui(20, weight: .semibold))
                        .foregroundStyle(theme.bone)
                    Text(app.profile?.email ?? "")
                        .font(FDFont.mono(12))
                        .foregroundStyle(theme.fog)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    FDBadge.tier(isPremium: app.isPremium)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statsCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "Flight record")
                HStack(spacing: 0) {
                    stat(value: "\(decks.decks.count)", label: "Decks")
                    divider
                    stat(value: "\(decks.buttons.count)", label: "Commands")
                    divider
                    stat(value: memberSince, label: "Since")
                }
                if Constants.Monetization.paywallEnabled, !app.isPremium {
                    Text("Free tier: \(Constants.Limits.freeDeckCount) deck, \(Constants.Limits.freeButtonCount) commands.")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                    FDPrimaryButton(title: "Upgrade Hangar") { showPaywall = true }
                }
            }
        }
    }

    private var callsignCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 12) {
                FDField(title: "Callsign", text: $controller.displayName, placeholder: "Operator")
                if let notice = controller.nameNotice {
                    Text(notice)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                }
                FDGhostButton(title: "Save callsign", systemImage: "checkmark") {
                    Task {
                        guard let profile = app.profile else { return }
                        app.profile = await controller.saveName(profile: profile)
                    }
                }
            }
        }
    }

    private var legalCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 14) {
                FDSectionLabel(text: "Legal & support")
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

    private var dangerCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 12) {
                FDSectionLabel(text: "Danger zone")
                Text("Deleting your hangar erases every deck, command, automation, and log entry we hold for you. It cannot be undone.")
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = controller.deleteError, controller.deleteStage != .needsPassword {
                    Text(error)
                        .font(FDFont.ui(13))
                        .foregroundStyle(theme.rust)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    HapticService.warning()
                    controller.beginDelete()
                } label: {
                    HStack(spacing: 8) {
                        if controller.deleteStage == .working {
                            ProgressView().tint(theme.rust)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Delete account")
                            .font(FDFont.ui(15, weight: .semibold))
                    }
                    .foregroundStyle(theme.rust)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(theme.rust.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.rust.opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(FDPressStyle(depth: 2))
                .disabled(controller.deleteStage == .working)
            }
        }
    }

    private var reauthSheet: some View {
        FDScreen {
            VStack(alignment: .leading, spacing: 18) {
                Text("Confirm it's you")
                    .font(FDFont.display(26))
                    .foregroundStyle(theme.bone)
                Text("Firebase asks for a fresh sign-in before an account can be deleted.")
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.fog)
                FDField(
                    title: "Passcode",
                    text: $controller.reauthPassword,
                    placeholder: "your password",
                    isSecure: true,
                    autocapitalization: .never
                )
                if let error = controller.deleteError {
                    Text(error)
                        .font(FDFont.ui(13))
                        .foregroundStyle(theme.rust)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FDPrimaryButton(
                    title: "Delete account",
                    isLoading: controller.deleteStage == .working
                ) {
                    Task {
                        guard let userId = app.userId else { return }
                        if await controller.confirmDeleteWithPassword(userId: userId) {
                            decks.stop()
                            dismiss()
                        }
                    }
                }
                FDGhostButton(title: "Cancel") { controller.cancelDelete() }
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }

    

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: { controller.deleteStage == .confirming },
            set: { if !$0, controller.deleteStage == .confirming { controller.cancelDelete() } }
        )
    }

    private var passwordBinding: Binding<Bool> {
        Binding(
            get: { controller.deleteStage == .needsPassword || (controller.deleteStage == .working && !controller.reauthPassword.isEmpty) },
            set: { if !$0 { controller.cancelDelete() } }
        )
    }

    private var initials: String {
        let name = app.profile?.displayName ?? "Operator"
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "FD" : letters.uppercased()
    }

    private var memberSince: String {
        guard let created = app.profile?.createdAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: created)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(width: 1, height: 34)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FDFont.mono(20, weight: .semibold))
                .foregroundStyle(theme.brass)
            Text(label.uppercased())
                .font(FDFont.micro(10))
                .tracking(1.2)
                .foregroundStyle(theme.fog)
        }
        .frame(maxWidth: .infinity)
    }
}
