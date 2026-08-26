//
//  StatusWidget.swift
//  StatusWidget
//
//  Created by lolli on 2023/7/15.
//
//  Rewritten against `/api/v1`. What was here before fetched the agent's
//  unauthenticated compat endpoint, which answers preformatted strings —
//  "1.3g / 1.9g", "31.7%" — and no history at all. Half this file was
//  machinery for parsing those strings back into numbers so a gauge could be
//  drawn from them, and no amount of it could produce a trend line. The
//  metrics endpoint answers numbers, and the history endpoint answers the
//  series, so both are gone.
//

import AppIntents
import Charts
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct StatusEntry: TimelineEntry {
    let date: Date
    let configuration: SelectServerIntent
    /// Nil while nothing has been read yet, which is what the placeholder and
    /// the failure states render from.
    let snapshot: WidgetSnapshot?
    let failure: String?
}

struct StatusProvider: AppIntentTimelineProvider {
    /// How long a reading is allowed to stand before the system is asked for
    /// another. WidgetKit treats this as a hint and will refuse to honour it
    /// for a widget nobody looks at, which is the intended behaviour: the
    /// budget belongs to the widgets someone actually has on a screen.
    private static let refreshAfter: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(
            date: Date(),
            configuration: SelectServerIntent(),
            snapshot: .demo,
            failure: nil
        )
    }

    func snapshot(for configuration: SelectServerIntent, in context: Context) async -> StatusEntry {
        // The gallery preview. Real data when there is any — a widget that
        // advertises itself with someone's own server is worth the read — and
        // the demo otherwise, never an error: the gallery is not somewhere to
        // report that an agent is down.
        let entry = await load(for: configuration)
        if entry.snapshot != nil { return entry }
        return StatusEntry(
            date: Date(),
            configuration: configuration,
            snapshot: .demo,
            failure: nil
        )
    }

    func timeline(for configuration: SelectServerIntent, in context: Context) async -> Timeline<StatusEntry> {
        let entry = await load(for: configuration)
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(Self.refreshAfter))
        )
    }

    private func load(for configuration: SelectServerIntent) async -> StatusEntry {
        let now = Date()
        guard let id = configuration.server?.id, let server = WidgetStore.server(id: id) else {
            return StatusEntry(
                date: now,
                configuration: configuration,
                // A server picked before it was deleted in the app: the id is
                // still in the widget's configuration and no longer in the
                // list. Falling back to a stale reading would be worse than
                // saying so.
                snapshot: nil,
                failure: WidgetError.notConfigured.errorDescription
            )
        }

        do {
            let (reading, history) = try await WidgetMonitorClient.load(server: server)
            let snapshot = WidgetSnapshot(
                serverId: server.id,
                name: reading.name.isEmpty ? server.name : reading.name,
                updatedAt: now,
                cpu: reading.cpu,
                mem: reading.mem,
                disk: reading.disk,
                memText: reading.memText,
                diskText: reading.diskText,
                netText: reading.netText,
                uptime: reading.uptime,
                cpuSeries: history.tail(\.cpu),
                memSeries: history.tail(\.memory),
                diskSeries: history.tail(\.disk),
                netRxSeries: history.tail(\.net_rx_speed),
                netTxSeries: history.tail(\.net_tx_speed)
            )
            WidgetStore.setSnapshot(snapshot)
            return StatusEntry(date: now, configuration: configuration, snapshot: snapshot, failure: nil)
        } catch {
            // The last good reading, with the failure alongside it. A widget
            // that blanks the moment a phone leaves Wi-Fi is less useful than
            // one showing numbers from ten minutes ago and saying so.
            return StatusEntry(
                date: now,
                configuration: configuration,
                snapshot: WidgetStore.snapshot(id: server.id),
                failure: (error as? WidgetError)?.errorDescription ?? error.localizedDescription
            )
        }
    }
}

private extension Array where Element == WidgetHistoryPoint {
    func tail(_ key: KeyPath<WidgetHistoryPoint, Double>) -> [Double] {
        suffix(WidgetSnapshot.maxSeriesPoints).map { $0[keyPath: key] }
    }
}

// MARK: - Entry view

struct StatusWidgetEntryView: View {
    var entry: StatusEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.widgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:
                Text("\(snapshot.name) \(snapshot.percentText(for: entry.configuration.metric))")
            case .accessoryRectangular:
                AccessoryRectangular(snapshot: snapshot, metric: entry.configuration.metric)
            case .accessoryCircular:
                AccessoryCircular(snapshot: snapshot, metric: entry.configuration.metric)
            default:
                // The family *is* the choice: `.systemSmall` is the readings
                // widget and `.systemMedium` the chart one, registered
                // separately so the gallery offers both by name.
                HomeScreen(
                    snapshot: snapshot,
                    metric: entry.configuration.metric,
                    family: family,
                    failure: entry.failure
                )
            }
        } else {
            Unavailable(message: entry.failure ?? WidgetError.notConfigured.errorDescription ?? "")
        }
    }
}

