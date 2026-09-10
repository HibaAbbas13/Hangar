import SwiftUI

struct ConsoleView: View {
    @ObservedObject var controller: ConsoleController
    @Environment(\.fdTheme) private var theme
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            FDScreen {
                VStack(alignment: .leading, spacing: FDSpace.base) {
                    FDPageHeader(eyebrow: "Console", title: "Run log") {
                        if !controller.events.isEmpty {
                            Button("Clear") { showClearConfirm = true }
                                .font(FDFont.ui(13, weight: .semibold))
                                .foregroundStyle(theme.brass)
                                .padding(.horizontal, FDSpace.snug)
                                .padding(.vertical, FDSpace.tight)
                                .background(theme.raised, in: Capsule())
                                .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
                                .accessibilityLabel("Clear the run log")
                        }
                    }
                    if !controller.events.isEmpty {
                        filterRow
                    }
                    if controller.filtered.isEmpty {
                        emptyState
                    } else {
                        log
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Clear the run log?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear \(controller.events.count) entries", role: .destructive) {
                    Task { await controller.clear() }
                }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("This only clears the log. Your services and commands are untouched.")
            }
        }
    }

    private var log: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FDSpace.base, pinnedViews: [.sectionHeaders]) {
                ForEach(controller.sections, id: \.day) { section in
                    Section {
                        VStack(spacing: FDSpace.tight) {
                            ForEach(section.events) { event in
                                ConsoleEventRow(event: event)
                            }
                        }
                        .padding(.horizontal, FDSpace.gutter)
                    } header: {
                        HStack {
                            FDSectionLabel(text: ConsoleController.dayTitle(section.day))
                            Spacer()
                            Text("\(section.events.count)")
                                .font(FDFont.mono(10))
                                .foregroundStyle(theme.fog)
                        }
                        .padding(.horizontal, FDSpace.gutter)
                        .padding(.vertical, 6)
                        // Full-bleed so a row scrolling underneath is covered
                        // edge to edge instead of showing past the band.
                        .background(theme.void.opacity(0.96))
                        .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .padding(.bottom, FDChromeInset.bottom)
        }
        .fdScrollEdges()
    }

    private var emptyState: some View {
        FDEmptyState(
            symbol: controller.isFiltering ? "line.3.horizontal.decrease.circle" : "terminal",
            title: controller.isFiltering ? "Nothing matches" : "Nothing has run yet",
            message: controller.isFiltering
                ? "No runs match this filter."
                : "Every command you press is logged here with its response code, how long the round trip took, and what came back — successes and failures alike.",
            actionTitle: controller.isFiltering ? "Clear filters" : nil,
            actionSystemImage: "arrow.counterclockwise",
            action: controller.isFiltering ? { controller.resetFilters() } : nil
        )
    }

    private var filterRow: some View {
        VStack(spacing: FDSpace.tight) {
            HStack(spacing: FDSpace.tight) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.fog)
                TextField("Search commands and services", text: $controller.query)
                    .font(FDFont.ui(14))
                    .foregroundStyle(theme.bone)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !controller.query.isEmpty {
                    Button {
                        controller.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.fog)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, FDSpace.snug)
            .frame(height: 44)
            .background(theme.inset, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )

            HStack(spacing: FDSpace.tight) {
                filterChip("All", nil, count: controller.events.count)
                filterChip("OK", .succeeded, count: controller.events.filter { $0.status == .succeeded }.count)
                filterChip("Failed", .failed, count: controller.events.filter { $0.status == .failed }.count)
                Spacer()
            }
        }
        .padding(.horizontal, FDSpace.gutter)
    }

    private func filterChip(_ title: String, _ status: TriggerStatus?, count: Int) -> some View {
        let selected = controller.statusFilter == status
        return Button {
            controller.statusFilter = status
            HapticService.select()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(FDFont.ui(13, weight: .semibold))
                Text("\(count)")
                    .font(FDFont.mono(11))
                    .opacity(0.7)
            }
            .padding(.horizontal, FDSpace.snug)
            .frame(height: 34)
            .foregroundStyle(selected ? theme.void : theme.bone)
            .background(selected ? theme.brass : theme.raised, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : theme.hairline, lineWidth: 1))
        }
        .buttonStyle(FDPressStyle(depth: 1))
        .accessibilityLabel("\(title), \(count) runs")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One run in the log.
