import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/base.dart';
import 'package:server_box/data/res/store.dart';

class PrivateKeyProvider extends Provider {
  const PrivateKeyProvider._();
  static const instance = PrivateKeyProvider._();

  static final pkis = <PrivateKeyInfo>[].vn;

  @override
  void load() {
    super.load();
    pkis.value = Stores.key.fetch();
  }

  static void add(PrivateKeyInfo info) {
    pkis.value.add(info);
    pkis.notify();
    Stores.key.put(info);
  }

  static void delete(PrivateKeyInfo info) {
    pkis.value.removeWhere((e) => e.id == info.id);
    pkis.notify();
    Stores.key.delete(info);
  }

  static void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = pkis.value.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      pkis.value.add(newInfo);
    } else {
      pkis.value[idx] = newInfo;
    }
    pkis.notify();
    Stores.key.put(newInfo);
  }
}
