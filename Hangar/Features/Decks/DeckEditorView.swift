import SwiftUI

struct DeckEditorView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let existing: Deck?

    @State private var name = ""
    @State private var provider: ServiceProvider = .vercel
    @State private var isActive = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FDScreenBackground(brassGlow: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FDField(title: "Deck name", text: $name, placeholder: "Vercel Micro-Services")
                        VStack(alignment: .leading, spacing: 10) {
                            FDSectionLabel(text: "Provider")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(ServiceProvider.allCases) { item in
                                    Button {
                                        provider = item
                                        HapticService.select()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: item.symbolName)
                                            Text(item.displayName)
                                                .font(FDFont.ui(13, weight: .medium))
                                        }
                                        .foregroundStyle(provider == item ? theme.void : theme.bone)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(provider == item ? theme.brass : theme.raised)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(theme.hairline, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        Toggle(isOn: $isActive) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active surface")
                                    .font(FDFont.ui(15, weight: .medium))
                                    .foregroundStyle(theme.bone)
                                Text("Inactive decks stay in the hangar and skip widgets.")
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(theme.fog)
                            }
                        }
                        .tint(theme.brass)
                        if let error {
                            Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
                        }
                        FDPrimaryButton(title: existing == nil ? "Commission deck" : "Save deck") {
                            Task { await save() }
                        }
                        if existing != nil {
                            FDGhostButton(title: "Decommission", systemImage: "trash") {
                                Task {
                                    guard let existing else { return }
                                    do {
                                        try await decks.deleteDeck(existing)
                                        dismiss()
                                    } catch {
                                        self.error = AppErrorMapper.message(for: error)
                                    }
                                }
                            }
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle(existing == nil ? "New deck" : "Deck settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(theme.fog)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    provider = existing.provider
                    isActive = existing.isActive
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Name the deck before commissioning."
            return
        }
        do {
            if var existing {
                existing.name = trimmed
                existing.provider = provider
                existing.isActive = isActive
                existing.iconName = provider.symbolName
                try await decks.saveDeck(existing)
            } else {
                try await decks.createDeck(name: trimmed, provider: provider, isPremium: app.isPremium)
            }
            dismiss()
        } catch {
            self.error = AppErrorMapper.message(for: error)
        }
    }
}
