//
//  WatchStatusWidget.swift
//  WatchStatusWidget Extension
//
//  Complications for the server the watch app was last showing. Everything is
//  read from the App Group the app writes after each successful refresh — a
//  widget extension gets a few seconds of runtime and no credentials, so it
//  never fetches anything itself.
//

import Charts
import SwiftUI
import WidgetKit

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), snapshot: .placeholder(name: "Server"), configured: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        // The app reloads these timelines as soon as it has fresher data, so
        // this interval only bounds how stale things get if it never runs.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [loadEntry()], policy: .after(next)))
    }

    private func loadEntry() -> WatchEntry {
        let servers = WatchStore.servers()
        guard !servers.isEmpty else {
            return WatchEntry(date: Date(), snapshot: .placeholder(name: "-"), configured: false)
        }
        let index = min(max(0, WatchStore.selectedIndex), servers.count - 1)
        let server = servers[index]
        return WatchEntry(
            date: Date(),
            // No reading yet means the app has not managed to load this server
            // since it was configured; the name is still worth showing.
            snapshot: WatchStore.snapshot(id: server.id) ?? .placeholder(name: server.name),
            configured: true
        )
    }
}

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
    let configured: Bool
}

struct WatchStatusWidgetEntryView: View {
    var entry: WatchProvider.Entry

    @Environment(\.widgetFamily) var family

    private var cpuText: String {
        entry.snapshot.cpu.map { String(format: "%.0f%%", $0) } ?? "--"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.cpu ?? 0, in: 0 ... 100) {
                Image(systemName: "cpu")
            } currentValueLabel: {
                Text(entry.snapshot.cpu.map { String(format: "%.0f", $0) } ?? "--")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.snapshot.name)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(cpuText).font(.system(size: 12, design: .monospaced))
                }
                if entry.snapshot.cpuSeries.isEmpty {
                    Text(entry.snapshot.memText)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                } else {
                    Chart(Array(entry.snapshot.cpuSeries.enumerated()), id: \.offset) { index, value in
                        AreaMark(x: .value("t", index), y: .value("%", value))
                            .foregroundStyle(.tertiary)
                        LineMark(x: .value("t", index), y: .value("%", value))
                    }
                    .chartYScale(domain: 0 ... 100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
        case .accessoryInline:
            Text("\(entry.snapshot.name) \(cpuText)")
        default:
            VStack {
                Text(entry.snapshot.name).lineLimit(1)
                Text(cpuText)
            }
        }
    }
}

struct WatchStatusWidget: Widget {
    let kind: String = "WatchStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Shows the server the watch app was last on.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// `PreviewProvider` rather than the `#Preview` macro, which needs watchOS 10.
struct WatchStatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        WatchStatusWidgetEntryView(
            entry: WatchEntry(
                date: Date(),
                snapshot: WatchSnapshot(
                    serverId: "demo",
                    name: "Server",
                    updatedAt: Date(),
                    cpu: 37,
                    mem: 68,
                    disk: 24,
                    memText: "1.3g / 1.9g",
                    diskText: "7.1g / 30g",
                    netText: "712k / 1.2m",
                    uptime: "up 3 days",
                    cpuSeries: [12, 30, 22, 48, 37, 41, 35],
                    memSeries: [60, 62, 65, 68],
                    netRxSeries: [],
                    netTxSeries: []
                ),
                configured: true
            )
        )
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
