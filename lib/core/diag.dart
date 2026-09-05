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

  /// The AI agent: a prompt going out, a tool it proposed being run.
  ///
  /// Never what was asked or what the tool was pointed at. A prompt is the
  /// most private thing this app handles — it can quote terminal output and
  /// file contents — so what is recorded is that one happened, and which of a
  /// fixed set of tools the model reached for.
  static const agent = DiagCategory('agent');

  /// Reaching a BMC, which is a machine's management controller rather than
  /// the machine.
  static const bmc = DiagCategory('bmc');

  /// Proxmox: reaching a cluster, and what it took to get there.
  ///
  /// Apart from [server], though it is reached through one. A PVE cluster is
  /// its own thing behind the machine — a login, a session, and usually an SSH
  /// tunnel, because the API is not normally on the public internet — and none
  /// of that is what `server` counts. Never a node name, a guest name or a
  /// VMID: those name the user's infrastructure.
  static const pve = DiagCategory('pve');

  /// The process list, and killing something in it.
  ///
  /// Apart from [service], which is init-system units. The two look alike and
  /// are not: a unit is named and declared, a process is whatever is running.
  /// Killing one is the most destructive thing this app does that nothing
  /// confirms afterwards — the command answers, and whether the process
  /// actually went is a marker the far side prints. Which of those came back
  /// is the whole question, and it differs by system type.
  static const process = DiagCategory('process');

  /// Handing a server to another device, and taking one in.
  ///
  /// Two halves that happen on two devices, which is why neither is visible
  /// from the other: a share that nobody could open leaves no trace on the
  /// device that made it. Never a name, an address or a payload — the payload
  /// is an encrypted server, credentials included.
  static const share = DiagCategory('share');

  /// Looking for servers on the network this device is on.
  ///
  /// How many an install finds, never which. The count is the question: a scan
  /// that reliably answers zero is a feature that looks broken, and the reasons
  /// it would — no `arp`, no mDNS responder, a network that isolates clients —
  /// are invisible from here and unreportable by the user.
  static const discovery = DiagCategory('discovery');

  /// Init-system units: listing them, and acting on one.
  ///
  /// Apart from [container], which is Docker and Podman. Which init system a
  /// server runs is the useful half — systemd is assumed far more often than
  /// it is true, and openrc and procd are why the abstraction exists.
  static const service = DiagCategory('service');

  /// The globe: whether it is looked at, and what puts a server on it.
  ///
  /// Never where a server is. No coordinate, no host, not even a country —
  /// what is recorded is which link of `IpGeo`'s chain answered and how many
  /// servers each one accounted for, which is the question the chain exists to
  /// be judged by: the country database costs every install the megabytes it
  /// ships in, and the city shards cost a request the user had to consent to.
  ///
  /// Apart from [server], where a coordinate typed by hand is one more field of
  /// a saved server rather than anything the globe did.
  static const globe = DiagCategory('globe');

  /// A yabs run: what was asked for, and whether it ever came back.
  ///
  /// The one feature here measured in *quarter hours*. Everything about how it
  /// is built — detached under `setsid`, watched by polling a directory, the
  /// record written at start so a reopened page picks it up — is there so a run
  /// survives the app being closed, and none of that is worth anything if runs
  /// do not finish. So the pair matters more than either half: a start with no
  /// finish is the case the design exists for and the case nobody reports,
  /// because by the time it has failed the user has moved on.
  ///
  /// Which phases were chosen is the other half, and it is the only thing that
  /// can judge [YabsOptions]' defaults — three of which deliberately disagree
  /// with yabs' own, each guessing that the user would rather spend less or
  /// disclose less. A guess nothing measures stays a guess.
  ///
  /// Never a result. A yabs run reports the machine's CPU model, its disk and
  /// network throughput and, with Geekbench on, a public URL naming it — which
  /// is the user's infrastructure described in detail. What is recorded is
  /// which phases ran and how it ended.
  static const benchmark = DiagCategory('benchmark');

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
