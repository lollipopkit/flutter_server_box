/// The two files a freshly unpacked Linux system needs before its package
/// manager works, and the settings that decide what goes in them.
///
/// Shared by both platforms rather than owned by either, because what they
/// share is the tarball: Android and iOS download the same rootfs and check it
/// against the same digest. Kept apart they drifted — Android seeded both and
/// iOS seeded neither, so `apk` on a phone worked and `apk` on an iPad reported
/// every package as missing, which reads as a broken mirror rather than a
/// missing resolver.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/store.dart';

/// Which profile the app opens a terminal in, by `LinuxProfile.id`.
///
/// A profile and not a distribution: two Alpines side by side are two profiles
/// of one distribution, so the distribution cannot be what identifies either.
/// Empty until something is chosen, which the platform layer reads as "the
/// first one there is".
String linuxProfileId() => Stores.setting.linuxProfile.fetch();

/// Which distribution a *new* profile would be of.
LinuxDistro linuxDistro() =>
    LinuxDistro.fromName(Stores.setting.linuxDistro.fetch());

/// Where [distro] is fetched from, without a trailing slash so a caller can
/// join a path onto it.
///
/// A setting because the official mirror is not reachable from every network,
/// and every mirror of one distribution carries the same tree under the same
/// layout.
///
/// It decides where the bytes come from and not which bytes are accepted: the
/// release is pinned and its digest checked by the caller that downloads it,
/// and the package manager verifies each package against the keys in the
/// rootfs. A mirror serving something else fails both of those, not this.
///
/// Per distribution, because a mirror of one is not a mirror of another — held
/// as a map so that switching away and back does not quietly drop what was
/// typed.
///
/// Falls back rather than throws. What is stored is whatever a text field last
/// held, and a system that will not install because a setting is malformed is
/// worse than one installed from the default.
String linuxMirror([LinuxDistro? distro]) {
  final it = distro ?? linuxDistro();
  final raw = (Stores.setting.linuxMirrors.fetch()[it.id] ?? '').trim();
  if (!isMirrorValid(raw)) return it.defaultMirror;
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

/// Records [mirror] as [distro]'s, or forgets it when [mirror] is empty.
///
/// Empty rather than a separate reset: a field cleared to nothing is how
/// someone asks for the default back, and storing the default verbatim would
/// pin it against a future release that moves it.
void setLinuxMirror(LinuxDistro distro, String mirror) {
  final next = Map<String, String>.from(Stores.setting.linuxMirrors.fetch());
  if (mirror.trim().isEmpty) {
    next.remove(distro.id);
  } else {
    next[distro.id] = mirror.trim();
  }
  Stores.setting.linuxMirrors.put(next);
}

/// Whether [value] is a URL a mirror could be at.
///
/// What the settings page refuses, and what [linuxMirror] falls back from.
/// `http` is allowed beside `https` because some mirrors are only reachable
/// that way, and neither the tarball's digest nor the package signatures depend
/// on the transport.
bool isMirrorValid(String value) {
  final url = Uri.tryParse(value);
  return url != null &&
      url.hasAuthority &&
      (url.isScheme('http') || url.isScheme('https'));
}

/// The resolvers to write into the guest's `/etc/resolv.conf`.
///
/// Not per distribution: this is the network the device is on, and every
/// distribution reads the same file. A setting for the same reason the mirror
/// is one, and with less to go on when it is wrong — a package manager reports
/// a resolver it cannot reach as a temporary error against the *mirror*, so the
/// address that is actually failing is never named.
List<String> linuxNameservers() {
  final chosen = parseNameservers(Stores.setting.linuxDns.fetch());
  return chosen.isEmpty ? parseNameservers(Defaults.linuxDns) : chosen;
}

/// The addresses in [value], which is whatever was typed into a text field —
/// commas, spaces or newlines between them.
///
/// Anything that is not an IP address is dropped. `resolv.conf` takes addresses
/// only, and a resolver library reads a name there as a resolver at an address
/// it can never reach — so a hostname typed here would fail as a timeout rather
/// than as the mistake it is.
List<String> parseNameservers(String value) => value
    .split(RegExp(r'[\s,;]+'))
    .where((e) => e.isNotEmpty && InternetAddress.tryParse(e) != null)
    .toList();

/// Where a system records the shell its terminals start with.
///
/// Inside the guest, not in the app's settings, and that is the whole point:
/// it makes one file the answer for both sides. The app writes it from the
/// settings page and reads it when opening a terminal; `chsh` inside the guest
/// writes the same file. Two stores would have meant two answers and a rule
/// about which wins.
///
/// Per system rather than one for all of them, which falls out of the same
/// choice: a shell is a path to a file inside one tree, and `/usr/bin/fish`
/// being installed in one says nothing about another.
const shellConfPath = 'etc/serverbox/shell';

/// What an interactive terminal in [root] runs.
///
/// The guest has no `login` and nothing in it reads `/etc/passwd`, so this file
/// is the only thing that decides — which is also why Alpine shipping no `chsh`
/// does not come into it, and why the `chsh` this app puts in the guest can be
/// a shell script.
///
/// **Interactive only.** A one-shot command keeps `/bin/sh`, because the app
/// and the Agent write POSIX and parse what comes back: `fish` is not a POSIX
/// shell, so a status script or an `&&` run through the user's choice would
/// fail in ways that read as the remote host being broken.
///
/// Read at the moment a terminal opens rather than from anything cached, so a
/// `chsh` run in the guest a second ago is in force now.
String linuxShell(String? root) {
  if (root == null) return Defaults.linuxShell;
  try {
    final raw = File(root.joinPath(shellConfPath)).readAsStringSync().trim();
    return isShellPathValid(raw) ? raw : Defaults.linuxShell;
  } catch (_) {
    // Absent, unreadable, whatever: a terminal that opens on `/bin/sh` beats
    // one that does not open.
    return Defaults.linuxShell;
  }
}

/// Records [shell] as [root]'s, or restores the default when it is empty.
Future<void> setLinuxShell(String root, String shell) async {
  final file = File(root.joinPath(shellConfPath));
  await file.parent.create(recursive: true);
  final chosen = shell.trim();
  await file.writeAsString(
    '${isShellPathValid(chosen) ? chosen : Defaults.linuxShell}\n',
  );
}

/// Whether [value] could name a shell inside the guest.
///
/// A guest-absolute path and nothing else. Anything relative would be resolved
/// against a working directory the session has not got yet, and the engine
/// would answer `ENOENT` from inside `sbm_ish_open` — a terminal that opens and
/// dies with the reason nowhere on screen.
bool isShellPathValid(String value) =>
    value.startsWith('/') && !value.contains(RegExp(r'\s'));

/// Whether [root] holds a file at the guest path [shell].
///
/// Checked before the setting is stored rather than after a terminal fails to
/// open. Under `realfs` the guest's `/bin/fish` really is `<root>/bin/fish` on
/// the host, so this is one `stat` — and links are not followed for the reason
/// [looksUnpacked] does not follow them.
Future<bool> shellExistsIn(String root, String shell) async {
  if (!isShellPathValid(shell)) return false;
  final type = await FileSystemEntity.type(
    root.joinPath(shell.substring(1)),
    followLinks: false,
  );
  return type != FileSystemEntityType.notFound;
}

/// A `chsh` for a system that has not got one.
///
/// Alpine ships none — it is in `shadow`, which a minirootfs does not carry —
/// and installing the real one would not help: it edits `/etc/passwd`, and
/// nothing in this guest reads that. There is no `login` here. What decides is
/// [shellConfPath], so a stand-in that writes that file does the job the real
/// one is reached for, and does it in a shell script.
///
/// At `/usr/local/bin`, which comes before `/usr/bin` in the PATH the engine
/// sets. So it also shadows the real `chsh` for anyone who installs `shadow`
/// afterwards — which is the outcome to want, since that one would edit a file
/// with no readers and report success.
const _chshVersion = 1;

String _chshScript(String defaultShell) =>
    '''
#!/bin/sh
# serverbox-chsh v$_chshVersion
#
# Rewritten by ServerBox when the version above changes. Local edits do not
# survive that; the file it writes, $shellConfPath, is yours.
set -e

conf=/$shellConfPath
usage() {
	echo "usage: chsh [-s SHELL] [-l]" >&2
	echo "       ServerBox's chsh. It sets the shell new terminals open with," >&2
	echo "       by writing \$conf. Nothing here reads /etc/passwd." >&2
	exit 2
}

current() {
	if [ -r "\$conf" ]; then head -n1 "\$conf"; else echo "$defaultShell"; fi
}

case "\$1" in
	"") echo "\$(current)"; exit 0 ;;
	-l|--list-shells)
		if [ -r /etc/shells ]; then grep -v '^#' /etc/shells | grep -v '^\$'; fi
		exit 0 ;;
	-s|--shell) ;;
	*) usage ;;
esac

shell="\$2"
[ -n "\$shell" ] || usage
case "\$shell" in
	/*) ;;
	*) echo "chsh: needs an absolute path: \$shell" >&2; exit 1 ;;
esac
[ -x "\$shell" ] || { echo "chsh: not executable: \$shell" >&2; exit 1; }

mkdir -p "\$(dirname "\$conf")"
printf '%s\\n' "\$shell" > "\$conf"
echo "chsh: \$shell — takes effect in the next terminal, not this one."
''';

/// Writes the stand-in, and the file it edits.
///
/// [force] false leaves both alone when they are there and current — the
/// startup path, which repairs a system unpacked before either existed. The
/// script is rewritten when its version moved, so a fix to it reaches systems
/// already installed; the shell file never is, because that one is the user's.
Future<void> seedChsh(String root, {bool force = false}) async {
  final conf = File(root.joinPath(shellConfPath));
  if (force || !await conf.exists()) {
    await setLinuxShell(root, Defaults.linuxShell);
  }

  final script = File(root.joinPath('usr/local/bin/chsh'));
  if (!force && await script.exists()) {
    final head = await _readHead(script);
    if (head.contains('# serverbox-chsh v$_chshVersion')) return;
    // Something else's `chsh`, from `apk add shadow`. Left alone: PATH puts
    // ours first anyway, and overwriting a package's file would have `apk`
    // reporting a modified system.
    if (!head.contains('# serverbox-chsh v')) return;
  }
  await script.parent.create(recursive: true);
  await script.writeAsString(_chshScript(Defaults.linuxShell));
  chmodGuestFile(script.path, 0x1ED); // 0755
}

/// Enough of [file] to find the marker in, or empty when it cannot be read.
///
/// The marker is the script's second line, so a few kilobytes settle it. Read
/// this way rather than with `readAsString` because of the case the caller
/// goes on to handle: `apk add shadow` puts a compiled `chsh` at that path,
/// and decoding one strictly throws — out of a function that runs while the
/// app is starting, before the check that would have said to leave it alone.
///
/// Empty is the safe answer. It contains no marker, so the caller reads the
/// file as somebody else's and does not touch it.
Future<String> _readHead(File file) async {
  try {
    final handle = await file.open();
    try {
      return const Utf8Decoder(
        allowMalformed: true,
      ).convert(await handle.read(4096));
    } finally {
      await handle.close();
    }
  } catch (_) {
    return '';
  }
}

/// `chmod`, which `dart:io` has not got and a file written into a guest cannot
/// do without.
///
/// Through libc rather than `chmod(1)`: iOS refuses to start a process, which
/// is the same refusal that put an interpreter on that platform. The symbol is
/// in the process on both.
void chmodGuestFile(String path, int mode) {
  final chmod = _chmod;
  if (chmod == null || mode == 0) return;
  final pointer = path.toNativeUtf8();
  try {
    chmod(pointer.cast(), mode);
  } finally {
    malloc.free(pointer);
  }
}

/// `link`, for the same reason [chmodGuestFile] exists: `dart:io` offers only
/// symbolic links, and a rootfs is full of hard ones.
///
/// Ubuntu 26.04 ships uutils coreutils as one 10 MB multi-call binary with 115
/// hard links pointing at it, and Perl adds another. Turning those into copies
/// would cost a gigabyte; turning them into symlinks is what the tar reader
/// already did by accident, and it produced links pointing nowhere — see the
/// unpacking code. A real hard link is what the archive asked for and costs
/// nothing.
///
/// Returns whether it worked. Failure is worth handling rather than throwing:
/// the caller has a correct fallback, and a system missing `ls` is worse than
/// one whose `ls` is a symlink.
bool linkGuestFile(String target, String path) {
  final link = _link;
  if (link == null) return false;
  final targetPtr = target.toNativeUtf8();
  final pathPtr = path.toNativeUtf8();
  try {
    return link(targetPtr.cast(), pathPtr.cast()) == 0;
  } catch (_) {
    return false;
  } finally {
    malloc.free(targetPtr);
    malloc.free(pathPtr);
  }
}

final _link = () {
  try {
    return DynamicLibrary.process().lookupFunction<
        Int Function(Pointer<Char>, Pointer<Char>),
        int Function(Pointer<Char>, Pointer<Char>)>('link');
  } catch (_) {
    return null;
  }
}();

final _chmod = () {
  try {
    final process = DynamicLibrary.process();
    // `mode_t` is `uint16_t` on Darwin and `unsigned int` everywhere else this
    // ships, and the lookup has to name the width the call will actually use.
    if (Platform.isIOS || Platform.isMacOS) {
      return process
          .lookupFunction<Int Function(Pointer<Char>, Uint16), int Function(Pointer<Char>, int)>('chmod');
    }
    return process
        .lookupFunction<Int Function(Pointer<Char>, UnsignedInt), int Function(Pointer<Char>, int)>('chmod');
  } catch (_) {
    return null;
  }
}();

/// Whether [root] holds an unpacked Linux system rather than a directory.
///
/// `bin/sh` and `etc/os-release` rather than anything of one distribution's:
/// every distribution ships both, and the question here is whether *a* system
/// is there. There is no manifest to consult — under `realfs` the tree is all
/// there is.
///
/// **Nothing here is followed.** Alpine's `/bin/sh` is an absolute symlink to
/// `/bin/busybox`, which is a path inside the *guest*; resolved against the
/// host it names a file iOS does not have, so `File.exists()` answers false for
/// a tree that is perfectly fine. Measured against a device's own rootfs: every
/// existing install would have read as absent, been offered for reinstall, and
/// taken everything in it.
Future<bool> looksUnpacked(String root) async {
  for (final path in const ['bin/sh', 'etc/os-release']) {
    final type = await FileSystemEntity.type(
      root.joinPath(path),
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
  }
  return true;
}

/// A resolver, because a minirootfs ships without `/etc/resolv.conf` and
/// neither platform exposes one a guest can read.
///
/// [overwrite] false writes only when there is none — the install path, and the
/// startup path that repairs a system unpacked before any of this existed. A
/// guest whose owner has since pointed it at their own resolver by editing the
/// file is not one to overwrite behind their back. The settings page passes
/// true, because there the owner is the one asking.
///
/// [nameservers] rather than reading the setting here: what this does is write
/// a file, and a function that writes a file is worth being able to call
/// without a database behind it.
Future<void> seedResolvConf(
  String root, {
  required List<String> nameservers,
  bool overwrite = false,
}) async {
  final etc = Directory(root.joinPath('etc'));
  if (!await etc.exists()) await etc.create(recursive: true);
  final conf = File(etc.path.joinPath('resolv.conf'));
  if (!overwrite && await conf.exists()) return;
  await conf.writeAsString(nameservers.map((e) => 'nameserver $e\n').join());
}

/// Where the package manager looks, pinned to the branch the rootfs came from.
///
/// The tarball does ship this file, and with the default mirror in it. Written
/// anyway, because what is being pinned is that the rootfs and the packages
/// come from one branch — a rootfs installing packages built for another is how
/// a distribution breaks — and that has to hold whatever a future tarball
/// defaults to.
///
/// [distro] decides both the path and the format; [mirror] is passed in for the
/// reason [seedResolvConf] takes its nameservers.
Future<void> seedRepositories(
  String root, {
  required LinuxDistro distro,
  required String mirror,
}) async {
  final repo = distro.repositories(mirror);
  final file = File(root.joinPath(repo.path));
  await file.parent.create(recursive: true);
  await file.writeAsString(repo.content);
}
