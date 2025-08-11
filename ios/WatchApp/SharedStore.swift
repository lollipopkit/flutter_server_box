//
//  SharedStore.swift
//  WatchEnd Watch App
//
//  Created by AI Assistant
//

import Foundation

enum SharedKeys {
    static let suiteId = "group.com.lollipopkit.toolbox" // TODO: replace with your actual App Group ID
    static let urls = "watch_shared_urls"
    static let selectedIndex = "watch_shared_selected_index"
    static let statusByUrl = "watch_shared_status_by_url"
}

struct SharedStore {
    static var defaults: UserDefaults? { UserDefaults(suiteName: SharedKeys.suiteId) }

    static func saveUrls(_ list: [String]) {
        defaults?.set(list, forKey: SharedKeys.urls)
    }

    static func saveSelectedIndex(_ index: Int) {
        defaults?.set(index, forKey: SharedKeys.selectedIndex)
    }

    static func saveStatus(url: String, status: Status) {
        var map = (defaults?.dictionary(forKey: SharedKeys.statusByUrl) as? [String: [String: String]]) ?? [:]
        map[url] = [
            "name": status.name,
            "cpu": status.cpu,
            "mem": status.mem,
            "disk": status.disk,
            "net": status.net,
        ]
        defaults?.set(map, forKey: SharedKeys.statusByUrl)
    }

    // Convenience for reading when needed in-app
    static func getSelectedIndex() -> Int {
        defaults?.integer(forKey: SharedKeys.selectedIndex) ?? 0
    }
}