///
/// The code and the round trip are the two things worth reading, so they sit on
/// the row itself — they used to be hidden behind a tap with nothing to suggest
/// the row could even be tapped. The disclosure now only holds the response
/// body, which is the part that genuinely needs the room.
struct ConsoleEventRow: View {
    @Environment(\.fdTheme) private var theme
    let event: ActivityEvent
    @State private var open = false

    private var tint: Color { event.status.tint(theme) }
    private var succeeded: Bool { event.status == .succeeded }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpace.tight) {
            Button {
                withAnimation(FDMotion.snappy) { open.toggle() }
                HapticService.light()
            } label: {
                row
            }
            .buttonStyle(.plain)

            if open {
                detail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(FDSpace.snug)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FDRadius.field, style: .continuous)
                .stroke(succeeded ? theme.hairline : tint.opacity(0.4), lineWidth: 1)
        )
    }

    private var row: some View {
        HStack(alignment: .center, spacing: FDSpace.snug) {
            // Shape carries the status as well as colour, so the log still
            // reads in greyscale and to colour-blind eyes.
            Image(systemName: event.status.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.buttonLabel)
                    .font(FDFont.ui(15, weight: .semibold))
                    .foregroundStyle(theme.bone)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(event.deckName)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(theme.fog)
                    Text(event.createdAt, style: .time)
                        .font(FDFont.mono(11))
                        .foregroundStyle(theme.fog)
                }
            }

            Spacer(minLength: FDSpace.tight)

            VStack(alignment: .trailing, spacing: 3) {
                Text(codeText)
                    .font(FDFont.mono(14, weight: .bold))
                    .foregroundStyle(tint)
                if event.durationMs > 0 {
                    Text(FDRunOutcome.format(duration: event.durationMs))
                        .font(FDFont.mono(11))
                        .foregroundStyle(theme.fog)
                }
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.fog)
                .rotationEffect(.degrees(open ? 180 : 0))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(open ? "Hides the response" : "Shows the response")
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: FDSpace.tight) {
            HStack(spacing: FDSpace.snug) {
                detailField("Status", event.status.plainTitle)
                detailField("Code", codeText)
                detailField("Took", event.durationMs > 0 ? FDRunOutcome.format(duration: event.durationMs) : "—")
                Spacer(minLength: 0)
            }
            FDHairline()
            Text(event.message.isEmpty ? "No response body was returned." : event.message)
                .font(FDFont.mono(12))
                .foregroundStyle(event.message.isEmpty ? theme.fog : theme.chrome)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FDSpace.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inset, in: RoundedRectangle(cornerRadius: FDRadius.field - 4, style: .continuous))
    }

    private func detailField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(FDFont.micro(9))
                .tracking(1.1)
                .foregroundStyle(theme.fog)
            Text(value)
                .font(FDFont.mono(12, weight: .medium))
                .foregroundStyle(theme.bone)
        }
        .accessibilityElement(children: .combine)
    }

    private var codeText: String {
        if let code = event.statusCode { return "\(code)" }
        return event.status == .succeeded ? "OK" : "—"
    }

    private var accessibilityLabel: String {
        var parts = ["\(event.buttonLabel), \(event.deckName)"]
        parts.append(event.status.plainTitle)
        if let code = event.statusCode { parts.append("HTTP \(code)") }
        if event.durationMs > 0 { parts.append("took \(FDRunOutcome.format(duration: event.durationMs))") }
        parts.append(event.createdAt.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: ", ")
    }
}
