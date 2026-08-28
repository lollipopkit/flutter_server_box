import Foundation
import MetricKit

/// The macOS half of native crash reporting: what the system recorded about a
/// crash this app could not see.
///
/// A SIGSEGV in the Rust FFI or in sqlite ends the process outright — no Dart
/// handler runs, nothing is written, and the next launch looks like a clean
/// start. MetricKit is the platform's own record of it.
///
/// The same file as `ios/Runner/CrashDiagnostics.swift` apart from the
/// availability annotation. The two Xcode projects are separate and neither
/// can reference the other's sources, so this is a copy; keep them in step.
///
/// **Delivery is on the system's schedule, not ours.** A payload arrives
/// somewhere between the next launch and roughly a day later, so a record
/// showing up now may describe a crash from several sessions ago. That is why
/// these are accumulated rather than read at a fixed point: whenever Dart next
/// asks, it gets whatever has arrived since it last asked.
@available(macOS 12.0, *)
final class CrashDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashDiagnostics()

    private static let storeKey = "sb_crash_diagnostics_pending"

    /// Enough to explain a pattern, few enough that a machine left offline for
    /// a month does not accumulate without bound. Oldest are dropped.
    private static let maxStored = 8

    /// The call stack is the large field by far, and a truncated one still
    /// names the top frames — which is the part that identifies a crash.
    private static let maxCallStackChars = 16 * 1024

    private override init() { super.init() }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var records: [[String: Any]] = []

        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                var record: [String: Any] = [
                    "kind": "crash",
                    // On the diagnostic's own metadata rather than the
                    // payload: one payload can carry diagnostics from several
                    // builds, since delivery lags the crash by up to a day and
                    // the app may have updated in between.
                    "appVersion": crash.metaData.applicationBuildVersion,
                    "osVersion": crash.metaData.osVersion,
                    "callStack": Self.callStack(crash.callStackTree),
                ]
                // Every one of these is optional in the API and any of them
                // can be absent in a real payload.
                if let signal = crash.signal { record["signal"] = signal }
                if let type = crash.exceptionType { record["exceptionType"] = type }
                if let code = crash.exceptionCode { record["exceptionCode"] = code }
                if let reason = crash.terminationReason {
                    record["terminationReason"] = reason
                }
                records.append(record)
            }

            // A hang is not a crash, and is reported as itself: the app was
            // alive and unresponsive, which is a different bug from a dead
            // process and has different causes.
            for hang in payload.hangDiagnostics ?? [] {
                records.append([
                    "kind": "hang",
                    "appVersion": hang.metaData.applicationBuildVersion,
                    "osVersion": hang.metaData.osVersion,
                    "duration": hang.hangDuration.value,
                    "callStack": Self.callStack(hang.callStackTree),
                ])
            }
        }

        guard !records.isEmpty else { return }
        Self.append(records)
    }

    /// Also required by the protocol. Metrics are usage statistics rather than
    /// failures, and nothing here collects them.
    func didReceive(_ payloads: [MXMetricPayload]) {}

    /// Everything accumulated since the last call, which it clears.
    ///
    /// Cleared on read because the caller writes them into a log that persists
    /// — keeping them here as well would report the same crash on every launch.
    static func take() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        let stored = defaults.array(forKey: storeKey) as? [[String: Any]] ?? []
        if !stored.isEmpty { defaults.removeObject(forKey: storeKey) }
        return stored
    }

    private static func append(_ records: [[String: Any]]) {
        let defaults = UserDefaults.standard
        var stored = defaults.array(forKey: storeKey) as? [[String: Any]] ?? []
        stored.append(contentsOf: records)
        if stored.count > maxStored {
            stored.removeFirst(stored.count - maxStored)
        }
        defaults.set(stored, forKey: storeKey)
    }

    private static func callStack(_ tree: MXCallStackTree) -> String {
        guard let text = String(data: tree.jsonRepresentation(), encoding: .utf8)
        else { return "" }
        if text.count <= maxCallStackChars { return text }
        return String(text.prefix(maxCallStackChars)) + "\n… truncated"
    }
}
