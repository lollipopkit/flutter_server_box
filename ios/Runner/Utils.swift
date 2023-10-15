//
//  Utils.swift
//  Runner
//
//  Created by lolli on 2023/9/16.
//

import Foundation

let accessoryKey = "accessory_widget_url"

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

enum ErrType: Error {
    case url(String)
    case http(String)
}

enum ContentState {
    case loading
    case error(ErrType)
    case normal(Status)
}

struct Status {
    let name: String
    let cpu: String
    let mem: String
    let disk: String
    let net: String
}
