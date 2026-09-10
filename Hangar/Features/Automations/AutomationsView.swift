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
                VStack(alignment: .leading, spacing: FDSpace.base) {
                    FDPageHeader(eyebrow: "Flows", title: flowTitle) {
                        if app.isPremium, decks.selectedDeck != nil {
                            FDIconButton(systemImage: "plus", label: "New flow") {
                                if let deck = decks.selectedDeck {
                                    editing = ExecutionProfile.make(name: "Release chain", deckId: deck.id)
                                }
                            }
                        }
                    }
                    content
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
            .onChange(of: decks.selectedDeckId) { _, _ in startController() }
            .onAppear { startController() }
        }
    }

    private var flowTitle: String {
        guard let deck = decks.selectedDeck else { return "Flows" }
        return deck.name
    }

    @ViewBuilder
    private var content: some View {
        if !app.isPremium {
            ScrollView(showsIndicators: false) {
                premiumPitch
                    .padding(.horizontal, FDSpace.gutter)
                    .padding(.bottom, FDChromeInset.bottom)
            }
        } else if let deck = decks.selectedDeck {
            VStack(alignment: .leading, spacing: FDSpace.snug) {
                if let error = controller.errorMessage {
                    banner(error, tone: theme.rust, symbol: "exclamationmark.triangle.fill")
                } else if let notice = controller.notice {
                    banner(notice, tone: theme.moss, symbol: "checkmark.circle.fill")
                }
                profileList(deck)
            }
        } else {
            FDEmptyState(
                symbol: "square.stack.3d.up",
                title: "No service selected",
                message: "A flow runs commands from one service in order. Add a service first."
            )
        }
    }

    private func banner(_ text: String, tone: Color, symbol: String) -> some View {
        HStack(alignment: .top, spacing: FDSpace.tight) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(FDFont.ui(13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tone)
        .padding(FDSpace.snug)
        .background(tone.opacity(0.1), in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
        .padding(.horizontal, FDSpace.gutter)
        .accessibilityElement(children: .combine)
    }

    /// The pitch has to answer "what would I use this for" before it asks for
    /// money, so it shows a real chain rather than describing one.
    private var premiumPitch: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: FDSpace.base) {
                FDBadge(text: "Premium", tone: .brass)
                Text("One press. Several commands, in order.")
                    .font(FDFont.display(24))
                    .foregroundStyle(theme.bone)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A rollback is rarely one request. Chain the commands you already have, put a wait between them, and run the whole thing from one button — or from Siri.")
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)

                FlowChain(steps: [
                    .init(title: "Roll back production", detail: "POST"),
                    .init(title: "Wait 30 seconds", detail: nil, isWait: true),
                    .init(title: "Health ping", detail: "GET"),
                    .init(title: "Notify #incidents", detail: "POST")
                ])
                .padding(.vertical, FDSpace.hair)
                .accessibilityLabel("Example flow: roll back production, wait 30 seconds, health ping, then notify the incidents channel")

                FDPrimaryButton(title: "See Premium") { showPaywall = true }
            }
        }
    }

    private func profileList(_ deck: Deck) -> some View {
        Group {
            if controller.profiles.isEmpty {
                FDEmptyState(
                    symbol: "arrow.triangle.branch",
                    title: "No flows yet",
                    message: "Chain the commands on \(deck.name) so one press runs them in order — roll back, wait, health check, notify.",
                    actionTitle: decks.buttons.isEmpty ? nil : "Build a flow"
                ) {
                    editing = ExecutionProfile.make(name: "Release chain", deckId: deck.id)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: FDSpace.snug) {
                        ForEach(controller.profiles) { profile in
                            FlowCard(
                                profile: profile,
                                buttons: decks.buttons,
                                isRunning: controller.isRunning,
                                onRun: {
                                    Task {
                                        await controller.run(
                                            profile,
                                            mode: app.executionMode,
                                            buttons: decks.buttons,
                                            deck: deck
                                        )
                                    }
                                },
                                onEdit: { editing = profile },
                                onDelete: { Task { await controller.delete(profile) } }
                            )
                        }
                    }
                    .padding(.horizontal, FDSpace.gutter)
                    .padding(.bottom, FDChromeInset.bottom)
                }
                .fdScrollEdges()
            }
        }
    }

    private func startController() {
        controller.bind(userId: app.userId ?? "")
        if let deck = decks.selectedDeck {
            controller.start(ownerId: deck.ownerId, deckId: deck.id)
        }
    }
}

