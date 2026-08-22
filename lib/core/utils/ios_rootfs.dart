import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/core/utils/guest_path.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/oci_image.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

/// A Linux userland on iOS, and what it takes to get one.
///
/// The opposite problem from Android's. There, a real rootfs runs and only
/// `execve` is in the way, which proot steps around. Here an App Store app has
/// no `fork`/`exec` at all and no `/bin/sh` in its sandbox, so there is nothing
/// to enter a rootfs *with*. The answer is an interpreter — ish-arm64 — that
/// dispatches guest AArch64 to pre-compiled native gadgets, writes no machine
/// code at runtime (iOS grants no JIT entitlement) and never hands a guest
/// binary to the kernel.
///
/// The engine is C, linked into the app and reached through the eight functions
/// in `ios/Runner/ish/sbm_ish.h`. It is absent from any build made with
/// `SBM_ISH = 0` in `ios/Flutter/Ish.xcconfig` — the switch that exists so a
/// build without it is one edit away, should App Store review object — and
/// [isAvailable] is how everything else asks, exactly as on Android.
abstract final class IosRootfs {
  /// Every system unpacked in the container, in the order their directories
  /// come back.
  ///
  /// Kept rather than re-scanned, and synchronous, because what asks is a
  /// widget being built. Refreshed by [scan], [install] and [removeProfile].
  static List<LinuxProfile> get profiles => List.unmodifiable(_profiles);
  static final _profiles = <LinuxProfile>[];

  /// The one the settings point at, or the first there is.
  ///
  /// Falls back rather than answering null for a stored id whose directory has
  /// since gone: something installed is a better answer than nothing.
  static LinuxProfile? get selected {
    if (_profiles.isEmpty) return null;
    final id = linuxProfileId();
    return _profiles.firstWhereOrNull((e) => e.id == id) ?? _profiles.first;
  }

  static LinuxProfile? byId(String id) =>
      _profiles.firstWhereOrNull((e) => e.id == id);

  /// The directory the systems live in, one subdirectory each, or null before
  /// [prepare]. Nothing runs at this level — see `sbm_ish_boot`.
  static String? _container;

  /// Where the selected system's tree is, or null before [prepare].
  ///
  /// Computed rather than kept: which one is selected is a setting, and it
  /// changes while the app runs.
  static String? get root => rootOf(selected?.id);

  /// Where one profile's tree is, or null before [prepare] or without an id.
  static String? rootOf(String? id) =>
      id == null ? null : _container?.joinPath(id);

  /// Whether this build carries the engine.
  ///
  /// Three ways to be false: not iOS, built with the switch off, or built
  /// before the shim existed — the last of which throws on lookup rather than
  /// answering, so it is caught here and treated as the absence it is.
  /// Asked once and kept. Every one of the three ways to be false is decided
  /// when the app is built, so the answer cannot change while it runs — and
  /// what reads this is a widget being built: `tab_add.dart` alone asks three
  /// times per build, between the rail and the grid, and each ask was a call
  /// across FFI.
  static bool get isAvailable => _availableAnswer ??= _askAvailable();
  static bool? _availableAnswer;

  static bool _askAvailable() {
    if (!Platform.isIOS) return false;
    final available = _available;
    if (available == null) return false;
    try {
      return available();
    } catch (e, s) {
      Loggers.app.warning('sbm_ish_available', e, s);
      return false;
    }
  }

  /// The last answer [isInstalled] gave, without asking the filesystem again.
  ///
  /// Synchronous for the same reason Android's is: what asks is a widget being
  /// built, and a file check per frame answers one question a hundred times.
  static bool get isReadySync => isAvailable && _profiles.isNotEmpty;

  /// Whether there is anything to enter at all.
  static Future<bool> get isInstalled async {
    await scan();
    return _profiles.isNotEmpty;
  }

