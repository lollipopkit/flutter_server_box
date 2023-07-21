extension NumX on num {
  String get convertBytes {
    const suffix = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = toDouble();
    int squareTimes = 0;
    for (; value / 1024 > 1 && squareTimes < suffix.length - 1; squareTimes++) {
      value /= 1024;
    }
    var finalValue = value.toStringAsFixed(1);
    if (finalValue.endsWith('.0')) {
      finalValue = finalValue.replaceFirst('.0', '');
    }
    return '$finalValue ${suffix[squareTimes]}';
  }
}

extension BigIntX on BigInt {
  String get convertBytes {
    const suffix = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = toDouble();
    int squareTimes = 0;
    for (; value / 1024 > 1 && squareTimes < suffix.length - 1; squareTimes++) {
      value /= 1024;
    }
    var finalValue = value.toStringAsFixed(1);
    if (finalValue.endsWith('.0')) {
      finalValue = finalValue.replaceFirst('.0', '');
    }
    return '$finalValue ${suffix[squareTimes]}';
  }
}
