import SwiftUI

/// One command on the pad.
///
/// The key carries four independent pieces of information and each gets its own
/// channel, because collapsing them is what made the old pad unreadable:
///
/// - **What it does** — the label, always the loudest thing on the key.
/// - **Where it goes** — the host, always visible. A control that fires at
///   production must never hide its target, and it used to be overwritten by
///   the run status.
/// - **Whether it is dangerous** — a standing property of the command. Shown as
///   a permanent amber rail and caution mark, never as colour that comes and
///   goes with the last result.
/// - **How the last run went** — a footer with the status code and round trip.
///   It fades to neutral after ten minutes so an old success stops reading as
///   live state.
struct CommandKey: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let label: String
    let iconName: String
    var destination: String = ""
    var outcome: FDRunOutcome = FDRunOutcome(status: .idle, statusCode: nil, durationMs: 0, at: nil)
    var isRunning: Bool = false
    var requiresConfirmation: Bool = false
    /// No endpoint stored yet. The key is shown but never fires.
    var needsArming: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    private var isDangerous: Bool { requiresConfirmation && !needsArming }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: FDSpace.snug)
                title
                footer
                    // Reserved whether or not this key has run, so the titles
                    // in a row sit on the same baseline instead of drifting
                    // with each key's history.
                    .frame(height: 30, alignment: .topLeading)
            }
            .padding(FDSpace.base)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(keyBackground)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.key, style: .continuous))
            .overlay(alignment: .leading) { dangerRail }
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.key, style: .continuous))
            .overlay(keyStroke)
            .animation(FDMotion.snappy, value: isRunning)
        }
        .buttonStyle(FDPressStyle(depth: 4))
        .disabled(disabled || isRunning)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Rows

    private var header: some View {
        HStack(alignment: .top, spacing: FDSpace.tight) {
            icon
            Spacer(minLength: 0)
            if needsArming {
                HStack(spacing: 3) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("SET UP")
                        .font(FDFont.micro(9))
                        .tracking(0.8)
                }
                .foregroundStyle(theme.brass)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.brass.opacity(0.14), in: Capsule())
                .accessibilityHidden(true)
            } else if isDangerous {
                // A word, not just a glyph: "why is this one orange" should not
                // need a legend.
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("CONFIRM")
                        .font(FDFont.micro(9))
                        .tracking(0.8)
                }
                .foregroundStyle(theme.warning)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.warning.opacity(0.14), in: Capsule())
                .accessibilityHidden(true)
            }
        }
    }

    private var title: some View {
        Text(label)
            .font(FDFont.ui(15, weight: .semibold))
            .foregroundStyle(theme.bone)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var footer: some View {
        if needsArming {
            Text("Add your webhook to arm this")
                .font(FDFont.ui(11))
                .foregroundStyle(theme.fog)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, FDSpace.hair + 2)
        } else if isRunning {
            HStack(spacing: 5) {
                Text("In flight")
                    .font(FDFont.micro(10))
                    .tracking(0.6)
                    .foregroundStyle(theme.brass)
                Spacer(minLength: 0)
            }
            .padding(.top, FDSpace.hair + 2)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if !destination.isEmpty {
                    Text(destination)
                        .font(FDFont.mono(10))
                        .foregroundStyle(theme.fog)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if outcome.hasRun {
                    HStack(spacing: 5) {
                        Image(systemName: outcome.status.symbolName)
                            .font(.system(size: 9, weight: .bold))
                        Text(outcome.codeText)
                            .font(FDFont.mono(10, weight: .medium))
                        if !outcome.durationText.isEmpty {
                            Text("· \(outcome.durationText)")
                                .font(FDFont.mono(10))
                                .foregroundStyle(theme.fog)
                        }
                    }
                    .foregroundStyle(outcomeTint)
                    .lineLimit(1)
                }
            }
            .padding(.top, FDSpace.hair + 2)
        }
    }

    // MARK: - Parts

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.inset)
                .frame(width: 40, height: 40)
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint)
                .opacity(isRunning ? 0.3 : (needsArming ? 0.5 : 1))
            if isRunning {
                if reduceMotion {
                    // No spinner under Reduce Motion — a static ring plus the
                    // "In flight" line still says the request is out.
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(theme.brass, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .frame(width: 36, height: 36)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let turn = timeline.date.timeIntervalSinceReferenceDate * 1.7
                        Circle()
                            .trim(from: 0, to: 0.28)
                            .stroke(theme.brass, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(turn * 360))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var iconTint: Color {
        if isRunning { return theme.brass }
        if needsArming { return theme.fog }
        return isDangerous ? theme.warning : theme.chrome
    }

    /// A 3pt bar down the leading edge. Danger is a property of the command, so
    /// unlike the outcome colours this never changes or decays.
    @ViewBuilder
    private var dangerRail: some View {
        if isDangerous {
            Rectangle()
                .fill(theme.warning.opacity(0.85))
                .frame(width: 3)
                .accessibilityHidden(true)
        }
    }

    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: FDRadius.key, style: .continuous)
            .fill(theme.raised)
            .overlay {
                if isRunning {
                    RoundedRectangle(cornerRadius: FDRadius.key, style: .continuous)
                        .fill(theme.brass.opacity(0.09))
                }
            }
    }

    private var keyStroke: some View {
        RoundedRectangle(cornerRadius: FDRadius.key, style: .continuous)
            .stroke(strokeColor, lineWidth: isRunning ? 1.4 : 1)
    }

    /// Only in-flight and a *fresh* failure earn a coloured edge. A success from
    /// an hour ago is history, and lighting the whole pad green for it made the
    /// pad look like a live status board it is not.
    private var strokeColor: Color {
        if isRunning { return theme.brass.opacity(0.75) }
        if needsArming { return theme.brass.opacity(0.35) }
        if outcome.isRecent, outcome.status == .failed || outcome.status == .blocked {
            return theme.rust.opacity(0.6)
        }
        if isDangerous { return theme.warning.opacity(0.28) }
        return theme.hairline
    }

    /// The outcome text keeps its status colour however old it is — "this
    /// command failed last time" stays true, and greying it out made a red 500
    /// read as ordinary metadata. Only the key's border decays, because that is
    /// the part claiming something is wrong *right now*.
    private var outcomeTint: Color {
        outcome.status.tint(theme)
    }

    // MARK: - Accessibility

    private var hint: String {
        if needsArming { return "Opens the editor so you can add its webhook" }
        return isDangerous ? "Asks you to confirm before it runs" : "Runs straight away"
    }

    private var accessibilityLabel: String {
        var parts = [label]
        if isDangerous { parts.append("production action") }
        if !destination.isEmpty { parts.append("calls \(destination)") }
        return parts.joined(separator: ", ")
    }

    private var accessibilityValue: String {
        if needsArming { return "Not set up yet" }
        if isRunning { return "In flight" }
        guard outcome.hasRun else { return "Not run yet" }
        var value = "Last run \(outcome.status.plainTitle)"
        if let code = outcome.statusCode { value += ", HTTP \(code)" }
        if !outcome.durationText.isEmpty { value += ", took \(outcome.durationText)" }
        return value
    }
}
