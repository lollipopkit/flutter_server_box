//
//  ContentView.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
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

    @State private var selection: Int = 0

    var body: some View {
        Group {
            if mgr.servers.isEmpty {
                EmptyHint()
            } else {
                TabView(selection: $selection) {
                    // Identified by server, not by index: pages keep their own
                    // load state, and index identity would show one server's
                    // numbers under another's name after the list changes.
                    ForEach(Array(mgr.servers.enumerated()), id: \.element.id) { index, server in
                        ServerPage(server: server).tag(index)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .onAppear { selection = clamped(WatchStore.selectedIndex) }
        .onChange(of: mgr.servers) { _ in selection = clamped(selection) }
        .onChange(of: selection) { newValue in
            // The widget shows whichever server the user last looked at.
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
            Text("Pick servers in the iOS app: Settings → iOS → Watch app.")
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 7) {
                header
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
        }
        // Re-runs when the page is reused for a different server, which is the
        // only way a value-identified page can change servers.
        .task(id: server.id) { await load() }
    }

    private var header: some View {
        HStack {
            Text(displayName)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Button {
                Task { await load() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
    }

    private var displayName: String {
        if case .loaded(let snapshot) = state { return snapshot.name }
        return server.name
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 5) {
                Text(message)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                Link("View help", destination: helpUrl).font(.caption2)
            }
        case .loaded(let snapshot):
            SnapshotView(snapshot: snapshot)
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
                netTxSeries: history.tailValues(\.net_tx_speed)
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

// MARK: - Rendering one reading

private struct SnapshotView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PercentRow(icon: "cpu", label: "CPU", percent: snapshot.cpu, detail: nil)
            if !snapshot.cpuSeries.isEmpty {
                PercentChart(values: snapshot.cpuSeries, tint: .green)
            }

            PercentRow(icon: "memorychip", label: "MEM", percent: snapshot.mem, detail: snapshot.memText)
            if !snapshot.memSeries.isEmpty {
                PercentChart(values: snapshot.memSeries, tint: .blue)
            }

            PercentRow(icon: "externaldrive", label: "DISK", percent: snapshot.disk, detail: snapshot.diskText)

            Label(snapshot.netText, systemImage: "network")
                .font(.system(.caption2, design: .monospaced))
            if !snapshot.netRxSeries.isEmpty || !snapshot.netTxSeries.isEmpty {
                NetChart(rx: snapshot.netRxSeries, tx: snapshot.netTxSeries)
            }

            if let uptime = snapshot.uptime, !uptime.isEmpty {
                Text(uptime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(snapshot.updatedAt, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

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
        .frame(height: 34)
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
        .chartLegend(.hidden)
        .frame(height: 34)
    }
}

// `PreviewProvider` rather than the `#Preview` macro, which needs watchOS 10.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
