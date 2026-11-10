import FileProvider

/// Lists a directory, in pages, and answers every request for changes by
/// asking for a fresh listing: the guest changes its files without telling
/// anyone, so there is no record of what changed to report.
class ListingEnumerator: NSObject, NSFileProviderEnumerator {
    private static let pageSize = 200

    private let names: () throws -> [String]
    private let item: (String) -> NSFileProviderItem?
    /// Listed once, on the first page: later pages build only their own items,
    /// and a directory changing in between does not shift them.
    private var listed: [String]?

    init(names: @escaping () throws -> [String], item: @escaping (String) -> NSFileProviderItem?) {
        self.names = names
        self.item = item
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            let start = Int(String(data: page.rawValue, encoding: .utf8) ?? "") ?? 0
            if start == 0 || listed == nil { listed = try names() }
            let all = listed ?? []
            let end = min(start + Self.pageSize, all.count)
            observer.didEnumerate(start < end ? all[start..<end].compactMap(item) : [])
            let next = end < all.count ? NSFileProviderPage(Data(String(end).utf8)) : nil
            observer.finishEnumerating(upTo: next)
        } catch {
            observer.finishEnumeratingWithError(error)
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(NSFileProviderSyncAnchor(Data(String(Date().timeIntervalSince1970).utf8)))
    }
}

extension ListingEnumerator {
    /// The installed systems.
    static func systems() -> ListingEnumerator {
        ListingEnumerator(names: LinuxFS.systems) { try? LinuxItem(LinuxFS.Doc(system: $0, path: "/")) }
    }

    /// What is in [doc]. The marker at a system's top drops out: `resolve`
    /// refuses it by where it is, however it was reached.
    static func children(of doc: LinuxFS.Doc) -> ListingEnumerator {
        ListingEnumerator(
            names: { try doc.directory().0.names().sorted() },
            item: { try? LinuxItem(doc.child($0)) }
        )
    }

    /// Nothing: no item is ever in the working set.
    static func empty() -> ListingEnumerator {
        ListingEnumerator(names: { [] }) { _ in nil }
    }
}
