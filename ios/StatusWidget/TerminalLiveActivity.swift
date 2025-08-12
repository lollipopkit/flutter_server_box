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
            }
            .padding(12)
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
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.startTime, style: .timer)
                            .font(.caption2)
                            .monospacedDigit()
                    }
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
                Text(context.state.startTime, style: .timer)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.hasTerminal ? "terminal" : "bolt.horizontal.circle")
            }
        }
    }
}

