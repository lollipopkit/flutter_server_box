import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';

/// What a directory listing can say about one entry.
///
/// The union of what `FileSystemEntity` and `SftpName` know, which is not the
/// same set: this device reports no owner and no mode, and a server reports no
/// distinction between a file it cannot stat and one that is not there. What
/// only one side can answer is nullable here and declared in
/// [FileBackendTraits], so a page can leave a column out rather than draw it
/// empty.
@immutable
class FileEntry {
  const FileEntry({
    required this.name,
    required this.kind,
    this.size,
    this.modified,
    this.mode,
    this.linkTarget,
  });

  /// The last component, never a path. Where an entry lives is the business of
  /// whoever asked for the listing.
  final String name;

  final FileKind kind;

  /// Null where the backend did not say — a directory over SFTP often has no
  /// meaningful one, and neither does anything this device refused to stat.
  final int? size;

  final DateTime? modified;

  /// POSIX permission bits — `0x1ED` for `755` — or null on a backend with no
  /// notion of them.
  ///
  /// Permission bits only. SFTP packs the type into the same field and this
  /// does not: [kind] already answers that, and a caller handing this to
  /// `chmod` should not have to know which bits to mask off first.
  final int? mode;

  /// Where a symlink points, when the backend resolved it. Null for anything
  /// that is not one, and for backends that do not follow links.
  final String? linkTarget;

  bool get isDir => kind == FileKind.dir;

  /// `rwxr-xr-x`, or null where the backend reported no mode.
  String? get modeStr {
    final value = mode;
    if (value == null) return null;
    const flags = 'rwx';
    final out = StringBuffer();
    for (var bit = 8; bit >= 0; bit--) {
      out.write(value & (1 << bit) != 0 ? flags[2 - bit % 3] : '-');
    }
    return out.toString();
  }
}

/// What a half-written [FileBackend.write] is parked under, before the rename
/// that puts it in place.
///
/// Shared because two parties need to agree on it: the backend that creates
/// one, and the cleanup that removes it when the write never got to finish —
/// a transfer whose isolate was killed runs no `catch` of its own.
const kStagingSuffix = '.sb-part-';

