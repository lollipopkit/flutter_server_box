import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/distribution.dart';

class AptProvider extends BusyProvider {
  SSHClient? client;
  Distribution? dist;
  String? whoami;
  List<UpgradePkgInfo>? upgradeable;
  String? error;
  String? updateLog;
  Function()? onUpgrade;

  AptProvider();

  Future<void> init(
      SSHClient client, Distribution dist, Function() onUpgrade) async {
    this.client = client;
    this.dist = dist;
    this.onUpgrade = onUpgrade;
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

    final result = await _update();
    try {
      getUpgradeableList(result);
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void getUpgradeableList(String raw) {
    switch (dist) {
      case Distribution.rehl:
        var list = raw.split('\n').sublist(2);
        list.removeWhere((element) => element.isEmpty);
        final endLine = list.lastIndexWhere(
            (element) => element.contains('Obsoleting Packages'));
        list = list.sublist(0, endLine);
        upgradeable = list.map((e) => UpgradePkgInfo(e, dist!)).toList();
        break;
      case Distribution.debian:
      case Distribution.unknown:
      default:
        final list = raw.split('\n').sublist(4);
        list.removeWhere((element) => element.isEmpty);
        upgradeable = list.map((e) => UpgradePkgInfo(e, dist!)).toList();
    }
  }

  Future<String> _update() async {
    switch (dist) {
      case Distribution.rehl:
        return await client!.run('yum check-update').string;
      case Distribution.debian:
      default:
        await client!.run('apt update');
        return await client!.run('apt list --upgradeable').string;
    }
  }

  Future<void> upgrade() async {
    if (client == null) {
      error = 'No client';
      return;
    }
    updateLog = null;

    final session = await client!.execute(upgradeCmd);
    session.stdout.listen((data) {
      updateLog = (updateLog ?? '') + data.string;
      notifyListeners();
      onUpgrade!();
    });
    refreshInstalled();
  }

  String get upgradeCmd {
    switch (dist) {
      case Distribution.rehl:
        return 'yum upgrade -y';
      case Distribution.debian:
      default:
        return 'apt upgrade -y';
    }
  }
}
