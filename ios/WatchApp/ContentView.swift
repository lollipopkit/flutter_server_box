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
        .onAppear { serverIndex = clamped(WatchStore.selectedIndex) }
        .onChange(of: mgr.servers) { _ in serverIndex = clamped(serverIndex) }
        .onChange(of: serverIndex) { newValue in
            // The complication shows whichever server the user last looked at.
            WatchStore.selectedIndex = newValue
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func clamped(_ index: Int) -> Int {
        guard !mgr.servers.isEmpty else { return 0 }
        return min(max(0, index), mgr.servers.count - 1)
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

    var body: some View {
        ScrollView {
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
                PercentRow(icon: "cpu", label: "CPU", percent: snapshot.cpu, detail: nil)
                PercentRow(icon: "memorychip", label: "MEM", percent: snapshot.mem, detail: snapshot.memText)
                PercentRow(icon: "externaldrive", label: "DISK", percent: snapshot.disk, detail: snapshot.diskText)
                Label(snapshot.netText, systemImage: "network")
                    .font(.system(.caption2, design: .monospaced))
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
                label: "MEM",
                percent: snapshot.mem,
                detail: snapshot.memText,
                series: snapshot.memSeries,
                tint: .blue
            )
        case .disk:
            MetricPage(
                label: "DISK",
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
    }
}

/// An agent that has only just started has no history, which is not an error
/// and must not be drawn as a flat line at zero.
private struct NoHistoryHint: View {
    var body: some View {
        Text("No history yet")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
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

private struct PercentRow: View {
    let icon: String
    let label: String
    /// Nil renders as "no data" — a source that cannot measure this must not
    /// look like a server sitting at 0%.
    let percent: Double?
    let detail: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(percent.map { String(format: "%.0f%%", $0) } ?? "--")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
        .frame(height: 74)
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
        .frame(height: 74)
    }
}

// `PreviewProvider` rather than the `#Preview` macro. The macro is available
// now that this target is watchOS 10, but a preview is not worth a diff.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
