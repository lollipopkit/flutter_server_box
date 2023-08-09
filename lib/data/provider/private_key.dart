import 'package:flutter/material.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/locator.dart';

class PrivateKeyProvider extends ChangeNotifier {
  List<PrivateKeyInfo> get pkis => _pkis;
  final _store = locator<PrivateKeyStore>();
  late List<PrivateKeyInfo> _pkis;

  void loadData() {
    _pkis = _store.fetch();
  }

  void add(PrivateKeyInfo info) {
    _pkis.add(info);
    _store.put(info);
    notifyListeners();
  }

  void delete(PrivateKeyInfo info) {
    _pkis.removeWhere((e) => e.id == info.id);
    _store.delete(info);
    notifyListeners();
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = _pkis.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      _pkis.add(newInfo);
    } else {
      _pkis[idx] = newInfo;
    }
    _store.put(newInfo);
    notifyListeners();
  }
}
