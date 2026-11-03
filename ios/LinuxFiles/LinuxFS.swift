import FileProvider
import Foundation

/// The installed Linux systems, as `IosRootfs` lays them out: directories
/// under `File Provider Storage/linux` in the App Group, each holding the
/// marker the app writes when it installs one.
///
/// An item's identifier is `<system>:<guest path>`, as on Android
/// (`LinuxDocumentsProvider`). Every access resolves that path with
/// [GuestPath], so a link points where it points for the guest, and neither a
/// link nor a crafted identifier reaches anything outside the system.
enum LinuxFS {
    /// `LinuxProfile.marker`.
    static let marker = ".installed"
    /// The system's `/dev`, a fakefs whose database the engine has mounted.
    static let devStore = ".dev"

    static var container: URL {
        NSFileProviderManager.default.documentStorageURL
            .appendingPathComponent("linux", isDirectory: true)
    }

    struct Doc {
        let system: String
        let path: String

        var identifier: NSFileProviderItemIdentifier {
            NSFileProviderItemIdentifier("\(system):\(path)")
        }

        var parent: NSFileProviderItemIdentifier {
            path == "/" ? .rootContainer : Doc(system: system, path: GuestPath.parent(path)).identifier
        }

        var root: String { LinuxFS.container.appendingPathComponent(system).path }

        init(system: String, path: String) {
            self.system = system
            self.path = path
        }

        init(_ identifier: NSFileProviderItemIdentifier) throws {
            let raw = identifier.rawValue
            guard let at = raw.firstIndex(of: ":"), at != raw.startIndex else {
                throw NSFileProviderError(.noSuchItem)
            }
            let system = String(raw[..<at])
            guard LinuxFS.isSystem(system) else { throw NSFileProviderError(.noSuchItem) }
            self.init(system: system, path: GuestPath.normalize(String(raw[raw.index(after: at)...])))
        }

        func child(_ name: String) -> Doc {
            Doc(system: system, path: GuestPath.child(path, name))
        }

        /// The host path, or `noSuchItem` for a lookup that loops or lands on
        /// the app's own bookkeeping — deleting the marker uninstalls the
        /// system, and the `/dev` store is a live mount's database.
        func resolve(followLast: Bool) throws -> String {
            guard let host = try GuestPath.resolve(
                root: root, guest: path, followLast: followLast, readLink: LinuxFS.readLink
            ) else { throw NSFileProviderError(.noSuchItem) }
            for name in LinuxFS.reserved {
                let own = root + "/" + name
                if host == own || host.hasPrefix(own + "/") { throw NSFileProviderError(.noSuchItem) }
            }
            // Checked by the kernel too, as late as it can be: the guest may
            // have swapped a directory checked above for a link since. What
            // still separates the check from the use is not guarded against.
            guard LinuxFS.within(root, host, followLast: followLast) else {
                throw NSFileProviderError(.noSuchItem)
            }
            return host
        }

        /// [name] as an entry for [self] to hold; the app's bookkeeping names
        /// are not one at a system's top.
        func checkChild(_ name: String) throws -> String {
            let name = try LinuxFS.checkName(name)
            if path == "/", LinuxFS.reserved.contains(name) {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            return name
        }
    }

    static let reserved: Set<String> = [marker, devStore]

    /// Whether the host kernel, resolving every link, also lands [host] in
    /// [root] — for the last component only when [followLast], and for the
    /// nearest part that exists when the rest does not.
    static func within(_ root: String, _ host: String, followLast: Bool) -> Bool {
        guard let base = realpath(root) else { return false }
        var probe = followLast ? host : (host as NSString).deletingLastPathComponent
        while kind(probe) == nil, probe.count > root.count {
            probe = (probe as NSString).deletingLastPathComponent
        }
        guard let real = realpath(probe) else { return false }
        return real == base || real.hasPrefix(base + "/")
    }

    private static func realpath(_ path: String) -> String? {
        guard let p = Darwin.realpath(path, nil) else { return nil }
        defer { free(p) }
        return String(cString: p)
    }

    /// The installed systems: directories carrying the marker.
    static func systems() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: container.path)) ?? []
        return names.filter(isSystem).sorted()
    }

    static func isSystem(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/") else { return false }
        let dir = container.appendingPathComponent(name).path
        return kind(dir) == S_IFDIR && kind(dir + "/" + marker) == S_IFREG
    }

    /// The label the user gave it: the marker's third line.
    static func label(_ system: String) -> String {
        let url = container.appendingPathComponent(system).appendingPathComponent(marker)
        let lines = ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count >= 3 {
            let label = lines[2].trimmingCharacters(in: .whitespaces)
            if !label.isEmpty { return label }
        }
        return system
    }

    /// The type bits of what is at [path], not following a link; nil when
    /// nothing is there.
    static func kind(_ path: String) -> mode_t? {
        var st = stat()
        guard lstat(path, &st) == 0 else { return nil }
        return st.st_mode & S_IFMT
    }

    /// [path]'s target, or nil when it is not a link. A link that cannot be
    /// read fails the lookup: passing it on as a plain path would let the
    /// kernel resolve it against the device's `/`.
    static func readLink(_ path: String) throws -> String? {
        guard kind(path) == S_IFLNK else { return nil }
        do {
            return try FileManager.default.destinationOfSymbolicLink(atPath: path)
        } catch {
            throw NSFileProviderError(.noSuchItem)
        }
    }

    static func checkName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != "..",
              !trimmed.contains("/"), !trimmed.contains("\0")
        else { throw CocoaError(.fileWriteInvalidFileName) }
        return trimmed
    }

    /// [name], or `name 2.ext` when that is taken, as the Files app names a
    /// copy.
    static func freeName(in dir: String, _ name: String) -> String {
        if kind(dir + "/" + name) == nil { return name }
        let ext = (name as NSString).pathExtension
        let base = ext.isEmpty ? name : (name as NSString).deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            if kind(dir + "/" + candidate) == nil { return candidate }
            n += 1
        }
    }

    /// Removes [path], and a directory's contents first, never through a link.
    static func deleteTree(_ path: String) throws {
        if kind(path) == S_IFDIR {
            for name in try FileManager.default.contentsOfDirectory(atPath: path) {
                try deleteTree(path + "/" + name)
            }
        }
        // `removeItem` on a link removes the link.
        try FileManager.default.removeItem(atPath: path)
    }
}
