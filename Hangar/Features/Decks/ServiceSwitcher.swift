import SwiftUI

struct ServiceSwitcher: View {
    @Environment(\.fdTheme) private var theme
    let decks: [Deck]
    let selectedId: String?
    var onSelect: (Deck) -> Void
    var onAdd: () -> Void
    var onEdit: () -> Void
    /// Offered only while the starter GitHub pad is not installed yet.
    var onAddStarter: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FDSectionLabel(text: "Service")
                Spacer()
                Button(action: onEdit) {
                    Text("Edit")
                        .font(FDFont.micro(11))
                        .foregroundStyle(theme.fog)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .disabled(selectedId == nil)
                .accessibilityLabel("Edit this service")

                if let onAddStarter {
                    // Two ways to add a service, so the starter pad stays
                    // reachable once the empty state that used to offer it is
                    // gone.
                    Menu {
                        Button("New service…", systemImage: "plus", action: onAdd)
                        Button("Add \(GitHubFleet.deckName)", systemImage: "chevron.left.forwardslash.chevron.right", action: onAddStarter)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.brass)
                            .frame(width: 36, height: 36)
                            .background(theme.raised, in: Circle())
                            .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
                    }
                    .accessibilityLabel("Add a service")
                } else {
                    FDIconButton(systemImage: "plus", label: "Add a service", action: onAdd)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(decks) { deck in
                        chip(deck, selected: deck.id == selectedId)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func chip(_ deck: Deck, selected: Bool) -> some View {
        Button {
            onSelect(deck)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: deck.iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(deck.name)
                    .font(FDFont.ui(13, weight: .semibold))
                    .lineLimit(1)
                Circle()
                    .fill(deck.isActive ? theme.moss : theme.fog)
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(selected ? theme.brass : theme.bone)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? theme.brass.opacity(0.14) : theme.raised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? theme.brass.opacity(0.55) : theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(FDPressStyle(depth: 2))
        .accessibilityLabel(deck.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
