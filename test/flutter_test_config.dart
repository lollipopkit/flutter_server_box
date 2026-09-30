import 'dart:async';

import 'package:server_box/core/service/theme_host.dart';

/// Runs before every test file.
///
/// The shared theme code reads the app's settings through a host set once at
/// launch; the app does it in `main`, and this is the tests' launch. The store
/// it reads is resolved per call, so each test's own store is the one read.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initThemeHost();
  await testMain();
}
