import SwiftUI

struct ConsoleView: View {
    @ObservedObject var controller: ConsoleController
    @Environment(\.fdTheme) private var theme

    var body: some View {
        NavigationStack {
            FDScreen {
                VStack(alignment: .leading, spacing: 16) {
                    FDPageHeader(eyebrow: "Console", title: "Local flight log") {
                        if !controller.events.isEmpty {
                            Button("Clear") {
                                Task { await controller.clear() }
                            }
                            .font(FDFont.ui(13, weight: .semibold))
                            .foregroundStyle(theme.brass)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.raised, in: Capsule())
                            .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
                        }
                    }
                    filterRow
                    if controller.filtered.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(controller.filtered) { event in
                                    ConsoleEventRow(event: event)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        FDEmptyState(
            symbol: "terminal",
            title: controller.events.isEmpty ? "Console is quiet" : "Nothing matches",
            message: controller.events.isEmpty
                ? "Fire a command from the pad. Status, duration, and the response remnant land here."
                : "No events match this filter. Clear it to see the full log.",
            actionTitle: controller.events.isEmpty ? nil : "Reset filters",
            actionSystemImage: "arrow.counterclockwise",
            action: controller.events.isEmpty ? nil : {
                controller.query = ""
                controller.statusFilter = nil
            }
        )
    }

    private var filterRow: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.fog)
                TextField("Filter commands", text: $controller.query)
                    .font(FDFont.mono(14))
                    .foregroundStyle(theme.bone)
            }
            .padding(12)
            .background(theme.inset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", nil)
                    filterChip("OK", .succeeded)
                    filterChip("Fault", .failed)
                    filterChip("Run", .running)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func filterChip(_ title: String, _ status: TriggerStatus?) -> some View {
        let selected = controller.statusFilter == status
        return Button {
            controller.statusFilter = status
        } label: {
            Text(title)
                .font(FDFont.micro(11))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? theme.void : theme.bone)
                .background(selected ? theme.brass : theme.raised, in: Capsule())
                .overlay(
                    Capsule().stroke(selected ? Color.clear : theme.hairline, lineWidth: 1)
                )
        }
    }
}

struct ConsoleEventRow: View {
    @Environment(\.fdTheme) private var theme
    let event: ActivityEvent
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.buttonLabel)
                        .font(FDFont.ui(15, weight: .semibold))
                        .foregroundStyle(theme.bone)
                    Text("\(event.deckName)  ·  \(event.provider.shortCallsign)")
                        .font(FDFont.micro(11))
                        .foregroundStyle(theme.fog)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.status.rawValue.uppercased())
                        .font(FDFont.micro(10))
                        .foregroundStyle(color)
                    Text(event.createdAt, style: .time)
                        .font(FDFont.mono(11))
                        .foregroundStyle(theme.fog)
                }
            }
            if open {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HTTP \(event.statusCode.map(String.init) ?? "—")  ·  \(event.durationMs)ms")
                        .font(FDFont.mono(12))
                        .foregroundStyle(theme.chrome)
                    Text(event.message.isEmpty ? "No response body captured." : event.message)
                        .font(FDFont.mono(12))
                        .foregroundStyle(theme.fog)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.hairline, lineWidth: 1))
        .onTapGesture { withAnimation(FDMotion.snappy) { open.toggle() } }
    }

    private var color: Color {
        switch event.status {
        case .succeeded: return theme.moss
        case .failed, .blocked: return theme.rust
        case .running, .queued: return theme.brass
        case .idle: return theme.fog
        }
    }
}
