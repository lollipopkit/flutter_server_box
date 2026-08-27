//
//  Utils.swift
//  Runner
//
//  Created by lolli on 2023/9/16.
//

import Foundation

/// Shared between the app and its iOS extensions. The watch targets cannot see
/// this file (they build for a different platform and carry their own copy in
/// `WatchShared.swift`), so the literal is duplicated there on purpose.
let appGroupId = "group.com.lollipopkit.toolbox"

let helpUrl = URL(string: "https://github.com/lollipopkit/flutter_server_box/wiki#home-widget--watchos-app")!

extension Date {
    func toStr() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
}

