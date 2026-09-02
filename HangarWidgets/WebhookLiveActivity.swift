import WidgetKit
import SwiftUI
import ActivityKit

struct WebhookLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WebhookActivityAttributes.self) { context in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.deckName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.745, green: 0.588, blue: 0.357))
                    Text(context.state.buttonLabel)
                        .font(.system(size: 16, weight: .semibold))
                    Text(context.state.message)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusMark(context.state.status)
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.106, green: 0.098, blue: 0.086))
            .activitySystemActionForegroundColor(Color(red: 0.745, green: 0.588, blue: 0.357))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("FD")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.745, green: 0.588, blue: 0.357))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.providerCode)
                        .font(.system(size: 12, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.buttonLabel)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(Color(red: 0.745, green: 0.588, blue: 0.357))
                    Text(context.state.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("FD")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.745, green: 0.588, blue: 0.357))
            } compactTrailing: {
                Image(systemName: context.state.status == "succeeded" ? "checkmark" : "bolt.fill")
            } minimal: {
                Text("FD")
            }
        }
    }

    @ViewBuilder
    private func statusMark(_ status: String) -> some View {
        let moss = Color(red: 0.455, green: 0.510, blue: 0.365)
        let rust = Color(red: 0.675, green: 0.325, blue: 0.255)
        let brass = Color(red: 0.745, green: 0.588, blue: 0.357)
        let color = status == "succeeded" ? moss : status == "failed" ? rust : brass
        Text(status.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }
}
