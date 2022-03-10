import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/distribution.dart';

class AptProvider extends BusyProvider {
  SSHClient? client;
  Distribution? dist;
  String? whoami;
  List<AptUpgradePkgInfo>? upgradeable;
  String? error;
  String? updateLog;

  AptProvider();

  Future<void> init(SSHClient client, Distribution dist) async {
    this.client = client;
    this.dist = dist;
    whoami = (await client.run('whoami').string).trim();
  }

  bool get isSU => whoami == 'root';

  void clear() {
    client = null;
    dist = null;
    upgradeable = null;
    error = null;
    updateLog = null;
    whoami = null;
  }

  Future<void> refreshInstalled() async {
    if (client == null) {
      error = 'No client';
      return;
    }
    await update();
    final result = await client!.run('apt list --upgradeable').string;
    try {
      final list = result.split('\n').sublist(4);
      list.removeWhere((element) => element.isEmpty);
      upgradeable = list.map((e) => AptUpgradePkgInfo(e, dist!)).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> update() async {
    if (client == null) {
      error = 'No client';
      return;
    }
    await client!.run('apt update');
  }

  Future<void> upgrade() async {
    if (client == null) {
      error = 'No client';
      return;
    }
    updateLog = null;

    final session = await client!.execute('apt upgrade -y');
    session.stdout.listen((data) {
      updateLog = (updateLog ?? '') + data.string;
      notifyListeners();
    });
    refreshInstalled();
  }
}
