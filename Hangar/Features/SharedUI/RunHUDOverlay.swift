import SwiftUI

struct RunHUDOverlay: View {
    @Environment(\.fdTheme) private var theme
    @ObservedObject private var hud = RunHUDStore.shared

    var body: some View {
        Group {
            switch hud.phase {
            case .hidden:
                EmptyView()
            case .running(let title, let detail, let startedAt, let fraction):
                card {
                    HStack(spacing: 14) {
                        RunSpinner(fraction: fraction)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(FDFont.ui(15, weight: .semibold))
                                .foregroundStyle(theme.bone)
                                .lineLimit(1)
                            Text(detail)
                                .font(FDFont.ui(12))
                                .foregroundStyle(theme.fog)
                                .lineLimit(2)
                            ElapsedLabel(startedAt: startedAt)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            case .done(let title, let detail, let succeeded, let statusCode, let durationMs):
                card {
                    HStack(spacing: 14) {
                        Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(succeeded ? theme.moss : theme.rust)
                            .symbolEffect(.bounce, value: succeeded)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(FDFont.ui(15, weight: .semibold))
                                .foregroundStyle(theme.bone)
                                .lineLimit(1)
                            Text(detail)
                                .font(FDFont.ui(12))
                                .foregroundStyle(theme.fog)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                if let statusCode {
                                    FDBadge(text: "\(statusCode)", tone: succeeded ? .moss : .rust)
                                }
                                Text(Self.formatDuration(durationMs))
                                    .font(FDFont.mono(11))
                                    .foregroundStyle(theme.fog)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(FDMotion.snappy, value: hud.phase)
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    private static func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms) ms" }
        return String(format: "%.1f s", Double(ms) / 1000)
    }
}

private struct RunSpinner: View {
    @Environment(\.fdTheme) private var theme
    var fraction: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.hairline, lineWidth: 3)
                .frame(width: 36, height: 36)
            if let fraction {
                Circle()
                    .trim(from: 0, to: max(0.06, min(1, fraction)))
                    .stroke(theme.brass, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(FDMotion.card, value: fraction)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let turn = timeline.date.timeIntervalSinceReferenceDate * 1.6
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(theme.brass, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(turn * 360))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ElapsedLabel: View {
    @Environment(\.fdTheme) private var theme
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.1)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            Text(elapsed < 1 ? String(format: "%.1f s", elapsed) : String(format: "%.0f s", elapsed))
                .font(FDFont.mono(11))
                .foregroundStyle(theme.brass)
                .contentTransition(.numericText())
        }
    }
}
