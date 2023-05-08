import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/locator.dart';

class PrivateKeyProvider extends BusyProvider {
  List<PrivateKeyInfo> get infos => _infos;
  final _store = locator<PrivateKeyStore>();
  late List<PrivateKeyInfo> _infos;

  void loadData() {
    _infos = _store.fetch();
  }

  void addInfo(PrivateKeyInfo info) {
    _infos.add(info);
    _store.put(info);
    notifyListeners();
  }

  void delInfo(PrivateKeyInfo info) {
    _infos.removeWhere((e) => e.id == info.id);
    _store.delete(info);
    notifyListeners();
  }

  void updateInfo(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = _infos.indexWhere((e) => e.id == old.id);
    _infos[idx] = newInfo;
    _store.put(newInfo);
    notifyListeners();
  }
}
