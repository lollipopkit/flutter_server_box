//
//  ContentView.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//
//  Two axes, and which is which is the whole navigation model:
//
//  - **Vertical** pages between servers. The Digital Crown drives it, which is
//    the one input a watch has that a finger does not have to cover the screen
//    to use — and moving between servers is the thing done most often.
//  - **Horizontal** pages between one server's charts. Swiping across stays
//    within the machine being looked at, so the gesture never changes two
//    things at once.
//
//  Both selections are persisted, because the complication shows whatever the
//  app was last on and the app is where that gets decided.
//

import Charts
import SwiftUI
import WidgetKit

struct ContentView: View {
    /// `@StateObject`, not `@ObservedObject`: this view is a struct that
    /// SwiftUI re-initialises freely, and an observed object created inline is
    /// rebuilt with it — which used to hand `WCSession.default.delegate` to a
    /// new instance and release the old one mid-flight, losing updates.
    @StateObject private var mgr = PhoneConnMgr()

    @State private var serverIndex: Int = 0

    var body: some View {
        Group {
            if mgr.servers.isEmpty {
                EmptyHint()
            } else {
                TabView(selection: $serverIndex) {
                    // Identified by server, not by index: pages keep their own
                    // load state, and index identity would show one server's
                    // numbers under another's name after the list changes.
                    ForEach(Array(mgr.servers.enumerated()), id: \.element.id) { index, server in
                        ServerPage(server: server).tag(index)
                    }
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .onAppear { serverIndex = storedIndex() }
        // Followed by id, not by position. The list is ordered by name and the
        // phone republishes it on every change, so renaming a server reorders
        // it — and holding a bare index would leave the page on whatever
        // machine had moved into that slot.
        .onChange(of: mgr.servers) { _ in serverIndex = storedIndex() }
        .onChange(of: serverIndex) { newValue in
            // The complication shows whichever server the user last looked at.
            WatchStore.selectedServerId =
                mgr.servers.indices.contains(newValue)
                    ? mgr.servers[newValue].id
                    : nil
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Where the remembered server sits in the list as it stands now.
    private func storedIndex() -> Int {
        guard !mgr.servers.isEmpty else { return 0 }
        if let id = WatchStore.selectedServerId,
           let found = mgr.servers.firstIndex(where: { $0.id == id }) {
            return found
        }
        // Gone from the list, or nothing remembered yet.
        return 0
    }
}

private struct EmptyHint: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("No server with a monitor agent yet. Add one in the iOS app.")
                .font(.system(.footnote, design: .monospaced))
                .multilineTextAlignment(.center)
            Link("View help", destination: helpUrl).font(.footnote)
        }
        .padding(.horizontal, 7)
    }
}

// MARK: - One server

struct ServerPage: View {
    let server: WatchServer

    private enum LoadState: Equatable {
        case loading
        case loaded(WatchSnapshot)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var chart: WatchChart = .overview

    var body: some View {
        content
            // Re-runs when the page is reused for a different server, which is
            // the only way a value-identified page can change servers.
            .task(id: server.id) { await load() }
            .onAppear { chart = WatchStore.selectedChart }
            .onChange(of: chart) { newValue in
                WatchStore.selectedChart = newValue
                WidgetCenter.shared.reloadAllTimelines()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            // Not inside the chart pager: there is nothing to page through
            // yet, and an empty carousel of five blank charts reads as five
            // broken ones.
            VStack(spacing: 7) {
                Text(server.name)
                    .font(.system(.headline, design: .monospaced))
                    .lineLimit(1)
                ProgressView()
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(server.name)
                        .font(.system(.headline, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    RefreshButton { await load() }
                }
                Text(message)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                Link("View help", destination: helpUrl).font(.caption2)
            }
            .padding(.horizontal, 9)
        case .loaded(let snapshot):
            TabView(selection: $chart) {
                ForEach(WatchChart.allCases) { page in
                    ChartPage(
                        snapshot: snapshot,
                        chart: page,
                        reload: { await load() }
                    )
                    .tag(page)
                }
            }
            .tabViewStyle(.page)
        }
    }

    private func load() async {
        // Show the last reading rather than a spinner when there is one: a
        // watch wakes up on a wrist raise and the fetch takes a moment.
        if case .loading = state, let cached = WatchStore.snapshot(id: server.id) {
            state = .loaded(cached)
        }

        do {
            let (reading, history) = try await MonitorClient.shared(for: server).load()
            let snapshot = WatchSnapshot(
                serverId: server.id,
                name: reading.name.isEmpty ? server.name : reading.name,
                updatedAt: Date(),
                cpu: reading.cpu,
                mem: reading.mem,
                disk: reading.disk,
                memText: reading.memText,
                diskText: reading.diskText,
                netText: reading.netText,
                uptime: reading.uptime,
                cpuSeries: history.tailValues(\.cpu),
                memSeries: history.tailValues(\.memory),
                netRxSeries: history.tailValues(\.net_rx_speed),
                netTxSeries: history.tailValues(\.net_tx_speed),
                diskSeries: history.tailValues(\.disk)
            )
            WatchStore.setSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            state = .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private extension Array where Element == HistoryPoint {
    /// The most recent points of one series, oldest first.
    func tailValues(_ key: KeyPath<HistoryPoint, Double>) -> [Double] {
        suffix(WatchSnapshot.maxSeriesPoints).map { $0[keyPath: key] }
    }
}

// MARK: - One chart

private struct ChartPage: View {
    let snapshot: WatchSnapshot
    let chart: WatchChart
    let reload: () async -> Void

    /// Two shapes, because the pages are two different things.
    ///
    /// The overview is a list, and how tall it comes out depends on what is in
    /// it — a long uptime, a larger text size — so it scrolls. A metric page is
    /// one number and one chart, and should be measured *from* the page rather
    /// than against it: a chart with a height written into it overflowed a 40mm
    /// watch, pushing the timestamp half off the bottom, and would leave a band
    /// of empty screen on a 49mm one.
    var body: some View {
        if chart == .overview {
            ScrollView { content }
        } else {
            content.frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            body(for: chart)
            Text(snapshot.updatedAt, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
    }

    private var header: some View {
        HStack(spacing: 4) {
            // The server name, not the chart's: the vertical axis is the one
            // that is easy to lose track of, since paging with the crown moves
            // without anything being touched.
            Text(snapshot.name)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 0)
            if chart != .overview {
                Image(systemName: chart.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            RefreshButton(reload: reload)
        }
    }

    @ViewBuilder
    private func body(for chart: WatchChart) -> some View {
        switch chart {
        case .overview:
            VStack(alignment: .leading, spacing: 7) {
                MetricRow(icon: "cpu", label: "CPU", value: MetricRow.percent(snapshot.cpu))
                MetricRow(icon: "memorychip", label: "Mem", value: MetricRow.percent(snapshot.mem))
                MetricRow(icon: "externaldrive", label: "Disk", value: MetricRow.percent(snapshot.disk))
                // A row like the three above it rather than a bare `Label`.
                // Without a label and a right-hand value it wrapped onto two
                // lines and read as a caption that had come loose from the
                // list, which is what it looked like on a 40mm watch.
                MetricRow(icon: "network", label: "Net", value: snapshot.netText)
                if let uptime = snapshot.uptime, !uptime.isEmpty {
                    Text(uptime)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .cpu:
            MetricPage(
                label: "CPU",
                percent: snapshot.cpu,
                detail: nil,
                series: snapshot.cpuSeries,
                tint: .green
            )
        case .memory:
            MetricPage(
                label: "Mem",
                percent: snapshot.mem,
                detail: snapshot.memText,
                series: snapshot.memSeries,
                tint: .blue
            )
        case .disk:
            MetricPage(
                label: "Disk",
                percent: snapshot.disk,
                detail: snapshot.diskText,
                series: snapshot.diskTrend,
                tint: .orange
            )
        case .network:
            VStack(alignment: .leading, spacing: 7) {
                Label(snapshot.netText, systemImage: "network")
                    .font(.system(.caption2, design: .monospaced))
                if snapshot.netRxSeries.isEmpty && snapshot.netTxSeries.isEmpty {
                    NoHistoryHint()
                } else {
                    NetChart(rx: snapshot.netRxSeries, tx: snapshot.netTxSeries)
                }
            }
        }
    }
}

private struct MetricPage: View {
    let label: String
    let percent: Double?
    let detail: String?
    let series: [Double]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(percent.map { String(format: "%.0f%%", $0) } ?? "--")
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if series.isEmpty {
                NoHistoryHint()
            } else {
                PercentChart(values: series, tint: tint)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// An agent that has only just started has no history, which is not an error
/// and must not be drawn as a flat line at zero.
private struct NoHistoryHint: View {
    var body: some View {
        Text("No history yet")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                minHeight: 44,
                maxHeight: .infinity,
                alignment: .center
            )
    }
}

private struct RefreshButton: View {
    let reload: () async -> Void

    var body: some View {
        Button {
            Task { await reload() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rendering

/// One line of the overview: an icon, what it is, and one number.
///
/// One number, and not a percentage with the byte counts wedged in beside it.
/// A watch is about a hundred and sixty points wide, and "1.8g / 1.9g" between
/// the label and the percentage had nowhere to go — it came out as `1.8g / 1…`,
/// which is a truncated number rather than a smaller one, and worth less than
/// the space it took. The full figures are on that metric's own page, which is
/// one turn of the crown away and has the width for them.
private struct MetricRow: View {
    let icon: String
    let label: String
    /// Already formatted: a percentage for the three that have one, and the
    /// byte counts for network, which has none.
    let value: String

    /// Nil renders as "--" — a source that cannot measure this must not look
    /// like a server sitting at 0%.
    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.0f%%", $0) } ?? "--"
    }

    var body: some View {
        HStack(spacing: 5) {
            // Fixed, so the labels start in the same place. The four SF
            // Symbols here are not the same width, and ragged icons make the
            // column of labels look like it was set by hand.
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            // Network's value is twice as long as a percentage, so it shrinks
            // rather than wrapping: a second line here would break the row
            // grid the other three are read against.
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct PercentChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            AreaMark(x: .value("t", index), y: .value("%", value))
                .foregroundStyle(tint.opacity(0.25))
            LineMark(x: .value("t", index), y: .value("%", value))
                .foregroundStyle(tint)
        }
        .chartYScale(domain: 0 ... 100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        // Whatever the page has left. `Chart` expands on its own once nothing
        // pins it, and the minimum is there for the one caller that is inside
        // a scroll view, where "what is left" is unbounded and a flexible view
        // collapses instead.
        .frame(minHeight: 44, maxHeight: .infinity)
    }
}

private struct NetChart: View {
    let rx: [Double]
    let tx: [Double]

    var body: some View {
        Chart {
            ForEach(Array(rx.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("B/s", value))
                    .foregroundStyle(by: .value("dir", "rx"))
            }
            ForEach(Array(tx.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("B/s", value))
                    .foregroundStyle(by: .value("dir", "tx"))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(minHeight: 44, maxHeight: .infinity)
    }
}

// `PreviewProvider` rather than the `#Preview` macro. The macro is available
// now that this target is watchOS 10, but a preview is not worth a diff.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
