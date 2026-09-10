import SwiftUI

struct FDTabBar: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: AppTab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(theme.panel.opacity(0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(theme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .padding(.top, 4)
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            guard selection != tab else { return }
            withAnimation(reduceMotion ? nil : FDMotion.snappy) { selection = tab }
            HapticService.select()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 16, weight: selected ? .semibold : .regular))
                    .symbolVariant(selected ? .fill : .none)
                Text(tab.title)
                    .font(FDFont.micro(10))
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? theme.brass : theme.fog)
            .frame(maxWidth: .infinity)
            // 44pt is the floor Apple sets for a control, and this is the most
            // used control in the app.
            .frame(height: 48)
            .background {
                if selected {
                    Capsule()
                        .fill(theme.brass.opacity(0.14))
                        .overlay(Capsule().stroke(theme.brass.opacity(0.25), lineWidth: 0.8))
                        .matchedGeometryEffect(id: "tab", in: indicator)
                }
            }
            // Without this the button is only tappable where the glyph and the
            // label actually paint — the transparent padding around a thin SF
            // Symbol was not hit-testable, so an unselected tab took several
            // attempts to hit. Every tab is now a full-width 48pt target.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .modifier(ConsoleAnchor(tab: tab))
    }
}

/// The tutorial points at the Console tab, so only that item carries an anchor.
private struct ConsoleAnchor: ViewModifier {
    let tab: AppTab

    func body(content: Content) -> some View {
        if tab == .console {
            content.tutorialAnchor(.console)
        } else {
            content
        }
    }
}
