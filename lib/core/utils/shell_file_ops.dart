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
    '${_emitRecord('path')}'
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
  final quoted = shellSingleQuote(path);
  return 'path=$quoted; '
      // The parent, by string rather than by `dirname`, which is one more
      // process and one more thing a minimal system may not have. `/foo` and
      // `/` both leave nothing behind, and the parent of both is the root.
      'dir=\${path%/*}; [ -z "\$dir" ] && dir=/; '
      // `-e` alone answers no for a symlink to nowhere, which is still an entry
      // somebody can see, rename and delete.
      'if [ -e "\$path" ] || [ -L "\$path" ]; then '
      '${_emitRecord('path')}'
      'elif [ ! -d "\$dir" ] || [ -x "\$dir" ]; then '
      'printf "%s" $kShellStatAbsentMark; exit $kShellStatAbsent; '
      'else printf "%s" $kShellStatDeniedMark; exit $kShellStatDenied; fi';
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
String _emitRecord(String variable) {
  final ref = '"\$$variable"';
  return 'name=\${$variable##*/}; '
      'perm=\$(stat -c %a $ref); '
      'size=\$(stat -c %s $ref); '
      'mtime=\$(stat -c %Y $ref); '
      'type=u; '
      '[ -d $ref ] && type=d; '
      '[ -f $ref ] && type=f; '
      // Last, so a link is reported as a link: the two tests above follow it
      // and would otherwise answer for whatever it points at.
      '[ -L $ref ] && type=l; '
      'printf "%s\\0%s\\0%s\\0%s\\0%s\\0" '
      '"\$name" "\$perm" "\$type" "\$size" "\$mtime"; ';
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
  final entries = <FileEntry>[];
  for (var i = 0; i + 4 < parts.length; i += 5) {
    final perm = int.tryParse(parts[i + 1], radix: 8);
    final kind = switch (parts[i + 2]) {
      'd' => FileKind.dir,
      'l' => FileKind.link,
      'f' => FileKind.file,
      _ => FileKind.other,
    };
    entries.add(
      FileEntry(
        name: parts[i],
        kind: kind,
        size: kind == FileKind.file ? int.tryParse(parts[i + 3]) : null,
        modified: shellFileTime(int.tryParse(parts[i + 4])),
        mode: perm,
      ),
    );
  }
  return entries;
}

/// `stat -c %Y` counts seconds; the rest of the app counts milliseconds.
DateTime? shellFileTime(int? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
