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
    /// `LinuxProfile.marker`: deleting it uninstalls the system.
    static let marker = ".installed"

    static let container = NSFileProviderManager.default.documentStorageURL
        .appendingPathComponent("linux", isDirectory: true)

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

        /// The host path, free of links but, unless [followLast], the last
        /// component; `noSuchItem` for a lookup that loops or lands on the
        /// marker, however it was reached.
        func resolve(followLast: Bool) throws -> String {
            guard let host = try GuestPath.resolve(
                root: root, guest: path, followLast: followLast, readLink: LinuxFS.readLink
            ) else { throw NSFileProviderError(.noSuchItem) }
            if host == root + "/" + LinuxFS.marker { throw NSFileProviderError(.noSuchItem) }
            return host
        }

        /// The directory [self] names, held open, and its host path.
        func directory() throws -> (DirHandle, String) {
            let host = try resolve(followLast: true)
            return (try DirHandle.open(root: root, path: host), host)
        }

        /// The directory holding the entry [self] names itself — a link, not
        /// what it points to — held open, the entry's name, and its host path.
        func entry() throws -> (DirHandle, String, String) {
            guard path != "/" else { throw NSFileProviderError(.noSuchItem) }
            let host = try resolve(followLast: false)
            let dir = try DirHandle.open(root: root, path: (host as NSString).deletingLastPathComponent)
            return (dir, (host as NSString).lastPathComponent, host)
        }

        /// The host path the Files app reads, through every link — checked by
        /// the kernel too, as late as it can be here. The Files app opens it by
        /// path, so a swap after this is not guarded against; it can only make
        /// it read, never write, outside.
        func readable() throws -> String {
            let host = try resolve(followLast: true)
            guard LinuxFS.within(root, host) else { throw NSFileProviderError(.noSuchItem) }
            return host
        }

        /// [name] as a new entry in the directory at [host]; the marker's name
        /// is not one at a system's top, however that was reached.
        func checkChild(_ name: String, in host: String) throws -> String {
            let name = try LinuxFS.checkName(name)
            if host == root, name == LinuxFS.marker { throw CocoaError(.fileWriteInvalidFileName) }
            return name
        }
    }

    /// Whether the host kernel, resolving every link, lands [host] in [root].
    static func within(_ root: String, _ host: String) -> Bool {
        guard let base = realpath(root), let real = realpath(host) else { return false }
        return real == base || real.hasPrefix(base + "/")
    }

    private static func realpath(_ path: String) -> String? {
        guard let p = Darwin.realpath(path, nil) else { return nil }
        defer { free(p) }
        return String(cString: p)
    }

    /// Where a copy into a system is built: beside the systems and in none of
    /// them, so no guest sees it, and on their volume, so it goes in with one
    /// rename. What an extension that was stopped mid-copy left is removed a
    /// day later; anything younger may be another copy's.
    static func staging() throws -> DirHandle {
        let name = ".staging"
        let top = try DirHandle.open(root: container.path, path: container.path)
        do { try top.makeDirectory(name) } catch let e as NSError where e.code == Int(EEXIST) {}
        let dir = try top.open(name)
        let stale = Date().addingTimeInterval(-86400)
        for entry in (try? dir.names()) ?? [] where (dir.modified(entry) ?? stale) < stale {
            try? dir.remove(entry)
        }
        return dir
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

    /// [name], or `name 2.ext` when that is taken in [dir], as the Files app
    /// names a copy.
    static func freeName(in dir: DirHandle, _ name: String) -> String {
        if dir.kind(name) == nil { return name }
        let ext = (name as NSString).pathExtension
        let base = ext.isEmpty ? name : (name as NSString).deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            if dir.kind(candidate) == nil { return candidate }
            n += 1
        }
    }
}
