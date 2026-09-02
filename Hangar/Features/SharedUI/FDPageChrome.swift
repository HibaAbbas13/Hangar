import SwiftUI

struct FDScreen<Content: View>: View {
    var brassGlow: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                FDScreenBackground(brassGlow: brassGlow)
            }
    }
}

struct FDPageHeader<Trailing: View>: View {
    @Environment(\.fdTheme) private var theme
    let eyebrow: String
    let title: String
    var horizontalPadding: CGFloat = 20
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(FDFont.micro(11))
                    .tracking(3.2)
                    .foregroundStyle(theme.fog)
                Text(title)
                    .font(FDFont.display(28))
                    .foregroundStyle(theme.bone)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

extension FDPageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, horizontalPadding: CGFloat = 20) {
        self.init(eyebrow: eyebrow, title: title, horizontalPadding: horizontalPadding, trailing: { EmptyView() })
    }
}

struct FDIconButton: View {
    @Environment(\.fdTheme) private var theme
    let systemImage: String
    
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.brass)
                .frame(width: 36, height: 36)
                .background(theme.raised, in: Circle())
                .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(FDPressStyle(depth: 2))
        .accessibilityLabel(label)
    }
}
