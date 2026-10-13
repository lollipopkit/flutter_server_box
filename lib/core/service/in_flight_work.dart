import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';

/// Work that suspension would cut off: an Agent reply, a file transfer.
///
/// While anything holds it, iOS is asked for background time when the app
/// leaves the foreground, rather than suspending the process at once and
/// leaving the work to hang on a connection that is gone by the time it
/// resumes. Only the transitions reach the platform.
abstract final class InFlightWork {
  static var _holds = 0;

  @visibleForTesting
  static int get holds => _holds;

  /// Holds it until the returned callback is called; calling that again does
  /// nothing, so a release on every way out cannot drop someone else's hold.
  static void Function() hold() {
    if (_holds++ == 0) unawaited(MethodChans.setInFlightWork(true));
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (--_holds == 0) unawaited(MethodChans.setInFlightWork(false));
    };
  }
}
