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
        let host = try doc.resolve(followLast: true)
        let attrs = try? FileManager.default.attributesOfItem(atPath: host)
        let isDir = LinuxFS.kind(host) == S_IFDIR
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
        if !isTop,
           let link = try? doc.resolve(followLast: false),
           access((link as NSString).deletingLastPathComponent, W_OK) == 0 {
            caps.formUnion([.allowsRenaming, .allowsReparenting, .allowsDeleting])
        }
        capabilities = caps
    }
}
