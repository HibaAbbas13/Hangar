import SwiftUI

struct ButtonEditorView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var decks: DeckController
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let existing: DeckButton?

    @State private var label = ""
    @State private var iconName = ButtonIcon.bolt.rawValue
    @State private var url = ""
    @State private var method: HTTPMethod = .POST
    @State private var bodyText = ""
    @State private var headerText = ""
    @State private var requiresConfirmation = true
    @State private var error: String?
    @State private var isSaving = false
    @State private var selectedTemplate: ProviderTemplate?

    private var keepsExistingSecret: Bool {
        guard let existing else { return false }
        return existing.isEncrypted || existing.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FDScreenBackground(brassGlow: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if existing == nil, let provider = decks.selectedDeck?.provider {
                            templateStrip(provider)
                        }
                        FDField(title: "Label", text: $label, placeholder: "Trigger Production Rollback")
                        IconPicker(selection: $iconName)
                        Picker("Method", selection: $method) {
                            ForEach(HTTPMethod.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        FDField(
                            title: "Webhook URL",
                            text: $url,
                            placeholder: keepsExistingSecret
                                ? "Leave blank to keep stored secret"
                                : "https://…",
                            keyboard: .URL,
                            autocapitalization: .never,
                            monospaced: true
                        )
                        FDField(
                            title: "Headers (Key: Value per line)",
                            text: $headerText,
                            placeholder: "Authorization: Bearer …",
                            autocapitalization: .never,
                            monospaced: true
                        )
                        FDField(
                            title: "Body",
                            text: $bodyText,
                            placeholder: "{ }",
                            autocapitalization: .never,
                            monospaced: true
                        )
                        Toggle(isOn: $requiresConfirmation) {
                            Text("Confirm before firing")
                                .font(FDFont.ui(15, weight: .medium))
                                .foregroundStyle(theme.bone)
                        }
                        .tint(theme.brass)
                        if let error {
                            Text(error).font(FDFont.ui(13)).foregroundStyle(theme.rust)
                        }
                        FDPrimaryButton(title: "Save command", isLoading: isSaving) {
                            Task { await save() }
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle(existing == nil ? "New command" : "Edit command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(theme.fog)
                }
            }
            .onAppear {
                if let existing { hydrate(existing) }
            }
        }
    }

    private func templateStrip(_ provider: ServiceProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FDSectionLabel(text: "\(provider.displayName) templates")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ProviderCatalog.templates(for: provider)) { template in
                        Button {
                            apply(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: template.iconName)
                                    .foregroundStyle(theme.brass)
                                Text(template.label)
                                    .font(FDFont.ui(12, weight: .medium))
                                    .foregroundStyle(theme.bone)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .frame(width: 140, alignment: .leading)
                            .background(theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(theme.hairline, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private func apply(_ template: ProviderTemplate) {
        selectedTemplate = template
        label = template.label
        iconName = template.iconName
        url = template.sampleURL
        method = template.method
        bodyText = template.body
        headerText = template.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        requiresConfirmation = template.requiresConfirmation
        HapticService.select()
    }

    private func hydrate(_ button: DeckButton) {
        label = button.label
        iconName = button.iconName
        let encrypted = button.isEncrypted || button.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix)
        url = encrypted ? "" : button.webhookUrl
        method = button.method
        bodyText = button.body
        headerText = button.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        requiresConfirmation = button.requiresConfirmation
    }

    private func save() async {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Label the command."; return }

        let existingEncrypted = existing.map {
            $0.isEncrypted || $0.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix)
        } ?? false
        let keepExistingSecret = existing != nil && trimmedURL.isEmpty && existingEncrypted

        var secret: WebhookSecret?
        if keepExistingSecret == false {
            guard let parsed = URL(string: trimmedURL),
                  let scheme = parsed.scheme?.lowercased(),
                  ["https", "http"].contains(scheme),
                  parsed.host != nil else {
                error = existingEncrypted
                    ? "Paste the webhook again to rotate it, or leave the field blank to keep the stored secret."
                    : "Enter a full webhook URL, starting with https://"
                return
            }
            secret = WebhookSecret(url: trimmedURL, headers: parseHeaders(), body: bodyText, method: method)
        }

        isSaving = true
        defer { isSaving = false }
        var button = existing ?? DeckButton.make(label: trimmed, iconName: iconName, sortOrder: decks.buttons.count)
        button.label = trimmed
        button.iconName = iconName
        button.requiresConfirmation = requiresConfirmation
        button.method = method
        if keepExistingSecret, let existing {
            button.webhookUrl = existing.webhookUrl
            button.isEncrypted = existing.isEncrypted
            button.headers = [:]
            button.body = ""
        }
        do {
            try await decks.saveButton(button, secret: secret, isPremium: app.isPremium, mode: app.executionMode)
            dismiss()
        } catch {
            self.error = AppErrorMapper.message(for: error)
        }
    }

    private func parseHeaders() -> [String: String] {
        var result: [String: String] = [:]
        headerText.split(separator: "\n").forEach { line in
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }
}

struct IconPicker: View {
    @Environment(\.fdTheme) private var theme
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FDSectionLabel(text: "Icon")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(ButtonIcon.allCases) { icon in
                    Button {
                        selection = icon.rawValue
                    } label: {
                        Image(systemName: icon.rawValue)
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(selection == icon.rawValue ? theme.void : theme.bone)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selection == icon.rawValue ? theme.brass : theme.inset)
                            )
                    }
                }
            }
        }
    }
}
