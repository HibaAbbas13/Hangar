import SwiftUI

struct DeckHomeView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Binding var showPaywall: Bool
    @ObservedObject var console: ConsoleController
    @State private var showEditor = false
    @State private var showButtonEditor = false
    @State private var editingButton: DeckButton?
    @State private var showDeckSettings = false

    var body: some View {
        NavigationStack {
            FDScreen {
                if decks.isSeeding {
                    seeding
                } else if decks.decks.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: FDSpace.section) {
                            header
                            ServiceSwitcher(
                                decks: decks.decks,
                                selectedId: decks.selectedDeckId,
                                onSelect: { decks.select($0) },
                                onAdd: openNewDeck,
                                onEdit: { showDeckSettings = true },
                                onAddStarter: decks.hasLiveExample ? nil : {
                                    Task { await decks.installLiveExample(isPremium: app.isPremium) }
                                }
                            )
                            .tutorialAnchor(.deck)
                            commandPad
                                .tutorialAnchor(.pad)
                            recentRuns
                        }
                        .padding(.horizontal, FDSpace.gutter)
                        .padding(.top, FDSpace.tight)
                        .padding(.bottom, FDChromeInset.bottom)
                    }
                    .fdScrollEdges(top: true)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditor) {
                DeckEditorView(existing: nil)
            }
            .sheet(isPresented: $showDeckSettings) {
                if let deck = decks.selectedDeck {
                    DeckEditorView(existing: deck)
                }
            }
            .sheet(item: $editingButton) { button in
                ButtonEditorView(existing: button)
            }
            .sheet(isPresented: $showButtonEditor) {
                ButtonEditorView(existing: nil)
            }
            .sheet(item: $decks.buttonNeedingSecret) { button in
                ButtonEditorView(existing: button)
            }
            .sheet(item: $decks.pendingTrigger) { pending in
                ConfirmRunSheet(
                    deck: pending.deck,
                    button: pending.button,
                    onConfirm: {
                        decks.confirmPending(premium: app.isPremium, executionMode: app.executionMode)
                    },
                    onCancel: { decks.pendingTrigger = nil }
                )
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.panel)
            }
        }
    }

    private var seeding: some View {
        VStack(spacing: FDSpace.base) {
            ProgressView()
                .tint(theme.brass)
            Text("Setting up your pad")
                .font(FDFont.ui(15, weight: .medium))
                .foregroundStyle(theme.fog)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Setting up your pad")
    }

    /// The service is the subject of this screen, so it is the headline. It used
    /// to be 13pt grey under a greeting set in 26pt serif, which told a first-time
    /// user the time of day and nothing about what the app controls.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: FDSpace.snug) {
            VStack(alignment: .leading, spacing: FDSpace.hair) {
                Text(app.isPremium ? "HANGAR" : "HANGAR · FREE")
                    .font(FDFont.micro(10))
                    .tracking(3)
                    .foregroundStyle(theme.fog)
                Text(decks.selectedDeck?.name ?? "Hangar")
                    .font(FDFont.display(30))
                    .foregroundStyle(theme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: FDSpace.tight)
            if let deck = decks.selectedDeck {
                DeckHealthPill(deck: deck, buttons: decks.buttons)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: FDSpace.base) {
                FDEmptyState(
                    symbol: "square.stack.3d.up",
                    title: "Connect your first service",
                    message: "A service holds the commands for one place you ship to — Vercel, GitHub, Netlify, Supabase, or anything that accepts a webhook.",
                    actionTitle: "Add a service",
                    expands: false
                ) {
                    openNewDeck()
                }
                VStack(spacing: FDSpace.tight) {
                    FDGhostButton(title: "Load the therango pad", systemImage: "play.circle") {
                        Task { await decks.installSampleFleet() }
                    }
                    Text("Live health checks against therango.co and its GitHub repo. Read-only until you add a deploy hook.")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                        .multilineTextAlignment(.center)
                    if !decks.hasLiveExample {
                        Button("Load the therango example") {
                            Task { await decks.installLiveExample(isPremium: app.isPremium) }
                        }
                        .font(FDFont.ui(13, weight: .medium))
                        .foregroundStyle(theme.fog)
                        .padding(.top, FDSpace.hair)
                    }
                }
                .padding(.horizontal, FDSpace.major)
                .padding(.top, FDSpace.tight)
            }
            .padding(.vertical, FDSpace.major)
            .padding(.bottom, FDChromeInset.bottom)
        }
    }

    private var commandPad: some View {
        VStack(alignment: .leading, spacing: FDSpace.snug) {
            HStack(alignment: .firstTextBaseline) {
                Text("Commands")
                    .font(FDFont.ui(17, weight: .semibold))
                    .foregroundStyle(theme.bone)
                if !app.isPremium, !decks.buttons.isEmpty {
                    Text("\(decks.buttons.count)/\(Constants.Limits.freeButtonCount)")
                        .font(FDFont.mono(11))
                        .foregroundStyle(theme.fog)
                        .accessibilityLabel("\(decks.buttons.count) of \(Constants.Limits.freeButtonCount) free commands used")
                }
                Spacer()
                Button(action: openNewButton) {
                    Label("Add", systemImage: "plus")
                        .font(FDFont.ui(14, weight: .semibold))
                        .foregroundStyle(theme.brass)
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Add a command")
            }
            if decks.buttons.isEmpty {
                padEmptyState
            } else {
                CommandPadGrid(
                    buttons: decks.buttons,
                    triggeringIds: decks.triggeringIds,
                    onTrigger: { button in
                        decks.requestTrigger(
                            button: button,
                            premium: app.isPremium,
                            executionMode: app.executionMode
                        )
                    },
                    onEdit: { editingButton = $0 },
                    onDelete: { button in
                        Task { await decks.deleteButton(button) }
                    }
                )
            }
        }
    }

    private var padEmptyState: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: FDSpace.snug) {
                Text("This service has no commands")
                    .font(FDFont.ui(15, weight: .semibold))
                    .foregroundStyle(theme.bone)
                Text("A command is one webhook — a deploy hook, a rollback, a health check. Add one, or start from a \(decks.selectedDeck?.provider.displayName ?? "provider") template.")
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: openNewButton) {
                    Label("Add a command", systemImage: "plus")
                        .font(FDFont.ui(14, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
            }
        }
    }

    /// The last few runs, inline.
    ///
    /// The pad on its own left most of the screen empty, and the Console — the
    /// thing that makes the app trustworthy — was a tab away and easy to miss.
    /// Three rows here fill the space with the only content that belongs on
    /// this screen and point at the tab for the rest.
    @ViewBuilder
    private var recentRuns: some View {
        let events = Array(
            console.events
                .filter { $0.deckId == decks.selectedDeckId }
                .prefix(3)
        )
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: FDSpace.snug) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent runs")
                        .font(FDFont.ui(17, weight: .semibold))
                        .foregroundStyle(theme.bone)
                    Spacer()
                    Button("Open Console") { app.selectedTab = .console }
                        .font(FDFont.ui(14, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { FDHairline() }
                        RecentRunRow(event: event)
                    }
                }
                .padding(.horizontal, FDSpace.snug)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: FDRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FDRadius.card, style: .continuous)
                        .stroke(theme.hairline, lineWidth: 1)
                )
            }
        }
    }

    private func openNewDeck() {
        if decks.canCreateDeck(isPremium: app.isPremium) {
            showEditor = true
        } else {
            showPaywall = true
        }
    }

    private func openNewButton() {
        if decks.canCreateButton(isPremium: app.isPremium) {
            showButtonEditor = true
        } else {
            showPaywall = true
        }
    }
}