/// Whether [name] is a staged copy of [destination]'s basename.
bool isStagingOf(String name, String destination) {
  final slash = destination.replaceAll(r'\', '/').lastIndexOf('/');
  final base = slash < 0 ? destination : destination.substring(slash + 1);
  return name.startsWith('$base$kStagingSuffix');
}

/// Where to park a write to [destination] until it can be renamed into place.
///
/// The counter alone was unique only within the isolate holding it, and every
/// transfer runs in a fresh one that starts it at zero — so two transfers to
/// the same destination both picked `<name>.sb-part-0`, wrote into each
/// other's bytes, and cleaned up each other's file. [_stagingToken] is drawn
/// once per isolate from a source that does not repeat across them, which is
/// what makes the two disagree; the counter then separates writes within one.
String stagingNameFor(String destination) =>
    '$destination$kStagingSuffix$_stagingToken-${_staging++}';

var _staging = 0;

/// Not `Random()`: its default seed is derived from the clock, and two
/// isolates spawned in the same millisecond would draw the same token — the
/// collision this exists to prevent.
final _stagingToken = Random.secure()
    .nextInt(1 << 32)
    .toRadixString(36)
    .padLeft(7, '0');

/// Gives [staging] the permission bits [destination] already has, before a
/// [FileBackend.write] renames the one onto the other.
///
/// A staged copy is created with whatever the far side's umask says, and the
/// rename carries *that* mode onto the destination. So saving an edit to a 0755
/// script left it 0644 and unrunnable, and replacing a 0600 file made it
/// world-readable — neither of which anyone asked for by saving a file.
/// Whatever was there keeps its permissions instead.
///
/// Best effort, and logged rather than fatal. The bytes are already across by
/// the time this runs, and a server that will not report or set a mode is one
/// where failing here would mean the file could never be saved at all, with the
/// new contents thrown away every time. The `monitor` agent's own write settled
/// on the same answer (`monitor/src/api/fs.rs`).
///
/// A no-op where the backend has no notion of permissions: there is nothing to
/// read and nothing to set, which is what [FileBackendTraits.permissions]
/// answering false means.
Future<void> carryModeToStaging(
  FileBackend backend,
  String staging,
  String destination,
) async {
  if (!backend.traits.permissions) return;
  try {
    final existing = await backend.stat(destination);
    // Nothing there is the ordinary case: a file being created for the first
    // time has no mode to keep. A directory is one the rename is about to fail
    // on anyway. A symlink is replaced *as a link* by the rename, so what the
    // new file inherits would be the link's own bits — `0777` on most systems,
    // which is not permissions being kept but a world-writable file being
    // created.
    if (existing == null || existing.isDir || existing.kind == FileKind.link) {
      return;
    }
    final mode = existing.mode;
    if (mode == null) return;
    await backend.chmod(staging, mode);
  } catch (e, s) {
    Loggers.app.warning("Could not carry $destination's mode over", e, s);
  }
}

/// The bits [FileEntry.mode] keeps: `rwxrwxrwx` plus setuid, setgid and
/// sticky, and nothing above them.
const kFilePermMask = 0xFFF;

enum FileKind { file, dir, link, other }

/// What a backend can and cannot do.
///
/// Asked rather than inferred from the runtime type: "does this have
/// permissions" is a question about the filesystem behind it, and the page that
/// draws a permission row should not be reading a class name to decide.
@immutable
class FileBackendTraits {
  const FileBackendTraits({
    this.permissions = false,
    this.symlinks = false,
    this.sudoFallback = false,
  });

  /// Entries carry [FileEntry.mode], and it can be changed.
  final bool permissions;

  /// Entries can be links, and [FileEntry.linkTarget] may be set.
  final bool symlinks;

  /// A refused operation can be retried through a shell with sudo. Only a
  /// backend that has a shell behind it can offer this; see `sftp_sudo.dart`.
  final bool sudoFallback;
}

/// Somewhere files live.
///
/// The third of this app's "where do the bytes come from" seams, beside
/// `ShellBackend` and `ServerExec`. Everything above it — the browser, the
/// transfer engine — is written against these seven methods, so that a second
/// kind of storage is a class rather than a branch in every page.
///
/// Paths are POSIX-shaped and absolute at this boundary, including on Windows,
/// where [LocalFileBackend] converts at its own edge. A backend is free to be
/// case-insensitive; nothing above assumes either way.
abstract interface class FileBackend {
  FileBackendTraits get traits;

  /// The only directories this backend will serve, or empty where it serves
  /// whatever it can see.
  ///
  /// Asked rather than declared in [FileBackendTraits], because the answer is
  /// the far side's and arrives over the wire: a `monitor` agent serves the
  /// directories its operator named and nothing else, and it is the only thing
  /// that knows which those are.
  ///
  /// Empty is "no such limit", not "nothing reachable" — the two backends with
  /// a whole filesystem behind them answer that, and a caller reading this to
  /// offer somewhere to go should show nothing rather than an empty list.
  Future<List<String>> reachableRoots();

  Future<List<FileEntry>> list(String path);

  /// Null when there is nothing there. Anything else — no permission, a broken
  /// link — throws, because "absent" and "unreadable" are different answers and
  /// a caller that conflates them deletes the wrong thing.
  Future<FileEntry?> stat(String path);

  Future<void> mkdir(String path);

  /// [recursive] is required for a directory with anything in it. Backends that
  /// cannot do it in one call do it themselves rather than making every caller
  /// walk the tree — SFTP's `rmdir` is the reason this parameter exists.
  Future<void> remove(String path, {bool recursive = false});

  Future<void> rename(String from, String to);

  /// Sets the POSIX permission bits, as an octal value — `0x1ED` for `755`.
  ///
  /// Only meaningful where [FileBackendTraits.permissions] is set; anywhere
  /// else it throws [UnsupportedError], and the page should not have offered
  /// it.
  Future<void> chmod(String path, int mode);

  /// The bytes, from [offset].
  ///
  /// Every backend honours the offset. It was a trait for a while — declared,
  /// answered `true` by both implementations, and read by nothing — which is a
  /// promise with no way to tell whether it was kept. A backend that cannot
  /// seek has no business implementing this interface: a transfer engine that
  /// has to check first is one that cannot resume anything.
  Stream<List<int>> read(String path, {int offset = 0});

  /// Writes [data] to [path], replacing whatever was there.
  ///
  /// Atomic from a reader's point of view: the implementation writes elsewhere
  /// and renames, so a transfer that dies halfway leaves no half-file under the
  /// name something else is about to open. [size] is a hint for progress and
  /// pre-allocation, not a contract.
  ///
  /// Replacing a file that is already there keeps its permission bits — see
  /// [carryModeToStaging], which every implementation that has any calls. A
  /// backend answering false to [FileBackendTraits.permissions] cannot, and
  /// does not claim to.
  ///
  /// [onStaging] is called with the path being staged onto, before anything is
  /// written there, for the caller that has to clean up after a process this
  /// side kills: `write` removes its own leftovers when it fails, and being
  /// killed is not a failure it gets to handle. A backend that stages
  /// somewhere this side cannot reach — the agent does its own — never calls
  /// it, and there is correspondingly nothing here to remove.
  ///
  /// [replayData] is backend-specific. Local and SFTP writes make one attempt
  /// and never consume it. The monitor backend uses it only after an HTTP 401
  /// to authenticate and replay the body. In particular, SFTP must not retry a
  /// timed-out rename: its outcome is unknown, so another write could replace
  /// a destination that the first attempt already committed.
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    Stream<List<int>> Function()? replayData,
  });

  /// Releases whatever this holds. A backend may be used again afterwards only
  /// if its own documentation says so.
  Future<void> close();
}
