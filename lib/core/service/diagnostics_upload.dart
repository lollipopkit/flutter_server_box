import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/core/service/diagnostics_platform.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';

/// The revision of the crash-collection notice.
///
/// Bumped when what is collected changes materially, which shows the intro
/// page again — consent given for one arrangement is not consent for another.
const kDiagnosticsConsentVer = 1;

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
/// **Off unless the user turns it on.** That is the only gate, and it is the
/// one F-Droid's Tracking anti-feature actually asks for: opt-in, disabled by
/// default, and told plainly what is sent.
abstract final class DiagnosticsUpload {
  /// Where reports go.
  ///
  /// Committed rather than injected, because a Sentry DSN is not a secret: it
  /// ships inside every client that uses it, is recoverable from any build,
  /// and grants only the ability to *write* events — it reads nothing back.
  ///
  /// The alternative was a build-time define, which would have left every
  /// F-Droid build without an upload path. That sounds tidy and is the wrong
  /// trade: opt-in and off-by-default is already what the anti-feature policy
  /// requires, so the define bought no compliance — it only excluded the users
  /// most likely to hit the crashes, since F-Droid is where a large part of
  /// this app's Android install base comes from. All three open crash reports
  /// are from that side.
  ///
  /// Still overridable with `--dart-define=SENTRY_DSN=...`, which is how a
  /// build points at a test instance instead of the live one.
  static const dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'https://b13cb67be5014853ac12fb760acf2b97@sentry.lollipopkit.com/1',
  );

  /// Whether this build can upload at all.
  ///
  /// Normally true; false only where a build deliberately defined an empty
  /// DSN. The settings page hides the switch when it is false, since a switch
  /// that cannot do anything is worse than one that is not offered.
  static bool get availableInBuild => dsn.isNotEmpty;

  static DiagnosticsLevel? _started;

  /// What the user has chosen.
  static DiagnosticsLevel get level =>
      DiagnosticsLevel.fromName(Stores.setting.diagnosticsLevel.fetch());

  /// Starts, stops or re-levels uploading to match the setting.
  ///
  /// Safe to call whenever the setting changes, and at launch.
  ///
  /// Nothing is uploaded until the intro page explaining the levels has been
  /// acknowledged. Off Android the default is `basic`, so without this check a
  /// fresh install would be sending before it had said anything — which is the
  /// difference between "opt-in" and "on by default" in F-Droid's terms, and
  /// the difference between asking and not in anyone else's.
  static Future<void> sync() async {
    final acknowledged =
        Stores.setting.diagnosticsConsentVer.fetch() >= kDiagnosticsConsentVer;
    final wanted = availableInBuild && acknowledged && level.uploads
        ? level
        : null;

    if (wanted == _started) return;
    if (wanted == null) {
      await _stop();
    } else if (_started == null) {
      await _start(wanted);
    } else if (_started!.streamsLogs != wanted.streamsLogs ||
        _started!.tracesPerformance != wanted.tracesPerformance) {
      // `enableLogs` and `tracesSampleRate` are read when the SDK is built, so
      // moving between basic and full has to rebuild it. Breadcrumb filtering
      // is read per call and would not have needed this.
      await _stop();
      await _start(wanted);
    } else {
      _started = wanted;
    }
  }

  static Future<void> _start(DiagnosticsLevel wanted) async {
    try {
      await sentry.Sentry.init((options) {
        options.dsn = dsn;
        options.release = 'server_box@1.0.${BuildData.build}';

        // At `full` these two are what turn "report a crash" into "report what
        // the app is doing": the log stream and traced operations arrive as
        // they happen rather than being held until something breaks. They are
        // also the only settings here whose cost scales with *use* rather than
        // with failures, which is why they are the level's defining feature
        // and not a default.
        options.enableLogs = wanted.streamsLogs;
        options.tracesSampleRate = wanted.tracesPerformance ? 1.0 : 0.0;
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
      _started = wanted;
      // Before the sink is installed, so the first error to arrive already
      // says what it arrived from. The pure-Dart SDK cannot work this out for
      // itself — see [DiagnosticsPlatform], which is also where the line
      // between "what hardware" and "whose hardware" is drawn.
      await DiagnosticsPlatform.describe();
      Diag.install(FanOutSink([LocalDiagnosticsSink(), const SentrySink()]));
      Loggers.app.info('Crash upload started at ${wanted.name}');
    } catch (e, s) {
      // A bad DSN or an unreachable server must not stop the app, and must
      // not take the local log down with it.
      Loggers.app.warning('Crash upload failed to start', e, s);
      _started = null;
    }
  }

  static Future<void> _stop() async {
    // Taken out of the sink first, so nothing is handed to an SDK that is
    // being shut down — and so withdrawing consent stops delivery rather than
    // asking the SDK to be quiet.
    Diag.install(LocalDiagnosticsSink());
    _started = null;
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
    // The one thing `basic` withholds. A crumb is already redacted — it says
    // "a machine on a LAN", not which — so this is not about identifiability
    // but about how much of a session's shape leaves the device.
    if (!DiagnosticsUpload.level.sendsBreadcrumbs) return;
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

  /// Forwards the log stream, at `full` only.
  ///
  /// This is the one channel that carries traffic while nothing is wrong, so
  /// it is gated on the level rather than on a sampling rate: a user who chose
  /// `basic` asked for failures, not for a running commentary.
  @override
  void log(DiagLevel level, String message, {String? logger}) {
    if (!DiagnosticsUpload.level.streamsLogs) return;
    final attrs = logger == null
        ? null
        : {'logger': sentry.SentryAttribute.string(logger)};
    // Fire-and-forget: a log line must never make the caller wait on a
    // network round trip, and losing one to a dropped connection costs
    // nothing that the local file has not already recorded.
    switch (level) {
      case DiagLevel.error:
        unawaited(Future.value(sentry.Sentry.logger.error(message, attributes: attrs)));
      case DiagLevel.warning:
        unawaited(Future.value(sentry.Sentry.logger.warn(message, attributes: attrs)));
      case DiagLevel.info:
        unawaited(Future.value(sentry.Sentry.logger.info(message, attributes: attrs)));
      case DiagLevel.debug:
        unawaited(Future.value(sentry.Sentry.logger.debug(message, attributes: attrs)));
    }
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
