import SwiftUI

struct FDScreenBackground: View {
    @Environment(\.fdTheme) private var theme
    var brassGlow: Bool = true

    var body: some View {
        ZStack {
            theme.void.ignoresSafeArea()
            if brassGlow {
                RadialGradient(
                    colors: [theme.brass.opacity(0.14), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
            RadialGradient(
                colors: [theme.panel.opacity(0.35), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 380
            )
            .ignoresSafeArea()

            // A little material noise. Flat dark fills read as cheap; grain
            // makes the same colour read as a lit surface.
            Image("Grain")
                .resizable(resizingMode: .tile)
                .opacity(0.035)
                .blendMode(.overlay)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}

struct FDHairline: View {
    @Environment(\.fdTheme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
    }
}

struct FDSectionLabel: View {
    @Environment(\.fdTheme) private var theme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(FDFont.micro(11))
            .tracking(1.6)
            
            
            .foregroundStyle(theme.fog)
    }
}

struct FDBadge: View {
    @Environment(\.fdTheme) private var theme
    let text: String
    var tone: Tone = .brass

    enum Tone { case brass, moss, rust, fog }

    var body: some View {
        Text(text.uppercased())
            .font(FDFont.micro(10))
            .tracking(1.2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(theme.hairline.opacity(0.6), lineWidth: 0.6))
    }

    private var foreground: Color {
        switch tone {
        case .brass: return theme.brass
        case .moss: return theme.moss
        case .rust: return theme.rust
        case .fog: return theme.fog
        }
    }

    private var background: Color {
        foreground.opacity(0.12)
    }
}

extension FDBadge {
    
    
    static func tier(isPremium: Bool) -> FDBadge {
        guard Constants.Monetization.paywallEnabled else {
            return FDBadge(text: "All access", tone: .brass)
        }
        return FDBadge(text: isPremium ? "Premium" : "Free", tone: isPremium ? .brass : .fog)
    }
}

struct FDPrimaryButton: View {
    @Environment(\.fdTheme) private var theme
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(theme.void)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(FDFont.ui(16, weight: .semibold))
            }
            .foregroundStyle(theme.void)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [theme.brassSoft, theme.brass],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
            )
            .shadow(color: theme.brass.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(FDPressStyle(depth: 3))
        .disabled(isLoading)
    }
}

struct FDGhostButton: View {
    @Environment(\.fdTheme) private var theme
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(FDFont.ui(15, weight: .semibold))
            }
            .foregroundStyle(theme.bone)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(theme.raised, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(FDPressStyle(depth: 2))
    }
}

struct FDField: View {
    @Environment(\.fdTheme) private var theme
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FDSectionLabel(text: title)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text, axis: .vertical)
                }
            }
            .font(monospaced ? FDFont.mono(14) : FDFont.ui(16))
            .foregroundStyle(theme.bone)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(monospaced)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(theme.inset, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
        }
    }
}

struct FDEmptyState: View {
    @Environment(\.fdTheme) private var theme
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionSystemImage: String? = "plus"
    var expands: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.raised)
                    .frame(width: 84, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(theme.hairline, lineWidth: 1)
                    )
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.brass)
            }
            VStack(spacing: 8) {
                Text(title)
                    .font(FDFont.ui(22, weight: .semibold))
                    .foregroundStyle(theme.bone)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(FDFont.ui(15))
                    .foregroundStyle(theme.fog)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            if let actionTitle, let action {
                FDPrimaryButton(title: actionTitle, systemImage: actionSystemImage, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: expands ? .infinity : nil)
    }
}
