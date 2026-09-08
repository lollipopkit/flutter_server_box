import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/core/service/aptabase.dart';
import 'package:server_box/core/service/diagnostics_platform.dart';
import 'package:server_box/core/service/known_identifiers.dart';
import 'package:server_box/core/service/native_exit.dart';
import 'package:server_box/core/service/openpanel.dart';
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

  /// Whether an error handed to [Diag] *now* would be uploaded.
  ///
  /// Not the same question as [level]: a level that uploads still answers
  /// false for the whole of startup, because the sink goes in at the end of
  /// `_doPlatformRelated`. That gap is what [CrashLog.uploadsNow] reads it
  /// for — a crash inside it is one nothing sent, and the only one the next
  /// launch has to report on its behalf.
  static bool get uploading => _started != null;

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
    } else if (_started!.tracesPerformance != wanted.tracesPerformance ||
        _started!.sendsAnalytics != wanted.sendsAnalytics) {
      // `tracesSampleRate` is read when the SDK is built, so moving between
      // basic and full has to rebuild it. Breadcrumb filtering is read per
      // call and would not have needed this; analytics is here because
      // dropping to `basic` has to stop it and take the queue with it.
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

        // What `full` adds: traced operations arrive as they happen rather
        // than being held until something breaks. It is also the only setting
        // here whose cost scales with *use* rather than with failures, which
        // is why it is the level's defining feature and not a default.
        options.tracesSampleRate = wanted.tracesPerformance ? 1.0 : 0.0;
        // Never, at any level — see [SentrySink.log]. Set rather than left to
        // the default, because the default flipping in a later SDK would
        // silently start streaming the app's log lines off the device.
        options.enableLogs = false;
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
        // The last thing every event passes through, and what decides whether
        // it goes at all — see [scrubWithStoredIdentifiers].
        //
        // A transaction comes here too, and only because `beforeSendTransaction`
        // is left unset: `SentryClient._runBeforeSend` tries that callback
        // first and falls through to this one when it is null. Setting it would
        // be a second entry point for a kind of event nothing in this app
        // produces — no `startTransaction` call exists here or in fl_lib, and
        // the pure-Dart SDK auto-instruments nothing. If one is ever started,
        // its spans need covering as well, which is a different function.
        options.beforeSend = (event, hint) => scrubWithStoredIdentifiers(event);
      });
      // Before the sink is installed, so the first error to arrive already
      // says what it arrived from. The pure-Dart SDK cannot work this out for
      // itself — see [DiagnosticsPlatform], which is also where the line
      // between "what hardware" and "whose hardware" is drawn.
      await DiagnosticsPlatform.describe();
      // `full` only, and started before the sink so the first crumb through it
      // is already counted. `AptabaseSink` captures nothing until this has
      // run, so a failure to reach the instance costs events rather than the
      // launch.
      if (wanted.sendsAnalytics) {
        // Two destinations, started independently, and each is a no-op in a
        // build with no endpoint for it. Published builds carry OpenPanel's
        // and not Aptabase's -- see [OpenPanelAnalytics] on why the heavier of
        // the two is the one that is configured, and [AptabaseAnalytics.stop]
        // for the reason the other one must stay unconfigured: it cannot be
        // fully stopped once started, so leaving `full` would not reliably
        // stop delivery of what it had already recorded.
        await AptabaseAnalytics.start();
        await OpenPanelAnalytics.start();
      }
      Diag.install(
        FanOutSink([
          LocalDiagnosticsSink(),
          const SentrySink(),
          const AptabaseSink(),
          const OpenPanelSink(),
        ]),
      );
      // **Only now.** [uploading] answers from this, and `CrashLog.uploadsNow`
      // reads that to decide whether the marker keeps the error — so between
      // an early assignment and this line, `uploading` said yes while nothing
      // was installed to make it true. That window is two awaits wide and both
      // reach the network, so a crash inside it was recorded as one somebody
      // had already heard about, and the next launch dropped it.
      _started = wanted;
      Loggers.app.info('Crash upload started at ${wanted.name}');
      // The last thing, and only now: a native crash is collected before this
      // runs and has been waiting for a sink that uploads. Without this the
      // one class of crash Dart cannot see at all -- a SIGSEGV in the Rust
      // FFI, in proot or in sqlite -- reached the local log and stopped there.
      NativeExitReport.reportPending();
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
    // Dropped rather than flushed -- see [AptabaseAnalytics.stop]. Withdrawing consent
    // must not be the thing that sends the last batch.
    await AptabaseAnalytics.stop();
    await OpenPanelAnalytics.stop();
    try {
      await sentry.Sentry.close();
    } catch (e, s) {
      Loggers.app.warning('Crash upload failed to stop', e, s);
    }
  }

  /// [scrub], with what this install currently knows to be the user's — or
  /// null, which drops the event.
  ///
  /// Read per event rather than kept: a server added since launch is one whose
  /// name would otherwise still go out. It is a store read on the way to the
  /// network, which is not a hot path — an event is a crash.
  ///
  /// **An event this cannot promise to have scrubbed does not go.** The
  /// records are the whole of what separates a report from a disclosure, so
  /// sending one without them would upload an unaudited string on the single
  /// path where nothing was able to check it. The failure is narrow — an error
  /// raised from an isolate that never opened a store, or while the app is
  /// coming down — and what is given up is one report, while the error is
  /// still written to the on-device log by the sink beside this one.
  ///
  /// An install with *no servers* is not this case. It has nothing to
  /// substitute, and its events go as they are.
  @visibleForTesting
  static sentry.SentryEvent? scrubWithStoredIdentifiers(
    sentry.SentryEvent event,
  ) {
    final Map<String, String> identifiers;
    try {
      identifiers = KnownIdentifiers.of(Stores.server.fetch());
    } catch (e, s) {
      Loggers.app.warning('Could not read what to scrub from a report', e, s);
      return null;
    }
    return scrub(event, identifiers);
  }

  /// Takes the user's own infrastructure back out of an outgoing event.
  ///
  /// **A crumb is written to be published; an exception's message is not.**
  /// Everything this app records by hand goes through [Redact] where it is
  /// made, and `SentrySink.log` drops the log stream for exactly that reason —
  /// but an error's text is written by whoever threw it, which includes
  /// packages and Riverpod. `Spi.toString` used to be `Spi<user@host:port>`,
  /// and Riverpod names a family provider after its argument: one
  /// `UnmountedRefException` uploaded a server's address and login. That
  /// `toString` is fixed, and this is the net under the next one.
  ///
  /// Precise rather than pattern-based — see [KnownIdentifiers] — so it
  /// removes what this install *knows* is the user's and never guesses. Text
  /// nothing here can attribute goes out as written; the class of errors that
  /// quote a hostname is what the levels and the opt-in are for.
  ///
  /// **Three fields of a `SentryEvent` are deliberately not touched**, each
  /// because reaching it would be writing against something that does not
  /// happen here rather than covering a path:
  ///
  /// - `extra` is deprecated in this SDK and nothing in this app writes one.
  /// - `contexts` is filled by [DiagnosticsPlatform], whose entire purpose is
  ///   deciding what may go in it — hardware and OS release, no name, no
  ///   identifier — and by the SDK's own `app`, `runtime` and `culture`. It
  ///   holds typed objects rather than free text.
  /// - `request` is set by an HTTP integration, and the pure-Dart SDK has
  ///   none. Adding `sentry_dio` would change that, and a monitor agent's URL
  ///   is exactly what such an event would carry: cover it then.
  @visibleForTesting
  static sentry.SentryEvent scrub(
    sentry.SentryEvent event,
    Map<String, String> identifiers,
  ) {
    // Nothing sets either: `sendDefaultPii` is false, and the SDK fills
    // `ip_address` and `server_name` only when it is true. Cleared anyway, for
    // the same reason that option is set explicitly rather than left to the
    // default — a later SDK changing its mind would be silent, and a hostname
    // is a name the machine answers to on every network it joins.
    //
    // The address the *receiving* server records from the connection is not
    // reachable from here. That is a setting on the instance (GlitchTip:
    // Organization → Scrub IP Addresses).
    event.user = null;
    event.serverName = null;

    if (identifiers.isEmpty) return event;

    String sub(String text) => KnownIdentifiers.substitute(text, identifiers);

    /// [key], substituted, under a name no entry of [out] has taken.
    ///
    /// **Keys are text too.** Every call site writes a literal one today —
    /// `Diag.crumb` names its fields in code — but nothing about
    /// `Map<String, dynamic>` stops the next one keying by server name, and a
    /// key discloses exactly what a value does.
    ///
    /// Numbered on collision rather than overwritten, which is the reason this
    /// is a function at all: two spellings of one address reduce to the same
    /// token, and a map literal would keep the last of them and silently come
    /// out shorter than it went in.
    String subKey(Map<Object?, Object?> out, String key) {
      final replaced = sub(key);
      if (!out.containsKey(replaced)) return replaced;
      var n = 2;
      while (out.containsKey('$replaced #$n')) {
        n++;
      }
      return '$replaced #$n';
    }

    // Through nested collections, not just the top level. A crumb's `data` is
    // one level of `String` today — `Diag.crumb` takes a `Map<String, String>`
    // — but the field is `Map<String, dynamic>`, and a value put a level down
    // would be a hole nothing would notice. Non-strings are returned as they
    // are, so numbers and booleans keep their type through the round trip, and
    // a key that is not text is left alone: there is nothing in it to match,
    // and rewriting it would change a shape this cannot read.
    Object? subValue(Object? value) {
      switch (value) {
        case String():
          return sub(value);
        case Map():
          final out = <Object?, Object?>{};
          for (final e in value.entries) {
            final key = e.key;
            out[key is String ? subKey(out, key) : key] = subValue(e.value);
          }
          return out;
        case Iterable():
          return value.map(subValue).toList();
        default:
          return value;
      }
    }

    final message = event.message;
    if (message != null) {
      message.formatted = sub(message.formatted);
      final template = message.template;
      if (template != null) message.template = sub(template);
      final params = message.params;
      // Replaced rather than written through, here and below: a list or map
      // handed to the SDK may be const, and assigning the field is not.
      if (params != null) message.params = params.map(subValue).toList();
    }

    for (final e in event.exceptions ?? const <sentry.SentryException>[]) {
      final value = e.value;
      if (value != null) e.value = sub(value);
    }

    for (final crumb in event.breadcrumbs ?? const <sentry.Breadcrumb>[]) {
      final message = crumb.message;
      if (message != null) crumb.message = sub(message);
      final data = crumb.data;
      if (data != null) {
        // Through the same walk as any nested map, then retyped: the field is
        // declared tighter than what that answers, and every key at this level
        // is already a `String`.
        crumb.data = Map<String, dynamic>.from(subValue(data)! as Map);
      }
    }

    final tags = event.tags;
    if (tags != null) {
      final out = <String, String>{};
      for (final e in tags.entries) {
        out[subKey(out, e.key)] = sub(e.value);
      }
      event.tags = out;
    }

    final culprit = event.culprit;
    if (culprit != null) event.culprit = sub(culprit);
    final transaction = event.transaction;
    if (transaction != null) event.transaction = sub(transaction);

    return event;
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

  /// Dropped, at every level. The log stream does not leave the device.
  ///
  /// It used to be forwarded at `full`, and it was the wrong thing to offer.
  /// A crumb is written to be published — [Breadcrumb] says so, and [Redact]
  /// is applied where the crumb is made. A log line is not: it is written for
  /// a developer reading the file on the device, by code going back years,
  /// and some of it formats a server name straight into the message. Uploading
  /// that continuously meant the one channel carrying unaudited strings was
  /// also the one that ran while nothing was wrong.
  ///
  /// Nothing is lost that a report needs. Crumbs carry what happened, and the
  /// log itself is still written, still shown by the Logs page, and still
  /// quoted into a crash report — which the user reads before sending.
  ///
  /// Overridden to say so rather than inherited, since an empty inherited
  /// `log` reads as a sink that has not got round to it.
  @override
  void log(DiagLevel level, String message, {String? logger}) {}

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
