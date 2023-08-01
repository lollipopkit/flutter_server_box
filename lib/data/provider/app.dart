import 'package:toolbox/core/provider_base.dart';

class AppProvider extends BusyProvider {
  int? _newestBuild;
  int? get newestBuild => _newestBuild;

  bool moveBg = true;

  void setNewestBuild(int build) {
    _newestBuild = build;
    notifyListeners();
  }
}
