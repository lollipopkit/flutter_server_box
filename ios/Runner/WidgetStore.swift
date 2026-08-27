//
//  WidgetStore.swift
//  Runner / StatusWidget
//
//  Where the home-screen widgets find the server list and the credential to
//  fetch it with.
//
//  Two containers, for the same reason `WatchStore` uses two:
//
//  - The App Group holds the list — name, address, certificate handling. Not
//    secret, and the widget extension has to be able to read it before the
//    user has picked anything, since it *is* what they pick from.
//  - The Keychain holds the scoped token. `UserDefaults` is a plist on disk;
//    a read-only bearer credential is still a credential.
//
//  Reaching the Keychain from both processes needs the shared access group in
//  `keychain-access-groups` — the default group is per-target, so a token the
//  app wrote would be invisible to the extension and it would silently fetch
//  nothing.
//

import Foundation

enum WidgetKeys {
    /// `[WidgetServer]`, JSON. Never contains a token.
    static let servers = "widget_servers"
    /// `[String: WidgetSnapshot]` keyed by server id, JSON. Written by
    /// whichever process last fetched, read when a fetch fails or has not
    /// happened yet.
    static let snapshots = "widget_snapshots"
}

/// One server a widget may be pointed at.
///
/// `Codable` and deliberately flat: this is decoded by an extension that gets
/// a few seconds to draw, and by an `EntityQuery` that runs while the user is
/// looking at a configuration sheet.
struct WidgetServer: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    /// Base address of the agent, no trailing slash.
    let addr: String
    let ignoreCert: Bool
    /// Whether this server was opted in to plaintext HTTP in the app.
    ///
    /// Carried rather than inferred from the scheme, because the question is
    /// not "is this http" but "did its owner agree to send a bearer token over
    /// it". `MonitorHttpCredential.allowInsecure` is where that was answered.
    let allowInsecure: Bool
    /// When the stored token lapses, seconds since epoch. Zero means there is
    /// no token — the app could not reach the agent when it last published.
    let tokenExpiresAt: Int

    var hasToken: Bool { tokenExpiresAt > 0 }
}

/// The last successful reading of one server, in the shape the widgets render.
///
/// Percentages are optional so a source that could not report one shows as no
/// data rather than as a convincing 0%. The same rule `WatchSnapshot` follows,
/// and the two are separate types on purpose: they live on different devices
/// and are versioned by different app releases.
struct WidgetSnapshot: Codable, Hashable {
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

    /// Oldest first, all sharing an index. Empty for an agent that has stored
    /// no history yet.
    let cpuSeries: [Double]
    let memSeries: [Double]
    let diskSeries: [Double]
    let netRxSeries: [Double]
    let netTxSeries: [Double]

    /// Bounds what goes into the App Group. A large widget draws about a
    /// hundred points across; the container is shared with the app and with
    /// every other widget's snapshot.
    static let maxSeriesPoints = 120

    static func placeholder(name: String) -> WidgetSnapshot {
        WidgetSnapshot(
            serverId: "", name: name, updatedAt: Date(),
            cpu: nil, mem: nil, disk: nil,
            memText: "-", diskText: "-", netText: "-", uptime: nil,
            cpuSeries: [], memSeries: [], diskSeries: [],
            netRxSeries: [], netTxSeries: []
        )
    }
}

enum WidgetStore {
    /// Falls back to `.standard` so a build whose App Group entitlement is
    /// missing still works within one process — the app keeps its list, only
    /// the extension goes blank. Losing the list entirely would be worse.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    private static let keychainService = "tech.lolli.toolbox.widget.monitor.token"

    /// Named explicitly on every query rather than left to the default.
    ///
    /// The default is the *first* entry of `keychain-access-groups`, and that
    /// slot belongs to the app's own group — the database encryption key goes
    /// through `flutter_secure_storage`, which names no group, and it must not
    /// start landing somewhere an extension can read it. So this is the second
    /// entry in both entitlement files, and nothing reaches it without asking.
    ///
    /// `$(AppIdentifierPrefix)` is substituted by Xcode at build time, so the
    /// team id is only knowable at runtime; the Info.plist key carries it
    /// across. Nil means the lookup failed, and every query then falls back to
    /// the default group — where the app's own writes would still be found,
    /// but the extension's would not, which is a widget that reads nothing
    /// rather than one that reads the wrong thing.
    private static var accessGroup: String? {
        guard let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String,
              !prefix.hasPrefix("$(")
        else { return nil }
        return "\(prefix)com.lollipopkit.toolbox.widgets"
    }

    // MARK: - Servers

    static func servers() -> [WidgetServer] {
        guard let data = defaults.data(forKey: WidgetKeys.servers) else { return [] }
        return (try? JSONDecoder().decode([WidgetServer].self, from: data)) ?? []
    }

    static func server(id: String) -> WidgetServer? {
        servers().first { $0.id == id }
    }

    /// Replaces the whole list, and drops anything left behind by a server
    /// that is no longer in it.
    ///
    /// A full replacement rather than a merge because the app publishes the
    /// whole set every time: a server deleted there must not keep a live
    /// credential here, and a merge has no way to notice it is gone.
    static func setServers(_ servers: [WidgetServer]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: WidgetKeys.servers)

        let live = Set(servers.map(\.id))
        for id in snapshots().keys where !live.contains(id) {
            removeSnapshot(id: id)
        }
        for id in tokenAccounts() where !live.contains(id) {
            setToken(nil, for: id)
        }
    }

    // MARK: - Snapshots

    static func snapshots() -> [String: WidgetSnapshot] {
        guard let data = defaults.data(forKey: WidgetKeys.snapshots) else { return [:] }
        return (try? JSONDecoder().decode([String: WidgetSnapshot].self, from: data)) ?? [:]
    }

    static func snapshot(id: String) -> WidgetSnapshot? { snapshots()[id] }

    static func setSnapshot(_ snapshot: WidgetSnapshot) {
        var all = snapshots()
        all[snapshot.serverId] = snapshot
        writeSnapshots(all)
    }

    static func removeSnapshot(id: String) {
        var all = snapshots()
        guard all.removeValue(forKey: id) != nil else { return }
        writeSnapshots(all)
    }

    private static func writeSnapshots(_ all: [String: WidgetSnapshot]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: WidgetKeys.snapshots)
    }

    // MARK: - Tokens

    private static func baseQuery(_ id: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    static func token(for id: String) -> String? {
        var query = baseQuery(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setToken(_ token: String?, for id: String) {
        let query = baseQuery(id)
        SecItemDelete(query as CFDictionary)

        guard let token, !token.isEmpty, let data = token.data(using: .utf8) else { return }
        var attrs = query
        attrs[kSecValueData as String] = data
        // A widget's timeline is refreshed while the device sits locked in a
        // pocket, so anything stricter than this would fail exactly when the
        // widget is meant to be updating.
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func tokenAccounts() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        var items: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
              let entries = items as? [[String: Any]]
        else { return [] }
        return entries.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
