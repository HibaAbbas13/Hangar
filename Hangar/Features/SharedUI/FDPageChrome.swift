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

/// A short scrim at the top of a scrolling screen.
///
/// Every tab scrolls its content edge-to-edge, which meant rows slid up under
/// the clock and the Dynamic Island with nothing between them. A native
/// navigation bar would solve it, but these screens deliberately have none — so
/// this is the same idea reduced to what it is: content fading out before it
/// reaches the status bar, and before it slides under the floating tab bar.
///
/// The top scrim belongs **only** to a scroll view that actually reaches the
/// top of the screen. Applied to one that starts below a page header it painted
/// an opaque band straight across the middle of the screen — a black line under
/// the title — because there was no status bar there for it to cover.
struct FDScrollEdges: ViewModifier {
    @Environment(\.fdTheme) private var theme
    var top: Bool
    var bottom: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if top {
                    LinearGradient(
                        stops: [
                            .init(color: theme.void, location: 0),
                            .init(color: theme.void, location: 0.72),
                            .init(color: theme.void.opacity(0.6), location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Tall enough to cover the status bar and the Dynamic
                    // Island on every iPhone. These scroll views already bleed
                    // to the top edge, so `ignoresSafeArea` adds nothing on its
                    // own — a short scrim left most of the clock area
                    // unshielded and rows showed straight through it.
                    .frame(height: 64)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if bottom {
                    // Without this a row scrolling behind the floating tab bar
                    // is simply sliced in half, which reads as a clipping bug
                    // rather than as content passing underneath.
                    LinearGradient(
                        colors: [.clear, theme.void.opacity(0.85), theme.void],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Fades a scrolling list out at its edges.
    ///
    /// Pass `top: true` only when the scroll view reaches the top of the screen;
    /// a list that starts under a header has nothing up there to fade against.
    func fdScrollEdges(top: Bool = false, bottom: Bool = true) -> some View {
        modifier(FDScrollEdges(top: top, bottom: bottom))
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
