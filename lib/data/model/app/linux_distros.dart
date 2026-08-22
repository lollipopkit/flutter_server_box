/// The manifest in force, and what it says about each distribution.
///
/// Loaded once by `Rootfs.prepare`, before anything reads it, in the same way
/// the platform layers locate their containers there. Reading before that
/// throws rather than answering from a default — a default here would be a
/// silent answer to "which bytes get downloaded".
///
/// ## What a manifest may and may not change
///
/// It may change what a known distribution *is*: its release, its digest, its
/// size, where it is fetched from. Those are the things that move on the
/// distributions' schedule.
///
/// It may not introduce one this build has never heard of. Installing a system
/// means writing its package manager's configuration, and the format of that
/// file is code — `LinuxDistro.repositories`. A manifest naming `debian` would
/// describe something this build could download and unpack and then leave
/// without working repositories. So [installable] is the intersection: what
/// the manifest describes and this build knows how to configure.
library;

import 'package:flutter/services.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

abstract final class LinuxDistros {
  /// Where the copy that ships inside the app lives.
  static const bundledAsset = 'assets/rootfs_manifest.json';

  static RootfsManifest? _current;

  /// Whether one has been loaded. False only before `Rootfs.prepare`.
  static bool get isLoaded => _current != null;

  static RootfsManifest get current {
    final it = _current;
    if (it == null) {
      throw StateError(
        'The rootfs manifest has not been loaded. Rootfs.prepare does that, '
        'and a test that reads distribution data has to call '
        'LinuxDistros.adoptForTest first — or loadBundled, where there is an '
        'asset bundle to read it from.',
      );
    }
    return it;
  }

  /// Takes [manifest] as the one in force.
  ///
  /// Nothing here checks it. A manifest that came off the network has to have
  /// been through `RootfsManifestTrust.verify` before it reaches this, and
  /// keeping the two apart is what stops "we parsed it" from being mistaken
  /// for "we believe it".
  static void adopt(RootfsManifest manifest) => _current = manifest;

  /// Reads the copy that ships inside the app.
  ///
  /// Unsigned, and correctly so: it arrives in the binary, so anyone who could
  /// alter it could alter the public key beside it.
  static Future<void> loadBundled() async {
    adopt(RootfsManifest.parse(await rootBundle.loadString(bundledAsset)));
  }

  /// What the manifest says about [distro], or null if it says nothing.
  ///
  /// Null is an ordinary answer, not a failure: a system installed by an
  /// earlier build carries its distribution's name in a marker file, and that
  /// name outlives any manifest that stops describing it.
  static RootfsDistro? describe(LinuxDistro distro) =>
      current.distros[distro.id];

  /// The distributions a new system can be installed of.
  ///
  /// Ordered as [LinuxDistro] declares them rather than as the manifest
  /// happens to serialise them, so a list someone is reading does not reorder
  /// itself when the manifest is refetched.
  static List<LinuxDistro> get installable => [
    for (final distro in LinuxDistro.values)
      if (current.distros.containsKey(distro.id)) distro,
  ];

  /// For tests, which have no `Rootfs.prepare` to adopt one for them.
  ///
  /// Takes an already parsed [manifest] and hands it to [adopt]; a test reads
  /// [bundledAsset] off disk itself, since there is no asset bundle in one.
  /// Named apart from [adopt] so that a production call site asking for this
  /// reads as the mistake it is.
  static void adoptForTest(RootfsManifest manifest) => adopt(manifest);
}
