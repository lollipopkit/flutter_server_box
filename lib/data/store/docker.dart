import '../../core/persistant_store.dart';

class DockerStore extends PersistentStore<String> {
  DockerStore() : super('docker');

  String? fetch(String id) {
    return box.get(id);
  }

  void put(String id, String host) {
    box.put(id, host);
  }
}
