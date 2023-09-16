//
//  Utils.swift
//  Runner
//
//  Created by lolli on 2023/9/16.
//

import Foundation

extension Date {
    func toStr() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
}

enum ContentState {
    case loading
    case error(String)
    case normal(Status)
}

struct Status {
    let name: String
    let cpu: String
    let mem: String
    let disk: String
    let net: String
}
