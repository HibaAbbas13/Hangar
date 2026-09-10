import SwiftUI

/// A three-step guided tour shown once per account, immediately after the
/// first sign-in. It points at the real interface rather than describing it,
/// because the thing people fail to grasp is what a "command" actually is.
enum TutorialStep: Int, CaseIterable, Hashable {
    case deck, pad, console

    var title: String {
        switch self {
        case .deck: return "This is a service"
        case .pad: return "These are your buttons"
        case .console: return "Everything is saved"
        }
    }

    var detail: String {
        switch self {
        case .deck:
            return "One service for each place you ship to. These commands are read-only health checks until you add a deploy hook."
        case .pad:
            return "Each key fires one web request. Press one and watch it turn green. The orange mark means a command asks before it fires."
        case .console:
            return "Every press is saved in History with its status code, how long it took, and what came back — including failures."
        }
    }

    var next: TutorialStep? { TutorialStep(rawValue: rawValue + 1) }
}

@MainActor
final class TutorialController: ObservableObject {
    @Published private(set) var step: TutorialStep?

    private static func key(_ userId: String) -> String { "fd.tutorial.seen.\(userId)" }
    private var userId = ""

    /// Starts the tour the first time an account reaches a populated deck.
    func startIfNeeded(userId: String, hasContent: Bool) {
        guard hasContent, !userId.isEmpty, step == nil else { return }
        guard !UserDefaults.standard.bool(forKey: Self.key(userId)) else { return }
        self.userId = userId
        withAnimation(FDMotion.card) { step = .deck }
    }

    func advance() {
        guard let current = step else { return }
        HapticService.light()
        if let next = current.next {
            withAnimation(FDMotion.card) { step = next }
        } else {
            finish()
        }
    }

    func finish() {
        if !userId.isEmpty {
            UserDefaults.standard.set(true, forKey: Self.key(userId))
        }
        withAnimation(FDMotion.card) { step = nil }
    }
}

// MARK: - Anchors

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TutorialStep: Anchor<CGRect>],
                       nextValue: () -> [TutorialStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as the target of a tutorial step.
    func tutorialAnchor(_ step: TutorialStep) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [step: $0] }
    }
}

// MARK: - Overlay

struct TutorialOverlay: View {
    @Environment(\.fdTheme) private var theme
    @ObservedObject var controller: TutorialController
    let frames: [TutorialStep: CGRect]

    var body: some View {
        if let step = controller.step, let hole = frames[step]?.insetBy(dx: -8, dy: -8) {
            ZStack(alignment: .topLeading) {
                spotlight(hole)
                card(step, hole: hole)
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    /// Dims everything except the step's target.
    private func spotlight(_ hole: CGRect) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.74))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .frame(width: hole.width, height: hole.height)
                    .position(x: hole.midX, y: hole.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { controller.advance() }
    }

    private func card(_ step: TutorialStep, hole: CGRect) -> some View {
        GeometryReader { geo in
            let cardHeight: CGFloat = 210
            let below = hole.maxY + 18
            let fitsBelow = below + cardHeight < geo.size.height
            let y = fitsBelow ? below : max(24, hole.minY - cardHeight - 18)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(TutorialStep.allCases, id: \.rawValue) { dot in
                        Capsule()
                            .fill(dot == step ? theme.brass : theme.hairline)
                            .frame(width: dot == step ? 18 : 6, height: 4)
                    }
                }
                Text(step.title)
                    .font(FDFont.display(24))
                    .foregroundStyle(theme.bone)
                Text(step.detail)
                    .font(FDFont.ui(14.5))
                    .foregroundStyle(theme.fog)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Skip") { controller.finish() }
                        .font(FDFont.ui(14, weight: .medium))
                        .foregroundStyle(theme.fog)
                    Spacer()
                    Button(step.next == nil ? "Got it" : "Next") { controller.advance() }
                        .font(FDFont.ui(15, weight: .semibold))
                        .foregroundStyle(theme.void)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(theme.brass, in: Capsule())
                }
                .padding(.top, 4)
            }
            .padding(18)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
            .padding(.horizontal, 20)
            .offset(y: y)
        }
    }
}
