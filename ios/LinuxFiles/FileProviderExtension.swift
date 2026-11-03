import FileProvider
import UniformTypeIdentifiers

/// Each installed Linux system as a folder in the Files app (#1855), served
/// in place from the App Group: nothing is copied, and what the guest writes
/// is what the Files app opens.
///
/// Mirrors Android's `LinuxDocumentsProvider`: the whole tree from `/`, links
/// resolved as the guest resolves them, the app's bookkeeping out of reach.
final class FileProviderExtension: NSFileProviderExtension {
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        if identifier == .rootContainer { return RootItem() }
        return try LinuxItem(LinuxFS.Doc(identifier))
    }

    /// Where the item's bytes are: through any link, since a link opened as a
    /// host path would be resolved against the device's `/`. An item reached
    /// through one therefore comes back from [persistentIdentifierForItem] as
    /// the file it names, which is the same file.
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard identifier != .rootContainer,
              let doc = try? LinuxFS.Doc(identifier),
              let host = try? doc.resolve(followLast: true)
        else { return nil }
        return URL(fileURLWithPath: host)
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        let base = Self.unprefixed(LinuxFS.container.path)
        let path = Self.unprefixed(url.standardizedFileURL.path)
        guard path.hasPrefix(base + "/") else { return nil }
        let rest = path.dropFirst(base.count + 1)
        let system = String(rest.prefix { $0 != "/" })
        guard LinuxFS.isSystem(system) else { return nil }
        return LinuxFS.Doc(system: system, path: GuestPath.normalize(String(rest.dropFirst(system.count)))).identifier
    }

    /// `/private/var/…` and `/var/…` are one place.
    private static func unprefixed(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }

    // In place: the file is always there, so nothing is downloaded, and a
    // copy the system stops needing is the user's file, never to be removed.

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(LinuxFS.kind(url.path) == nil ? NSFileProviderError(.noSuchItem) : nil)
    }

    override func itemChanged(at url: URL) {}

    override func stopProvidingItem(at url: URL) {}

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        switch containerItemIdentifier {
        case .rootContainer: return ListingEnumerator.systems()
        case .workingSet: return ListingEnumerator.empty()
        default: return ListingEnumerator.children(of: try LinuxFS.Doc(containerItemIdentifier))
        }
    }

    // MARK: - Actions

    override func createDirectory(
        withName directoryName: String,
        inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        run(completionHandler) {
            let parent = try LinuxFS.Doc(parentItemIdentifier)
            let dir = try parent.resolve(followLast: true)
            let name = try parent.checkChild(directoryName)
            if LinuxFS.kind(dir + "/" + name) != nil { throw NSFileProviderError(.filenameCollision) }
            try FileManager.default.createDirectory(atPath: dir + "/" + name, withIntermediateDirectories: false)
            return try LinuxItem(parent.child(name))
        }
    }

    override func importDocument(
        at fileURL: URL,
        toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        run(completionHandler) {
            let parent = try LinuxFS.Doc(parentItemIdentifier)
            let dir = try parent.resolve(followLast: true)
            guard LinuxFS.kind(dir) == S_IFDIR else { throw NSFileProviderError(.noSuchItem) }
            let scoped = fileURL.startAccessingSecurityScopedResource()
            defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
            let name = LinuxFS.freeName(in: dir, try parent.checkChild(fileURL.lastPathComponent))
            try FileManager.default.copyItem(at: fileURL, to: URL(fileURLWithPath: dir + "/" + name))
            return try LinuxItem(parent.child(name))
        }
    }

    override func renameItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        toName itemName: String,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        run(completionHandler) {
            let doc = try LinuxFS.Doc(itemIdentifier)
            guard doc.path != "/" else { throw NSFileProviderError(.noSuchItem) }
            let parent = LinuxFS.Doc(system: doc.system, path: GuestPath.parent(doc.path))
            return try move(doc, into: parent, as: parent.checkChild(itemName))
        }
    }

    override func reparentItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        newName: String?,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        run(completionHandler) {
            let doc = try LinuxFS.Doc(itemIdentifier)
            let parent = try LinuxFS.Doc(parentItemIdentifier)
            guard doc.path != "/" else { throw NSFileProviderError(.noSuchItem) }
            return try move(doc, into: parent, as: parent.checkChild(newName ?? GuestPath.name(doc.path)))
        }
    }

    override func deleteItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            let doc = try LinuxFS.Doc(itemIdentifier)
            guard doc.path != "/" else { throw NSFileProviderError(.noSuchItem) }
            try LinuxFS.deleteTree(doc.resolve(followLast: false))
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    // MARK: - Helpers

    /// Moves the entry [doc] names itself — a link stays a link — to [name]
    /// in [parent]. Between two systems a copy and then a delete: they are
    /// separate trees, and the copy is whole before the original goes.
    private func move(_ doc: LinuxFS.Doc, into parent: LinuxFS.Doc, as name: String) throws -> NSFileProviderItem {
        let from = try doc.resolve(followLast: false)
        let dir = try parent.resolve(followLast: true)
        let to = dir + "/" + name
        // Not into itself: `mv a a/b` would detach the tree.
        guard to != from, !to.hasPrefix(from + "/") else { throw CocoaError(.fileWriteInvalidFileName) }
        if LinuxFS.kind(to) != nil { throw NSFileProviderError(.filenameCollision) }
        if parent.system == doc.system {
            try FileManager.default.moveItem(atPath: from, toPath: to)
        } else {
            try FileManager.default.copyItem(atPath: from, toPath: to)
            try LinuxFS.deleteTree(from)
        }
        return try LinuxItem(parent.child(name))
    }

    private func run(
        _ completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void,
        _ body: () throws -> NSFileProviderItem
    ) {
        do {
            completionHandler(try body(), nil)
        } catch {
            completionHandler(nil, error)
        }
    }
}
