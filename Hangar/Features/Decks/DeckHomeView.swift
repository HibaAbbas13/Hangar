import SwiftUI

struct DeckHomeView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Binding var showPaywall: Bool
    @StateObject private var motion = MotionParallax()
    @State private var showEditor = false
    @State private var showButtonEditor = false
    @State private var editingButton: DeckButton?
    @State private var showDeckSettings = false

    var body: some View {
        NavigationStack {
            FDScreen {
                if decks.isSeeding {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(theme.brass)
                        Text("Arming sample pad")
                            .font(FDFont.ui(15, weight: .medium))
                            .foregroundStyle(theme.fog)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if decks.decks.isEmpty {
                    VStack(spacing: 16) {
                        FDEmptyState(
                            symbol: "square.stack.3d.up",
                            title: "Commission a deck",
                            message: "A deck is one service surface — Vercel, GitHub, Netlify, Supabase, or a custom hook wall.",
                            actionTitle: "New deck",
                            expands: false
                        ) {
                            openNewDeck()
                        }
                        FDGhostButton(title: "Load sample pad") {
                            Task { await decks.installSampleFleet() }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            header
                            deckPager
                            commandPad
                            recentStrip
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
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
            .sheet(item: $decks.pendingTrigger) { pending in
                ConfirmSheet(
                    title: pending.button.label,
                    message: "This fires \(pending.deck.name) immediately through your configured webhook.",
                    confirmTitle: "Execute now",
                    onConfirm: {
                        decks.confirmPending(premium: app.isPremium, executionMode: app.executionMode)
                    },
                    onCancel: { decks.pendingTrigger = nil }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .top) {
                if let toast = decks.toast {
                    Text(toast)
                        .font(FDFont.ui(13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(theme.hairline, lineWidth: 0.8))
                        .padding(.top, 8)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                                decks.toast = nil
                            }
                        }
                }
            }
        }
        .onAppear { if !app.reducedMotion { motion.start() } }
        .onDisappear { motion.stop() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HANGAR")
                    .font(FDFont.micro(11))
                    .tracking(3.2)
                    .foregroundStyle(theme.fog)
                Text(Greeting.line(name: app.profile?.firstName ?? "operator"))
                    .font(FDFont.display(28))
                    .foregroundStyle(theme.bone)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            Spacer(minLength: 12)
            FDBadge.tier(isPremium: app.isPremium)
        }
    }

    private var deckPager: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FDSectionLabel(text: "Active surface")
                Spacer()
                FDIconButton(systemImage: "plus", label: "New deck", action: openNewDeck)
            }
            TabView(selection: Binding(
                get: { decks.selectedDeckId ?? decks.decks.first?.id ?? "" },
                set: { id in
                    if let deck = decks.decks.first(where: { $0.id == id }) {
                        decks.select(deck)
                    }
                }
            )) {
                ForEach(decks.decks) { deck in
                    DeckHeroCard(deck: deck) {
                        showDeckSettings = true
                    }
                    .fdParallax(pitch: motion.pitch, roll: motion.roll, enabled: !app.reducedMotion)
                    .padding(.horizontal, 2)
                    .tag(deck.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 156)
            if decks.decks.count > 1 {
                HStack(spacing: 6) {
                    ForEach(decks.decks) { deck in
                        Capsule()
                            .fill(deck.id == decks.selectedDeckId ? theme.brass : theme.hairline)
                            .frame(width: deck.id == decks.selectedDeckId ? 16 : 6, height: 4)
                    }
                }
            }
        }
    }

    private var commandPad: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FDSectionLabel(text: "Command pad")
                Spacer()
                Button("Add", action: openNewButton)
                    .font(FDFont.micro(11))
                    .foregroundStyle(theme.brass)
            }
            if decks.buttons.isEmpty {
                MetalCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "plus.square.dashed")
                                .foregroundStyle(theme.brass)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No commands yet")
                                    .font(FDFont.ui(15, weight: .semibold))
                                    .foregroundStyle(theme.bone)
                                Text("Bind a webhook, or load the sample pad.")
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(theme.fog)
                            }
                        }
                        Button("Load sample pad") {
                            Task { await decks.installSampleFleet() }
                        }
                        .font(FDFont.ui(13, weight: .semibold))
                        .foregroundStyle(theme.brass)
                    }
                }
                .onTapGesture { openNewButton() }
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

    private var recentStrip: some View {
        Group {
            if let error = decks.lastError {
                Text(error)
                    .font(FDFont.ui(13))
                    .foregroundStyle(theme.rust)
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

struct DeckHeroCard: View {
    @Environment(\.fdTheme) private var theme
    let deck: Deck
    let onEdit: () -> Void

    var body: some View {
        MetalCard(padded: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: deck.iconName)
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(theme.brass)
                            .frame(width: 36, height: 36)
                            .background(theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deck.provider.shortCallsign)
                                .font(FDFont.micro(10))
                                .tracking(1.4)
                                .foregroundStyle(theme.fog)
                            Text(deck.name)
                                .font(FDFont.ui(18, weight: .semibold))
                                .foregroundStyle(theme.bone)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(theme.fog)
                    }
                }
                HStack {
                    FDBadge(text: deck.isActive ? "Live" : "Hold", tone: deck.isActive ? .moss : .fog)
                    if deck.isShared {
                        FDBadge(text: "Shared", tone: .brass)
                    }
                    Spacer()
                    if let last = deck.lastTriggeredAt {
                        Text(last, style: .relative)
                            .font(FDFont.mono(11))
                            .foregroundStyle(theme.fog)
                    }
                }
            }
            .padding(18)
        }
    }
}
