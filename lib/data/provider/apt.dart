import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/distribution.dart';

class AptProvider extends BusyProvider {
  SSHClient? client;
  Distribution? dist;
  List<AptUpgradePkgInfo>? upgradeable;

  AptProvider();

  void init(SSHClient client, Distribution dist) {
    this.client = client;
    this.dist = dist;
  }

  void clear() {
    client = null;
    dist = null;
    upgradeable = null;
  }

  bool get isReady {
    return upgradeable != null && !isBusy;
  }

  Future<void> refreshInstalled() async {
    await update();
    final result = utf8.decode(await client!.run('apt list --upgradeable'));
    final list = result.split('\n').sublist(4);
    list.removeWhere((element) => element.isEmpty);
    upgradeable = list.map((e) => AptUpgradePkgInfo(e, dist!)).toList();
    notifyListeners();
  }

  Future<void> update() async {
    await client!.run('apt update');
  }

  // Future<void> upgrade() async {
  //   setBusyState();
  //   await client!.run('apt upgrade -y');
  //   refreshInstalled();
  // }
}
