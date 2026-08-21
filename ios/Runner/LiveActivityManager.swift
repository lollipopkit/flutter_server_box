//
//  LiveActivityManager.swift
//  Runner
//
//  Handles starting/updating/stopping Terminal Live Activities from Flutter via MethodChannel.
//

import Foundation
import ActivityKit

/// Owns the app's single Terminal Live Activity.
///
/// An actor rather than a namespace of statics, for two reasons.
///
/// `Activity.request` is synchronous and makes a blocking XPC round trip to
/// `liveactivitiesd`. Called straight from the MethodChannel handler it ran on
/// the main thread, so the whole UI stopped for as long as that daemon took to
/// answer — visible when the first activity of a run is requested.
///
/// And `current` was read and written from every detached `Task` the old code
/// spawned, with nothing ordering them.
@available(iOS 16.2, *)
actor LiveActivityManager {
    static let shared = LiveActivityManager()

    /// `Activity.request` parks the thread it is called on. Keep it off the
    /// cooperative pool, whose threads are counted.
    private static let requestQueue = DispatchQueue(label: "tech.lolli.toolbox.live-activity")

    private var current: Activity<TerminalAttributes>?

    private struct Payload: Decodable {
        let id: String
        let title: String
        let subtitle: String
        let startTimeMs: Int
        let status: String
        let hasTerminal: Bool?
        let connectionCount: Int?
    }

    private static func parse(_ json: String) -> Payload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// The multi-session title is localized here rather than in Dart, so it
    /// follows the language the widget renders in. Terminals and not
    /// connections: two of them can be shells on this device, inside the Linux
    /// userland the app installed, with nothing connected to anything.
    ///
    /// The subtitle is whatever Dart sent. It used to be a fixed "Multiple SSH
    /// sessions active", which said SSH about whatever happened to be open —
    /// two local Alpine shells included. What Dart sends instead is their
    /// names, which is both true and worth reading.
    private static func contentState(from p: Payload) -> TerminalAttributes.ContentState {
        let isMulti = (p.id == "multi_connections")
        let title = isMulti
            ? String(format: NSLocalizedString("%d terminals", comment: "Title for several open terminals"), p.connectionCount ?? 1)
            : p.title
        let subtitle = p.subtitle
        return TerminalAttributes.ContentState(
            id: p.id,
            title: title,
            subtitle: subtitle,
            status: p.status,
            startTime: Date(timeIntervalSince1970: TimeInterval(p.startTimeMs) / 1000.0),
            hasTerminal: p.hasTerminal ?? true,
            connectionCount: p.connectionCount ?? 1
        )
    }

    private func trackedActivities() -> [Activity<TerminalAttributes>] {
        var activities = Activity<TerminalAttributes>.activities
        if let current = current, !activities.contains(where: { $0.id == current.id }) {
            activities.append(current)
        }
        return activities
    }

    private func updatableActivity() -> Activity<TerminalAttributes>? {
        if let current = current,
           current.activityState == .active || current.activityState == .stale {
            return current
        }
        let activity = Activity<TerminalAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
        current = activity
        return activity
    }

    func start(json: String) async {
        guard let payload = Self.parse(json) else { return }

        if let activity = updatableActivity() {
            let content = ActivityContent(state: Self.contentState(from: payload), staleDate: nil)
            await apply(content, to: activity)
            return
        }

        current = await Self.request(payload)
    }

    func update(json: String) async {
        guard let payload = Self.parse(json) else { return }
        guard let activity = updatableActivity() else {
            await start(json: json)
            return
        }
        let content = ActivityContent(state: Self.contentState(from: payload), staleDate: nil)
        await apply(content, to: activity)
    }

    func stop() async {
        let activities = trackedActivities()
        current = nil
        for activity in activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    /// Push `content` to the activity we keep, and end any other one the system
    /// still has — a previous run can leave one behind.
    private func apply(
        _ content: ActivityContent<TerminalAttributes.ContentState>,
        to activity: Activity<TerminalAttributes>
    ) async {
        current = activity
        let duplicates = trackedActivities().filter { $0.id != activity.id }
        await activity.update(content)
        for duplicate in duplicates {
            await duplicate.end(dismissalPolicy: .immediate)
        }
    }

    /// The payload rather than the built content crosses onto the queue, because
    /// `ActivityContent` is not `Sendable` and `Payload` implicitly is.
    private static func request(_ payload: Payload) async -> Activity<TerminalAttributes>? {
        await withCheckedContinuation { continuation in
            requestQueue.async {
                let content = ActivityContent(state: contentState(from: payload), staleDate: nil)
                continuation.resume(
                    returning: try? Activity<TerminalAttributes>.request(
                        attributes: TerminalAttributes(id: payload.id),
                        content: content,
                        pushType: nil
                    )
                )
            }
        }
    }
}
