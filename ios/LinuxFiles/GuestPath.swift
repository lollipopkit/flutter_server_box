import Foundation

/// Paths inside a Linux rootfs, resolved the way the guest resolves them.
///
/// The iOS twin of Android's `GuestPath.kt`. A rootfs is full of links written
/// for the guest — `/bin -> usr/bin`, `/etc/alternatives/awk -> /usr/bin/mawk`
/// — and opened as host paths an absolute target lands on the device's own
/// `/`. Every path here is resolved one component at a time against the
/// rootfs instead, so what comes out holds no link but, when asked for, the
/// last component, and never leaves the rootfs.
enum GuestPath {
    /// The most links one lookup follows, as Linux's `MAXSYMLINKS`.
    static let maxLinks = 40

    /// [path] made absolute and free of `.`, `..` and repeated separators.
    static func normalize(_ path: String) -> String {
        "/" + segments(path).joined(separator: "/")
    }

    static func parent(_ path: String) -> String {
        let parts = segments(path)
        return parts.isEmpty ? "/" : "/" + parts.dropLast().joined(separator: "/")
    }

    static func child(_ parent: String, _ name: String) -> String {
        normalize(parent.hasSuffix("/") ? parent + name : parent + "/" + name)
    }

    static func name(_ path: String) -> String {
        segments(path).last ?? ""
    }

    /// The host path [guest] names under [root], or nil for a lookup that
    /// loops. [readLink] answers a host path's link target, nil for anything
    /// that is not a link. [followLast] follows a link in the final component
    /// too: reading does, deleting and renaming act on the link itself.
    static func resolve(
        root: String,
        guest: String,
        followLast: Bool,
        readLink: (String) throws -> String?
    ) rethrows -> String? {
        var pending = segments(guest, clamp: false)
        var done: [String] = []
        var links = 0
        while !pending.isEmpty {
            let part = pending.removeFirst()
            if part == "." { continue }
            // Never above the rootfs: the guest's `/..` is its `/`.
            if part == ".." {
                if !done.isEmpty { done.removeLast() }
                continue
            }
            let host = join(root, done + [part])
            let target = pending.isEmpty && !followLast ? nil : try readLink(host)
            guard let target else {
                done.append(part)
                continue
            }
            links += 1
            if links > maxLinks { return nil }
            if target.hasPrefix("/") { done.removeAll() }
            pending.insert(contentsOf: segments(target, clamp: false), at: 0)
        }
        return join(root, done)
    }

    private static func join(_ root: String, _ parts: [String]) -> String {
        guard !parts.isEmpty else { return root }
        var base = root
        while base.hasSuffix("/") { base.removeLast() }
        return base + "/" + parts.joined(separator: "/")
    }

    /// The non-empty components of [path]. With [clamp], `.` is dropped and
    /// `..` taken back lexically; without it both are kept for [resolve].
    private static func segments(_ path: String, clamp: Bool = true) -> [String] {
        var out: [String] = []
        for part in path.split(separator: "/", omittingEmptySubsequences: true) {
            let p = String(part)
            if !clamp {
                out.append(p)
                continue
            }
            switch p {
            case ".": break
            case "..": if !out.isEmpty { out.removeLast() }
            default: out.append(p)
            }
        }
        return out
    }
}
