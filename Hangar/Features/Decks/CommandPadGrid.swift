import SwiftUI

struct CommandPadGrid: View {
    @ObservedObject private var hud = RunHUDStore.shared
    let buttons: [DeckButton]
    let triggeringIds: Set<String>
    var onTrigger: (DeckButton) -> Void
    var onEdit: (DeckButton) -> Void
    var onDelete: (DeckButton) -> Void

    static func host(for button: DeckButton) -> String {
        if !button.host.isEmpty { return button.host }
        let raw = button.webhookUrl
        guard !raw.hasPrefix(Constants.Crypto.encryptedPrefix) else { return "" }
        return ButtonRepository.host(of: raw)
    }

    private var rows: [[DeckButton]] {
        stride(from: 0, to: buttons.count, by: 2).map { start in
            Array(buttons[start..<min(start + 2, buttons.count)])
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                CommandKey(
                    label: button.label,
                    iconName: button.iconName,
                    destination: Self.host(for: button),
                    outcome: button.lastOutcome,
                    isRunning: isRunning(button),
                    requiresConfirmation: button.requiresConfirmation,
                    needsArming: button.needsArming
                ) {
                    onTrigger(button)
                }
                .contextMenu {
                    Button("Edit command", systemImage: "slider.horizontal.3") { onEdit(button) }
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(button) }
                }
                .animation(FDMotion.card.delay(FDMotion.stagger(index)), value: buttons.count)
            }
        }
    }

    private func isRunning(_ button: DeckButton) -> Bool {
        triggeringIds.contains(button.id) || hud.pulsingIds.contains(button.id)
    }
}
