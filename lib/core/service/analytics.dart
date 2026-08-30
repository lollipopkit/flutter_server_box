import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/data/res/build_data.dart';

/// Counts what the app is used for, at `full` only.
///
/// **The instrumentation is [Diag], not a second set of call sites.** Every
/// `Diag.crumb` in this app already names an action and carries redacted
/// properties, because a crumb is written to be published — see [Breadcrumb].
/// An analytics event wants exactly that, so [PostHogSink] turns each crumb
/// into one and nothing has to be instrumented twice. Adding a crumb adds an
/// event; the two cannot drift, because there is only one of them.
///
/// **`dio` against the ingestion API, not `posthog_flutter`.** The same
/// decision as `sentry` over `sentry_flutter`, for stronger reasons: that
/// package brings an Android and an iOS SDK whose defaults include autocapture
/// and session replay — screen contents, taps and text — which is the opposite
/// of what this is allowed to send, and it would be a dependency F-Droid has
/// to vet in order to ship a feature that is off by default. Here what leaves
/// the device is the list below and nothing else.
///
/// **The identifier persists, and that is a deliberate reversal.** It was
/// random per launch, which kept anything from being connected across runs.
/// An experiment cannot work that way: a user reassigned to a different
/// variant on every launch makes the two arms the same population, so the
/// result measures nothing. Supporting A/B tests means accepting a stable
/// anonymous id, and there is no version of that which is also per launch.
///
/// What is done to bound it instead:
///
/// - It exists **only at `full`**. `start` is what creates it, and [stop]
///   deletes it — so turning collection off is not "stop sending", it is
///   "forget which install this was". Turning it back on is a new identity,
///   with the experiment reassignment that implies.
/// - It is a random 128-bit value and nothing else. Not derived from any
///   device property, so it cannot be recomputed after deletion, and it
///   identifies an install rather than a device or a person.
/// - It lives in [PrefStore], **not** in `Stores.setting`, because the backup
///   file carries every setting (see `BackupV2`) and restoring one onto a
///   second device would give both the same identity — which is precisely the
///   cross-device link this is not allowed to create.
abstract final class Analytics {
  /// Where events go. Empty in a build that was not given one, which is every
  /// build until `--dart-define=POSTHOG_HOST=...` supplies it.
  ///
  /// Unlike the Sentry DSN this is not committed: that one was already public
  /// in every shipped binary and had a year of reports behind it, while this
  /// endpoint does not exist yet. Fill both defines in before enabling.
  static const host = String.fromEnvironment('POSTHOG_HOST');

  /// The project write key. Public by design, like the Sentry DSN — it can
  /// only append events and reads nothing back.
  static const key = String.fromEnvironment('POSTHOG_KEY');

  /// Whether this build can send at all.
  static bool get availableInBuild => host.isNotEmpty && key.isNotEmpty;

  /// How many events are held before a send is forced.
  ///
  /// A crumb is cheap and frequent — every route change is one — so events are
  /// batched rather than sent individually. This is the ceiling that keeps a
  /// long session from holding an unbounded list; [_flushEvery] is what
  /// bounds how *stale* the queue gets.
  static const _maxBatch = 50;

  /// How often a partial batch goes out anyway.
  static const _flushEvery = Duration(minutes: 2);

  /// Dropped rather than queued once the queue is this long.
  ///
  /// Reached only when sending has been failing, and the newest events are the
  /// ones kept: a device that is offline for an hour must not spend memory
  /// remembering that, and analytics is the one thing here that is worth
  /// nothing if it costs anything.
  static const _maxQueue = 500;

  static final _queue = <Map<String, Object?>>[];
  /// Where the install identity is kept. See the class doc for why this is
  /// `PrefStore` and not a setting.
  static const _idKey = 'analytics_install_id';

  static Timer? _timer;
  static Dio? _dio;
  static String? _distinctId;

  /// Properties attached to every event, set from [Diag.tag].
  static final _superProps = <String, String>{};

  /// Whether events are being collected right now.
  static bool get started => _distinctId != null;

  /// The install identity, for the one other thing that needs it: asking which
  /// experiment variants this install is in. Null when collection is off.
  static String? get distinctId => _distinctId;

