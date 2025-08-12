//
//  LiveActivityManager.swift
//  Runner
//
//  Handles starting/updating/stopping Terminal Live Activities from Flutter via MethodChannel.
//

import Foundation
import ActivityKit

@available(iOS 16.2, *)
class LiveActivityManager {
    static var current: Activity<TerminalAttributes>?

    struct Payload: Decodable {
        let id: String
        let title: String
        let subtitle: String
        let startTimeMs: Int
        let status: String
        let hasTerminal: Bool?
    }

    private static func parse(_ json: String) -> Payload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    static func start(json: String) {
        guard #available(iOS 16.2, *) else { return }
        guard let p = parse(json) else { return }
        let attributes = TerminalAttributes(id: p.id)
        let date = Date(timeIntervalSince1970: TimeInterval(p.startTimeMs) / 1000.0)
        let state = TerminalAttributes.ContentState(
            id: p.id,
            title: p.title,
            subtitle: p.subtitle,
            status: p.status,
            startTime: date,
            hasTerminal: p.hasTerminal ?? true
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            current = try Activity<TerminalAttributes>.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // ignore
        }
    }

    static func update(json: String) {
        guard #available(iOS 16.2, *) else { return }
        guard let p = parse(json) else { return }
        let date = Date(timeIntervalSince1970: TimeInterval(p.startTimeMs) / 1000.0)
        let state = TerminalAttributes.ContentState(
            id: p.id,
            title: p.title,
            subtitle: p.subtitle,
            status: p.status,
            startTime: date,
            hasTerminal: p.hasTerminal ?? true
        )
        if let activity = current {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            start(json: json)
        }
    }

    static func stop() {
        guard #available(iOS 16.2, *) else { return }
        if let activity = current {
            Task { await activity.end(dismissalPolicy: .immediate) }
            current = nil
        }
    }
}

