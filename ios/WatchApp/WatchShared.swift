//
//  WatchShared.swift
//  WatchApp / WatchWidget
//
//  Types both watch targets need. `Utils.swift` can't serve that role: it is
//  built for the app and its iOS extensions, and its `Status` shape is the
//  Go-compat one this app no longer speaks.
//

import Foundation

/// Same identifier as the iOS side, duplicated because no source file is
/// shared across the platform boundary.
let watchAppGroupId = "group.com.lollipopkit.toolbox"

let helpUrl = URL(string: "https://github.com/lollipopkit/flutter_server_box/wiki#home-widget--watchos-app")!

enum WatchKeys {
    /// `[WatchServer]`, JSON. Never contains passwords — those live in the
    /// Keychain, keyed by server id.
    static let servers = "watch_servers"
    /// `[String: WatchSnapshot]` keyed by server id, JSON. Written by the app,
    /// read by the widget.
    static let snapshots = "watch_snapshots"
    /// Which page the user was last on, so the widget shows the same server.
    static let selectedIndex = "watch_shared_selected_index"
    /// Which chart within that page, by `WatchChart.rawValue`. Same purpose,
    /// the other axis.
    static let selectedChart = "watch_shared_selected_chart"
    /// Pre-v2 payload, kept only so an install that has not been opened since
    /// the rewrite can be migrated.
    ///
    /// TODO: drop with `WatchServer.Kind.legacy`.
    static let legacyCtx = "ctx"
}

/// One page of a server's readings.
///
/// The horizontal axis of the watch app: servers page vertically, a server's
/// own metrics page across. Ordered by how often they answer the question
/// someone raised their wrist to ask — the summary first, then the metric most
/// likely to be the reason they looked.
///
/// `Int` raw values because this is persisted for the complication to follow,
/// and appending a case must not renumber the ones already written.
enum WatchChart: Int, CaseIterable, Identifiable {
    case overview = 0
    case cpu = 1
    case memory = 2
    case network = 3
    case disk = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .cpu: return "CPU"
        case .memory: return "MEM"
        case .network: return "NET"
        case .disk: return "DISK"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .disk: return "externaldrive"
        }
    }
}

/// One server the watch may show.
struct WatchServer: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        /// Reached through monitor's `/api/v1`: authenticated, and the only
        /// kind that can produce charts.
        case monitor
        /// A bare Go-compat `/status` URL typed by hand in an older build.
        /// Unauthenticated, current values only.
        ///
        /// TODO: drop with monitor's `/status` compat route.
        case legacy
    }

    let id: String
    let name: String
    let kind: Kind
    /// Base address of the agent for `.monitor`, the full status URL for
    /// `.legacy`.
    let addr: String
    let ignoreCert: Bool

    init(id: String, name: String, kind: Kind, addr: String, ignoreCert: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.addr = addr
        self.ignoreCert = ignoreCert
    }
}

/// The last successful reading of one server, in the shape both the app and
/// the widget render.
///
/// Percentages are optional because a source that cannot report one must show
/// as "no data" rather than as a convincing 0%.
struct WatchSnapshot: Codable, Hashable {
    let serverId: String
    let name: String
    let updatedAt: Date

    let cpu: Double?
    let mem: Double?
    let disk: Double?

    let memText: String
    let diskText: String
    let netText: String
    let uptime: String?

    /// Oldest first, and all of them share an index. Empty for a source with no
    /// history (`.legacy`, or an agent that has not stored any yet).
    let cpuSeries: [Double]
    let memSeries: [Double]
    let netRxSeries: [Double]
    let netTxSeries: [Double]

    /// Optional only so a snapshot written before the disk chart existed still
    /// decodes. Absent means the same as empty — and a whole-dictionary decode
    /// failure would blank every server's last reading at once, not just this
    /// one's, which is why it is not simply a new non-optional field.
    ///
    /// TODO: make this non-optional once no install can still be carrying a
    /// snapshot from before it.
    let diskSeries: [Double]?

    /// The disk history, however it was stored.
    var diskTrend: [Double] { diskSeries ?? [] }

    /// Bounds what goes into the App Group: the widget draws a sparkline a few
    /// hundred points wide at most, and the container is shared with the app.
    static let maxSeriesPoints = 60

    static func placeholder(name: String) -> WatchSnapshot {
        WatchSnapshot(
            serverId: "", name: name, updatedAt: Date(),
            cpu: nil, mem: nil, disk: nil,
            memText: "-", diskText: "-", netText: "-", uptime: nil,
            cpuSeries: [], memSeries: [], netRxSeries: [], netTxSeries: [],
            diskSeries: []
        )
    }
}

/// Byte counts the way the rest of the app prints them ("1.3g"), so a watch
/// face and a server card don't disagree about the same number.
func formatBytes(_ bytes: Double) -> String {
    let units = ["b", "k", "m", "g", "t", "p"]
    var value = max(0, bytes)
    var idx = 0
    while value >= 1024, idx < units.count - 1 {
        value /= 1024
        idx += 1
    }
    return idx == 0 ? "\(Int(value))\(units[idx])" : String(format: "%.1f%@", value, units[idx])
}
