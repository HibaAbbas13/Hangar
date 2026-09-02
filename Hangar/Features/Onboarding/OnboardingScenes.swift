import SwiftUI

struct LoopScene: View {
    @Environment(\.fdTheme) private var theme
    let reduceMotion: Bool

    enum Phase: CaseIterable {
        case rest, press, outbound, land, inbound, settled

        var pressed: Bool { self == .press || self == .outbound }
        
        var dotSide: CGFloat {
            switch self {
            case .rest, .press: return -1
            case .outbound, .land: return 1
            case .inbound: return -1
            case .settled: return -1
            }
        }
        var dotVisible: Bool {
            self == .press || self == .outbound || self == .inbound
        }
        var returning: Bool { self == .inbound }
        var endpointLit: Bool { self == .land || self == .inbound }
        var keySettled: Bool { self == .settled }

        var duration: Double {
            switch self {
            case .rest: return 0.5
            case .press: return 0.25
            case .outbound: return 0.7
            case .land: return 0.3
            case .inbound: return 0.6
            case .settled: return 1.1
            }
        }
    }

    var body: some View {
        Group {
            if reduceMotion {
                diagram(.settled)
            } else {
                diagram(.rest)
                    .phaseAnimator(Phase.allCases) { view, phase in
                        diagram(phase)
                    } animation: { phase in
                        .easeInOut(duration: phase.duration)
                    }
            }
        }
        .frame(height: 190)
    }

    private func diagram(_ phase: Phase) -> some View {
        HStack(spacing: 0) {
            key(phase)
            wire(phase)
            endpoint(phase)
        }
        .frame(maxWidth: 300)
    }

    private func key(_ phase: Phase) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(phase.keySettled ? theme.moss : theme.hairline, lineWidth: 1.4)
                )
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(phase.pressed ? 0.1 : 0.3),
                        radius: phase.pressed ? 4 : 12, y: phase.pressed ? 2 : 7)
            Image(systemName: phase.keySettled ? "checkmark" : "bolt.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(phase.keySettled ? theme.moss : theme.brass)
        }
        .scaleEffect(phase.pressed ? 0.92 : 1)
    }

    private func wire(_ phase: Phase) -> some View {
        ZStack {
            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1.5)
            Circle()
                .fill(phase.returning ? theme.moss : theme.brass)
                .frame(width: 11, height: 11)
                .shadow(color: (phase.returning ? theme.moss : theme.brass).opacity(0.7), radius: 6)
                .offset(x: phase.dotSide * 45)
                .opacity(phase.dotVisible ? 1 : 0)
        }
        .frame(width: 100)
    }

    private func endpoint(_ phase: Phase) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.inset)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(phase.endpointLit ? theme.moss : theme.hairline, lineWidth: 1.2)
                )
                .frame(width: 68, height: 82)
            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { row in
                    Capsule()
                        .fill(phase.endpointLit && row == 1 ? theme.moss : theme.chrome.opacity(0.5))
                        .frame(width: 30, height: 3)
                }
            }
        }
    }
}

struct SurfacesScene: View {
    @Environment(\.fdTheme) private var theme
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                stack(step: 3)
            } else {
                stack(step: 0)
                    .phaseAnimator([0, 1, 2, 3, 3]) { view, step in
                        stack(step: step)
                    } animation: { _ in .spring(response: 0.55, dampingFraction: 0.78) }
            }
        }
        .frame(height: 190)
    }

    private func stack(step: Int) -> some View {
        ZStack {
            surface(index: 0, step: step, symbol: "lock.fill", title: "Lock Screen", y: -52)
            surface(index: 1, step: step, symbol: "square.grid.2x2.fill", title: "Widget", y: 4)
            surface(index: 2, step: step, symbol: "mic.fill", title: "Siri", y: 60)
        }
    }

    private func surface(index: Int, step: Int, symbol: String, title: String, y: CGFloat) -> some View {
        let shown = step > index
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(theme.inset)
                    .frame(width: 38, height: 38)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.brass)
            }
            Text(title)
                .font(FDFont.ui(15, weight: .medium))
                .foregroundStyle(theme.bone)
            Spacer(minLength: 0)
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.moss)
                .opacity(shown ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 244)
        .background(theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .offset(x: shown ? 0 : -26, y: y)
        .opacity(shown ? 1 : 0)
    }
}

struct LogScene: View {
    @Environment(\.fdTheme) private var theme
    let reduceMotion: Bool

    private struct Row {
        let label: String
        let code: String
        let ok: Bool
    }

    private let rows = [
        Row(label: "Health ping", code: "200", ok: true),
        Row(label: "Redeploy production", code: "204", ok: true),
        Row(label: "Purge CDN cache", code: "500", ok: false)
    ]

    var body: some View {
        Group {
            if reduceMotion {
                list(step: 3)
            } else {
                list(step: 0)
                    .phaseAnimator([0, 1, 2, 3, 3]) { view, step in
                        list(step: step)
                    } animation: { _ in .spring(response: 0.5, dampingFraction: 0.8) }
            }
        }
        .frame(height: 190)
    }

    private func list(step: Int) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                let shown = step > index
                HStack(spacing: 10) {
                    Circle()
                        .fill(row.ok ? theme.moss : theme.rust)
                        .frame(width: 7, height: 7)
                    Text(row.label)
                        .font(FDFont.ui(14))
                        .foregroundStyle(theme.bone)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.code)
                        .font(FDFont.mono(13, weight: .medium))
                        .foregroundStyle(row.ok ? theme.moss : theme.rust)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(theme.raised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(row.ok ? theme.hairline : theme.rust.opacity(0.5), lineWidth: 1)
                )
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 14)
            }
        }
        .frame(width: 268)
    }
}