  /// Reads the container: one profile per subdirectory that holds a system.
  ///
  /// The directory listing is the list. A subdirectory that does not look
  /// unpacked is skipped rather than repaired — half of an install is not a
  /// profile, and `install` deletes what it could not finish.
  static Future<void> scan() async {
    final container = _container;
    if (container == null) {
      _profiles.clear();
      return;
    }
    // Built beside the list rather than in it. [profiles] and [selected] are
    // synchronous because what reads them is a widget being built, and every
    // frame drawn between the clear and the last await used to see nothing
    // installed — no chips, no rail rows, and `open` refusing for want of an
    // id. Renaming one was enough to hit it.
    final found = <LinuxProfile>[];
    final dir = Directory(container);
    if (!await dir.exists()) {
      _profiles.clear();
      return;
    }
    final entries = await dir.list(followLinks: false).toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final id = entry.path.split(Platform.pathSeparator).last;
      if (id.startsWith('.')) continue;
      if (!await looksUnpacked(entry.path)) continue;
      final marker = File(entry.path.joinPath(LinuxProfile.marker));
      found.add(
        LinuxProfile.decode(
          id,
          await marker.exists() ? await marker.readAsString() : '',
        ),
      );
    }
    _profiles
      ..clear()
      ..addAll(found);
  }


  /// Downloads and unpacks a system of [distro] as a profile of its own.
  ///
  /// Returns what it installed. Every other profile is left alone — this is how
  /// a second Alpine comes to sit beside the first, and why nothing here asks
  /// whether something is already installed.
  ///
  /// [into] reinstalls in place, keeping the id and the label: that is what
  /// replacing an outdated one means. Without it a new id is generated.
  ///
  /// Unpacked in Dart, because iOS will not start a process — no `tar`, and
  /// that refusal is the reason this platform has an interpreter at all. What
  /// `realfs` needs is only a directory tree, which is why this is possible;
  /// under `fakefs` it would have meant carrying a metadata database and the
  /// tool that writes one.
  ///
  /// One at a time. [_install] picks an id from the scan that opens it, so two
  /// overlapping there are handed the same one — and then the same directory,
  /// which the second deletes out from under the first.
  static Future<LinuxProfile> install({
    required LinuxDistro distro,
    LinuxProfile? into,
    String? label,
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) {
    if (_installing) {
      return Future.error(StateError('An install is already running'));
    }
    _installing = true;
    return _install(
      distro: distro,
      into: into,
      label: label,
      onProgress: onProgress,
      cancel: cancel,
    ).whenComplete(() => _installing = false);
  }

  static bool _installing = false;

  static Future<LinuxProfile> _install({
    required LinuxDistro distro,
    LinuxProfile? into,
    String? label,
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final container = _container;
    if (container == null) throw StateError('IosRootfs.prepare was not called');
    await scan();

    final id = into?.id ?? LinuxProfile.nextId(distro, _profiles.map((e) => e.id));
    final root = container.joinPath(id);
    // Read once, so that a setting changed mid-download cannot have the digest
    // checked against one distribution and the repositories written for
    // another.
    final mirror = linuxMirror(distro);

    final dir = Directory(root);
    // Reinstalling in place deletes the tree, so the engine has to let go of
    // what it mounted from it first.
    if (into != null) detach(id);
    // A userland is complete or absent; there is no repairing half of one.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final archivePath = root.joinPath('rootfs.tar.gz');
    try {
      await Dio().download(
        distro.rootfsUrl(mirror),
        archivePath,
        cancelToken: cancel,
        // The download is most of the wait, so it owns most of the bar; the
        // unpacking gets the last tenth.
        onReceiveProgress: (got, total) =>
            onProgress?.call(total > 0 ? (got / total) * 0.9 : null),
      );

      final file = File(archivePath);
      final digest = (await sha256.bind(file.openRead()).first).toString();
      if (digest != distro.sha256) {
        throw StateError(
          'The system did not match its digest and was discarded. '
          'Expected ${distro.sha256}, got $digest.',
        );
      }

      await _extract(file, dir, distro: distro, onProgress: onProgress);
      // Without these `apk` reaches nothing: the guest's sockets work and an
      // address literal is fetched fine, but there is no resolver, so every
      // mirror is a "temporary error" and every package is missing.
      // Measured on a device by `integration_test/ios_load_test.dart`.
      await seedResolvConf(root, nameservers: linuxNameservers());
      await seedRepositories(root, distro: distro, mirror: mirror);
      await seedChsh(root, force: true);
      // Last, for the reason Android's marker is last: it is the record that
      // this finished, so anything that threw above must not leave one.
      final profile = LinuxProfile(
        id: id,
        distro: distro,
        version: distro.version,
        label: label ?? into?.label ?? distro.label,
      );
      await File(root.joinPath(LinuxProfile.marker)).writeAsString(profile.encode());
      await scan();
      return profile;
    } catch (_) {
      // Nothing half-installed is left to be mistaken for a working one.
      if (await dir.exists()) await dir.delete(recursive: true);
      await scan();
      rethrow;
    } finally {
      final leftover = File(archivePath);
      if (await leftover.exists()) await leftover.delete();
    }
  }

  /// Rewrites the resolver and repository files of a system already on disk.
  ///
  /// Both are seeded at install and never again, so a mirror or a resolver
  /// changed afterwards would otherwise only take effect on the next install —
  /// which here means deleting the system and everything its package manager
  /// put in it.
  ///
  /// Written for the distribution *on disk*, not the one the setting names:
  /// with a switch pending, the repositories file apt or apk is about to read
  /// still belongs to the tree that is there.
  /// Every profile, not only the selected one: the resolvers are the device's
  /// network and apply to all of them, and a mirror belongs to a distribution
  /// so each profile of it wants the new one too.
  static Future<void> applyNetSettings() async {
    for (final profile in _profiles) {
      final root = rootOf(profile.id);
      if (root == null) continue;
      await seedResolvConf(
        root,
        nameservers: linuxNameservers(),
        overwrite: true,
      );
      await seedRepositories(
        root,
        distro: profile.distro,
        mirror: linuxMirror(profile.distro),
      );
    }
  }

  /// Removes one system and everything in it. The others stay.
  static Future<void> removeProfile(String id) async {
    // A known id, before a recursive delete is built from it. `rootOf` only
    // joins a path, so anything the caller passes becomes one.
    if (byId(id) == null) return;
    final root = rootOf(id);
    if (root == null) return;
    // Before the directory goes: its `/dev` is a fakefs whose database lives
    // inside it, and the engine keeps the name attached until told otherwise.
    //
    // And only if that worked. Deleting the tree under a mount that is still
    // live takes the database with it, and the next thing the engine reads
    // through that mount is a sqlite I/O error — which it answers with
    // `die()`, parking whichever thread asked. Seen on a device as the whole
    // app freezing a few seconds after a system was deleted.
    // Retried, because the usual reason this fails is that it was asked too
    // soon. Closing a terminal hangs its process up; the shell then has to be
    // scheduled, take the signal and exit before the pty it held stops
    // counting against `/dev/pts`, and deleting the system is one tap later.
    // Measured on a device: the first attempt answers `_EBUSY` and names
    // `/alpine/dev/pts`.
    //
    // Waiting here rather than inside the engine keeps it off the main
    // isolate: `detach` is a blocking call, and looping it in C would hold
    // both the app and `attached_lock` for as long as it took.
    var err = detach(id);
    for (var i = 0; err < 0 && i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      err = detach(id);
    }
    if (err < 0) {
      throw StateError('The Linux system is still in use ($err)');
    }
    final dir = Directory(root);
    if (await dir.exists()) await dir.delete(recursive: true);
    await scan();
  }

  /// Puts the downloaded rootfs on disk, whichever shape it came in.
  ///
  /// [LinuxDistro.compression] and [LinuxDistro.layout] are two axes because
  /// they are two decisions: what decompresses the download, and whether what
  /// falls out is the filesystem or an image describing one.
  static Future<void> _extract(
    File archiveFile,
    Directory into, {
    required LinuxDistro distro,
    void Function(double? progress)? onProgress,
  }) async {
    final bytes = await archiveFile.readAsBytes();
    final outer = TarDecoder().decodeBytes(
      decompressRootfs(bytes, distro.compression),
    );

    switch (distro.layout) {
      case LinuxRootfsLayout.plain:
        await _unpackTar(outer, into, onProgress: onProgress);
      case LinuxRootfsLayout.oci:
        // In order, and each over the last: a later layer's copy of a path
        // replaces an earlier one's, and its whiteouts delete what earlier
        // layers put there.
        for (final layer in ociLayers(outer)) {
          await _unpackTar(
            TarDecoder().decodeBytes(ociLayerTar(layer)),
            into,
            applyWhiteouts: true,
            onProgress: onProgress,
          );
        }
    }
  }

  static Future<void> _unpackTar(
    Archive archive,
    Directory into, {
    bool applyWhiteouts = false,
    void Function(double? progress)? onProgress,
  }) async {
    var done = 0;
    for (final entry in archive) {
      done++;
      if (done % 200 == 0) {
        onProgress?.call(0.9 + (done / archive.length) * 0.1);
      }
      final path = into.path.joinPath(entry.name);

      if (applyWhiteouts) {
        final mark = ociWhiteout(entry.name.split('/').last);
        if (mark != null) {
          final parent = Directory(File(path).parent.path);
          if (mark.opaque) {
            if (await parent.exists()) {
              await for (final child in parent.list(followLinks: false)) {
                await child.delete(recursive: true);
              }
            }
          } else {
            final target = parent.path.joinPath(mark.deletes!);
            final dir = Directory(target);
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            } else {
              final file = File(target);
              if (await file.exists()) await file.delete();
            }
          }
          continue;
        }
      }

      // Links as links, never followed. Under `realfs` a guest symlink is
      // resolved inside the guest, so `/bin/sh -> /bin/busybox` means the
      // guest's busybox; written as a copy of whatever the host has at that
      // path it is the wrong file, and skipped it is no file — which is how an
      // earlier attempt booted with no `/bin/sh` to run.
      if (entry.isSymbolicLink) {
        final link = Link(path);
        await link.parent.create(recursive: true);
        if (await link.exists()) await link.delete();
        await link.create(entry.symbolicLink!);
        continue;
      }
      if (entry.isDirectory) {
        // The tarball's mode is deliberately not applied. Rocky ships 17
        // directories at 0555, `/usr/bin` and `/usr/lib` among them, and
        // `realfs` hands the host's mode straight to the guest — where the
        // host process is this app rather than root, so uid 0 in the guest
        // buys nothing and a package manager cannot create its temp files.
        // Created at the default 0755 instead, which is the one difference
        // between an image that can install packages here and one that cannot.
        await Directory(path).create(recursive: true);
        continue;
      }
      if (!entry.isFile) {
        // Device nodes, which a tarball carries and no unprivileged process
        // can create. `/dev` is built at boot instead — see the C side.
        continue;
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.readBytes() ?? const []);
      // The mode the tarball recorded. It matters more here than under
      // `fakefs`: `realfs` reports the host's mode to the guest, so a busybox
      // written 0644 by Dart is a busybox the guest cannot execute.
      //
      // Through libc rather than `chmod(1)`: iOS refuses to start a process,
      // which is the same refusal that put an interpreter on this platform.
      chmodGuestFile(path, entry.mode & 0xfff);
    }
  }

  /// The host path a guest path names, or null when it names nothing inside.
  ///
  /// Simpler here than on Android and for the reason the whole platform is
  /// simpler: `realfs` mounts an ordinary directory tree, so the guest's `/etc`
  /// really is `<root>/etc` on the host. See [resolveWithinRoot] for what has
  /// to be refused — which is the same on both.
  static Future<String?> hostPathOf(String guest, {bool forWrite = false}) {
    final root = IosRootfs.root;
    if (root == null) return Future.value();
    return resolveWithinRoot(root, guest, forWrite: forWrite);
  }

  /// Locates where the filesystem would be. Call once, before anything asks.
  ///
  /// The container is `linux/`, holding one subdirectory per system. Releases
  /// before this unpacked a single tree directly at `alpine/`, and nothing
  /// moves it: such an install reads as absent and is offered fresh.
  ///
  /// TODO(migration residue; remove once no install predates the container):
  /// the old `alpine/` tree is left on disk where nothing can reach or delete
  /// it. Deliberate only because none of this has shipped — a released build
  /// would have to move it or remove it.
  static Future<void> prepare() async {
    if (!Platform.isIOS) return;
    _container = (await getApplicationSupportDirectory()).path.joinPath('linux');
    await scan();
    for (final profile in _profiles) {
      final root = rootOf(profile.id);
      if (root == null) continue;
      // A system unpacked before [install] seeded a resolver has none, and
      // nothing else would ever give it one. Writes only when absent, so a
      // guest pointed at its owner's own resolver keeps it.
      await seedResolvConf(root, nameservers: linuxNameservers());
      // Repairs a system unpacked before either existed, and carries a fix to
      // the script itself into one already installed.
      await seedChsh(root);
    }
  }

  /// What [boot] answers when the machine is already up — `-EEXIST`.
  ///
  /// Not an error anywhere: there is one machine per app process by design, so
  /// the second caller to ask for it is a terminal opening beside the Agent,
  /// or the other way round.
  static const alreadyBooted = -17;

  /// Starts the machine, once. Returns 0, [alreadyBooted] if it is already up,
  /// or a negative errno.
  ///
  /// One machine per app process, because the engine keeps its kernel state in
  /// globals — but a machine runs as many processes as it is asked to, which
  /// is what [open] is for.
  static int boot({String? profileId}) {
    final boot = _boot;
    final container = _container;
    final id = profileId ?? selected?.id;
    if (boot == null || container == null || id == null) return -1;
    final pointer = container.toNativeUtf8();
    final profile = id.toNativeUtf8();
    try {
      return boot(pointer.cast(), profile.cast());
    } finally {
      malloc.free(pointer);
      malloc.free(profile);
    }
  }

  /// Mounts a system's filesystems, so a session can be opened in it.
  ///
  /// [open] does this itself; this exists for attaching one ahead of time.
  /// Unmounts a system's filesystems, so a later [attach] mounts afresh.
  ///
  /// Negative on failure, `-EBUSY` (-16) while a session still holds them —
  /// the caller closes those first. Logged rather than thrown: a delete the
  /// user asked for goes ahead either way, and what is left is a mount that
  /// outlives the tree until the app restarts.
  static int detach(String profileId) {
    final detach = _detach;
    if (detach == null) return -1;
    final pointer = profileId.toNativeUtf8();
    try {
      final err = detach(pointer.cast());
      if (err < 0) Loggers.app.warning('sbm_ish_detach($profileId) = $err');
      return err;
    } finally {
      malloc.free(pointer);
    }
  }

  static int attach(String profileId) {
    final attach = _attach;
    if (attach == null) return -1;
    final pointer = profileId.toNativeUtf8();
    try {
      return attach(pointer.cast());
    } finally {
      malloc.free(pointer);
    }
  }

  /// Opens a session: a process in the machine, on a pty of its own.
  ///
  /// [command] null or empty gives an interactive shell. Sessions do not share
  /// a console, so a terminal and a one-shot command cannot land on each
  /// other's output.
  ///
  /// [shell] is what runs it, empty meaning `/bin/sh`. The guest has no `login`
  /// and nothing in it reads `/etc/passwd`, so this is the only thing that
  /// decides — see `linuxShell()`.
  static int open({
    String? command,
    String shell = '',
    String? profileId,
    int columns = 80,
    int rows = 25,
  }) {
    final open = _open;
    final id = profileId ?? selected?.id;
    if (open == null || id == null) return -1;
    final profile = id.toNativeUtf8();
    final shellPointer = shell.toNativeUtf8();
    final pointer = (command ?? '').toNativeUtf8();
    try {
      return open(
        profile.cast(),
        shellPointer.cast(),
        pointer.cast(),
        columns,
        rows,
      );
    } finally {
      malloc.free(profile);
      malloc.free(shellPointer);
      malloc.free(pointer);
    }
  }

  /// What [session] has printed, waiting up to [timeout] for the first byte.
  ///
  /// Null once it has ended and its output is drained; empty when it simply
  /// had nothing to say yet. A caller has to tell those apart.
  ///
  /// Bytes rather than a `String`, because that is what a console emits and
  /// the lengths it emits them in are its own — a character can arrive across
  /// two calls. This used to answer `String.fromCharCodes`, which reads every
  /// byte as one code unit, and the terminal then encoded that back to UTF-8:
  /// each byte of a multi-byte character became two. Nothing outside ASCII
  /// survived it, the tty's echo of what was typed included, so typing a
  /// Chinese character into the terminal showed mojibake before any command
  /// had run.
  static Uint8List? read(
    int session, {
    Duration timeout = const Duration(milliseconds: 200),
  }) {
    final read = _read;
    if (read == null) return null;
    final buffer = _readBuffer;
    final count = read(
      session,
      buffer.cast(),
      _readLimit,
      timeout.inMilliseconds,
    );
    // -EBUSY: a guest thread died holding the output lock. Told apart from
    // the session having ended, because the answer is different — that one
    // is over, this one is broken.
    if (count == -16) throw StateError('The guest stopped holding its lock');
    if (count < 0) return null;
    if (count == 0) return _empty;
    return Uint8List.fromList(buffer.asTypedList(count));
  }

  static const _readLimit = 8192;
  static final _empty = Uint8List(0);

  /// Allocated once and kept.
  ///
  /// A terminal reads on a timer, so this was 8 KB malloc'd and freed on every
  /// frame of every open session, for the whole life of the session — paid
  /// even while the shell sat at a prompt with nothing to say. Only ever
  /// touched from the isolate that calls [read], and its contents are copied
  /// out before the call returns, so nothing outlives the next one.
  static final Pointer<Uint8> _readBuffer = malloc<Uint8>(_readLimit);

  /// Types [input] at [session].
  ///
  /// Bytes, for the reason [read] answers in them. Decoding a terminal's byte
  /// stream to a `String` on the way in only to encode it again cannot be
  /// lossless for anything that is not already whole valid UTF-8 — a
  /// multi-byte character split across two keystrokes' worth of input among
  /// them.
  static int write(int session, List<int> input) {
    final write = _write;
    if (write == null) return -1;
    if (input.isEmpty) return 0;
    final buffer = malloc<Uint8>(input.length);
    try {
      buffer.asTypedList(input.length).setAll(0, input);
      return write(session, buffer.cast(), input.length);
    } finally {
      malloc.free(buffer);
    }
  }

  /// Tells [session] its terminal changed size.
  static void resize(int session, int columns, int rows) =>
      _resize?.call(session, columns, rows);

  /// [session]'s exit status, or null while it is still running.
  static int? exitCode(int session) {
    final code = _exitCode?.call(session) ?? -1;
    return code < 0 ? null : code;
  }

  /// Ends [session]. Its process is hung up, not killed: a shell ignores
  /// SIGTERM and takes SIGHUP as its terminal going away, which it has.
  static void close(int session) => _close?.call(session);

  // — The engine's functions ————————————————————————————————————————
  //
  // Looked up in the running process rather than a `.dylib` of their own: the
  // shim is compiled into the app, not shipped beside it. Each is resolved
  // once and left null when it is not there, which is the same answer the
  // switch being off gives — and the reason nothing above has to know which of
  // the two happened.

  static final DynamicLibrary? _process = Platform.isIOS
      ? DynamicLibrary.process()
      : null;

  static T? _look<T extends Function>(String name, T Function(DynamicLibrary) f) {
    final process = _process;
    if (process == null) return null;
    try {
      return f(process);
    } catch (_) {
      return null;
    }
  }

  static final _available = _look(
    'sbm_ish_available',
    (p) => p.lookupFunction<Bool Function(), bool Function()>('sbm_ish_available'),
  );
  static final _boot = _look(
    'sbm_ish_boot',
    (p) => p.lookupFunction<Int Function(Pointer<Char>, Pointer<Char>), int Function(Pointer<Char>, Pointer<Char>)>('sbm_ish_boot'),
  );
  static final _attach = _look(
    'sbm_ish_attach',
    (p) => p.lookupFunction<Int Function(Pointer<Char>), int Function(Pointer<Char>)>('sbm_ish_attach'),
  );
  static final _detach = _look(
    'sbm_ish_detach',
    (p) => p.lookupFunction<Int Function(Pointer<Char>), int Function(Pointer<Char>)>('sbm_ish_detach'),
  );
  static final _open = _look(
    'sbm_ish_open',
    (p) => p.lookupFunction<Int Function(Pointer<Char>, Pointer<Char>, Pointer<Char>, Int, Int), int Function(Pointer<Char>, Pointer<Char>, Pointer<Char>, int, int)>('sbm_ish_open'),
  );
  static final _read = _look(
    'sbm_ish_read',
    (p) => p.lookupFunction<Int Function(Int, Pointer<Char>, Int, Int), int Function(int, Pointer<Char>, int, int)>('sbm_ish_read'),
  );
  static final _write = _look(
    'sbm_ish_write',
    (p) => p.lookupFunction<Int Function(Int, Pointer<Char>, Int), int Function(int, Pointer<Char>, int)>('sbm_ish_write'),
  );
  static final _resize = _look(
    'sbm_ish_resize',
    (p) => p.lookupFunction<Void Function(Int, Int, Int), void Function(int, int, int)>('sbm_ish_resize'),
  );
  static final _exitCode = _look(
    'sbm_ish_exit_code',
    (p) => p.lookupFunction<Int Function(Int), int Function(int)>('sbm_ish_exit_code'),
  );
  static final _close = _look(
    'sbm_ish_close',
    (p) => p.lookupFunction<Void Function(Int), void Function(int)>('sbm_ish_close'),
  );
}