/// Nothing has ever been read for this widget.
///
/// Distinct from a failed refresh, which keeps the last reading and puts the
/// reason beside it — here there is nothing to show at all, so the reason is
/// all there is.
private struct Unavailable: View {
    let message: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(6)
    }
}

// MARK: - Home screen families

private struct HomeScreen: View {
    let snapshot: WidgetSnapshot
    let metric: WidgetMetric
    let family: WidgetFamily
    let failure: String?

    /// Every metric, always — see `StatusWidgetMedium`. Asking how many charts
    /// someone wants is a question with one sensible answer, and a setting
    /// whose only effect is to show less.
    private static let chartCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 7) {
            header
            if family == .systemSmall {
                Readings(snapshot: snapshot, family: family)
            } else {
                charts(metric.following(Self.chartCount))
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(family == .systemSmall ? 2 : 4)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(snapshot.name)
                .font(.system(family == .systemSmall ? .subheadline : .title3, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button(intent: RefreshIntent()) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .tint(.secondary)
        }
    }

    /// The time of the reading, and why it is not newer.
    ///
    /// Both, when a refresh has failed: the numbers above are real, they are
    /// just from the timestamp shown, and the reason belongs next to it rather
    /// than in place of the whole widget.
    private var footer: some View {
        HStack(spacing: 4) {
            Text(snapshot.updatedAt, style: .time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            if let failure {
                Text(failure)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    /// One chart, or a grid of them.
    ///
    /// Four go in a 2x2 rather than a column: on a large widget a column of
    /// four is four wide, flat lines, and the shape of a trend is the reason
    /// to draw it at all.
    @ViewBuilder
    private func charts(_ metrics: [WidgetMetric]) -> some View {
        if metrics.count >= 4 {
            VStack(spacing: 6) {
                ForEach(0 ..< 2, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0 ..< 2, id: \.self) { column in
                            MetricChart(snapshot: snapshot, metric: metrics[row * 2 + column], compact: true)
                        }
                    }
                }
            }
        } else if metrics.count == 2 {
            HStack(spacing: 6) {
                ForEach(metrics, id: \.self) { m in
                    MetricChart(snapshot: snapshot, metric: m, compact: true)
                }
            }
        } else {
            ForEach(metrics, id: \.self) { m in
                MetricChart(snapshot: snapshot, metric: m, compact: family == .systemSmall)
            }
        }
    }
}

private struct Readings: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 3 : 5) {
            // A small widget is the size of an app icon. Four labelled rows in
            // it are legible only at a size nobody can read at arm's length,
            // so it gets the two readings that answer "is this machine busy".
            let shown: [WidgetMetric] = family == .systemSmall
                ? [.cpu, .memory]
                : [.cpu, .memory, .disk, .network]
            ForEach(shown, id: \.self) { metric in
                Reading(snapshot: snapshot, metric: metric, family: family)
            }
        }
    }
}

private struct Reading: View {
    let snapshot: WidgetSnapshot
    let metric: WidgetMetric
    let family: WidgetFamily

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: metric.icon).font(.system(size: 10)).frame(width: 13)
            Text(metric.short)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if family != .systemSmall, let detail = snapshot.detailText(for: metric) {
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(snapshot.percentText(for: metric))
                .font(.system(size: family == .systemSmall ? 13 : 12, weight: .semibold, design: .monospaced))
        }
    }
}

