/// The Linux systems this app knows how to install, and what differs between
/// them.
///
/// An enum and not a user-supplied descriptor, because every entry carries a
/// digest that has to have been verified by someone. What is fetched here is
/// executable code, and the pin is the only thing that makes downloading it
/// different from running whatever the connection returned — a mirror the user
/// types is allowed to decide *where* the bytes come from and never *which*.
///
/// Adding one is a case here and an arm in each `switch` below; the switches
/// are exhaustive, so the compiler names every place that has to answer for it.
/// What it is not is only code: an entry needs its rootfs verified to actually
/// boot. On Android that is proot, which runs glibc systems as readily as musl
/// ones. On iOS it is the ish-arm64 engine, and whether a glibc system runs
/// under it is **unverified** — Alpine is musl, and nothing else has been
/// tried.
enum LinuxDistro {
  alpine;

  /// What is stored, and what [fromName] reads back.
  ///
  /// By name rather than by index, because an index silently changes meaning
  /// when a case is inserted and this value outlives the build that wrote it.
  String get id => name;

  /// The one named [id], or [alpine] for anything else.
  ///
  /// Falls back rather than throws: this parses a stored string and a marker
  /// file, and neither is worth losing an installed system over. Alpine is the
  /// fallback because it is the only one any release ever installed.
  static LinuxDistro fromName(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => alpine);

  /// What the user sees. A proper noun, so it is not localized.
  String get label => switch (this) { LinuxDistro.alpine => 'Alpine' };

  /// The release this build installs.
  String get version => switch (this) { LinuxDistro.alpine => '3.22.5' };

  /// The branch the packages come from, which is not the same as [version]:
  /// the rootfs is one release off a branch that keeps moving under it.
  ///
  /// Alpine's is 3.22 rather than the newest, and that is not for want of
  /// updating — see [AndroidRootfs] for what apk-tools 3 does under proot.
  String get branch => switch (this) { LinuxDistro.alpine => 'v3.22' };

  /// Where this is fetched from when the user has named no mirror.
  String get defaultMirror => switch (this) {
    LinuxDistro.alpine => 'https://dl-cdn.alpinelinux.org/alpine',
  };

  /// The digest of what [rootfsUrl] answers, whatever mirror serves it.
  String get sha256 => switch (this) {
    LinuxDistro.alpine =>
      '3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70',
  };

  /// The arm64 rootfs tarball, on [mirror].
  ///
  /// arm64 alone, on both platforms: proot ships for it and nothing else, and
  /// the ish-arm64 engine interprets the architecture it runs on.
  String rootfsUrl(String mirror) => switch (this) {
    LinuxDistro.alpine =>
      '$mirror/$branch/releases/aarch64/'
          'alpine-minirootfs-$version-aarch64.tar.gz',
  };

  /// The file this system's package manager reads, and what to put in it.
  ///
  /// A path and its contents rather than a writer, so that the caller stays the
  /// one thing touching the filesystem. Both parts differ per distribution —
  /// apk reads a list of URLs, apt reads `deb <url> <suite> <components>` — so
  /// neither the name nor the format can be hoisted out of here.
  ({String path, String content}) repositories(String mirror) => switch (this) {
    LinuxDistro.alpine => (
      path: 'etc/apk/repositories',
      content: '$mirror/$branch/main\n$mirror/$branch/community\n',
    ),
  };
}

/// One Linux system unpacked on this device.
///
/// A directory under the container plus the marker inside it. The two together
/// are the whole record: no table, no setting listing what exists. A profile
/// deleted from disk therefore cannot linger in a list, and a list cannot
/// promise a tree that is not there.
///
/// [id] is that directory's name and is not in the marker — the directory *is*
/// the id. It is generated rather than typed: a name someone types has to be
/// made unique and made safe for a path, and a label does neither of those
/// jobs any worse for being ordinary text.
///
/// [distro] is a field rather than the id, which is the whole reason this type
/// exists: two Alpines side by side are two profiles of one distribution, and
/// keying the directory by distribution would have made that impossible.
final class LinuxProfile {
  /// The file each profile's directory carries, naming what is in it.
  ///
  /// Hidden, so a shell listing the guest's `/` does not show it.
  static const marker = '.installed';

  final String id;
  final LinuxDistro distro;

  /// What was unpacked. Empty for an install from a build whose marker carried
  /// no version.
  final String version;

  /// What the user sees, and may change. The distribution's own name when
  /// nothing was chosen.
  final String label;

  const LinuxProfile({
    required this.id,
    required this.distro,
    required this.version,
    required this.label,
  });

  LinuxProfile copyWith({String? label, String? version}) => LinuxProfile(
    id: id,
    distro: distro,
    version: version ?? this.version,
    label: label ?? this.label,
  );

  /// Three lines: the distribution, the version, then the label.
  ///
  /// Written by `install`, read when the container is scanned. A file rather
  /// than a setting, because it describes the tree and has to go when the tree
  /// does — a setting would outlive a directory deleted from under the app and
  /// claim an install that is not there.
  /// The label is flattened on the way out: it is the one field a user types,
  /// and a newline in it would write a fourth line that [decode] reads as a
  /// truncated name.
  String encode() =>
      '${distro.id}\n$version\n${label.replaceAll(RegExp(r'[\r\n]+'), ' ')}\n';

  /// The reverse, and every shape a build ever wrote.
  ///
  /// [id] comes from the caller because it is the directory's name.
  ///
  /// TODO(migration residue; remove once no install predates the three-line
  /// marker): the shorter forms below are earlier formats — distribution and
  /// version, a bare version string, and an empty file. The last two read as
  /// Alpine, which is what they were: nothing else was installable then.
  static LinuxProfile decode(String id, String raw) {
    final lines = raw.trim().split('\n').map((e) => e.trim()).toList();
    final distro = lines.length >= 2
        ? LinuxDistro.fromName(lines.first)
        : LinuxDistro.alpine;
    final version = switch (lines.length) {
      0 => '',
      1 => lines.first,
      _ => lines[1],
    };
    final label = lines.length >= 3 && lines[2].isNotEmpty
        ? lines[2]
        : distro.label;
    return LinuxProfile(
      id: id,
      distro: distro,
      version: version,
      label: label,
    );
  }

  /// A directory name for a new profile of [distro], not colliding with
  /// [taken].
  ///
  /// Readable rather than random — someone reading a file listing or a `du`
  /// should be able to tell which is which — and still generated, so nothing
  /// the user types reaches a path.
  static String nextId(LinuxDistro distro, Iterable<String> taken) {
    final used = taken.toSet();
    if (!used.contains(distro.id)) return distro.id;
    for (var n = 2; ; n++) {
      final candidate = '${distro.id}-$n';
      if (!used.contains(candidate)) return candidate;
    }
  }
}
