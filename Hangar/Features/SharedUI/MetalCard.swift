import SwiftUI

struct MetalCard<Content: View>: View {
    @Environment(\.fdTheme) private var theme
    var cornerRadius: CGFloat = FDRadius.card
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
