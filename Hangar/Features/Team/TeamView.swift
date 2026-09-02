import SwiftUI

struct TeamView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @StateObject private var controller = TeamController()
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !app.isPremium {
                Text("Team sync is a premium rail. Operators join a deck with a one-time code and fire the same commands.")
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.fog)
                FDPrimaryButton(title: "Unlock team sync") { showPaywall = true }
            } else if let deck = decks.selectedDeck {
                if deck.ownerId == app.userId {
                    FDGhostButton(title: "Issue invite code", systemImage: "person.badge.plus") {
                        Task { await controller.createInvite(deck: deck) }
                    }
                    if let invite = controller.invite {
                        MetalCard {
                            VStack(alignment: .leading, spacing: 8) {
                                FDSectionLabel(text: "Invite code")
                                Text(invite.code)
                                    .font(FDFont.mono(28, weight: .bold))
                                    .foregroundStyle(theme.brass)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                FDField(title: "Join a deck", text: $controller.joinCode, placeholder: "A7K2Q9LM", autocapitalization: .characters)
                FDPrimaryButton(title: "Join", isLoading: controller.isWorking) {
                    Task {
                        await controller.join(
                            userId: app.userId ?? "",
                            displayName: app.profile?.displayName ?? "Operator",
                            email: app.profile?.email ?? ""
                        )
                    }
                }
                if let error = controller.errorMessage {
                    Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
                } else if let notice = controller.notice {
                    Text(notice).font(FDFont.ui(13)).foregroundStyle(theme.moss)
                }
                ForEach(controller.members) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.displayName)
                                .font(FDFont.ui(15, weight: .medium))
                                .foregroundStyle(theme.bone)
                            Text(member.email)
                                .font(FDFont.mono(12))
                                .foregroundStyle(theme.fog)
                        }
                        Spacer()
                        if deck.ownerId == app.userId {
                            Button("Remove") { Task { await controller.remove(member) } }
                                .font(FDFont.ui(13))
                                .foregroundStyle(theme.rust)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .onAppear {
            if let deck = decks.selectedDeck {
                controller.start(ownerId: deck.ownerId, deckId: deck.id)
            }
        }
    }
}
