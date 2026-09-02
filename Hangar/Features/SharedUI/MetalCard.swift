import SwiftUI

struct MetalCard<Content: View>: View {
    @Environment(\.fdTheme) private var theme
    var cornerRadius: CGFloat = 24
    var padded: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padded ? 18 : 0)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.raised.opacity(0.96),
                                theme.panel
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.16),
                                        theme.hairline.opacity(0.9),
                                        Color.black.opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
            }
    }
}

struct CommandKey: View {
    @Environment(\.fdTheme) private var theme
    let label: String
    let iconName: String
    var status: TriggerStatus = .idle
    var requiresConfirmation: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @State private var pressAmount = 0.0

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.inset)
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(iconColor)
                        .symbolEffect(.bounce, value: status == .succeeded)
                    if status == .running {
                        ProgressView()
                            .tint(theme.warning)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if requiresConfirmation, status != .running {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.warning)
                            .offset(x: 14, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                Text(label)
                    .font(FDFont.ui(13, weight: .medium))
                    .foregroundStyle(theme.bone)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 34, alignment: .top)
            }
            .padding(.top, 16)
            .padding(.bottom, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .top)
            .background(keyBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(keyStroke)
            .shadow(color: .black.opacity(status == .running ? 0.12 : 0.32), radius: status == .running ? 6 : 16, y: status == .running ? 4 : 10)
            .offset(y: status == .running ? 2 : 0)
        }
        .buttonStyle(FDPressStyle(depth: 6))
        .disabled(disabled || status == .running)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(label)
        .accessibilityHint(requiresConfirmation ? "Asks for confirmation before firing" : "")
    }

    private var iconColor: Color {
        switch status {
        case .succeeded: return theme.moss
        case .failed: return theme.rust
        case .running, .queued: return theme.warning
        
        
        default: return theme.chrome
        }
    }

    
    
    private var statusTint: Color? {
        switch status {
        case .succeeded: return theme.moss
        case .failed: return theme.rust
        case .running, .queued: return theme.warning
        default: return nil
        }
    }

    private var keyBackground: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.07),
                theme.raised,
                theme.panel
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var keyStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        statusTint?.opacity(0.55) ?? theme.hairline
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }
}

struct ConfirmSheet: View {
    @Environment(\.fdTheme) private var theme
    let title: String
    let message: String
    let confirmTitle: String
    var isDestructive: Bool = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(theme.hairline)
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.warning)
                .padding(.top, 8)
            Text(title)
                .font(FDFont.display(24))
                .foregroundStyle(theme.bone)
            Text(message)
                .font(FDFont.ui(15))
                .foregroundStyle(theme.fog)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            VStack(spacing: 10) {
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(FDFont.ui(16, weight: .semibold))
                        .foregroundStyle(theme.bone)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(theme.rust.opacity(isDestructive ? 0.9 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button("Hold", action: onCancel)
                    .font(FDFont.ui(15, weight: .medium))
                    .foregroundStyle(theme.fog)
                    .frame(height: 44)
            }
            .padding(.horizontal, 4)
        }
        .padding(22)
        .background(theme.panel)
    }
}
