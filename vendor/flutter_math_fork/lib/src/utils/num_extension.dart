import 'dart:math' as math;

extension IntExt on int {
  int clampInt(int lowerLimit, int upperLimit) {
    assert(upperLimit >= lowerLimit);
    if (this < lowerLimit) return lowerLimit;
    if (this > upperLimit) return upperLimit;
    return this;
  }
}

@pragma('dart2js:tryInline')
@pragma('vm:prefer-inline')
T max3<T extends num>(T a, T b, T c) => math.max(math.max(a, b), c);
