import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/pkg/manager.dart';
import 'package:toolbox/data/model/pkg/upgrade_info.dart';
import 'package:toolbox/data/model/server/dist.dart';

class PkgProvider extends ChangeNotifier {
  final logger = Logger('PKG');

  SSHClient? client;
  Dist? dist;
  PkgManager? type;
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

  Future<void> init(
    SSHClient client,
    Dist? dist,
    Function() onUpgrade,
    Function() onUpdate,
    PwdRequestFunc onPasswordRequest,
    String user,
  ) async {
    this.client = client;
    this.dist = dist;
    this.onUpgrade = onUpgrade;
    this.onPasswordRequest = onPasswordRequest;
    whoami = user;

    type = fromDist(dist);
    if (type == null) {
      error = 'Unsupported dist: $dist';
    }
  }

  bool get isSU => whoami == 'root';

  void clear() {
    client = dist = updateLog = upgradeLog = upgradeable =
        error = whoami = onUpdate = onUpgrade = onPasswordRequest = null;
    isRequestingPwd = false;
  }

  Future<void> refresh() async {
    final result = await _update();
    try {
      _parse(result);
    } catch (e) {
      error = '[Server Raw]:\n$result\n[App Error]:\n$e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void _parse(String? raw) {
    if (raw == null) return;
    final list = type?.updateListRemoveUnused(raw.split('\n'));
    upgradeable = list?.map((e) => UpgradePkgInfo(e, type)).toList();
  }

  Future<String?> _update() async {
    final updateCmd = type?.update;
    if (updateCmd != null) {
      await client!.exec(
        _wrap(updateCmd),
        onStderr: _onPwd,
        onStdout: (data, sink) {
          updateLog = (updateLog ?? '') + data;
          if (onUpdate != null) onUpdate!();
          notifyListeners();
        },
      );
    }
    final listCmd = type?.listUpdate;
    if (listCmd == null) {
      error = 'Unsupported dist: $dist';
      return null;
    }
    return await client?.run(_wrap(listCmd)).string;
  }

  Future<void> upgrade() async {
    final upgradeCmd =
        type?.upgrade(upgradeable?.map((e) => e.package).join(" ") ?? '');

    if (upgradeCmd == null) {
      error = 'Unsupported dist: $dist';
      return;
    }

    await client!.exec(
      _wrap(upgradeCmd),
      onStderr: _onPwd,
      onStdout: (log, sink) {
        if (lastLog == log.trim()) return;
        upgradeLog = (upgradeLog ?? '') + log;
        lastLog = log.trim();
        notifyListeners();
        if (onUpgrade != null) onUpgrade!();
      },
    );

    upgradeLog = null;
    refresh();
  }

  Future<void> _onPwd(String event, StreamSink<Uint8List> stdin) async {
    if (isRequestingPwd) return;
    isRequestingPwd = true;
    await onPwd(event, stdin, onPasswordRequest);
    isRequestingPwd = false;
  }

  String _wrap(String cmd) =>
      'export LANG=en_US.utf-8 && ${isSU ? "" : "sudo -S "}$cmd';
}
