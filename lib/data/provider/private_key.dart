import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/locator.dart';

class PrivateKeyProvider extends BusyProvider {
  List<PrivateKeyInfo> get infos => _infos;
  late List<PrivateKeyInfo> _infos;

  void loadData() {
    _infos = locator<PrivateKeyStore>().fetch();
  }

  void addInfo(PrivateKeyInfo info) {
    _infos.add(info);
    locator<PrivateKeyStore>().put(info);
    notifyListeners();
  }

  void delInfo(PrivateKeyInfo info) {
    _infos.removeWhere((e) => e.id == info.id);
    locator<PrivateKeyStore>().delete(info);
    notifyListeners();
  }

  void updateInfo(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = _infos.indexWhere((e) => e.id == old.id);
    _infos[idx] = newInfo;
    locator<PrivateKeyStore>().update(old, newInfo);
    notifyListeners();
  }
}