  /// Begins a run's collection, minting the install identity if this is the
  /// first time collection has ever been switched on. Idempotent.
  static Future<void> start() async {
    if (started) return;
    if (!availableInBuild) return;
    var id = PrefStore.shared.get<String>(_idKey);
    if (id == null || id.isEmpty) {
      // 128 bits from `Random.secure`, so two installs switching this on in
      // the same millisecond are not the same identity, and so it cannot be
      // guessed from anything about the device.
      final rnd = Random.secure();
      id = List.generate(
        16,
        (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await PrefStore.shared.set(_idKey, id);
    }
    _distinctId = id;
    _dio = Dio(
      BaseOptions(
        baseUrl: host,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _timer = Timer.periodic(_flushEvery, (_) => unawaited(flush()));
  }

  /// Ends it, and forgets who this was.
  ///
  /// The queue is *dropped*, not flushed: the one moment this runs is consent
  /// being withdrawn, and the queue then holds events the user has just said
  /// they did not want sent. Flushing would be honouring a setting by ignoring
  /// it once.
  ///
  /// The identity goes with it. Keeping it would make "off" mean "paused", and
  /// the record of which install this was is the part worth deleting — the
  /// cost is that switching back on lands in a fresh experiment assignment.
  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    _superProps.clear();
    _distinctId = null;
    _dio?.close(force: true);
    _dio = null;
    await PrefStore.shared.remove(_idKey);
  }

  /// Records one event. Never blocks, never throws.
  static void capture(String event, Map<String, String> props) {
    if (!started) return;
    if (_queue.length >= _maxQueue) _queue.removeAt(0);
    _queue.add({
      'event': event,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'properties': {
        'distinct_id': _distinctId,
        // Which release an answer is about. Every question this is here to
        // answer is really "in this version", and a build number is not
        // reconstructable from anything else in the payload.
        'build': '${BuildData.build}',
        ..._superProps,
        ...props,
      },
    });
    if (_queue.length >= _maxBatch) unawaited(flush());
  }

  /// Attaches a fact about this run to every event from here on.
  static void setSuperProp(String key, String? value) {
    if (value == null) {
      _superProps.remove(key);
    } else {
      _superProps[key] = value;
    }
  }

  /// Sends what is queued.
  ///
  /// Best effort in both directions: a failure drops the batch rather than
  /// retrying it, because a retry queue is a way to send the same event twice
  /// and to keep a failing request alive across the moment consent is
  /// withdrawn. Analytics is not worth either.
  static Future<void> flush() async {
    final dio = _dio;
    if (dio == null || _queue.isEmpty) return;
    final batch = List<Map<String, Object?>>.from(_queue);
    _queue.clear();
    try {
      await dio.post<void>(
        '/batch/',
        data: {'api_key': key, 'batch': batch},
      );
    } catch (e) {
      // Not through `Diag`: this is the sink's own failure, and reporting it
      // as a diagnostic would make every offline launch produce an event
      // about being unable to send events.
      Loggers.app.warning('Analytics.flush: $e');
    }
  }
}

/// Turns [Diag] into PostHog events, at `full` only.
///
/// Beside [SentrySink] rather than instead of it, and the split is what each
/// backend is for: Sentry answers "what broke and what led to it", so a crumb
/// is context it holds until something fails. PostHog answers "what is this
/// used for", so the same crumb is the answer itself and goes out as it
/// happens. One call site, two questions.
final class PostHogSink extends DiagnosticsSink {
  const PostHogSink();

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
    Analytics.capture(eventName(crumb), crumb.data ?? const {});
  }

  /// A tag is a fact about the whole run, so it becomes a super property.
  @override
  void tag(String key, String? value) {
    if (!DiagnosticsUpload.level.sendsAnalytics) return;
    Analytics.setSuperProp(key, value);
  }

  /// Not sent. An error is Sentry's question, and a stack trace is not
  /// something this backend can do anything with. Overridden to say so.
  @override
  void error(Object error, StackTrace? stack, {String? source}) {}

  /// Not sent, for the reason [SentrySink.log] gives: the log is written for a
  /// developer on the device and is not audited for publication.
  @override
  void log(DiagLevel level, String message, {String? logger}) {}

  @override
  Future<void> flush() => Analytics.flush();
}
