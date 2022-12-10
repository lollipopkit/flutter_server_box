import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/distribution.dart';

class AptProvider extends BusyProvider {
  final logger = Logger('AptProvider');

  SSHClient? client;
  Distribution? dist;
  Function()? onUpgrade;
  Function()? onUpdate;
  PwdRequestFunc? onPasswordRequest;

  String? whoami;
  List<UpgradePkgInfo>? upgradeable;
  String? error;
  String? upgradeLog;
  String? updateLog;
  String lastLog = '';
  bool isRequestingPwd = false;

  AptProvider();

  Future<void> init(
      SSHClient client,
      Distribution dist,
      Function() onUpgrade,
      Function() onUpdate,
      PwdRequestFunc onPasswordRequest,
      String user) async {
    this.client = client;
    this.dist = dist;
    this.onUpgrade = onUpgrade;
    this.onPasswordRequest = onPasswordRequest;
    whoami = user;
  }

  bool get isSU => whoami == 'root';

  void clear() {
    client = dist = updateLog = upgradeLog = upgradeable =
        error = whoami = onUpdate = onUpgrade = onPasswordRequest = null;
    isRequestingPwd = false;
  }

  Future<void> refreshInstalled() async {
    final result = await _update();
    try {
      getUpgradeableList(result);
    } catch (e) {
      error = '[Server Raw]:\n$result\n[App Error]:\n$e';
    } finally {
      notifyListeners();
    }
  }

  void getUpgradeableList(String? raw) {
    if (raw == null) return;
    var list = raw.split('\n');
    switch (dist) {
      case Distribution.rehl:
        list = list.sublist(2);
        list.removeWhere((element) => element.isEmpty);
        final endLine = list.lastIndexWhere(
            (element) => element.contains('Obsoleting Packages'));
        list = list.sublist(0, endLine);
        break;
      default:
        // avoid other outputs
        // such as: [Could not chdir to home directory /home/test: No such file or directory, , WARNING: apt does not have a stable CLI interface. Use with caution in scripts., , Listing...]
        final idx =
            list.indexWhere((element) => element.contains('[upgradable from:'));
        if (idx == -1) {
          upgradeable = [];
          return;
        }
        list = list.sublist(idx);
        list.removeWhere((element) => element.isEmpty);
    }
    upgradeable = list.map((e) => UpgradePkgInfo(e, dist!)).toList();
  }

  Future<String?> _update() async {
    switch (dist) {
      case Distribution.rehl:
        return await client?.run(_wrap('yum check-update')).string;
      default:
        await client!.exec(
          _wrap('apt update'),
          onStderr: _onPwd,
          onStdout: (data, sink) {
            updateLog = (updateLog ?? '') + data;
            notifyListeners();
            onUpdate!();
          },
        );
        return await client
            ?.run('apt list --upgradeable'.withLangExport)
            .string;
    }
  }

  Future<void> upgrade() async {
    final upgradeCmd = () {
      switch (dist) {
        case Distribution.rehl:
          return 'yum upgrade -y';
        default:
          return 'apt upgrade -y';
      }
    }();

    await client!.exec(
      _wrap(upgradeCmd),
      onStderr: (data, sink) => _onPwd(data, sink),
      onStdout: (log, sink) {
        if (lastLog == log.trim()) return;
        upgradeLog = (upgradeLog ?? '') + log;
        lastLog = log.trim();
        notifyListeners();
        onUpgrade!();
      },
    );

    upgradeLog = null;
    refreshInstalled();
  }

  Future<void> _onPwd(String event, StreamSink<Uint8List> stdin) async {
    if (isRequestingPwd) return;
    isRequestingPwd = true;
    if (event.contains('[sudo] password for ')) {
      final user = pwdRequestWithUserReg.firstMatch(event)?.group(1);
      logger.info('sudo password request for $user');
      final pwd = await onPasswordRequest!();
      if (pwd.isEmpty) {
        logger.info('sudo password request cancelled');
        return;
      }
      stdin.add('$pwd\n'.uint8List);
    }
    isRequestingPwd = false;
  }

  String _wrap(String cmd) =>
      'export LANG=en_US.utf-8 && ${isSU ? "" : "sudo -S "}$cmd';
}
