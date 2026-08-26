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
        WatchEntry(
            date: Date(),
            snapshot: .placeholder(name: "Server"),
            chart: .cpu,
            configured: true
        )
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
            return WatchEntry(
                date: Date(),
                snapshot: .placeholder(name: "-"),
                chart: .overview,
                configured: false
            )
        }
        let index = min(max(0, WatchStore.selectedIndex), servers.count - 1)
        let server = servers[index]
        return WatchEntry(
            date: Date(),
            // No reading yet means the app has not managed to load this server
            // since it was configured; the name is still worth showing.
            snapshot: WatchStore.snapshot(id: server.id) ?? .placeholder(name: server.name),
            // Both axes of the app's navigation, so the complication is a
            // shortcut back to what was last being looked at rather than a
            // fixed view of CPU.
            chart: WatchStore.selectedChart,
            configured: true
        )
    }
}

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
    let chart: WatchChart
    let configured: Bool
}

struct WatchStatusWidgetEntryView: View {
    var entry: WatchProvider.Entry

    @Environment(\.widgetFamily) var family

    /// Which metric this complication is about, and everything drawn from it.
    ///
    /// Follows the app's own chart selection, with one exception: the overview
    /// page has no single number, and a complication has room for exactly one.
    /// CPU stands in for it — the reading someone glances at a watch face for.
    private var metric: (label: String, icon: String, percent: Double?, detail: String, series: [Double]) {
        switch entry.chart {
        case .memory:
            return ("MEM", "memorychip", entry.snapshot.mem, entry.snapshot.memText, entry.snapshot.memSeries)
        case .disk:
            return ("DISK", "externaldrive", entry.snapshot.disk, entry.snapshot.diskText, entry.snapshot.diskTrend)
        case .network:
            // A rate, not a percentage: there is no ceiling to show it against,
            // so the gauge stays empty and the text carries the reading.
            return ("NET", "network", nil, entry.snapshot.netText, entry.snapshot.netRxSeries)
        case .overview, .cpu:
            return ("CPU", "cpu", entry.snapshot.cpu, entry.snapshot.memText, entry.snapshot.cpuSeries)
        }
    }

    private var valueText: String {
        metric.percent.map { String(format: "%.0f%%", $0) } ?? "--"
    }

    var body: some View {
        let metric = self.metric
        switch family {
        case .accessoryCircular:
            Gauge(value: metric.percent ?? 0, in: 0 ... 100) {
                Image(systemName: metric.icon)
            } currentValueLabel: {
                Text(metric.percent.map { String(format: "%.0f", $0) } ?? "--")
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
                    Text(metric.percent == nil ? metric.label : valueText)
                        .font(.system(size: 12, design: .monospaced))
                }
                if metric.series.isEmpty {
                    Text(metric.detail)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                } else {
                    TrendLine(values: metric.series, isPercent: metric.percent != nil)
                }
            }
        case .accessoryInline:
            Text("\(entry.snapshot.name) \(metric.percent == nil ? metric.detail : valueText)")
        default:
            VStack {
                Text(entry.snapshot.name).lineLimit(1)
                Text(valueText)
            }
        }
    }
}

/// One series, scaled by what it measures.
///
/// A percentage is drawn against a fixed 0...100 so two glances at the same
/// complication are comparable; a byte rate has no ceiling to draw against, and
/// pinning one to 0...100 would flatten every line above 100 B/s against the
/// top of the box. The two need different scales, and `chartYScale` takes a
/// domain whose type differs between them — hence a branch on the view rather
/// than on the argument.
private struct TrendLine: View {
    let values: [Double]
    let isPercent: Bool

    var body: some View {
        if isPercent {
            chart.chartYScale(domain: 0 ... 100)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            AreaMark(x: .value("t", index), y: .value("v", value))
                .foregroundStyle(.tertiary)
            LineMark(x: .value("t", index), y: .value("v", value))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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

// `PreviewProvider` rather than the `#Preview` macro. The macro is available
// now that this target is watchOS 10, but a preview is not worth a diff.
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
                    netTxSeries: [],
                    diskSeries: [24, 24, 25, 24]
                ),
                chart: .cpu,
                configured: true
            )
        )
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
