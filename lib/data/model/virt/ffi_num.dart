/// FFI numbers and times as the virt models hold them, and back. Imported by
/// the files that convert, not exported with the models.
library;

extension VirtFfiInt on int {
  BigInt get big => BigInt.from(this);

  /// Unix seconds, as local time.
  DateTime get unixTime => DateTime.fromMillisecondsSinceEpoch(this * 1000);

  /// Seconds as a duration; none when not positive.
  Duration? get positiveSeconds => this > 0 ? Duration(seconds: this) : null;
}

extension VirtFfiTime on DateTime {
  int get unixSeconds => millisecondsSinceEpoch ~/ 1000;
}
