import 'package:flutter/material.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/res/store.dart';

class PrivateKeyProvider extends ChangeNotifier {
  List<PrivateKeyInfo> get pkis => _pkis;
  late List<PrivateKeyInfo> _pkis;

  void load() {
    _pkis = Stores.key.fetch();
  }

  void add(PrivateKeyInfo info) {
    _pkis.add(info);
    Stores.key.put(info);
    notifyListeners();
  }

  void delete(PrivateKeyInfo info) {
    _pkis.removeWhere((e) => e.id == info.id);
    Stores.key.delete(info);
    notifyListeners();
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = _pkis.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      _pkis.add(newInfo);
    } else {
      _pkis[idx] = newInfo;
    }
    Stores.key.put(newInfo);
    notifyListeners();
  }
}