private struct MetricChart: View {
    let snapshot: WidgetSnapshot
    let metric: WidgetMetric
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: metric.icon).font(.system(size: 9))
                Text(metric.short)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(snapshot.percentText(for: metric))
                    .font(.system(size: compact ? 11 : 14, weight: .semibold, design: .monospaced))
            }
            TrendChart(
                values: snapshot.series(for: metric),
                secondary: metric == .network ? snapshot.netTxSeries : [],
                isPercent: metric != .network,
                tint: metric.tint
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One series, or two for a metric with an in and an out.
private struct TrendChart: View {
    let values: [Double]
    let secondary: [Double]
    let isPercent: Bool
    let tint: Color

    var body: some View {
        if values.isEmpty && secondary.isEmpty {
            // An agent that has only just started has no history. Drawing that
            // as a flat line at zero would read as a machine doing nothing.
            Text("No history")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isPercent {
            chart.chartYScale(domain: 0 ... 100)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("t", index), y: .value("v", value))
                    .foregroundStyle(tint.opacity(0.22))
                LineMark(x: .value("t", index), y: .value("v", value))
                    .foregroundStyle(tint)
            }
            ForEach(Array(secondary.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("v", value))
                    .foregroundStyle(tint.opacity(0.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock screen families

private struct AccessoryRectangular: View {
    let snapshot: WidgetSnapshot
    let metric: WidgetMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(snapshot.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(snapshot.percentText(for: metric))
                    .font(.system(size: 12, design: .monospaced))
            }
            let series = snapshot.series(for: metric)
            if series.isEmpty {
                Text(snapshot.detailText(for: metric) ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
            } else {
                TrendChart(
                    values: series,
                    secondary: [],
                    isPercent: metric != .network,
                    tint: .primary
                )
            }
        }
    }
}

private struct AccessoryCircular: View {
    let snapshot: WidgetSnapshot
    let metric: WidgetMetric

    var body: some View {
        Gauge(value: snapshot.percent(for: metric) ?? 0, in: 0 ... 100) {
            Image(systemName: metric.icon)
        } currentValueLabel: {
            Text(snapshot.percent(for: metric).map { String(format: "%.0f", $0) } ?? "--")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Reading a snapshot by metric

private extension WidgetMetric {
    var short: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "MEM"
        case .disk: return "DISK"
        case .network: return "NET"
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "externaldrive"
        case .network: return "network"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: return .green
        case .memory: return .blue
        case .disk: return .orange
        case .network: return .purple
        }
    }
}

private extension WidgetSnapshot {
    func percent(for metric: WidgetMetric) -> Double? {
        switch metric {
        case .cpu: return cpu
        case .memory: return mem
        case .disk: return disk
        // A rate has no ceiling to be a percentage of.
        case .network: return nil
        }
    }

    /// Nil percentages render as "--" rather than as 0%: a source that could
    /// not measure something must not look like a machine sitting idle.
    func percentText(for metric: WidgetMetric) -> String {
        if metric == .network { return netText }
        return percent(for: metric).map { String(format: "%.0f%%", $0) } ?? "--"
    }

    func detailText(for metric: WidgetMetric) -> String? {
        switch metric {
        case .cpu: return nil
        case .memory: return memText
        case .disk: return diskText
        case .network: return netText
        }
    }

    func series(for metric: WidgetMetric) -> [Double] {
        switch metric {
        case .cpu: return cpuSeries
        case .memory: return memSeries
        case .disk: return diskSeries
        case .network: return netRxSeries
        }
    }

    static let demo = WidgetSnapshot(
        serverId: "demo",
        name: "Server",
        updatedAt: Date(),
        cpu: 31.7,
        mem: 68,
        disk: 24,
        memText: "1.3g / 1.9g",
        diskText: "7.1g / 30.0g",
        netText: "712.3k / 1.2m",
        uptime: "up 3 days",
        cpuSeries: [12, 30, 22, 48, 37, 41, 35, 29, 44, 31],
        memSeries: [60, 62, 65, 68, 67, 68, 69, 68, 66, 68],
        diskSeries: [23, 23, 24, 24, 24, 24, 24, 24, 24, 24],
        netRxSeries: [1000, 4200, 900, 8800, 3300, 2100, 6400, 1200, 5100, 2600],
        netTxSeries: [800, 1200, 700, 2400, 1500, 900, 1800, 600, 2200, 1100]
    )
}

// MARK: - Chrome

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

/// Readings as text, at `.systemSmall` — and the lock-screen families, which
/// live in their own gallery and so cost this entry nothing.
///
/// Two widgets rather than one that supports both sizes. A single entry the
/// user swipes between sizes made "how big" and "what it shows" two settings
/// that could disagree; here the size *is* the choice, made once, in the
/// gallery. No `.systemLarge` either: it was the medium's four charts with
/// more space around them.
struct StatusWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "StatusWidgetSmall",
            intent: SelectServerIntent.self,
            provider: StatusProvider()
        ) { entry in
            StatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server readings")
        .description("A server's current readings, from its monitor agent.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
        ])
    }
}

/// One chart per metric, at `.systemMedium`.
struct StatusWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "StatusWidgetMedium",
            intent: SelectServerIntent.self,
            provider: StatusProvider()
        ) { entry in
            StatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server charts")
        .description("A server's trends, from its monitor agent.")
        .supportedFamilies([.systemMedium])
    }
}

/// Tapping the refresh button asks WidgetKit to run the timeline again.
///
/// The empty result is the whole implementation: returning from an
/// `AppIntent` invoked from a widget is itself what invalidates the timeline.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"
    static var description = IntentDescription("Refresh status.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}
