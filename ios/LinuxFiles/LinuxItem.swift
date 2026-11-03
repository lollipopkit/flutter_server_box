import FileProvider
import UniformTypeIdentifiers

/// The provider's top: one folder per installed system.
final class RootItem: NSObject, NSFileProviderItem {
    let itemIdentifier = NSFileProviderItemIdentifier.rootContainer
    let parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
    let filename = "Linux"
    let contentType = UTType.folder
    let capabilities: NSFileProviderItemCapabilities = [.allowsReading, .allowsContentEnumerating]
}

/// A file or directory inside a system. What a link points to is what is
/// shown, so `/bin` opens as a directory; a dangling one is still listed, as
/// a file to delete.
final class LinuxItem: NSObject, NSFileProviderItem {
    let itemIdentifier: NSFileProviderItemIdentifier
    let parentItemIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let contentType: UTType
    let capabilities: NSFileProviderItemCapabilities
    let documentSize: NSNumber?
    let contentModificationDate: Date?
    let creationDate: Date?

    init(_ doc: LinuxFS.Doc) throws {
        let entry = try doc.resolve(followLast: false)
        let host = LinuxFS.kind(entry) == S_IFLNK ? try doc.resolve(followLast: true) : entry
        let kind = LinuxFS.kind(host)
        // A FIFO, a socket or a device node would block or mislead whoever
        // opens it; a dangling link is still listed, as a file to delete.
        if let kind, kind != S_IFREG, kind != S_IFDIR { throw NSFileProviderError(.noSuchItem) }
        let attrs = try? FileManager.default.attributesOfItem(atPath: host)
        let isDir = kind == S_IFDIR
        let isTop = doc.path == "/"

        itemIdentifier = doc.identifier
        parentItemIdentifier = doc.parent
        filename = isTop ? LinuxFS.label(doc.system) : GuestPath.name(doc.path)
        contentType = isDir
            ? .folder
            : UTType(filenameExtension: (filename as NSString).pathExtension) ?? .data
        documentSize = isDir ? nil : attrs?[.size] as? NSNumber
        contentModificationDate = attrs?[.modificationDate] as? Date
        creationDate = attrs?[.creationDate] as? Date

        var caps: NSFileProviderItemCapabilities = [.allowsReading]
        let writable = access(host, W_OK) == 0
        if isDir {
            caps.insert(.allowsContentEnumerating)
            if writable { caps.insert(.allowsAddingSubItems) }
        } else if writable {
            caps.insert(.allowsWriting)
        }
        if !isTop, access((entry as NSString).deletingLastPathComponent, W_OK) == 0 {
            caps.formUnion([.allowsRenaming, .allowsReparenting, .allowsDeleting])
        }
        capabilities = caps
    }
}
