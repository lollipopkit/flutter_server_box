import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// Reading a filesystem's shape with nothing but a POSIX shell.
///
/// Two backends need this, for different reasons. `SftpFileBackend` escalates a
/// refused listing through `sudo`, where the protocol is no longer in play and
/// only a command will do. `ScpFileBackend` has no protocol for metadata at all
/// — SCP moves file *contents* and says nothing about what is in a directory —
/// so this is its normal path.
///
/// One shape for both: five NUL-terminated fields per entry, `name`, `perm`,
/// `type`, `size`, `mtime`. NUL rather than a separator anybody types, because
/// a filename may contain everything else, newlines included.
///
/// `find` and `stat -c` rather than `ls -l`: `ls` output is a format meant for
/// people, varies between implementations, and puts a locale-dependent date in
/// the middle of it. Both of these are in busybox and toybox as well as in
/// coreutils, which matters — the machines that reach this code are the ones
/// too small to run an SFTP subsystem.

/// One directory level.
///
/// `-mindepth 1 -maxdepth 1` is this directory and no deeper; `-exec … {} +`
/// hands the whole batch to one shell rather than starting one per file.
String shellListCommand(String path) =>
    'find ${shellSingleQuote(path)} '
    '-mindepth 1 -maxdepth 1 '
    '-exec sh -c \''
    'for path do '
    // A file that is gone by the time its metadata is read is simply not
    // reported: `find` names what was there a moment ago, and /proc and /tmp
    // churn under any listing.
    '${_emitRecord('path', onVanished: 'continue')}'
    'done'
    '\' sh {} +';

/// One path, or a marker saying why not.
///
/// Absence and refusal are the two answers a caller has to tell apart:
/// "nothing there" invites creating something, and "you may not look" does not.
/// The shell cannot simply report whether `stat` worked — a path under a
/// directory this user cannot search fails exactly like one that was never
/// there — so the parent is tested separately, and only a parent this user
/// *can* search makes an absence an absence.
///
/// Both are said twice, on stdout as [kShellStatAbsentMark] /
/// [kShellStatDeniedMark] and as an exit code. The exit code alone was not
/// enough: a host that closes the channel without an exit-status message —
/// which is the kind of host this backend exists for — leaves the caller with
/// no answer at all, and a `stat` that cannot say "nothing there" is one that
/// fails every copy into a directory that does not exist yet.
String shellStatCommand(String path) {
  final quoted = shellSingleQuote(_withoutTrailingSlash(path));
  return 'path=$quoted; '
      // The parent, by string rather than by `dirname`, which is one more
      // process and one more thing a minimal system may not have. `/foo` and
      // `/` both leave nothing behind, and the parent of both is the root.
      'dir=\${path%/*}; [ -z "\$dir" ] && dir=/; '
      // `-e` alone answers no for a symlink to nowhere, which is still an entry
      // somebody can see, rename and delete.
      'if [ -e "\$path" ] || [ -L "\$path" ]; then '
      // Same answer as the branch below, for the same path that reaches it a
      // moment later: something was there when the test ran and is not there
      // now, which is an absence rather than a failure to look.
      '${_emitRecord('path', onVanished: 'printf "%s" $kShellStatAbsentMark; exit $kShellStatAbsent')}'
      'elif [ ! -d "\$dir" ] || [ -x "\$dir" ]; then '
      'printf "%s" $kShellStatAbsentMark; exit $kShellStatAbsent; '
      'else printf "%s" $kShellStatDeniedMark; exit $kShellStatDenied; fi';
}

/// [path] without the trailing separators that carry no meaning.
///
/// `${path##*/}` — which is how the entry's name is derived — expands to
/// *nothing* for `/dir/`, so a stat spelled with a trailing slash came back as
/// a [FileEntry] with an empty name where SFTP and the local backend both
/// answer `dir`. The root keeps its one slash, being all it is.
String _withoutTrailingSlash(String path) {
  var end = path.length;
  while (end > 1 && path[end - 1] == '/') {
    end--;
  }
  return path.substring(0, end);
}

/// What [shellStatCommand] prints when there is nothing at the path.
///
/// Not a word anyone would type: it is compared against the whole of stdout,
/// and a filename could otherwise be mistaken for it.
const kShellStatAbsentMark = '__sb_absent__';

/// What [shellStatCommand] prints when it could not look: a directory on the
/// way is not searchable by this user, so whether anything is there is
/// unanswerable.
const kShellStatDeniedMark = '__sb_denied__';

/// [shellStatCommand] found nothing at the path.
const kShellStatAbsent = 44;

/// [shellStatCommand] could not look.
const kShellStatDenied = 13;

