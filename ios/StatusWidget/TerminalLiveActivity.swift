//
//  TerminalLiveActivity.swift
//  StatusWidget
//
//  Renders the Live Activity UI for SSH/Terminal sessions.
//

import SwiftUI
import WidgetKit
import ActivityKit

// Helper to map status strings to a color dot (case-insensitive).
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

// Normalize status for display: capitalize first letter only.
@inline(__always)
private func formatStatus(_ status: String) -> String {
    let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return status }
    let head = String(first).uppercased()
    let tail = String(trimmed.dropFirst()).lowercased()
    return head + tail
}

// Localize known statuses; fall back to formatted original.
@inline(__always)
/// What is said instead of a status the activity can no longer vouch for.
private func localizedUnknown() -> String {
    NSLocalizedString("Status unknown", comment: "Live Activity has not been refreshed recently")
}

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
                        // Stale means nothing has refreshed this for five
                        // minutes, which is the app being killed as often as
                        // it is the app being suspended — see
                        // `LiveActivityManager.staleAfter`. Either way the
                        // status shown is the one from before that, so it is
                        // not reported as current.
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
                            // As on the lock screen: a status nothing has
                            // refreshed for five minutes is not reported as
                            // current.
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
            // 锁屏 / 通知样式预览
            attributes
                .previewContext(contentState, viewKind: .content)
                .previewDisplayName("Lock Screen")

            // 岛屿展开态预览
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
                .previewDisplayName("Dynamic Island • Expanded")

            // 岛屿紧凑态预览
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.compact))
                .previewDisplayName("Dynamic Island • Compact")

            // 岛屿最小态预览
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
                .previewDisplayName("Dynamic Island • Minimal")
        }
    }
}
#endif
