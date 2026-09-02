import 'package:fl_lib/fl_lib.dart';

/// The categories this app records, alongside the ones [DiagCategory] defines
/// for every app on fl_lib (`lifecycle`, `nav`, `store`, `network`).
///
/// These are the things this app does that a crash report has to be read
/// against. Both open reports naming a crash point at a terminal, and neither
/// says which kind of terminal — [terminal] carries the engine so the next one
/// does.
///
/// At `full` the same crumbs are also what says which features are used, so a
/// category with no call sites is a feature nothing can be said about — see
/// `OpenPanelSink`. That is the second reason to add one, and the reason the
/// list is not only about crashes.
abstract final class SbDiag {
  /// Reaching a server: which transport was chosen, whether it connected.
  static const server = DiagCategory('server');

  /// A terminal session opening or closing, and what is behind it — sshd, the
  /// iOS Linux engine, or proot on Android.
  static const terminal = DiagCategory('terminal');

  /// Browsing and transferring files, over SFTP, SCP or the agent's file API.
  static const file = DiagCategory('file');

  /// Container and service management.
  static const container = DiagCategory('container');

  /// The local Linux userland: installing one, replacing it, removing it.
  ///
  /// Separate from [terminal], which is where one is *used*. The two answer
  /// different questions — how many installs ever get one at all, against how
  /// often the one they have is opened — and an install that fails never
  /// reaches a terminal to be counted by.
  static const linux = DiagCategory('linux');

  /// A snippet being run.
  ///
  /// Not [terminal], which is where it lands: a snippet is a thing the user
  /// wrote and reuses, and how many people ever run one is the question. What
  /// it *contains* is never recorded — see the note on [Breadcrumb].
  static const snippet = DiagCategory('snippet');

  /// A port forward starting.
  static const forward = DiagCategory('forward');

  /// Backup and restore, whichever destination they use.
  ///
  /// The one feature where a failure is not the worst outcome — a restore that
  /// silently does nothing is — and the one nobody reports, because a user
  /// finds out about it on a device they no longer have.
  static const backup = DiagCategory('backup');
}

/// Keys for [Diag.tag], which is what every crumb is read against.
///
/// Named here rather than spelled at each call site: a tag written under two
/// spellings is two tags, and the second one silently replaces nothing.
abstract final class SbDiagTag {
  /// The build number. Which release a report came from is the first thing
  /// asked and the thing users most often leave out.
  static const build = 'build';

  /// Whether this build has a Linux engine at all, and which.
  static const rootfs = 'rootfs';

  /// The storage schema this install is on, after migration.
  static const schema = 'schema';
}
