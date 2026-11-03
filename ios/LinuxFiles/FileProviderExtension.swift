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
              let host = try? doc.readable()
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
        // Only what can be read through: a FIFO would block its reader.
        let kind = LinuxFS.kind(url.path)
        completionHandler(kind == S_IFREG || kind == S_IFDIR ? nil : NSFileProviderError(.noSuchItem))
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
            let (dir, host) = try parent.directory()
            let name = try parent.checkChild(directoryName, in: host)
            if dir.kind(name) != nil { throw NSFileProviderError(.filenameCollision) }
            try dir.makeDirectory(name)
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
            let (dir, host) = try parent.directory()
            let scoped = fileURL.startAccessingSecurityScopedResource()
            defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
            let name = LinuxFS.freeName(in: dir, try parent.checkChild(fileURL.lastPathComponent, in: host))
            try dir.importItem(fileURL, as: name)
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
            let parent = LinuxFS.Doc(system: doc.system, path: GuestPath.parent(doc.path))
            return try move(doc, into: parent, as: itemName)
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
            return try move(doc, into: parent, as: newName ?? GuestPath.name(doc.path))
        }
    }

    override func deleteItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            let (dir, name, _) = try LinuxFS.Doc(itemIdentifier).entry()
            try dir.remove(name)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    // MARK: - Helpers

    /// Moves the entry [doc] names itself — a link stays a link — to [name]
    /// in [parent]. Between two systems a copy and then a delete: they are
    /// separate trees, and the copy is whole before the original goes.
    private func move(_ doc: LinuxFS.Doc, into parent: LinuxFS.Doc, as newName: String) throws -> NSFileProviderItem {
        let (from, entry, fromHost) = try doc.entry()
        let (into, intoHost) = try parent.directory()
        let name = try parent.checkChild(newName, in: intoHost)
        // Not into itself: `mv a a/b` would detach the tree.
        let toHost = intoHost + "/" + name
        guard toHost != fromHost, !toHost.hasPrefix(fromHost + "/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        if parent.system == doc.system {
            try from.rename(entry, to: into, as: name)
        } else {
            if into.kind(name) != nil { throw NSFileProviderError(.filenameCollision) }
            try from.copy(entry, to: into, as: name)
            try from.remove(entry)
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
