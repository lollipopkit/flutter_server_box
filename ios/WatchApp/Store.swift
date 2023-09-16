//
//  Store.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import Foundation

class Store {
    static let defaults = UserDefaults.standard

    static let _ctxKey = "ctx"
    static func getCtx() -> [String: Any] {
        return defaults.object(forKey: _ctxKey) as? [String: Any] ?? [:]
    }
    static func setCtx(_ ctx: [String: Any]) {
        defaults.set(ctx, forKey: _ctxKey)
    }
}
