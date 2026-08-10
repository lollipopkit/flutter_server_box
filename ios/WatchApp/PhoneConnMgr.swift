//
//  PhoneConnMgr.swift
//  WatchEnd Watch App
//
//  Created by lolli on 2023/9/16.
//

import Foundation
import WatchConnectivity
import WidgetKit

/// Receives the server list from the iPhone app and keeps it on disk.
///
/// Every WatchConnectivity path the phone can use is handled, because which
/// one arrives depends on whether both apps happen to be running:
///
/// - the application context, which is what a watch that was asleep gets, and
///   which is read explicitly at activation rather than only waited for;
/// - a live message, in both the reply-carrying and reply-less shapes — the
///   phone sends the former, and a delegate implementing only the latter
///   cannot receive it at all, which is why the phone's "realtime update"
///   never worked before;
/// - the reply to this app's own `requestData`, which is how a freshly
///   installed watch app configures itself without the user having to open the
///   iPhone's settings page.
final class PhoneConnMgr: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var servers: [WatchServer] = []

    private var session: WCSession?

    override init() {
        super.init()

        servers = WatchStore.servers()
        if servers.isEmpty {
            // TODO: drop with `WatchServer.Kind.legacy`.
            let migrated = WatchStore.migrateLegacyCtx()
            if !migrated.isEmpty {
                WatchStore.setServers(migrated)
                servers = migrated
            }
        }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        // Anything the phone sent while this app was not running is sitting
        // here already; the delegate callback for it is not guaranteed to
        // arrive again, so waiting for one loses the configuration.
        ingest(session.receivedApplicationContext)
        requestLatestData()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // Right after activation the phone app is usually not in the
        // foreground, so `isReachable` is false and the request below would be
        // dropped. Asking again when it flips is what actually gets an answer.
        if session.isReachable { requestLatestData() }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        ingest(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        ingest(message)
        // The sender waits on this; not answering fails its send.
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        ingest(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        ingest(applicationContext)
    }

    // MARK: - Pull

    func requestLatestData() {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["action": "requestData"]) { [weak self] reply in
            self?.ingest(reply)
        } errorHandler: { error in
            // Expected whenever the phone app is not in the foreground; the
            // application context covers that case.
            NSLog("Watch requestData failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Payload

    /// Applies a payload from the phone, ignoring one that carries no server
    /// list at all (an empty reply, or a message about something else).
    private func ingest(_ payload: [String: Any]) {
        guard let parsed = Self.parse(payload) else { return }

        DispatchQueue.main.async {
            for (id, password) in parsed.passwords {
                WatchStore.setPassword(password, for: id)
                // The password is not part of a server's identity, so a client
                // cached against an otherwise unchanged server would keep using
                // a token minted with the old one.
                MonitorClient.forget(id: id)
            }
            WatchStore.setServers(parsed.servers)
            self.servers = parsed.servers
            // The widget reads the same container and would otherwise keep
            // showing a server that is no longer configured.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Payload shape (`WatchSync.buildPayload` on the phone):
    ///
    ///     {"v": 2,
    ///      "servers": [{"id", "name", "addr", "user", "pwd", "ignoreCert"}],
    ///      "urls": ["http://host:3770/status"]}
    ///
    /// `urls` is the pre-v2 shape and is still accepted so an install that has
    /// not been migrated on the phone keeps working.
    static func parse(_ payload: [String: Any]) -> (servers: [WatchServer], passwords: [String: String])? {
        let rawServers = payload["servers"] as? [[String: Any]]
        let rawUrls = payload["urls"] as? [String]
        // Distinguishes "the phone says there are none" from "this isn't a
        // configuration payload"; only the latter is ignored.
        if rawServers == nil, rawUrls == nil { return nil }

        var servers: [WatchServer] = []
        var passwords: [String: String] = [:]

        for entry in rawServers ?? [] {
            guard let id = entry["id"] as? String,
                  let addr = (entry["addr"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !id.isEmpty, !addr.isEmpty
            else { continue }
            servers.append(
                WatchServer(
                    id: id,
                    name: entry["name"] as? String ?? addr,
                    kind: .monitor,
                    addr: addr,
                    user: entry["user"] as? String,
                    ignoreCert: entry["ignoreCert"] as? Bool ?? false
                )
            )
            // Absent means "no password", which has to clear a stored one
            // rather than leave the previous credential in place.
            passwords[id] = entry["pwd"] as? String ?? ""
        }

        // TODO: drop with `WatchServer.Kind.legacy`.
        for url in rawUrls ?? [] where !url.isEmpty {
            servers.append(.legacy(url: url))
        }

        return (servers, passwords)
    }
}
