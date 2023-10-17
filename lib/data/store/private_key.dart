import '../../core/persistant_store.dart';
import '../model/server/private_key_info.dart';

class PrivateKeyStore extends PersistentStore<PrivateKeyInfo> {
  PrivateKeyStore() : super('key');

  void put(PrivateKeyInfo info) {
    box.put(info.id, info);
  }

  List<PrivateKeyInfo> fetch() {
    final keys = box.keys;
    final ps = <PrivateKeyInfo>[];
    for (final key in keys) {
      final s = box.get(key);
      if (s != null) {
        ps.add(s);
      }
    }
    return ps;
  }

  PrivateKeyInfo? get(String? id) {
    if (id == null) return null;
    return box.get(id);
  }

  void delete(PrivateKeyInfo s) {
    box.delete(s.id);
  }
}
