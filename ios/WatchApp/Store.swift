//
//  Store.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import Foundation

/// Where the watch keeps what the phone sent it.
///
/// Two containers on purpose:
///
/// - The App Group holds the server list and the last reading, because the
///   widget process has to read them too.
/// - The Keychain holds scoped monitor tokens. `UserDefaults` is a plist on
///   disk; even a read-only bearer credential does not belong there.
enum WatchStore {
    /// Falls back to `.standard` so that a build whose App Group entitlement
    /// is missing or mis-provisioned still works as an app — only the widget
    /// goes stale, which beats losing the server list entirely.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: watchAppGroupId) ?? .standard
    }

    private static let keychainService = "tech.lolli.toolbox.watch.monitor.token"
    private static let legacyPasswordService = "tech.lolli.toolbox.watch.monitor"

    // MARK: - Servers

    static func servers() -> [WatchServer] {
        guard let data = defaults.data(forKey: WatchKeys.servers) else { return [] }
        return (try? JSONDecoder().decode([WatchServer].self, from: data)) ?? []
    }

    static func setServers(_ servers: [WatchServer]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: WatchKeys.servers)

        // A server the phone stopped sending must not leave its token (or a
        // stale reading) behind on the watch.
        let live = Set(servers.map(\.id))
        for id in snapshots().keys where !live.contains(id) {
            removeSnapshot(id: id)
        }
        for id in tokenAccounts() where !live.contains(id) {
            setToken(nil, for: id)
        }
        for id in tokenAccounts(service: legacyPasswordService) where !live.contains(id) {
            setToken(nil, for: id)
        }
    }

    // MARK: - Selection

    static var selectedIndex: Int {
        get { defaults.integer(forKey: WatchKeys.selectedIndex) }
        set { defaults.set(newValue, forKey: WatchKeys.selectedIndex) }
    }

    /// Which chart the user was last on, so the complication shows the same
    /// one. Defaults to the overview, which is also what an unset key reads as.
    static var selectedChart: WatchChart {
        get { WatchChart(rawValue: defaults.integer(forKey: WatchKeys.selectedChart)) ?? .overview }
        set { defaults.set(newValue.rawValue, forKey: WatchKeys.selectedChart) }
    }

    // MARK: - Snapshots

    static func snapshots() -> [String: WatchSnapshot] {
        guard let data = defaults.data(forKey: WatchKeys.snapshots) else { return [:] }
        return (try? JSONDecoder().decode([String: WatchSnapshot].self, from: data)) ?? [:]
    }

    static func snapshot(id: String) -> WatchSnapshot? {
        snapshots()[id]
    }

    static func setSnapshot(_ snapshot: WatchSnapshot) {
        var all = snapshots()
        all[snapshot.serverId] = snapshot
        writeSnapshots(all)
    }

    static func removeSnapshot(id: String) {
        var all = snapshots()
        guard all.removeValue(forKey: id) != nil else { return }
        writeSnapshots(all)
    }

    private static func writeSnapshots(_ all: [String: WatchSnapshot]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: WatchKeys.snapshots)
    }

    // MARK: - Tokens

    static func token(for id: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setToken(_ token: String?, for id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(query as CFDictionary)
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyPasswordService,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(legacyQuery as CFDictionary)

        guard let token, !token.isEmpty, let data = token.data(using: .utf8) else { return }
        var attrs = query
        attrs[kSecValueData as String] = data
        // The watch is unlocked whenever it is on the wrist, and a refresh may
        // run while the screen is off; anything stricter would fail there.
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func tokenAccounts() -> [String] {
        tokenAccounts(service: keychainService)
    }

    private static func tokenAccounts(service: String) -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var items: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
              let entries = items as? [[String: Any]]
        else { return [] }
        return entries.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
