/// Pending package updates, as the shared parser reports them.
///
/// **Read when something asks, not on a timer.** Working out what would be
/// upgraded costs about a second of CPU per machine, and the answer only
/// changes when somebody runs the package manager's own refresh — so it lives
/// in its own shell function (`SbPkg`, `commands::ON_DEMAND`) and the surfaces
/// that show it collect on the way in. `PkgHook` is where that is decided: the
/// updates tab asks for every machine, a server's own page for one.
///
/// A monitor-backed server is the exception and cannot be otherwise: its agent
/// collects on its own extended cycle, because a client asking for `/metrics`
/// expects an answer rather than a package manager running inside the request.
///
/// **And it never refreshes an index.** That needs root and the network,
/// and is a decision an operator makes rather than a side effect of opening a
/// page. Which is why [indexAge] exists and is load-bearing: `apt` off a
/// three-month-old cache reports zero updates, and is telling the truth about
/// what it knows rather than about the machine.
library;

class PkgUpdates {
  const PkgUpdates({
    this.manager = '',
    this.items = const [],
    this.security,
    this.indexAge,
  });

  /// `apt`, `dnf`, `yum`, `zypper`, `pacman`, `apk`, `pkg`, `brew`, or empty
  /// where the server has no manager this build can read.
  final String manager;

  final List<PkgUpdate> items;

  /// How many of [items] are security updates, or null where this manager
  /// cannot say.
  ///
  /// **Null is not zero.** Only apt, apk and zypper name the archive an update
  /// comes from well enough to tell; reporting "0 security updates" on a dnf
  /// box would be a reassurance nothing checked.
  final int? security;

  /// Since the package index was last refreshed, measured on the server so a
  /// phone with a wrong clock cannot change the answer. Null where the
  /// manager's index could not be found.
  final Duration? indexAge;

  int get total => items.length;

  /// Whether the server has a package manager this build can read at all.
  ///
  /// Told apart from "nothing to upgrade" throughout: one is a server that is
  /// up to date, the other is a question that was never answered.
  bool get supported => manager.isNotEmpty;

  /// Whether the index is old enough that a count off it means little.
  ///
  /// A week, because that is roughly where a distribution's own security
  /// updates start being missed — Debian and Ubuntu publish several a week,
  /// and `unattended-upgrades` refreshes daily. Below it the count is worth
  /// showing plainly; above it the app says how old the index is beside the
  /// number rather than instead of it.
  static const staleAfter = Duration(days: 7);

  bool get stale => indexAge != null && indexAge! > staleAfter;

  /// What a person would type to apply these, or null where this build has
  /// nothing to suggest.
  ///
  /// **Never with a yes flag.** Every one of these either asks before it does
  /// anything or is about to change the system without being able to; adding
  /// `-y` would remove the last place a person can look at the plan. The two
  /// that do not ask — `apk` and `brew` — are why the app types the command
  /// rather than sending it.
  ///
  /// `sudo` is on the ones that need root, which is all of them except brew.
  /// It may not be installed or permitted; that surfaces in the terminal,
  /// where the user can edit the line before sending it.
  String? get upgradeCommand => switch (manager) {
    'apt' => 'sudo apt-get upgrade',
    // `dnf upgrade` is the whole-system one; `update` is its old alias.
    'dnf' => 'sudo dnf upgrade',
    'yum' => 'sudo yum update',
    'zypper' => 'sudo zypper up',
    // Partial upgrades are unsupported on Arch, so this is `-Syu` rather than
    // `-Su`: anything else is how an install gets a mismatched libc.
    'pacman' => 'sudo pacman -Syu',
    'apk' => 'sudo apk upgrade',
    'pkg' => 'sudo pkg upgrade',
    'brew' => 'brew upgrade',
    _ => null,
  };

  static PkgUpdates fromJson(Map<String, dynamic> json) {
    final age = json['index_age_secs'];
    return PkgUpdates(
      manager: json['manager'] as String? ?? '',
      items: [
        for (final raw in (json['items'] as List? ?? const []))
          PkgUpdate.fromJson(raw as Map<String, dynamic>),
      ],
      security: json['security'] as int?,
      indexAge: age is int ? Duration(seconds: age) : null,
    );
  }
}

class PkgUpdate {
  const PkgUpdate({
    required this.name,
    required this.to,
    this.from,
    this.security = false,
    this.repo,
  });

  final String name;

  /// The installed version, or null where the manager did not print one — apt
  /// omits it for a package arriving as a new dependency, and dnf's
  /// `check-update` never prints it at all.
  final String? from;

  final String to;

  /// Only meaningful where [PkgUpdates.security] is non-null.
  final bool security;

  /// The archive it comes from, as the manager named it.
  final String? repo;

  static PkgUpdate fromJson(Map<String, dynamic> json) => PkgUpdate(
    name: json['name'] as String? ?? '',
    from: json['from'] as String?,
    to: json['to'] as String? ?? '',
    security: json['security'] as bool? ?? false,
    repo: json['repo'] as String?,
  );
}