private struct RecentRunRow: View {
    @Environment(\.fdTheme) private var theme
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: FDSpace.snug) {
            Image(systemName: event.status.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(event.status.tint(theme))
                .frame(width: 16)
            Text(event.buttonLabel)
                .font(FDFont.ui(14))
                .foregroundStyle(theme.bone)
                .lineLimit(1)
            Spacer(minLength: FDSpace.tight)
            if let code = event.statusCode {
                Text("\(code)")
                    .font(FDFont.mono(12, weight: .medium))
                    .foregroundStyle(event.status.tint(theme))
            }
            Text(FDRunOutcome.relative(event.createdAt))
                .font(FDFont.mono(10))
                .foregroundStyle(theme.fog)
        }
        .frame(height: 42)
        .accessibilityElement(children: .combine)
    }
}

/// The one-glance answer to "is this service healthy right now".
///
/// It reads from the commands already on screen rather than adding a fetch, and
/// it says nothing at all until something has actually run — a health badge
/// that is green before you have used the app is a lie.
struct DeckHealthPill: View {
    @Environment(\.fdTheme) private var theme
    let deck: Deck
    let buttons: [DeckButton]

    private var lastRun: DeckButton? {
        buttons.filter { $0.lastTriggered != nil }
            .max { ($0.lastTriggered ?? .distantPast) < ($1.lastTriggered ?? .distantPast) }
    }

    private var failing: Int {
        buttons.filter { $0.lastStatus == .failed || $0.lastStatus == .blocked }.count
    }

    var body: some View {
        if let last = lastRun, let at = last.lastTriggered {
            let ok = failing == 0
            HStack(spacing: 5) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(ok ? "All clear" : "\(failing) failing")
                        .font(FDFont.micro(10))
                        .tracking(0.6)
                    Text(FDRunOutcome.relative(at))
                        .font(FDFont.mono(9))
                        .foregroundStyle(theme.fog)
                }
            }
            .foregroundStyle(ok ? theme.moss : theme.rust)
            .padding(.horizontal, FDSpace.tight)
            .padding(.vertical, 6)
            .background((ok ? theme.moss : theme.rust).opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke((ok ? theme.moss : theme.rust).opacity(0.3), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ok
                ? "All commands healthy. Last run \(FDRunOutcome.relative(at))."
                : "\(failing) commands failing. Last run \(FDRunOutcome.relative(at)).")
        }
    }
}
