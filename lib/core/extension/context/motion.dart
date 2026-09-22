import 'package:flutter/material.dart';

/// How long a movement takes here.
///
/// Every platform has a switch for people who find motion unpleasant, and what
/// it asks for is not "no animation" but "nothing that travels": a fade is
/// fine, a card growing across the page is not. So a movement that would have
/// taken [full] is cut to something short enough that its path cannot be
/// followed — which is what turns a resize into a cross-fade without a second
/// code path for it.
///
/// Not zero. A change that happens between two frames reads as the page having
/// been replaced, which is the thing the switch is trying to avoid.
extension MotionX on BuildContext {
  Duration motion(Duration full) =>
      MediaQuery.disableAnimationsOf(this) ? Durations.short2 : full;

  /// Whether the device has asked for less movement.
  ///
  /// For the cases a shorter duration cannot express — a loop, or a value that
  /// animates on its own every few seconds.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
