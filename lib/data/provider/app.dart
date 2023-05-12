import 'package:toolbox/core/provider_base.dart';

class AppProvider extends BusyProvider {
  int? _newestBuild;
  int? get newestBuild => _newestBuild;

  bool _moveBg = true;
  bool get moveBg => _moveBg;

  void setNewestBuild(int build) {
    _newestBuild = build;
    notifyListeners();
  }

  void setCanMoveBg(bool moveBg) {
    _moveBg = moveBg;
  }
}
