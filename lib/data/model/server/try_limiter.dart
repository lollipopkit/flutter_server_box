import 'package:server_box/data/res/store.dart';

class TryLimiter {
  final Map<String, int> _triedTimes = {};

  static final _default = TryLimiter();

  static bool canTry(String id) {
    final maxCount = Stores.setting.maxRetryCount.fetch();
    if (maxCount <= 0) {
      return true;
    }
    final times = _default._triedTimes[id] ?? 0;
    if (times >= maxCount) {
      return false;
    }
    return true;
  }

  static void inc(String sid) {
    _default._triedTimes[sid] = (_default._triedTimes[sid] ?? 0) + 1;
  }

  static void reset(String id) {
    _default._triedTimes[id] = 0;
  }

  static void clear() {
    _default._triedTimes.clear();
  }
}
