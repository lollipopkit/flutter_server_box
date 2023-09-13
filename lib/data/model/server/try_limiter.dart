import 'package:toolbox/data/res/store.dart';

class TryLimiter {
  final Map<String, int> _triedTimes = {};

  bool canTry(String id) {
    final maxCount = Stores.setting.maxRetryCount.fetch();
    if (maxCount <= 0) {
      return true;
    }
    final times = _triedTimes[id] ?? 0;
    if (times >= maxCount) {
      return false;
    }
    return true;
  }

  void inc(String sid) {
    _triedTimes[sid] = (_triedTimes[sid] ?? 0) + 1;
  }

  void reset(String id) {
    _triedTimes[id] = 0;
  }

  void clear() {
    _triedTimes.clear();
  }
}
