import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/locator.dart';

class ServerProvider extends BusyProvider {
  late List<ServerPrivateInfo> _servers;

  List<ServerPrivateInfo> get servers => _servers;

  Future<void> loadData() async {
    setBusyState(true);
    _servers = locator<ServerStore>().fetch();
    setBusyState(false);
    notifyListeners();
  }

  void addServer(ServerPrivateInfo info) {
    _servers.add(info);
    locator<ServerStore>().put(info);
    notifyListeners();
  }

  void delServer(ServerPrivateInfo info) {
    _servers.remove(info);
    locator<ServerStore>().delete(info);
    notifyListeners();
  }
}
