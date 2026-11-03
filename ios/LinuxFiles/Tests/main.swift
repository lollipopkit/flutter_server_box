import Foundation

// `GuestPath` and `DirHandle` against a real tree of links, as Android's
// `GuestPathTest` does: the links out of it are the point. Run by `run.sh`.

let fm = FileManager.default
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("linuxfiles-\(getpid())")
let root = tmp.appendingPathComponent("rootfs").path
let outside = tmp.appendingPathComponent("outside").path
var failures = 0

func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok {
        failures += 1
        print("FAIL line \(line): \(what)")
    }
}

func eq(_ a: String?, _ b: String?, line: Int = #line) {
    check(a == b, "\(String(describing: a)) != \(String(describing: b))", line: line)
}

func readLink(_ path: String) -> String? {
    var st = stat()
    guard lstat(path, &st) == 0, st.st_mode & S_IFMT == S_IFLNK else { return nil }
    return try? fm.destinationOfSymbolicLink(atPath: path)
}

func resolve(_ guest: String, followLast: Bool = true) -> String? {
    GuestPath.resolve(root: real, guest: guest, followLast: followLast, readLink: readLink)
}

try fm.createDirectory(atPath: root + "/usr/bin", withIntermediateDirectories: true)
try fm.createDirectory(atPath: root + "/etc/alternatives", withIntermediateDirectories: true)
try fm.createDirectory(atPath: outside, withIntermediateDirectories: true)
let real = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
fm.createFile(atPath: root + "/usr/bin/mawk", contents: Data([1]))
fm.createFile(atPath: outside + "/secret", contents: Data([2]))
try fm.createSymbolicLink(atPath: root + "/bin", withDestinationPath: "usr/bin")
try fm.createSymbolicLink(atPath: root + "/etc/alternatives/awk", withDestinationPath: "/usr/bin/mawk")
try fm.createSymbolicLink(atPath: root + "/escape", withDestinationPath: "../../../../..")
try fm.createSymbolicLink(atPath: root + "/host", withDestinationPath: outside)
try fm.createSymbolicLink(atPath: root + "/loop", withDestinationPath: "loop")
try fm.createSymbolicLink(atPath: root + "/dangling", withDestinationPath: "/nowhere")
defer { _ = try? DirHandle.open(root: tmp.path, path: tmp.path).remove("rootfs") }

// GuestPath
eq(resolve("/"), real)
eq(resolve("/bin/mawk"), real + "/usr/bin/mawk")
eq(resolve("/etc/alternatives/awk"), real + "/usr/bin/mawk")
eq(resolve("/etc/alternatives/awk", followLast: false), real + "/etc/alternatives/awk")
eq(resolve("/escape/usr"), real + "/usr")
eq(resolve("/../../usr/bin"), real + "/usr/bin")
eq(resolve("/host"), real + outside)
eq(resolve("/loop"), nil)
eq(resolve("/dangling"), real + "/nowhere")
eq(GuestPath.normalize("a//b/./c/../d"), "/a/b/d")
eq(GuestPath.normalize("/../x"), "/x")
eq(GuestPath.parent("/a/b"), "/a")
eq(GuestPath.parent("/"), "/")
eq(GuestPath.child("/", "x"), "/x")
eq(GuestPath.child("/a", ".."), "/")
eq(GuestPath.name("/a/b"), "b")

// DirHandle: a link where a directory was checked is refused, not followed.
check((try? DirHandle.open(root: real, path: real + "/usr/bin")) != nil, "opens a plain directory")
check((try? DirHandle.open(root: real, path: real + "/host")) == nil, "follows a link out")
check((try? DirHandle.open(root: real, path: real + "/bin")) == nil, "follows a link in")
check((try? DirHandle.open(root: real, path: outside)) == nil, "opens outside the root")

// Removing a tree holding a link out removes the link, never what it names.
let top = try DirHandle.open(root: real, path: real)
try top.makeDirectory("tree")
let tree = try top.open("tree")
try tree.makeDirectory("sub")
try fm.createSymbolicLink(atPath: real + "/tree/sub/out", withDestinationPath: outside)
try top.copy("tree", to: top, as: "copy")
eq(readLink(real + "/copy/sub/out"), outside)
try top.remove("tree")
try top.remove("copy")
check(top.kind("tree") == nil && top.kind("copy") == nil, "trees removed")
check(fm.fileExists(atPath: outside + "/secret"), "removed through a link")

// A rename never replaces what is there.
fm.createFile(atPath: real + "/a", contents: Data([1]))
fm.createFile(atPath: real + "/b", contents: Data([2]))
check((try? top.rename("a", to: top, as: "b")) == nil, "rename replaced a file")
check(fm.contents(atPath: real + "/b") == Data([2]), "rename changed the target")

print(failures == 0 ? "ok" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
