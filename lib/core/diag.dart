import 'package:fl_lib/fl_lib.dart';

/// The categories this app records, alongside the ones [DiagCategory] defines
/// for every app on fl_lib (`lifecycle`, `nav`, `store`, `network`).
///
/// These are the things this app does that a crash report has to be read
/// against. At `full` the same crumbs are also what says which features are
/// used, so a category with no call sites is a feature nothing can be said
/// about — see `OpenPanelSink`. That is the second reason to add one, and the
/// reason the list is not only about crashes.
///
/// Never recorded, at any level: what a prompt asked, where a tool was pointed,
/// where a server is, what a snippet contains. A category names the kind of
/// action; `data` carries things like a verb and which transport, never a value
/// the user typed.
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
  /// Separate from [terminal], which is where one is *used*: an install that
  /// fails never reaches a terminal to be counted by.
  static const linux = DiagCategory('linux');

  /// A snippet being run.
  ///
  /// Not [terminal], which is where it lands: how many people ever run one is
  /// the question, and what it *contains* is never recorded.
  static const snippet = DiagCategory('snippet');

  /// A port forward starting.
  static const forward = DiagCategory('forward');

  /// Backup and restore, whichever destination they use.
  ///
  /// The one feature where a failure is not the worst outcome — a restore that
  /// silently does nothing is — and the one nobody reports, because a user
  /// finds out about it on a device they no longer have.
  static const backup = DiagCategory('backup');

  /// The AI agent: a prompt going out, a tool it proposed being run.
  static const agent = DiagCategory('agent');

  /// Reaching a BMC, which is a machine's management controller rather than
  /// the machine.
  static const bmc = DiagCategory('bmc');

  /// Init-system units: listing them, and acting on one.
  ///
  /// Apart from [container], which is Docker and Podman. Which init system a
  /// server runs is the useful half — systemd is assumed far more often than
  /// it is true, and openrc and procd are why the abstraction exists.
  static const service = DiagCategory('service');

  /// The globe: whether it is looked at, and what puts a server on it.
  ///
  /// Never where a server is. What is recorded is which link of `IpGeo`'s
  /// chain answered and how many servers each one accounted for, which is the
  /// question the chain exists to be judged by.
  static const globe = DiagCategory('globe');

  /// Moving settings between devices: remote sync, and the push that keeps a
  /// watch or a home widget fed.
  ///
  /// Not [backup], though one is built on the other. A backup is asked for and
  /// its failure is seen; a sync runs unattended, and a user meets its failure
  /// on a device that never received anything.
  static const sync = DiagCategory('sync');
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
