import SwiftUI

struct AutomationsView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Binding var showPaywall: Bool
    @StateObject private var controller = AutomationController()
    @State private var editing: ExecutionProfile?

    var body: some View {
        NavigationStack {
            FDScreen {
                VStack(alignment: .leading, spacing: 8) {
                    FDPageHeader(eyebrow: "Flows", title: "Execution profiles") {
                        FDIconButton(systemImage: "plus", label: "New flow") {
                            guard app.isPremium else { showPaywall = true; return }
                            if let deck = decks.selectedDeck {
                                editing = ExecutionProfile.make(name: "Nightly rollback chain", deckId: deck.id)
                            }
                        }
                    }
                    if !app.isPremium {
                        premiumCard
                        Spacer()
                    } else if let deck = decks.selectedDeck {
                        if let error = controller.errorMessage {
                            Text(error)
                                .font(FDFont.ui(13))
                                .foregroundStyle(theme.rust)
                                .padding(.horizontal, 20)
                        } else if let notice = controller.notice {
                            Text(notice)
                                .font(FDFont.ui(13))
                                .foregroundStyle(theme.moss)
                                .padding(.horizontal, 20)
                        }
                        profileList(deck)
                    } else {
                        FDEmptyState(
                            symbol: "arrow.triangle.branch",
                            title: "No active deck",
                            message: "Commission a deck before chaining commands."
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { profile in
                if decks.selectedDeck != nil {
                    ProfileEditorView(profile: profile, buttons: decks.buttons) { saved in
                        Task { await controller.save(saved) }
                    }
                }
            }
            .onChange(of: decks.selectedDeckId) { _, _ in
                if let deck = decks.selectedDeck {
                    controller.start(ownerId: deck.ownerId, deckId: deck.id)
                }
            }
            .onAppear {
                if let deck = decks.selectedDeck {
                    controller.start(ownerId: deck.ownerId, deckId: deck.id)
                }
            }
        }
    }

    private var premiumCard: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Premium sequence rails")
                    .font(FDFont.display(22))
                    .foregroundStyle(theme.bone)
                Text("Chain rollback → health ping → notify. Runs through the same encrypted proxy as a single command.")
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.fog)
                FDPrimaryButton(title: "Unlock flows") { showPaywall = true }
            }
        }
        .padding(.horizontal, 20)
    }

    private func profileList(_ deck: Deck) -> some View {
        Group {
            if controller.profiles.isEmpty {
                FDEmptyState(
                    symbol: "arrow.triangle.branch",
                    title: "No flows yet",
                    message: "Chain commands with dwell time between each fire — rollback, then ping, then notify.",
                    actionTitle: "New flow"
                ) {
                    editing = ExecutionProfile.make(name: "Release chain", deckId: deck.id)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(controller.profiles) { profile in
                            MetalCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(profile.name)
                                            .font(FDFont.ui(17, weight: .semibold))
                                            .foregroundStyle(theme.bone)
                                        Spacer()
                                        FDBadge(text: "\(profile.steps.count) steps", tone: .fog)
                                    }
                                    Text(profile.steps.map { stepName($0) }.joined(separator: "  →  "))
                                        .font(FDFont.mono(12))
                                        .foregroundStyle(theme.fog)
                                        .lineLimit(2)
                                    HStack {
                                        Button("Run") {
                                            Task {
                                                await controller.run(
                                                    profile,
                                                    mode: app.executionMode,
                                                    buttons: decks.buttons,
                                                    deck: deck
                                                )
                                            }
                                        }
                                        .font(FDFont.ui(13, weight: .semibold))
                                        .foregroundStyle(theme.void)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(theme.brass, in: Capsule())
                                        Button("Edit") { editing = profile }
                                            .font(FDFont.ui(13, weight: .medium))
                                            .foregroundStyle(theme.brass)
                                        Spacer()
                                        Button("Delete", role: .destructive) {
                                            Task { await controller.delete(profile) }
                                        }
                                        .font(FDFont.ui(13))
                                        .foregroundStyle(theme.rust)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func stepName(_ step: ExecutionStep) -> String {
        decks.buttons.first { $0.id == step.buttonId }?.label ?? "Command"
    }
}

struct ProfileEditorView: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var profile: ExecutionProfile
    let buttons: [DeckButton]
    let onSave: (ExecutionProfile) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                FDScreenBackground(brassGlow: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        FDField(title: "Flow name", text: $profile.name, placeholder: "Release chain")
                        FDSectionLabel(text: "Steps")
                        ForEach($profile.steps) { $step in
                            MetalCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Picker("Command", selection: $step.buttonId) {
                                        ForEach(buttons) { button in
                                            Text(button.label).tag(button.id)
                                        }
                                    }
                                    Stepper("Dwell \(step.delaySeconds)s", value: $step.delaySeconds, in: 0...120)
                                        .foregroundStyle(theme.bone)
                                }
                            }
                        }
                        FDGhostButton(title: "Add step", systemImage: "plus") {
                            if let first = buttons.first {
                                profile.steps.append(.make(buttonId: first.id, delaySeconds: 5))
                            }
                        }
                        FDPrimaryButton(title: "Save flow") {
                            onSave(profile)
                            dismiss()
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Edit flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
