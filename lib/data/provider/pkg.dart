import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/pkg/upgrade_info.dart';
import 'package:toolbox/data/model/server/dist.dart';

enum _Type { apt, yum, dnf, zypper, pkg, pacman, opkg }

class PkgProvider extends BusyProvider {
  final logger = Logger('PkgProvider');

  SSHClient? client;
  Dist? dist;
  _Type? type;
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

  PkgProvider();

  Future<void> init(
      SSHClient client,
      Dist? dist,
      Function() onUpgrade,
      Function() onUpdate,
      PwdRequestFunc onPasswordRequest,
      String user) async {
    this.client = client;
    this.dist = dist;
    this.onUpgrade = onUpgrade;
    this.onPasswordRequest = onPasswordRequest;
    whoami = user;

    switch (dist) {
      case Dist.centos:
      case Dist.rocky:
        type = _Type.yum;
        break;
      case Dist.debian:
      case Dist.ubuntu:
      case Dist.kali:
      case Dist.armbian:
        type = _Type.apt;
        break;
      case Dist.fedora:
        type = _Type.dnf;
        break;
      case Dist.opensuse:
        type = _Type.zypper;
        break;
      case Dist.freebsd:
        type = _Type.pkg;
        break;
      case Dist.wrt:
        type = _Type.opkg;
        break;
      case Dist.arch:
        type = _Type.pacman;
        break;
      case null:
        error = 'Unsupported dist: $dist';
        break;
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
    } finally {
      notifyListeners();
    }
  }

  void _parse(String? raw) {
    if (raw == null) return;
    var list = raw.split('\n');
    switch (type) {
      case _Type.yum:
        list = list.sublist(2);
        list.removeWhere((element) => element.isEmpty);
        final endLine = list.lastIndexWhere(
            (element) => element.contains('Obsoleting Packages'));
        list = list.sublist(0, endLine);
        break;
      case _Type.apt:
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
        break;
      default:
        return;
    }
    upgradeable = list.map((e) => UpgradePkgInfo(e, dist!)).toList();
  }

  Future<String?> _update() async {
    switch (type) {
      case _Type.yum:
        return await client?.run(_wrap('yum check-update')).string;
      case _Type.apt:
        await client!.exec(
          _wrap('apt update'),
          onStderr: _onPwd,
          onStdout: (data, sink) {
            updateLog = (updateLog ?? '') + data;
            notifyListeners();
            if (onUpdate != null) onUpdate!();
          },
        );
        return await client
            ?.run('apt list --upgradeable'.withLangExport)
            .string;
      default:
        error = 'Unsupported dist: $dist';
        return null;
    }
  }

  Future<void> upgrade() async {
    final upgradeCmd = () {
      switch (type) {
        case _Type.yum:
          return 'yum upgrade -y';
        case _Type.apt:
          return 'apt upgrade -y';
        default:
          return null;
      }
    }();

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