// MARK: - Flow chain

/// The vertical "A → wait → B → C" diagram.
///
/// The steps used to be a single mono line joined with arrows and clipped at two
/// lines, which meant a four-step flow showed two steps and an ellipsis. Drawing
/// the chain costs the same space and actually communicates the order.
struct FlowChain: View {
    @Environment(\.fdTheme) private var theme

    struct Step: Identifiable {
        let id = UUID()
        var title: String
        var detail: String?
        var isWait: Bool = false
    }

    let steps: [Step]
    var limit: Int = 5

    private var shown: [Step] { Array(steps.prefix(limit)) }
    private var overflow: Int { max(0, steps.count - limit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .center, spacing: FDSpace.snug) {
                    marker(step)
                    HStack(spacing: FDSpace.tight) {
                        Text(step.title)
                            .font(FDFont.ui(13, weight: step.isWait ? .regular : .medium))
                            .foregroundStyle(step.isWait ? theme.fog : theme.bone)
                            .lineLimit(1)
                        if let detail = step.detail {
                            Text(detail)
                                .font(FDFont.mono(10, weight: .medium))
                                .foregroundStyle(theme.fog)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 26)

                if index < shown.count - 1 || overflow > 0 {
                    // The rail lines up with the centre of the markers above
                    // and below it.
                    HStack(spacing: FDSpace.snug) {
                        Rectangle()
                            .fill(theme.hairline)
                            .frame(width: 1.5, height: 12)
                            .frame(width: 18)
                        Spacer(minLength: 0)
                    }
                }
            }
            if overflow > 0 {
                HStack(spacing: FDSpace.snug) {
                    Text("+\(overflow)")
                        .font(FDFont.mono(10, weight: .medium))
                        .foregroundStyle(theme.fog)
                        .frame(width: 18)
                    Text(overflow == 1 ? "one more step" : "\(overflow) more steps")
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func marker(_ step: Step) -> some View {
        ZStack {
            Circle()
                .fill(step.isWait ? theme.inset : theme.brass.opacity(0.16))
                .frame(width: 18, height: 18)
            if step.isWait {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.fog)
            } else {
                Circle()
                    .fill(theme.brass)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 18)
        .accessibilityHidden(true)
    }
}

// MARK: - Flow card

struct FlowCard: View {
    @Environment(\.fdTheme) private var theme
    let profile: ExecutionProfile
    let buttons: [DeckButton]
    let isRunning: Bool
    let onRun: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var chainSteps: [FlowChain.Step] {
        profile.steps.flatMap { step -> [FlowChain.Step] in
            let button = buttons.first { $0.id == step.buttonId }
            var out: [FlowChain.Step] = []
            if step.delaySeconds > 0 {
                out.append(.init(title: "Wait \(step.delaySeconds)s", detail: nil, isWait: true))
            }
            out.append(.init(
                title: button?.label ?? "Command removed",
                detail: button?.method.rawValue
            ))
            return out
        }
    }

    /// A flow that fires anything needing confirmation is itself a production
    /// action — the card has to say so before the Run button is pressed.
    private var isDangerous: Bool {
        profile.steps.contains { step in
            buttons.first { $0.id == step.buttonId }?.requiresConfirmation == true
        }
    }

    var body: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: FDSpace.snug) {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.name)
                        .font(FDFont.ui(17, weight: .semibold))
                        .foregroundStyle(theme.bone)
                        .lineLimit(1)
                    Spacer(minLength: FDSpace.tight)
                    if isDangerous {
                        FDBadge(text: "Production", tone: .rust)
                    }
                }

                if let lastRun = profile.lastRunAt {
                    Text("Last run \(FDRunOutcome.relative(lastRun))")
                        .font(FDFont.mono(10))
                        .foregroundStyle(theme.fog)
                }

                if profile.steps.isEmpty {
                    Text("No steps yet. Edit this flow to add commands.")
                        .font(FDFont.ui(13))
                        .foregroundStyle(theme.fog)
                } else {
                    FlowChain(steps: chainSteps)
                        .padding(.vertical, FDSpace.hair)
                }

                FDHairline()

                HStack(spacing: FDSpace.base) {
                    Button(action: onRun) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isRunning ? "Running…" : "Run flow")
                                .font(FDFont.ui(14, weight: .semibold))
                        }
                        .foregroundStyle(theme.void)
                        .padding(.horizontal, FDSpace.base)
                        .frame(height: 38)
                        .background(theme.brass, in: Capsule())
                    }
                    .buttonStyle(FDPressStyle(depth: 2))
                    .disabled(isRunning || profile.steps.isEmpty)
                    .opacity(isRunning || profile.steps.isEmpty ? 0.45 : 1)

