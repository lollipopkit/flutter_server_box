//
//  SharedStore.swift (Widget)
//  WatchStatusWidget Extension
//
//  Created by AI Assistant
//

import Foundation

enum SharedKeysWidget {
    static let suiteId = "group.com.lollipopkit.toolbox" // TODO: replace with your actual App Group ID
    static let urls = "watch_shared_urls"
    static let selectedIndex = "watch_shared_selected_index"
    static let statusByUrl = "watch_shared_status_by_url"
}

struct WidgetSharedStore {
    static var defaults: UserDefaults? { UserDefaults(suiteName: SharedKeysWidget.suiteId) }

    static func readUrls() -> [String] {
        (defaults?.array(forKey: SharedKeysWidget.urls) as? [String]) ?? []
    }

    static func readSelectedIndex() -> Int {
        defaults?.integer(forKey: SharedKeysWidget.selectedIndex) ?? 0
    }

    static func readStatus(url: String) -> Status? {
        guard let map = defaults?.dictionary(forKey: SharedKeysWidget.statusByUrl) as? [String: [String: String]],
              let dic = map[url]
        else { return nil }
        let name = dic["name"] ?? ""
        let cpu = dic["cpu"] ?? ""
        let mem = dic["mem"] ?? ""
        let disk = dic["disk"] ?? ""
        let net = dic["net"] ?? ""
        return Status(name: name, cpu: cpu, mem: mem, disk: disk, net: net)
    }
}