/// The five fields for the path in shell variable [variable].
///
/// Shared so a listing and a stat cannot drift apart in what they report or in
/// what order — the parser is one function and would read a changed field
/// silently as the field that used to be there.
///
/// [onVanished] is what to run when the metadata could not be read *and* the
/// path is no longer there. The two callers answer that differently and neither
/// answer is an error; a path that is still there is, and says so by failing —
/// see below.
String _emitRecord(String variable, {required String onVanished}) {
  final ref = '"\$$variable"';
  return 'name=\${$variable##*/}; '
      // One `stat` where there were three. Three processes per entry is three
      // times the cost on exactly the machines this backend exists for, and it
      // made three separate failures out of one question.
      'if meta=\$(stat -c "%a %s %Y" $ref); then '
      'perm=\${meta%% *}; rest=\${meta#* }; '
      'size=\${rest%% *}; mtime=\${rest##* }; '
      'type=u; '
      '[ -d $ref ] && type=d; '
      '[ -f $ref ] && type=f; '
      // Last, so a link is reported as a link: the two tests above follow it
      // and would otherwise answer for whatever it points at.
      '[ -L $ref ] && type=l; '
      'printf "%s\\0%s\\0%s\\0%s\\0%s\\0" '
      '"\$name" "\$perm" "\$type" "\$size" "\$mtime"; '
      // Anything still there whose metadata could not be read fails the whole
      // command, which is the point: the record used to be printed regardless,
      // with `stat`'s error on stderr and an exit status of zero over it. A
      // directory readable but not searchable lists every name and stats none
      // of them, and that came back as a successful listing with every size and
      // mode blank — where a failure is what offers the user sudo, and a host
      // whose `stat` has no `-c` at all would say so instead of quietly
      // answering nothing about every file on it.
      'elif [ -e $ref ] || [ -L $ref ]; then exit 1; '
      'else $onVanished; fi; ';
}

/// Every entry [shellListCommand] or [shellStatCommand] printed.
List<FileEntry> parseShellFileRecords(String output) {
  // Split, not filtered. The command prints five NUL-terminated fields per
  // entry and an empty one is still a field — `stat -c %a` printing nothing
  // used to be dropped, and from that entry onward names were read out of the
  // perm column and sizes out of the mtime column. A silently rearranged
  // listing is worse than a short one.
  final parts = output.split('\u0000');
  // The command's own trailing NUL leaves one empty string at the end.
  if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
  // Anything left over is not a short listing, it is an unreadable one. A
  // command killed part-way through prints an incomplete tail, and dropping it
  // answered "these are the entries" for a directory whose remaining contents
  // nobody ever saw — which is what a caller then reports as empty, or deletes
  // into. There is no version of that worth showing, so it fails instead.
  if (parts.length % 5 != 0) {
    throw const ShellFileRecordException('the listing ended mid-record');
  }
  final entries = <FileEntry>[];
  for (var i = 0; i < parts.length; i += 5) {
    final kind = switch (parts[i + 2]) {
      'd' => FileKind.dir,
      'l' => FileKind.link,
      'f' => FileKind.file,
      // The command's own "none of the above": a socket, a fifo, a device.
      'u' => FileKind.other,
      // Not one of the four tokens `_emitRecord` can print, so this is not its
      // output. Read as `other` it turned whatever the far side happened to
      // send — a banner, a shell's own error — into an entry with a name.
      final forged => throw ShellFileRecordException(
        'unknown entry type "$forged"',
      ),
    };
    entries.add(
      FileEntry(
        name: parts[i],
        kind: kind,
        size: kind == FileKind.file
            ? _shellNumber(parts[i + 3], 10, 'size')
            : null,
        modified: shellFileTime(_shellNumber(parts[i + 4], 10, 'mtime')),
        mode: _shellNumber(parts[i + 1], 8, 'mode'),
      ),
    );
  }
  return entries;
}

/// One numeric field, or null where the command printed nothing for it.
///
/// Empty is tolerated and anything else is not: a field the far side left
/// blank is a fact about that entry, while a field carrying something that is
/// not a number is a sign the output is not this command's at all — and read
/// through `tryParse` it arrived as a null indistinguishable from the first.
int? _shellNumber(String field, int radix, String what) {
  if (field.isEmpty) return null;
  final value = int.tryParse(field, radix: radix);
  if (value == null) {
    throw ShellFileRecordException('unreadable $what "$field"');
  }
  return value;
}

/// The far side's output is not a listing this can read.
///
/// Distinct from a command that failed, which says so in its own words: this
/// is a command that reported success and printed something else.
final class ShellFileRecordException implements Exception {
  const ShellFileRecordException(this.message);

  final String message;

  @override
  String toString() => 'Unreadable listing: $message';
}

/// `stat -c %Y` counts seconds; the rest of the app counts milliseconds.
DateTime? shellFileTime(int? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// `mv`, refusing a destination that is a directory.
///
/// `mv a b` moves `a` *into* `b` when `b` is one, so renaming a file to the
/// name of an existing folder files it away inside instead of failing — where
/// SFTP's own `SSH_FXP_RENAME` refuses outright, and where the browser's
/// rename dialog gives no hint that it might. Shared so that escalating an
/// SFTP rename through `sudo` cannot quietly change what the rename does.
///
/// Asked in the same command, so it costs no extra round trip. The path goes
/// through `printf`'s argument, still single-quoted, and never into a
/// double-quoted string: a filename may contain `"`, `$` or a backtick.
String shellRenameCommand(String from, String to) {
  final target = shellSingleQuote(to);
  return 'if [ -d $target ]; then '
      'printf "%s: is a directory\\n" $target >&2; exit 1; fi; '
      'mv -- ${shellSingleQuote(from)} $target';
}
