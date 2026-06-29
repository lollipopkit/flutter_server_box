import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/store.dart';

class SftpReq {
  final Spi spi;
  final String remotePath;
  final String localPath;
  final SftpReqType type;
  String? privateKey;
  Spi? jumpSpi;
  String? jumpPrivateKey;
  Map<String, Spi>? jumpSpisById;
  Map<String, String>? privateKeysByKeyId;
  Map<String, String>? knownHostFingerprints;
  late final int timeoutSeconds;
  late final int progressUpdateIntervalSeconds;

  SftpReq(this.spi, this.remotePath, this.localPath, this.type) {
    timeoutSeconds = Stores.setting.timeout.fetch();
    progressUpdateIntervalSeconds =
        normalizeServerStatusRefreshSeconds(
          Stores.setting.serverStatusUpdateInterval.fetch(),
        ) ??
        Defaults.updateInterval;
    privateKeysByKeyId = {};

    final keyId = spi.keyId;
    if (keyId != null) {
      privateKey = getPrivateKey(keyId);
      privateKeysByKeyId![keyId] = privateKey!;
    }

    final allServers = {
      for (final server in Stores.server.fetch()) server.id: server,
    };
    jumpSpisById = collectJumpServers(spi: spi, serversById: allServers);

    final firstJumpId = spi.firstJumpId;
    if (firstJumpId != null) {
      jumpSpi = jumpSpisById?[firstJumpId];
      jumpPrivateKey = Stores.key.fetchOne(jumpSpi?.keyId)?.key;
      if (jumpSpi?.keyId case final jumpKeyId?) {
        if (jumpPrivateKey != null) {
          privateKeysByKeyId![jumpKeyId] = jumpPrivateKey!;
        }
      }
    }

    for (final jump in jumpSpisById?.values ?? const <Spi>[]) {
      final jumpKeyId = jump.keyId;
      if (jumpKeyId == null || privateKeysByKeyId!.containsKey(jumpKeyId)) {
        continue;
      }
      final key = Stores.key.fetchOne(jumpKeyId)?.key;
      if (key == null) {
        continue;
      }
      privateKeysByKeyId![jumpKeyId] = key;
    }

    if (jumpSpisById != null && jumpSpisById!.isEmpty) {
      jumpSpisById = null;
    }
    if (privateKeysByKeyId != null && privateKeysByKeyId!.isEmpty) {
      privateKeysByKeyId = null;
    }

    try {
      knownHostFingerprints = Map<String, String>.from(
        Stores.setting.sshKnownHostFingerprints.get(),
      );
    } catch (e, s) {
      Loggers.app.warning('Failed to load SSH known host fingerprints', e, s);
      knownHostFingerprints = null;
    }
  }
}

enum SftpReqType { download, upload }

class SftpTransferProgress {
  final double percent;
  final int transferredBytes;

  const SftpTransferProgress({
    required this.percent,
    required this.transferredBytes,
  });
}

enum SftpWorkerStatus { preparing, sshConnectted, loading, finished }
