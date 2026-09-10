import SwiftUI

/// The last thing between a thumb and production.
///
/// A stock alert with "Cancel / OK" is the wrong control here: it is one tap
/// away from the press that opened it, it says nothing about where the request
/// is going, and it looks identical to the alert that asks whether you want to
/// enable notifications. This sheet answers the three questions an operator has
/// before firing at production — *what*, *where*, and *is this reversible* —
/// and then asks for a deliberate press-and-hold rather than a tap.
struct ConfirmRunSheet: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let deck: Deck
    let button: DeckButton
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var holdProgress: Double = 0
    @State private var holdTask: Task<Void, Never>?
    @State private var didFire = false

    private static let holdDuration: Double = 0.9

    private var host: String {
        button.host.isEmpty ? CommandPadGrid.host(for: button) : button.host
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpace.gutter) {
            eyebrow
            Text(button.label)
                .font(FDFont.display(28))
                .foregroundStyle(theme.bone)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            target

            Text("This runs as soon as you let go. Hangar cannot undo it for you.")
                .font(FDFont.ui(14))
                .foregroundStyle(theme.fog)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            confirmControl

            Button(action: onCancel) {
                Text("Cancel")
                    .font(FDFont.ui(16, weight: .medium))
                    .foregroundStyle(theme.fog)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
            }
        }
        .padding(FDSpace.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel)
        .onDisappear { holdTask?.cancel() }
    }

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("PRODUCTION ACTION")
                .font(FDFont.micro(11))
                .tracking(2.2)
        }
        .foregroundStyle(theme.warning)
        .accessibilityLabel("Production action")
    }

    /// Where this is going, spelled out. The method and host are the two facts
    /// that tell an operator whether they are about to hit the right thing.
    private var target: some View {
        VStack(alignment: .leading, spacing: FDSpace.tight) {
            HStack(spacing: FDSpace.tight) {
                Image(systemName: deck.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.brass)
                Text(deck.name)
                    .font(FDFont.ui(14, weight: .semibold))
                    .foregroundStyle(theme.bone)
                Text(deck.provider.displayName)
                    .font(FDFont.micro(10))
                    .foregroundStyle(theme.fog)
            }
            HStack(spacing: FDSpace.tight) {
                Text(button.method.rawValue)
                    .font(FDFont.mono(11, weight: .bold))
                    .foregroundStyle(theme.brass)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.brass.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(host.isEmpty ? "Stored endpoint" : host)
                    .font(FDFont.mono(12))
                    .foregroundStyle(theme.chrome)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(FDSpace.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inset, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Target: \(deck.name), \(deck.provider.displayName). \(button.method.rawValue) to \(host.isEmpty ? "the stored endpoint" : host)")
    }

    @ViewBuilder
    private var confirmControl: some View {
        if voiceOver {
            // Press-and-hold is not a gesture VoiceOver can perform reliably, so
            // that audience gets an ordinary button. The sheet itself is still
            // the confirmation step.
            Button(action: fire) {
                Text("Run \(button.label)")
                    .font(FDFont.ui(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(theme.rust, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
            }
        } else {
            holdButton
        }
    }

    private var holdButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                .fill(theme.rust.opacity(0.22))
            // The fill is the progress indicator — no separate bar to read.
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                    .fill(theme.rust)
                    .frame(width: proxy.size.width * holdProgress)
            }
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))

            HStack(spacing: FDSpace.tight) {
                Image(systemName: holdProgress > 0.99 ? "checkmark" : "hand.tap.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(holdProgress > 0.05 ? "Keep holding…" : "Hold to run")
                    .font(FDFont.ui(16, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .frame(height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                .stroke(theme.rust.opacity(0.7), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
        .accessibilityLabel("Hold to run \(button.label)")
        .accessibilityHint("Press and hold for one second to send the request")
    }

    // MARK: - Hold

    private func startHold() {
        guard holdTask == nil, !didFire else { return }
        HapticService.light()
        let steps = 36
        holdTask = Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(Self.holdDuration / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                withAnimation(reduceMotion ? nil : .linear(duration: Self.holdDuration / Double(steps))) {
                    holdProgress = Double(step) / Double(steps)
                }
                // A tick at the halfway mark so the hold has a felt shape
                // rather than a silent wait followed by a bang.
                if step == steps / 2 { HapticService.light() }
            }
            fire()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        guard !didFire else { return }
        withAnimation(FDMotion.snappy) { holdProgress = 0 }
    }

    private func fire() {
        guard !didFire else { return }
        didFire = true
        HapticService.heavy()
        onConfirm()
    }
}
