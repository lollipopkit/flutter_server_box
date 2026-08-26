//
//  WatchShared.swift
//  WatchApp / WatchWidget
//
//  Types both watch targets need. `Utils.swift` can't serve that role: it is
//  built for the app and its iOS extensions, which are a different platform —
//  no source file is shared across that boundary.
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
    /// Which server the user was last on, by id, so the complication shows the
    /// same one.
    ///
    /// By id and not by position. The list is ordered by name and the phone
    /// republishes it on every change, so renaming a server reorders it — and
    /// a stored index would then point at a different machine, silently, with
    /// the complication following along.
    static let selectedServerId = "watch_shared_selected_server_id"
    /// Which chart within that page, by `WatchChart.rawValue`. Same purpose,
    /// the other axis.
    static let selectedChart = "watch_shared_selected_chart"
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
        case .memory: return "Mem"
        case .network: return "Net"
        case .disk: return "Disk"
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
    let id: String
    let name: String
    /// Base address of the agent, no trailing slash.
    let addr: String
    let ignoreCert: Bool
    /// Whether this server was opted in to plaintext HTTP in the app.
    ///
    /// Checked before the token is sent (`MonitorClient`), never at storage
    /// time — the same question the phone asks, answered the same way, since
    /// the credential the watch holds is as good as the one the phone does.
    let allowInsecure: Bool

    init(
        id: String,
        name: String,
        addr: String,
        ignoreCert: Bool = false,
        allowInsecure: Bool = false
    ) {
        self.id = id
        self.name = name
        self.addr = addr
        self.ignoreCert = ignoreCert
        self.allowInsecure = allowInsecure
    }

    /// Hand-written for `allowInsecure` alone: a list stored by a build that
    /// predates the key would otherwise fail to decode *entirely*, and
    /// `Store.servers()` answers a decoding failure with an empty list — so
    /// adding this field would have emptied the watch until the next push.
    /// Absent reads as false, which is the refusing answer.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        addr = try c.decode(String.self, forKey: .addr)
        ignoreCert = try c.decodeIfPresent(Bool.self, forKey: .ignoreCert) ?? false
        allowInsecure = try c.decodeIfPresent(Bool.self, forKey: .allowInsecure) ?? false
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

    /// Oldest first, and all of them share an index. Empty for an agent that
    /// has not stored any history yet.
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
