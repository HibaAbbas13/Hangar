import SwiftUI

/// Team sync, inside the Account screen.
///
/// This used to put a full-width primary button on "Join a service" — a rarely
/// used action that then outranked everything else on the screen, upgrade
/// included. Joining is now a single row that opens a sheet, so the section
/// costs three lines until someone actually needs it.
struct TeamView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @StateObject private var controller = TeamController()
    @Binding var showPaywall: Bool
    @State private var showJoin = false

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpace.snug) {
            if !app.isPremium {
                Text("Share a service with your team. They join with a one-time code and press the same commands — without ever seeing your webhook URLs.")
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                Button("See Premium") { showPaywall = true }
                    .font(FDFont.ui(14, weight: .semibold))
                    .foregroundStyle(theme.brass)
            } else if let deck = decks.selectedDeck {
                if deck.ownerId == app.userId {
                    if let invite = controller.invite {
                        inviteCode(invite)
                    } else {
                        actionRow(
                            title: "Invite someone to \(deck.name)",
                            subtitle: "Creates a one-time code",
                            symbol: "person.badge.plus"
                        ) {
                            Task { await controller.createInvite(deck: deck) }
                        }
                    }
                }

                actionRow(
                    title: "Join a service",
                    subtitle: "Enter a code a teammate sent you",
                    symbol: "arrow.right.circle"
                ) {
                    showJoin = true
                }

                if let error = controller.errorMessage {
                    Text(error)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.rust)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let notice = controller.notice {
                    Text(notice)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.moss)
                }

                if !controller.members.isEmpty {
                    FDHairline()
                    ForEach(controller.members) { member in
                        memberRow(member, canRemove: deck.ownerId == app.userId)
                    }
                }
            } else {
                Text("Select a service to share it.")
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.fog)
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinServiceSheet(controller: controller)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let deck = decks.selectedDeck {
                controller.start(ownerId: deck.ownerId, deckId: deck.id)
            }
        }
    }

    private func actionRow(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FDSpace.snug) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.brass)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FDFont.ui(15, weight: .medium))
                        .foregroundStyle(theme.bone)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                }
                Spacer(minLength: FDSpace.tight)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.fog)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(subtitle)
    }

    private func inviteCode(_ invite: DeckInvite) -> some View {
        VStack(alignment: .leading, spacing: FDSpace.tight) {
            FDSectionLabel(text: "Invite code")
            HStack {
                Text(invite.code)
                    .font(FDFont.mono(24, weight: .bold))
                    .foregroundStyle(theme.brass)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    UIPasteboard.general.string = invite.code
                    HapticService.success()
                    controller.notice = "Code copied"
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.brass)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Copy invite code")
            }
            Text("Single use. Share it however you like — it grants access to this service only.")
                .font(FDFont.ui(12))
                .foregroundStyle(theme.fog)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FDSpace.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inset, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
    }

    private func memberRow(_ member: TeamMember, canRemove: Bool) -> some View {
        HStack(spacing: FDSpace.snug) {
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(FDFont.ui(14, weight: .medium))
                    .foregroundStyle(theme.bone)
                Text(member.email)
                    .font(FDFont.mono(11))
                    .foregroundStyle(theme.fog)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: FDSpace.tight)
            if canRemove {
                Button {
                    Task { await controller.remove(member) }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.fog)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Remove \(member.displayName)")
            }
        }
        .frame(minHeight: 44)
    }
}

struct JoinServiceSheet: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppController
    @ObservedObject var controller: TeamController

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpace.gutter) {
            VStack(alignment: .leading, spacing: FDSpace.hair) {
                Text("Join a service")
                    .font(FDFont.display(24))
                    .foregroundStyle(theme.bone)
                Text("Paste the code a teammate sent you.")
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.fog)
            }
            FDField(
                title: "Invite code",
                text: $controller.joinCode,
                placeholder: "A7K2Q9LM",
                autocapitalization: .characters,
                monospaced: true
            )
            if let error = controller.errorMessage {
                Text(error)
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.rust)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            FDPrimaryButton(title: "Join", isLoading: controller.isWorking) {
                Task {
                    await controller.join(
                        userId: app.userId ?? "",
                        displayName: app.profile?.displayName ?? "Teammate",
                        email: app.profile?.email ?? ""
                    )
                    if controller.errorMessage == nil { dismiss() }
                }
            }
            .disabled(controller.joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(FDSpace.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel)
    }
}
