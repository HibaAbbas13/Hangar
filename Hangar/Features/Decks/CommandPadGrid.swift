import SwiftUI

struct CommandPadGrid: View {
    let buttons: [DeckButton]
    let triggeringIds: Set<String>
    var onTrigger: (DeckButton) -> Void
    var onEdit: (DeckButton) -> Void
    var onDelete: (DeckButton) -> Void

    private var rows: [[DeckButton]] {
        stride(from: 0, to: buttons.count, by: 2).map { start in
            Array(buttons[start..<min(start + 2, buttons.count)])
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 12) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, button in
                        CommandKey(
                            label: button.label,
                            iconName: button.iconName,
                            status: triggeringIds.contains(button.id) ? .running : button.lastStatus,
                            requiresConfirmation: button.requiresConfirmation
                        ) {
                            onTrigger(button)
                        }
                        .contextMenu {
                            Button("Edit") { onEdit(button) }
                            Button("Delete", role: .destructive) { onDelete(button) }
                        }
                        .animation(FDMotion.card.delay(FDMotion.stagger(rowIndex * 2 + column)), value: buttons.count)
                    }
                }
            }
        }
    }
}
