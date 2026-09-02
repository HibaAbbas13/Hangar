import SwiftUI

struct FDTabBar: View {
    @Environment(\.fdTheme) private var theme
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(FDMotion.snappy) { selection = tab }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 16, weight: selection == tab ? .semibold : .light))
                            .symbolVariant(selection == tab ? .fill : .none)
                        Text(tab.title)
                            .font(FDFont.micro(10))
                            .tracking(0.6)
                    }
                    .foregroundStyle(selection == tab ? theme.brass : theme.fog)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(theme.brass.opacity(0.12))
                                .overlay(Capsule().stroke(theme.brass.opacity(0.25), lineWidth: 0.8))
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
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
}
