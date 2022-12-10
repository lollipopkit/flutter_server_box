import 'package:toolbox/core/persistant_store.dart';

class DockerStore extends PersistentStore {
  String? getDockerHost(String id) {
    return box.get(id);
  }

  void setDockerHost(String id, String host) {
    box.put(id, host);
  }
}
