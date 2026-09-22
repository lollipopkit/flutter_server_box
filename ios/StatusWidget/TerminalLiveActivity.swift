//
//  TerminalLiveActivity.swift
//  StatusWidget
//
//  Renders the Live Activity UI for SSH/Terminal sessions.
//

import SwiftUI
import WidgetKit
import ActivityKit

// Map status strings to indicator colors without case sensitivity.
@inline(__always)
private func getStatusDotColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "connected":
        return .green
    case "connecting":
        return .yellow
    case "disconnected":
        return .red
    default:
        return .secondary
    }
}

// Normalize a status for display by capitalizing only its first letter.
@inline(__always)
private func formatStatus(_ status: String) -> String {
    let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return status }
    let head = String(first).uppercased()
    let tail = String(trimmed.dropFirst()).lowercased()
    return head + tail
}

/// Return the label used when the activity's last status is stale.
@inline(__always)
private func localizedUnknown() -> String {
    NSLocalizedString("Status unknown", comment: "Live Activity has not been refreshed recently")
}

// Localize known statuses and format unrecognized values for display.
private func localizedStatus(_ status: String) -> String {
    switch status.lowercased() {
    case "connected":
        return NSLocalizedString("Connected", comment: "Session connected status")
    case "connecting":
        return NSLocalizedString("Connecting", comment: "Session connecting status")
    case "disconnected":
        return NSLocalizedString("Disconnected", comment: "Session disconnected status")
    default:
        return formatStatus(status)
    }
}

@available(iOS 16.1, *)
struct TerminalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TerminalAttributes.self) { context in
            let state = context.state

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("Terminal", comment: "Terminal label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if state.connectionCount > 1 {
                            Text("(\(state.connectionCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(state.subtitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        // A stale activity has not been refreshed within
                        // `LiveActivityManager.staleAfter`, usually because
                        // the app was suspended or terminated. Do not present
                        // its last reported status as current.
                        Circle()
                            .fill(context.isStale ? .secondary : getStatusDotColor(state.status))
                            .frame(width: 6, height: 6)
                        Text(context.isStale ? localizedUnknown() : localizedStatus(state.status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: state.hasTerminal ? "terminal" : "bolt.horizontal.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Terminal", comment: "Terminal label"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if context.state.connectionCount > 1 {
                                Text("(\(context.state.connectionCount))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(context.state.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 6) {
                            // Match the lock screen by treating a stale status
                            // as unknown.
                            Circle()
                                .fill(context.isStale ? .secondary : getStatusDotColor(context.state.status))
                                .frame(width: 6, height: 6)
                            Text(context.isStale
                                 ? localizedUnknown()
                                 : localizedStatus(context.state.status))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.subtitle)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.hasTerminal ? "terminal" : "bolt.horizontal.circle")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: context.state.hasTerminal ? "terminal" : "bolt.horizontal.circle")
            }
        }
    }
}

#if DEBUG
@available(iOS 16.2, *)
struct TerminalLiveActivity_Previews: PreviewProvider {
    static let attributes = TerminalAttributes(id: "preview")
    static let contentState = TerminalAttributes.ContentState(
        id: "preview",
        title: "root@server-01",
        subtitle: "CPU 37% • Mem 1.3G/2.0G",
        status: "Connected",
        startTime: Date().addingTimeInterval(-1234),
        hasTerminal: true,
        connectionCount: 2
    )

    static var previews: some View {
        Group {
            // Lock screen and notification preview.
            attributes
                .previewContext(contentState, viewKind: .content)
                .previewDisplayName("Lock Screen")

            // Expanded Dynamic Island preview.
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
                .previewDisplayName("Dynamic Island • Expanded")

            // Compact Dynamic Island preview.
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.compact))
                .previewDisplayName("Dynamic Island • Compact")

            // Minimal Dynamic Island preview.
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
                .previewDisplayName("Dynamic Island • Minimal")
        }
    }
}
#endif