                    Button("Edit", action: onEdit)
                        .font(FDFont.ui(14, weight: .medium))
                        .foregroundStyle(theme.brass)
                        .frame(height: 38)

                    Spacer()

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.fog)
                            .frame(width: 38, height: 38)
                    }
                    .accessibilityLabel("Delete \(profile.name)")
                }
            }
        }
        .confirmationDialog(
            "Delete “\(profile.name)”?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete flow", role: .destructive, action: onDelete)
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The commands in it are not deleted.")
        }
    }
}

// MARK: - Editor

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
                    VStack(alignment: .leading, spacing: FDSpace.gutter) {
                        FDField(title: "Flow name", text: $profile.name, placeholder: "Release chain")

                        VStack(alignment: .leading, spacing: FDSpace.snug) {
                            HStack {
                                FDSectionLabel(text: "Steps")
                                Spacer()
                                Text("Runs top to bottom")
                                    .font(FDFont.ui(11))
                                    .foregroundStyle(theme.fog)
                            }

                            if runnableButtons.isEmpty {
                                Text(buttons.isEmpty
                                     ? "This service has no commands yet. Add a command before building a flow."
                                     : "None of this service's commands have a webhook yet. Set one up on the pad first.")
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(theme.fog)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            ForEach(Array($profile.steps.enumerated()), id: \.element.id) { index, $step in
                                stepCard(index: index, step: $step)
                            }

                            FDGhostButton(title: "Add step", systemImage: "plus") {
                                if let next = nextSuggestedButton() {
                                    profile.steps.append(.make(buttonId: next.id, delaySeconds: 0))
                                    HapticService.light()
                                }
                            }
                            .disabled(runnableButtons.isEmpty)
                            .opacity(runnableButtons.isEmpty ? 0.45 : 1)
                        }

                        FDPrimaryButton(title: "Save flow") {
                            onSave(profile)
                            HapticService.success()
                            dismiss()
                        }
                        .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(FDSpace.section)
                }
            }
            .navigationTitle(profile.steps.isEmpty ? "New flow" : "Edit flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    /// Steps can only point at commands that can actually run. A step aimed at
    /// a command with no webhook yet would stall the whole flow.
    private var runnableButtons: [DeckButton] {
        buttons.filter { $0.hasSecret }
    }

    /// The next command not already in the flow.
    ///
    /// Every new step used to default to the first command, so building a
    /// three-step chain produced three copies of the same one and three trips
    /// through the picker to fix it. A flow is usually "these commands, in the
    /// order they appear", so that is what adding a step now assumes.
    private func nextSuggestedButton() -> DeckButton? {
        let used = Set(profile.steps.map(\.buttonId))
        return runnableButtons.first { !used.contains($0.id) } ?? runnableButtons.first
    }

    private func stepCard(index: Int, step: Binding<ExecutionStep>) -> some View {
        MetalCard {
            VStack(alignment: .leading, spacing: FDSpace.snug) {
                HStack {
                    Text("STEP \(index + 1)")
                        .font(FDFont.micro(10))
                        .tracking(1.4)
                        .foregroundStyle(theme.fog)
                    Spacer()
                    Button {
                        profile.steps.removeAll { $0.id == step.wrappedValue.id }
                        HapticService.light()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(theme.fog)
                    }
                    .accessibilityLabel("Remove step \(index + 1)")
                }
                Picker("Command", selection: step.buttonId) {
                    ForEach(runnableButtons) { button in
                        Text(button.label).tag(button.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.brass)

                Stepper(value: step.delaySeconds, in: 0...300, step: 5) {
                    Text(step.wrappedValue.delaySeconds == 0
                         ? "Run straight after the previous step"
                         : "Wait \(step.wrappedValue.delaySeconds)s first")
                        .font(FDFont.ui(13))
                        .foregroundStyle(theme.bone)
                }
                .tint(theme.brass)
            }
        }
    }
}
