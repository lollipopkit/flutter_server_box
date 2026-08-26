//
//  WidgetMonitorClient.swift
//  StatusWidget
//
//  Reads one server's `/api/v1/metrics` and `/api/v1/metrics/history` with the
//  scoped, read-only token the app obtained from the agent.
//
//  The widget fetches for itself rather than being fed by the app, for the
//  same reason the watch app does: a widget refreshes on the system's
//  schedule, and one that only ever showed what the app last saw would be as
//  stale as the last time someone opened it.
//

import Foundation

enum WidgetError: LocalizedError {
    case notConfigured
    case noToken
    case insecure
    case badUrl
    case http(Int, String)
    case transport(String)
    case decoding(String)

    /// `String(localized:)` and not a bare literal: these are drawn on a home
    /// screen, and the target carries a `Localizable.strings` catalog that the
    /// SwiftUI `Text` literals elsewhere already look up. A plain `String` does
    /// not go through it.
    var errorDescription: String? {
        switch self {
        case .notConfigured: return String(localized: "Pick a server")
        case .noToken: return String(localized: "No credential — open the app")
        // Named rather than reported as a network failure, because it is a
        // decision and not a fault: the address is plain HTTP and this server
        // was never opted in to that.
        case .insecure: return String(localized: "HTTPS required")
        case .badUrl: return String(localized: "Bad address")
        // The remaining three carry the agent's or the system's own words,
        // which are not this app's to translate.
        case .http(let code, let msg): return msg.isEmpty ? "HTTP \(code)" : msg
        case .transport(let s): return s
        case .decoding(let s): return s
        }
    }
}

/// One reading, reduced to what a widget can show.
struct WidgetReading {
    let name: String
    let cpu: Double?
    let mem: Double?
    let disk: Double?
    let memText: String
    let diskText: String
    let netText: String
    let uptime: String?
}

/// One bucket of the agent's stored history, oldest first.
struct WidgetHistoryPoint: Decodable {
    let cpu: Double
    let memory: Double
    let disk: Double
    let net_rx_speed: Double
    let net_tx_speed: Double
}

final class WidgetMonitorClient: NSObject {
    private let server: WidgetServer

    fileprivate lazy var session: URLSession = URLSession(
        configuration: .ephemeral,
        delegate: self,
        delegateQueue: nil
    )

    init(server: WidgetServer) {
        self.server = server
        super.init()
    }

    /// Current values plus whatever history the agent has stored.
    ///
    /// History failing is not fatal: an agent that has just started has none,
    /// and numbers with no chart beat an error.
    static func load(server: WidgetServer) async throws -> (WidgetReading, [WidgetHistoryPoint]) {
        let client = WidgetMonitorClient(server: server)
        // A `URLSession` with a delegate holds a strong reference to it until
        // it is invalidated, and this one is built per call — without this the
        // client and its session outlive every timeline refresh.
        defer { client.session.finishTasksAndInvalidate() }
        let reading = try await client.metrics()
        let history = (try? await client.history()) ?? []
        return (reading, history)
    }

    private var base: String {
        let addr = server.addr.trimmingCharacters(in: .whitespacesAndNewlines)
        return addr.hasSuffix("/") ? String(addr.dropLast()) : addr
    }

