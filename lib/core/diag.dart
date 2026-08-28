import 'package:fl_lib/fl_lib.dart';

/// The categories this app records, alongside the ones [DiagCategory] defines
/// for every app on fl_lib (`lifecycle`, `nav`, `store`, `network`).
///
/// These are the four things this app does that a crash report has to be read
/// against. Both open reports naming a crash point at a terminal, and neither
/// says which kind of terminal — [terminal] carries the engine so the next one
/// does.
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
