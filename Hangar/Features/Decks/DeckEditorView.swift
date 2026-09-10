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
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                FDScreenBackground(brassGlow: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FDField(title: "Service name", text: $name, placeholder: "therango production")
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
                            VStack(alignment: .leading, spacing: FDSpace.hair) {
                                Text("Active")
                                    .font(FDFont.ui(15, weight: .medium))
                                    .foregroundStyle(theme.bone)
                                Text("Inactive services stay in your account but are hidden from widgets and Siri.")
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(theme.fog)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(theme.brass)
                        if let error {
                            Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
                        }
                        FDPrimaryButton(title: existing == nil ? "Add service" : "Save service") {
                            Task { await save() }
                        }
                        if existing != nil {
                            // Deleting a service takes its commands with it and
                            // cannot be undone. It used to be a single tap on a
                            // button styled like every other one.
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete service", systemImage: "trash")
                                    .font(FDFont.ui(15, weight: .semibold))
                                    .foregroundStyle(theme.rust)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.rust.opacity(0.1), in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                                            .stroke(theme.rust.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(FDPressStyle(depth: 2))
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle(existing == nil ? "New service" : "Service settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(theme.fog)
                }
            }
            .confirmationDialog(
                existing.map { "Delete “\($0.name)”?" } ?? "Delete service?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete service and its commands", role: .destructive) {
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
                Button("Keep", role: .cancel) {}
            } message: {
                Text("Its commands are deleted with it. Runs already in the Console are kept. This cannot be undone.")
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
            error = "Give the service a name first."
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