    /// Whether this connection may carry a credential.
    ///
    /// The same question the app asks before every request. Loopback counts as
    /// secure without TLS — that is the reverse-proxy-on-the-same-host case,
    /// which really is encrypted — and everything else in plaintext needs the
    /// server's own opt-in. `usesCleartextTraffic` in the manifest is the
    /// Android counterpart and answers a different question: whether the
    /// *process* may speak plaintext at all, not whether this server's owner
    /// agreed to send a bearer token over it.
    private func isSendable(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "https" { return true }
        if server.allowInsecure { return true }
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private func metrics() async throws -> WidgetReading {
        let m: Metrics = try await get("/api/v1/metrics")
        return WidgetReading(
            name: m.server_name,
            cpu: m.cpu_usage,
            mem: m.memory.usage_percent,
            disk: m.disk.usage_percent,
            memText: "\(formatWidgetBytes(Double(m.memory.used))) / \(formatWidgetBytes(Double(m.memory.total)))",
            diskText: "\(formatWidgetBytes(Double(m.disk.used))) / \(formatWidgetBytes(Double(m.disk.total)))",
            netText: "\(formatWidgetBytes(Double(m.network.rx_bytes))) / \(formatWidgetBytes(Double(m.network.tx_bytes)))",
            uptime: m.uptime
        )
    }

    /// The window, thinned by the agent to what a sparkline this size can
    /// draw.
    ///
    /// `max_points` is what makes the two numbers mean what they say. Without
    /// it the agent answers with 300 buckets whatever was asked, and the tail
    /// this gets cut down to covered the newest part of the window rather than
    /// the window — three hours requested, seventy minutes drawn. An agent too
    /// old to know the parameter still answers with 300, which is why the tail
    /// is taken anyway.
    private func history(minutes: Int = 180) async throws -> [WidgetHistoryPoint] {
        let maxPoints = WidgetSnapshot.maxSeriesPoints
        return try await get(
            "/api/v1/metrics/history?minutes=\(minutes)&max_points=\(maxPoints)"
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: base + path) else { throw WidgetError.badUrl }
        guard isSendable(url) else { throw WidgetError.insecure }
        guard let token = WidgetStore.token(for: server.id), !token.isEmpty else {
            throw WidgetError.noToken
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Shorter than the app's. A widget's timeline refresh is given a few
        // seconds by the system; spending thirty of them on one request means
        // being killed rather than answering.
        req.timeoutInterval = 8

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw WidgetError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse,
           !(200 ..< 300).contains(http.statusCode) {
            // A scoped token the agent refuses is not going to start working,
            // and leaving it in place wedges the widget until it expires — up
            // to ninety days. Dropping it makes the app mint a replacement on
            // its next publish.
            if http.statusCode == 401 || http.statusCode == 403 {
                WidgetStore.setToken(nil, for: server.id)
                throw WidgetError.noToken
            }
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw WidgetError.http(http.statusCode, obj?["error"] as? String ?? "")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WidgetError.decoding("\(error)")
        }
    }
}

extension WidgetMonitorClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only the certificate check, and only when this server was configured
        // to skip it in the app — a self-signed agent is the common case, and
        // the setting travels with the server rather than being global.
        guard server.ignoreCert,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

/// Byte counts the way the rest of the app prints them ("1.3g"), so a widget
/// and a server card never disagree about the same number.
func formatWidgetBytes(_ bytes: Double) -> String {
    let units = ["b", "k", "m", "g", "t", "p"]
    var value = max(0, bytes)
    var idx = 0
    while value >= 1024, idx < units.count - 1 {
        value /= 1024
        idx += 1
    }
    return idx == 0 ? "\(Int(value))\(units[idx])" : String(format: "%.1f%@", value, units[idx])
}

/// Mirrors the agent's `SystemMetrics`, narrowed to what a widget shows.
/// Decoding ignores everything else, so agent-side additions are harmless.
private struct Metrics: Decodable {
    struct Memory: Decodable {
        let total: UInt64
        let used: UInt64
        let usage_percent: Double?
    }

    struct Disk: Decodable {
        let total: UInt64
        let used: UInt64
        let usage_percent: Double?
    }

    struct Network: Decodable {
        let rx_bytes: UInt64
        let tx_bytes: UInt64
    }

    let server_name: String
    // Optional, matching what the Android widget's parser already tolerates.
    // The agent sends these on every reading, so this is not a case anyone has
    // hit — but one omitted field currently fails the whole decode, and a
    // widget that says "--" for a number is a far better answer than one that
    // says the server is unreachable.
    let cpu_usage: Double?
    let memory: Memory
    let disk: Disk
    let network: Network
    let uptime: String?
}
