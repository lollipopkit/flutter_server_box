//
//  MonitorClient.swift
//  WatchEnd Watch App
//
//  Reads one server's `/api/v1/metrics` and `/api/v1/metrics/history` with the scoped,
//  read-only token the phone obtained from the agent.
//
//  The watch fetches for itself rather than being fed by the phone, so a watch
//  on Wi-Fi away from its phone still updates.
//

import Foundation

enum MonitorError: LocalizedError {
    case badUrl(String)
    case http(Int, String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badUrl(let s): return s
        case .http(let code, let msg): return msg.isEmpty ? "HTTP \(code)" : msg
        case .decoding(let s): return s
        case .transport(let s): return s
        }
    }
}

/// A reading of one server, already reduced to what a 45mm screen can show.
struct MonitorReading {
    let name: String
    let cpu: Double?
    let mem: Double?
    let disk: Double?
    let memText: String
    let diskText: String
    let netText: String
    let uptime: String?
}

final class MonitorClient: NSObject {
    /// One client per server, so its URLSession connection pool outlives a
    /// single refresh.
    private static var cache: [String: (server: WatchServer, client: MonitorClient)] = [:]
    private static let cacheLock = NSLock()

    static func shared(for server: WatchServer) -> MonitorClient {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // Keyed by id but compared by value: an address or certificate setting
        // the phone changed must not keep talking to the old endpoint.
        if let entry = cache[server.id], entry.server == server {
            return entry.client
        }
        let client = MonitorClient(server: server)
        cache[server.id] = (server, client)
        return client
    }

    let server: WatchServer

    private lazy var session: URLSession = URLSession(
        configuration: .default,
        delegate: self,
        delegateQueue: nil
    )

    init(server: WatchServer) {
        self.server = server
        super.init()
    }

    /// Whether a bearer token may go to this URL.
    ///
    /// The same question the phone asks before every request, and the home
    /// widget after it. Loopback counts as secure without TLS — that is the
    /// reverse proxy on the same host, which really is encrypted — and
    /// everything else in plaintext needs the server's own opt-in. A watch
    /// carries a credential as real as the phone's; the reason it is a
    /// narrower one is that it can be revoked separately, not that it matters
    /// less on the wire.
    private func isSendable(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "https" { return true }
        if server.allowInsecure { return true }
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    /// Base address with any trailing slash removed, so paths can be appended.
    private var base: String {
        let addr = server.addr.trimmingCharacters(in: .whitespacesAndNewlines)
        return addr.hasSuffix("/") ? String(addr.dropLast()) : addr
    }

    // MARK: - Public

    /// Current values plus whatever history the agent has stored.
    ///
    /// History failing is not fatal: an agent that has just started has none,
    /// and a page with live numbers and no chart is better than an error.
    func load() async throws -> (MonitorReading, [HistoryPoint]) {
        let reading = try await loadMetrics()
        let history = (try? await loadHistory()) ?? []
        return (reading, history)
    }

    // MARK: - monitor /api/v1

    private func loadMetrics() async throws -> MonitorReading {
        let metrics: Metrics = try await get("/api/v1/metrics")
        return MonitorReading(
            name: metrics.server_name,
            cpu: Double(metrics.cpu_usage),
            mem: Double(metrics.memory.usage_percent),
            disk: Double(metrics.disk.usage_percent),
            memText: "\(formatBytes(Double(metrics.memory.used))) / \(formatBytes(Double(metrics.memory.total)))",
            diskText: "\(formatBytes(Double(metrics.disk.used))) / \(formatBytes(Double(metrics.disk.total)))",
            netText: "\(formatBytes(Double(metrics.network.rx_bytes))) / \(formatBytes(Double(metrics.network.tx_bytes)))",
            uptime: metrics.uptime
        )
    }

    /// The window, thinned by the agent to what a watch-sized chart can draw.
    ///
    /// `max_points` is what makes the window mean what it says: without it the
    /// agent answers with 300 buckets regardless, and the tail taken from them
    /// covers the newest fifth of the hour rather than the hour. An agent too
    /// old to know the parameter still answers with 300, so the tail is taken
    /// either way.
    private func loadHistory(minutes: Int = 60) async throws -> [HistoryPoint] {
        let maxPoints = WatchSnapshot.maxSeriesPoints
        return try await get(
            "/api/v1/metrics/history?minutes=\(minutes)&max_points=\(maxPoints)"
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: base + path) else {
            throw MonitorError.badUrl(base + path)
        }
        var req = URLRequest(url: url)
        guard isSendable(url) else {
            throw MonitorError.transport("HTTPS required")
        }
        guard let token = WatchStore.token(for: server.id), !token.isEmpty else {
            throw MonitorError.http(401, "No read-only watch token")
        }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await send(req)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MonitorError.decoding("\(error)")
        }
    }

    // MARK: - Transport

    private func send(_ req: URLRequest) async throws -> Data {
        var req = req
        req.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw MonitorError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { return data }
        guard (200 ..< 300).contains(http.statusCode) else {
            // The agent answers errors as `{"error": "..."}`; anything else is
            // shown as the bare status code.
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw MonitorError.http(http.statusCode, obj?["error"] as? String ?? "")
        }
        return data
    }
}

extension MonitorClient: URLSessionDelegate {
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

// MARK: - Wire types

/// Mirrors monitor's `SystemMetrics`, narrowed to the fields the watch shows.
/// Decoding ignores everything else, so agent-side additions are harmless.
private struct Metrics: Decodable {
    struct Memory: Decodable {
        let total: UInt64
        let used: UInt64
        let usage_percent: Double
    }

    struct Disk: Decodable {
        let total: UInt64
        let used: UInt64
        let usage_percent: Double
    }

    struct Network: Decodable {
        let rx_bytes: UInt64
        let tx_bytes: UInt64
    }

    let server_name: String
    let cpu_usage: Double
    let memory: Memory
    let disk: Disk
    let network: Network
    let uptime: String?
}

/// One bucket of monitor's `/api/v1/metrics/history`, oldest first.
struct HistoryPoint: Decodable {
    let cpu: Double
    let memory: Double
    let disk: Double
    let net_rx_speed: Double
    let net_tx_speed: Double
}
