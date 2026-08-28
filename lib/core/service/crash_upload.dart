import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';

/// Sends what [Diag] records to a Sentry-compatible server, when the user has
/// asked for it.
///
/// **`sentry`, not `sentry_flutter`, and that is the whole design.** The
/// Flutter package brings an Android and an iOS SDK whose job is to install
/// signal handlers for SIGSEGV and SIGABRT. This app must not have those: the
/// iOS Linux engine interrupts its guest threads with SIGUSR1 and expects to
/// own signal disposition, and `enableNativeCrashHandling = false` is a
/// runtime flag that has been reported not to take effect. The pure-Dart
/// package has no native half to disable — nothing to get wrong.
///
/// What that gives up, this app already had: native crashes come from
/// `ApplicationExitInfo` and MetricKit, and breadcrumbs are placed by hand
/// where they are worth having. It also costs nothing in dependencies — the
/// package pulls in no transitive additions at all, which is the difference
/// between a reviewable diff and an Android SDK for F-Droid to vet.
///
/// **Off unless a build supplies a DSN, and off unless the user turns it on.**
/// Those are two separate gates on purpose. The DSN is compile-time, so a
/// build that was not given one — which is every build F-Droid makes from this
/// source — has no upload path in it at all, and needs no anti-feature
/// declaration. Where the path does exist, it is still opt-in and defaults to
/// off, which is what keeps it clear of the Tracking anti-feature.
abstract final class CrashUpload {
  /// Where reports go, injected at build time with
  /// `--dart-define=SENTRY_DSN=...`.
  ///
  /// Never committed. A DSN in the source would ship in the F-Droid build too,
  /// and the point of this arrangement is that it does not.
  static const dsn = String.fromEnvironment('SENTRY_DSN');

  /// Whether this build can upload at all.
  ///
  /// Read by the settings page: an switch that cannot do anything is worse
  /// than one that is not offered, and this is false in every F-Droid build.
  static bool get availableInBuild => dsn.isNotEmpty;

  static bool _started = false;

  /// Starts or stops uploading to match the setting.
  ///
  /// Safe to call whenever the setting changes, and at launch.
  static Future<void> sync() async {
    final wanted = availableInBuild && Stores.setting.crashUpload.fetch();
    if (wanted == _started) return;
    if (wanted) {
      await _start();
    } else {
      await _stop();
    }
  }

  static Future<void> _start() async {
    try {
      await sentry.Sentry.init((options) {
        options.dsn = dsn;
        options.release = 'server_box@1.0.${BuildData.build}';

        options.tracesSampleRate = 0;
        // No IP address, no username, nothing the SDK infers. A crash report
        // is about a build and a code path, not about a person. It is the
        // default, and set anyway because a later SDK flipping it would be
        // silent.
        options.sendDefaultPii = false;
        // The crumbs this app places are deliberate and already redacted; the
        // SDK does not get to turn every `print` into one as well.
        options.enablePrintBreadcrumbs = false;
        options.maxBreadcrumbs = 200;
        // Thread names and stack dumps of unrelated isolates are not what a
        // report needs, and are the SDK guessing at context rather than this
        // app supplying it.
        options.attachThreads = false;
      });
      _started = true;
      Diag.install(FanOutSink([LocalDiagnosticsSink(), const SentrySink()]));
      Loggers.app.info('Crash upload started');
    } catch (e, s) {
      // A bad DSN or an unreachable server must not stop the app, and must
      // not take the local log down with it.
      Loggers.app.warning('Crash upload failed to start', e, s);
      _started = false;
    }
  }

  static Future<void> _stop() async {
    // Taken out of the sink first, so nothing is handed to an SDK that is
    // being shut down — and so withdrawing consent stops delivery rather than
    // asking the SDK to be quiet.
    Diag.install(LocalDiagnosticsSink());
    _started = false;
    try {
      await sentry.Sentry.close();
    } catch (e, s) {
      Loggers.app.warning('Crash upload failed to stop', e, s);
    }
  }
}

/// Forwards [Diag] to Sentry.
///
/// A second sink beside the local file rather than a replacement for it: the
/// file is what works with no network and no account, and is what a user
/// pastes into an issue. Uploading is an addition to that, never a substitute.
final class SentrySink extends DiagnosticsSink {
  const SentrySink();

  @override
  void breadcrumb(Breadcrumb crumb) {
    sentry.Sentry.addBreadcrumb(
      sentry.Breadcrumb(
        category: crumb.category.name,
        message: crumb.message,
        level: _level(crumb.level),
        data: crumb.data,
      ),
    );
  }

  @override
  void error(Object error, StackTrace? stack, {String? source}) {
    unawaited(
      sentry.Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: source == null
            ? null
            : (scope) => scope.setTag('source', source),
      ),
    );
  }

  @override
  void tag(String key, String? value) {
    sentry.Sentry.configureScope((scope) {
      if (value == null) {
        scope.removeTag(key);
      } else {
        scope.setTag(key, value);
      }
    });
  }

  /// Nothing to do: `captureException` is already dispatched when it is
  /// called, and the SDK has no separate drain. Overridden to say so, since an
  /// empty inherited `flush` looks like an oversight rather than a fact about
  /// this backend.
  @override
  Future<void> flush() async {}

  static sentry.SentryLevel _level(DiagLevel level) => switch (level) {
    DiagLevel.debug => sentry.SentryLevel.debug,
    DiagLevel.info => sentry.SentryLevel.info,
    DiagLevel.warning => sentry.SentryLevel.warning,
    DiagLevel.error => sentry.SentryLevel.error,
  };
}
