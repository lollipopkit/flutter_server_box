import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/service/app.dart';

class AppProvider extends BusyProvider {
  Map? _notify;
  Map? get notify => _notify;
  int? _newestBuild;
  int? get newestBuild => _newestBuild;

  Future<void> loadData() async {
    setBusyState(true);
    final service = AppService();
    _notify = await service.getNotify();
    setBusyState(false);
    notifyListeners();
  }

  void setNewestBuild(int build) {
    _newestBuild = build;
    notifyListeners();
  }
}
