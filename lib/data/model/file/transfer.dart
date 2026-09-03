import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/store.dart';

/// Move a file from one place to another.
///
/// Two ends, neither privileged. `download` and `upload` were not directions,
/// they were the names of the only two pairs that existed — a server and this
/// device — and naming them made a third pair unrepresentable.
class FileTransfer {
  FileTransfer({required this.from, required this.to, this.isDir = false}) {
    // Where each end is, which is what says whether this is an upload, a
    // download, or a copy between two servers — and never a path or a name.
    //
    // Here rather than in the six places one is constructed, and here rather
    // than on the worker: this is the isolate that has the stores, and so the
    // only one where a sink exists to receive it. `file.open backend` counts
    // browsers being opened, which is not the same as anything being moved.
    Diag.crumb(
      SbDiag.file,
      'transfer',
      data: {
        'from': _refKind(from),
        'to': _refKind(to),
        'dir': isDir ? 'yes' : 'no',
      },
    );

    // Read here, on the isolate that has the stores. The one that runs the
    // transfer does not.
    timeoutSeconds = Stores.setting.timeout.fetch();
    progressUpdateIntervalSeconds =
        normalizeServerStatusRefreshSeconds(
          Stores.setting.serverStatusUpdateInterval.fetch(),
        ) ??
        Defaults.updateInterval;
  }

  final FileRef from;
  final FileRef to;

  /// Whether [from] names a directory, and so a whole tree.
  ///
  /// Carried rather than discovered, because the browser already knows — it
  /// listed the thing — and the isolate would otherwise have to connect once
  /// just to ask.
  final bool isDir;

  late final int timeoutSeconds;
  late final int progressUpdateIntervalSeconds;

  /// What to call this job: the name the file will have when it lands.
  String get name => to.name;

  /// Whether this needs an isolate of its own.
  ///
  /// Only SSH does. Its symmetric crypto is pure Dart and would peg the UI
  /// thread for the length of the transfer — that is the whole reason the
  /// isolate exists (see `benchmark/README.md`). A copy within this device has
  /// no crypto at all, and a monitor agent is reached over HTTPS, whose crypto
  /// is native. Starting an isolate for either would cost more than it saved.
  bool get needsIsolate => from is SshFileRef || to is SshFileRef;

  /// Whether the two specialised SFTP paths can serve this.
  ///
  /// They move one file each: segmented reads and a single write handle are
  /// what makes them fast, and neither generalises to a tree. A directory
  /// takes the general path whatever its two ends are.
  bool get isSingleFile => !isDir;
}

/// Which side of the app an end of a transfer is on.
///
/// A `switch` on the sealed type rather than `runtimeType`, so a fourth kind
/// of [FileRef] fails to compile here instead of arriving as a class name an
/// obfuscated build is free to rewrite.
String _refKind(FileRef ref) => switch (ref) {
  LocalFileRef() => 'local',
  SshFileRef() => 'ssh',
  MonitorFileRef() => 'monitor',
};

/// How far along, in the two numbers a list can show.
class FileTransferProgress {
  const FileTransferProgress({
    required this.percent,
    required this.transferredBytes,
  });

  final double percent;
  final int transferredBytes;
}

/// What a transfer is doing, as far as anyone watching can tell.
enum FileTransferStage {
  preparing,

  /// Reached the far side. Only a transfer with a far side reports this.
  connected,

  loading,
  finished,
}
