//
//  MonitorClient.swift
//  WatchEnd Watch App
//
//  Talks to one server's `monitor` agent, the same way the Flutter app's
//  `MonitorHttpClient` does: log in for a JWT, then read `/api/v1/metrics` and
//  `/api/v1/metrics/history`.
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
    /// One client per server, so the JWT outlives a single refresh.
    ///
    /// Logging in costs the agent a bcrypt verification (~100ms by design); a
    /// fresh client per wrist raise would pay it every time and count against
    /// the agent's login throttle.
    private static var cache: [String: (server: WatchServer, client: MonitorClient)] = [:]
    private static let cacheLock = NSLock()

    static func shared(for server: WatchServer) -> MonitorClient {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // Keyed by id but compared by value: an address, user or password the
        // phone changed must not keep talking to the old endpoint with the old
        // token.
        if let entry = cache[server.id], entry.server == server {
            return entry.client
        }
        let client = MonitorClient(server: server)
        cache[server.id] = (server, client)
        return client
    }

    /// Drops the cached token, so the next call logs in again.
    ///
    /// Used when a password may have changed underneath us — the credential
    /// lives in the Keychain and is not part of `WatchServer`'s identity.
    static func forget(id: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[id] = nil
    }

    let server: WatchServer

    private var token: String?
    private lazy var session: URLSession = URLSession(
        configuration: .default,
        delegate: self,
        delegateQueue: nil
    )

    init(server: WatchServer) {
        self.server = server
        super.init()
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
        switch server.kind {
        case .legacy:
            return (try await loadLegacy(), [])
        case .monitor:
            let reading = try await loadMetrics()
            let history = (try? await loadHistory()) ?? []
            return (reading, history)
        }
    }

    // MARK: - monitor /api/v1

    private func loadMetrics() async throws -> MonitorReading {
        let metrics: Metrics = try await authed { try await self.get("/api/v1/metrics") }
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

    private func loadHistory(minutes: Int = 60) async throws -> [HistoryPoint] {
        try await authed { try await self.get("/api/v1/metrics/history?minutes=\(minutes)") }
    }

    /// Runs `fn` with a token, taking one first if there is none and taking a
    /// fresh one once if the agent rejects the one we have.
    private func authed<T: Decodable>(_ fn: @escaping () async throws -> T) async throws -> T {
        if token == nil { try await login() }
        do {
            return try await fn()
        } catch MonitorError.http(401, _) {
            token = nil
            try await login()
            return try await fn()
        }
    }

    private func login() async throws {
        guard let url = URL(string: base + "/api/v1/login") else {
            throw MonitorError.badUrl(base)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "username": server.user ?? "",
            "password": WatchStore.password(for: server.id) ?? "",
        ])

        let data = try await send(req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["token"] as? String, !token.isEmpty
        else {
            throw MonitorError.decoding("No token in login response")
        }
        self.token = token
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: base + path) else {
            throw MonitorError.badUrl(base + path)
        }
        var req = URLRequest(url: url)
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data = try await send(req)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MonitorError.decoding("\(error)")
        }
    }

    // MARK: - Go-compat /status

    /// TODO: drop with `WatchServer.Kind.legacy`.
    private func loadLegacy() async throws -> MonitorReading {
        guard let url = URL(string: server.addr) else {
            throw MonitorError.badUrl(server.addr)
        }
        let data = try await send(URLRequest(url: url))
        guard let all = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MonitorError.decoding("Not JSON")
        }
        if let code = all["code"] as? Int, code != 0 {
            throw MonitorError.http(code, all["msg"] as? String ?? "")
        }
        let json = all["data"] as? [String: Any] ?? [:]
        let cpuText = json["cpu"] as? String ?? ""
        return MonitorReading(
            name: json["name"] as? String ?? server.name,
            cpu: Double(cpuText.trimmingCharacters(in: CharacterSet(charactersIn: "% "))),
            mem: nil,
            disk: nil,
            memText: json["mem"] as? String ?? "-",
            diskText: json["disk"] as? String ?? "-",
            netText: json["net"] as? String ?? "-",
            uptime: nil
        )
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
