import 'dart:async';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';

/// Counts what the app is used for, at `full` only.
///
/// **The instrumentation is [Diag], not a second set of call sites.** Every
/// `Diag.crumb` already names an action and carries redacted properties,
/// because a crumb is written to be published — see [Breadcrumb]. An analytics
/// event wants exactly that, so [AptabaseSink] turns each crumb into one and
/// nothing has to be instrumented twice.
///
/// **The vendor SDK rather than the wire format.** `aptabase_flutter` is pure
/// Dart, captures nothing on its own, and four of its five dependencies are
/// already in this tree. What it owns is the two things worth not
/// reimplementing: the `systemProps` shape the server expects, and the session
/// semantics every report is grouped by.
///
/// What it sends is fixed and short: `isDebug`, `osName`, `osVersion`,
/// `locale`, `appVersion`, `appBuildNumber`, `sdkVersion`, plus a session id
/// that rotates after an hour idle and is never persisted. No device model, no
/// advertising id, no hardware value, and no field for a user — the protocol
/// has nowhere to put one, which is also why nothing here stores an
/// identifier.
abstract final class AptabaseAnalytics {
  /// The self-hosted instance's base URL. Empty unless a build supplies
  /// `--dart-define=APTABASE_HOST=...`.
  ///
  /// **Not committed, unlike the Sentry DSN.** That one is in the source
  /// because a build without it cannot report a crash, and a crash report is
  /// the thing a user is asked to send. Usage counting is for whoever publishes
  /// the build, so a fork or an F-Droid rebuild should count nothing by default
  /// rather than quietly report to an endpoint they did not choose.
  static const host = String.fromEnvironment('APTABASE_HOST');

  /// The app key. Public by design — it can only append events — but supplied
  /// with [host] rather than committed, for the reason given there.
  ///
  /// The `SH` in the middle is Aptabase's marker for a self-hosted instance,
  /// and is what makes [host] required rather than resolved from a region.
  static const appKey = String.fromEnvironment('APTABASE_APP_KEY');

  /// Whether this build can send at all.
  static bool get availableInBuild => host.isNotEmpty && appKey.isNotEmpty;

  static bool _started = false;

  /// Whether events are being collected right now.
  static bool get started => _started;

  /// Begins a run's collection. Idempotent.
  ///
  /// `Aptabase.init` is not undoable — there is no `dispose` — so [stop] turns
  /// this off at the sink rather than at the SDK, which is why [_started] is a
  /// flag of its own rather than inferred from the SDK's state.
  static Future<void> start() async {
    if (_started) return;
    if (!availableInBuild) return;
    try {
      await Aptabase.init(appKey, InitOptions(host: host));
      _started = true;
    } catch (e) {
      // An unreachable instance must not stop the app, and must not take the
      // local sink down with it.
      Loggers.app.warning('AptabaseAnalytics.start: $e');
    }
  }

  /// Stops *recording*, which is as far as this can go.
  ///
  /// **It does not stop sending, and that is a limitation rather than a
  /// decision.** `Aptabase.init` is not undoable: anything already in its
  /// `StorageManager` is delivered on the next tick. So after this returns,
  /// events recorded *before* consent was withdrawn can still leave the
  /// device; nothing recorded after it can.
  ///
  /// [OpenPanelAnalytics.stop] owns its queue and so drops what was held
  /// instead of delivering it. Matching that here needs a `dispose` upstream or
  /// a replacement SDK, so this destination must not be configured in a build
  /// until then — which is also why it is not.
  static Future<void> stop() async {
    _started = false;
  }

  /// Records one event. Never blocks, never throws.
  ///
  /// The SDK buffers and sends on its own schedule, so this returns immediately
  /// and a failure to send is its problem rather than the caller's.
  static void capture(String event, Map<String, String> props) {
    if (!_started) return;
    unawaited(
      Aptabase.instance.trackEvent(event, props).catchError((Object e) {
        // Not through `Diag`: this is the sink's own failure, and reporting it
        // as a diagnostic would make every offline launch produce an event
        // about being unable to send events.
        Loggers.app.warning('AptabaseAnalytics.capture: $e');
      }),
    );
  }
}

/// Turns [Diag] into Aptabase events, at `full` only.
///
/// Beside [SentrySink] rather than instead of it, and the split is what each
/// backend is for: Sentry answers "what broke and what led to it", so a crumb
/// is context it holds until something fails. Aptabase answers "what is this
/// used for", so the same crumb is the answer itself and goes out as it
/// happens.
final class AptabaseSink extends DiagnosticsSink {
  const AptabaseSink();

  /// The event name a crumb becomes.
  ///
  /// `category.message`, so `nav.push` and `server.ssh connect`. Both halves
  /// are fixed phrases by [Breadcrumb]'s own rule — values live in `data` —
  /// which is what keeps the event list finite and groupable.
  static String eventName(Breadcrumb crumb) =>
      '${crumb.category.name}.${crumb.message}';

  @override
  void breadcrumb(Breadcrumb crumb) {
    if (!DiagnosticsUpload.level.sendsAnalytics) return;
    AptabaseAnalytics.capture(eventName(crumb), crumb.data ?? const {});
  }

  /// Not sent. A tag is a fact about the run, and Aptabase already collects
  /// the ones it can act on — os, app version, locale — in `systemProps`. The
  /// rest (`schema`, `rootfs`) belong to a crash report, which is Sentry's.
  @override
  void tag(String key, String? value) {}

  /// Not sent. An error is Sentry's question, and a stack trace is not
  /// something this backend can do anything with.
  @override
  void error(Object error, StackTrace? stack, {String? source}) {}

  /// Not sent, for the reason [SentrySink.log] gives: the log is written for a
  /// developer on the device and is not audited for publication.
  @override
  void log(DiagLevel level, String message, {String? logger}) {}

  /// Nothing to do: `Aptabase` exposes no flush, and sends on its own timer at
  /// the same `onInactive` edge `Diag.flush` is awaited on.
  @override
  Future<void> flush() async {}
}
