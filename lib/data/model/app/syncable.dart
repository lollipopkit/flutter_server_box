abstract class SyncAble<T> {
  /// If [other] is newer than [this] then return true,
  /// else return false
  bool needSync(T other);

  /// Merge [other] into [this],
  /// return [this] after merge
  T merge(T other);
}
