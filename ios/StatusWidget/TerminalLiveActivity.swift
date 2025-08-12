//
//  TerminalLiveActivity.swift
//  StatusWidget
//
//  Renders the Live Activity UI for SSH/Terminal sessions.
//

import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.1, *)
struct TerminalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TerminalAttributes.self) { context in
            let state = context.state
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(state.hasTerminal ? "Terminal" : "SSH")
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
                    Text(state.subtitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(state.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.startTime, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: state.hasTerminal ? "terminal" : "bolt.horizontal.circle")
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(context.state.hasTerminal ? "Terminal" : "SSH")
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
                    }.padding()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.startTime, style: .timer)
                            .font(.caption2)
                            .frame(width: 40, height: 20, alignment: .trailing)
                            .monospacedDigit()
                    }.padding()
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
