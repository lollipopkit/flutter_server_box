import Darwin
import FileProvider

/// A directory held open by descriptor. Every change the extension makes goes
/// through one, by name, with `*at` calls that never follow a link: a
/// directory the guest swaps for a link after it was checked is refused, not
/// followed out of the system. Android's provider leaves that window open
/// because a proot guest can reach everything anyway; an iSH guest cannot.
final class DirHandle {
    let fd: Int32

    private init(_ fd: Int32) {
        self.fd = fd
    }

    deinit {
        close(fd)
    }

    /// [path], a link-free host path at or under [root], opened one component
    /// at a time without following a link.
    static func open(root: String, path: String) throws -> DirHandle {
        guard path == root || path.hasPrefix(root + "/") else { throw NSFileProviderError(.noSuchItem) }
        let top = Darwin.open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard top >= 0 else { throw posixError() }
        var dir = DirHandle(top)
        for part in path.dropFirst(root.count).split(separator: "/") {
            dir = try dir.open(String(part))
        }
        return dir
    }

    func open(_ name: String) throws -> DirHandle {
        let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard child >= 0 else { throw posixError() }
        return DirHandle(child)
    }

    /// The type bits of [name], not following a link; nil when it is absent.
    func kind(_ name: String) -> mode_t? {
        var st = stat()
        guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { return nil }
        return st.st_mode & S_IFMT
    }

    /// When [name] last changed, not following a link.
    func modified(_ name: String) -> Date? {
        var st = stat()
        guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
    }

    func names() throws -> [String] {
        let copy = dup(fd)
        guard copy >= 0 else { throw posixError() }
        guard let dir = fdopendir(copy) else {
            close(copy)
            throw posixError()
        }
        defer { closedir(dir) }
        rewinddir(dir)
        var out: [String] = []
        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) {
                String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
            }
            if name != "." && name != ".." { out.append(name) }
        }
        return out
    }

    func makeDirectory(_ name: String) throws {
        guard mkdirat(fd, name, 0o755) == 0 else { throw posixError() }
    }

    /// Moves [name] to [newName] in [dir], refusing to replace anything there.
    func rename(_ name: String, to dir: DirHandle, as newName: String) throws {
        guard renameatx_np(fd, name, dir.fd, newName, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw NSFileProviderError(.filenameCollision) }
            throw posixError()
        }
    }

    /// Removes [name], a directory's contents first; a link is removed as a
    /// link. A read-only directory is made writable first: the guest is root.
    func remove(_ name: String) throws {
        var st = stat()
        if fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0, st.st_mode & S_IFMT == S_IFDIR {
            if st.st_mode & S_IRWXU != S_IRWXU {
                guard fchmodat(fd, name, (st.st_mode & 0o7777) | S_IRWXU, AT_SYMLINK_NOFOLLOW) == 0 else {
                    throw posixError()
                }
            }
            let child = try open(name)
            for entry in try child.names() { try child.remove(entry) }
            guard unlinkat(fd, name, AT_REMOVEDIR) == 0 else { throw posixError() }
        } else {
            guard unlinkat(fd, name, 0) == 0 else { throw posixError() }
        }
    }

    /// Copies [name] to [newName] in [dir]: a link as a link, nothing that is
    /// not a file, a directory or a link.
    func copy(_ name: String, to dir: DirHandle, as newName: String) throws {
        switch kind(name) {
        case S_IFDIR:
            try dir.makeDirectory(newName)
            let from = try open(name)
            let into = try dir.open(newName)
            for entry in try from.names() { try from.copy(entry, to: into, as: entry) }
            // Last: a read-only directory takes no children.
            try copyMode(from: from.fd, to: into.fd)
        case S_IFLNK:
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
            let length = readlinkat(fd, name, &buffer, buffer.count - 1)
            guard length >= 0 else { throw posixError() }
            buffer[length] = 0
            guard symlinkat(buffer, dir.fd, newName) == 0 else { throw posixError() }
        case S_IFREG:
            let source = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard source >= 0 else { throw posixError() }
            defer { close(source) }
            try dir.write(newName, from: source, keepMode: true)
        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    /// Builds an entry with [build] in [staging], under a name of its own, and
    /// only once it is whole moves it here as [name]. On a failure only that
    /// entry is removed: nothing here is touched, and the guest never sees
    /// half of one.
    func publish(_ name: String, staging: DirHandle, _ build: (DirHandle, String) throws -> Void) throws {
        let temp = UUID().uuidString
        do {
            try build(staging, temp)
            try staging.rename(temp, to: self, as: name)
        } catch {
            try? staging.remove(temp)
            throw error
        }
    }

    /// Copies [url] — from outside, the user's — in as [name].
    func importItem(_ url: URL, as name: String) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw NSFileProviderError(.noSuchItem)
        }
        if isDir.boolValue {
            try makeDirectory(name)
            let into = try open(name)
            for entry in try FileManager.default.contentsOfDirectory(atPath: url.path) {
                try into.importItem(url.appendingPathComponent(entry), as: entry)
            }
        } else {
            let source = Darwin.open(url.path, O_RDONLY | O_CLOEXEC)
            guard source >= 0 else { throw posixError() }
            defer { close(source) }
            try write(name, from: source)
        }
    }

    /// Writes [source] to a new [name], its mode too when [keepMode]; nothing
    /// is left behind when that fails.
    private func write(_ name: String, from source: Int32, keepMode: Bool = false) throws {
        let dest = openat(fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o644)
        guard dest >= 0 else {
            if errno == EEXIST { throw NSFileProviderError(.filenameCollision) }
            throw posixError()
        }
        defer { close(dest) }
        do {
            guard fcopyfile(source, dest, nil, copyfile_flags_t(COPYFILE_DATA)) == 0 else { throw posixError() }
            if keepMode { try copyMode(from: source, to: dest) }
        } catch {
            unlinkat(fd, name, 0)
            throw error
        }
    }
}

/// The root filesystem is `realfs`: the host's permission bits are the guest's.
private func copyMode(from source: Int32, to dest: Int32) throws {
    var st = stat()
    guard fstat(source, &st) == 0, fchmod(dest, st.st_mode & 0o7777) == 0 else { throw posixError() }
}

private func posixError() -> Error {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
}
