import 'dart:async';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';

/// Counts what the app is used for, at `full` only.
///
/// **The instrumentation is [Diag], not a second set of call sites.** Every
/// `Diag.crumb` in this app already names an action and carries redacted
/// properties, because a crumb is written to be published — see [Breadcrumb].
/// An analytics event wants exactly that, so [AptabaseSink] turns each crumb
/// into one and nothing has to be instrumented twice. Adding a crumb adds an
/// event; the two cannot drift, because there is only one of them.
///
/// **Aptabase, and the vendor SDK rather than the wire format.** That is the
/// opposite of the choice made for Sentry, and for a reason that does not
/// apply here: `sentry_flutter` was rejected because its native half installs
/// signal handlers this app cannot allow. `aptabase_flutter` is pure Dart,
/// **captures nothing on its own** — its own README says so — and four of its
/// five dependencies are already in this tree. What it does own is the two
/// things worth not reimplementing: the `systemProps` shape the server expects,
/// and the session semantics every report is grouped by.
///
/// What it sends is fixed and short: `isDebug`, `osName`, `osVersion`,
/// `locale`, `appVersion`, `appBuildNumber`, `sdkVersion`, plus a session id
/// that rotates after an hour idle. No device model, no advertising id, no
/// hardware value, and no field for a user — the protocol has nowhere to put
/// one.
///
/// **Nothing here stores an identifier, on the device or anywhere else.** What
/// identifies a run is the SDK's session id, which it rotates after an hour
/// idle and never persists.
///
/// This was briefly not the case: supporting A/B tests needs a user to stay in
/// the same arm across launches, and nothing short of a stored value does
/// that. Experiments were dropped and the id went with them, since there was
/// no second use to keep it alive for. Worth recording because the direction
/// matters — the position was reached by *removing* a feature, not by
/// engineering around it, and reintroducing experiments would mean
/// reintroducing the stored id and saying so in the privacy policy again.
abstract final class AptabaseAnalytics {
  /// The self-hosted instance's base URL. Empty unless a build supplies
  /// `--dart-define=APTABASE_HOST=...`.
  ///
  /// **Not committed, unlike the Sentry DSN.** That one is in the source
  /// because a build without it cannot report a crash, and a crash report is
  /// the thing a user is asked to send. This is the opposite case: usage
  /// counting is for whoever publishes the build, so a build someone else made
  /// — an F-Droid rebuild, a fork, a checkout — should count nothing by
  /// default rather than quietly report to an endpoint they did not choose.
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
  /// this off at the sink rather than at the SDK. That is why [_started] is a
  /// flag of its own instead of being inferred from the SDK's state.
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
  /// decision.** `Aptabase.init` is not undoable: its `_dispose` is private
  /// and reached only when the SDK decides tracking is disabled, its periodic
  /// timer and its `AppLifecycleListener` keep running, and anything already
  /// in its `StorageManager` is delivered on the next tick. So after this
  /// returns, events recorded *before* consent was withdrawn can still leave
  /// the device — nothing recorded after it can.
  ///
  /// [OpenPanelAnalytics.stop] is the shape this should have: it owns its
  /// queue, so withdrawing consent drops what was held rather than delivering
  /// it. Matching that here means either a `dispose` upstream or replacing the
  /// SDK, and until one of those happens this destination must not be
  /// configured in a build — which is also why it is not. Do not turn it on
  /// without closing this, or "off" will mean "off from now on, mostly".
  static Future<void> stop() async {
    _started = false;
  }

  /// Records one event. Never blocks, never throws.
  ///
  /// The SDK buffers and sends on its own schedule — on a timer, and when the
  /// app goes inactive — so this returns immediately and a failure to send is
  /// its problem rather than the caller's.
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
/// happens. One call site, two questions.
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

  /// Nothing to do, and that is a fact about this SDK rather than an
  /// oversight. `Aptabase` exposes no flush: it sends on its own timer and on
  /// `AppLifecycleListener.onInactive`, which is the same edge `Diag.flush` is
  /// awaited on. Calling one from the other would be asking it to do what it
  /// is already doing.
  @override
  Future<void> flush() async {}
}
