import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
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
    bakSync.sync(milliDelay: 1000);
  }

  static void delete(PrivateKeyInfo info) {
    pkis.value.removeWhere((e) => e.id == info.id);
    pkis.notify();
    Stores.key.delete(info);
    bakSync.sync(milliDelay: 1000);
  }

  static void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final idx = pkis.value.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      pkis.value.add(newInfo);
      Stores.key.put(newInfo);
      Stores.key.delete(old);
    } else {
      pkis.value[idx] = newInfo;
      Stores.key.put(newInfo);
    }
    pkis.notify();
    bakSync.sync(milliDelay: 1000);
  }
}
