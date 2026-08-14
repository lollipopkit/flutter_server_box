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
  FileTransfer({required this.from, required this.to}) {
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

  late final int timeoutSeconds;
  late final int progressUpdateIntervalSeconds;

  /// What to call this job: the name the file will have when it lands.
  String get name => to.name;

  /// Whether this needs an isolate of its own.
  ///
  /// Copying within this device is a file copy with no crypto in it, and the
  /// isolate exists because SSH's symmetric crypto is pure Dart and would peg
  /// the UI thread. Starting one out of symmetry would cost more than it saved.
  bool get needsIsolate => !(from is LocalFileRef && to is LocalFileRef);
}

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
