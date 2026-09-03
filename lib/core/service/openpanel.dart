import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/diagnostics_platform.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/data/res/build_data.dart';

/// The second analytics destination, beside Aptabase.
///
/// **Why there are two, and what each is for.** Aptabase answers "what is this
/// used for" while storing no identifier at all — its protocol has no field
/// for a user, so a session cannot be joined to the one before it. What it
/// cannot answer is anything spanning launches: retention, or a funnel a user
/// takes two sessions to walk. OpenPanel can, because it accepts a
/// `profileId`, and accepting one is exactly what makes it the heavier choice.
///
/// **This one's endpoint is committed and Aptabase's is not**, so a published
/// build counts profiles and no build counts sessions until someone supplies
/// `APTABASE_HOST` and `APTABASE_APP_KEY`. A committed endpoint is also what
/// the privacy policy has to describe, since a rebuild from this source — an
/// F-Droid one, a fork — reports here too unless its builder changes the
/// value. What that rebuild inherits is the *default off*: `full` is opted
/// into by hand or nothing is sent at all.
///
/// Being the configured one makes this a privacy decision rather than a
/// configuration one:
///
/// - It mints a persistent [profileId]. Aptabase needs none, so with only
///   Aptabase configured nothing is stored on the device — see
///   [AptabaseAnalytics]. Configuring this reverses that, which is why the
///   privacy policy names the identifier rather than only the endpoint.
/// - The identity is bounded the same way the rest is: it exists **only at
///   `full`**, [start] creates it and [stop] deletes it, it is a random 128
///   bits derived from no device property, and it lives in [PrefStore] rather
///   than `Stores.setting` because `BackupV2` restores every setting and would
///   hand a second device the same identity.
///
/// **Both destinations receive the same events**, since both sinks read the
/// same `Diag.crumb` calls. Nothing is deduplicated between them: they are two
/// separate datasets that happen to be fed from one instrumentation, and a
/// number taken from one is not comparable with the other's — Aptabase counts
/// sessions, this counts profiles.
abstract final class OpenPanelAnalytics {
  /// The self-hosted instance's API base, no trailing slash.
  ///
  /// `/api` is part of it: the bare `/track` answers 307 and only `/api/track`
  /// is the ingestion route.
  ///
  /// Overridable with `--dart-define=OPENPANEL_URL=...`, which is how a build
  /// points at a test instance.
  static const url = String.fromEnvironment(
    'OPENPANEL_URL',
    defaultValue: 'https://diag.lollipopkit.com/api',
  );

  /// The write client's id. Public in the same sense the Sentry DSN is: it
  /// ships inside every binary and grants appending events, nothing else.
  ///
  /// It is also the whole credential — the id alone is what the request
  /// carries. OpenPanel authenticates ingestion three ways, in order: the
  /// client's `ignoreCorsAndSecret`, an `Origin` the project's CORS list
  /// allows, or a client secret. This client has the first one set, so the
  /// other two never run and neither header is sent.
  ///
  /// Neither of the others is usable here. An app is not a browser and has no
  /// `Origin` to send — OpenPanel's CORS wildcard still requires the header to
  /// be present (`cors.includes('*') && origin`), so a project permissive
  /// enough to allow anything still refuses a request with no `Origin` at all.
  /// A secret would ship in every binary, and this app's source is public, so
  /// it would be readable without even unpacking one. What is left is honest
  /// about what the endpoint is: publicly writable, exactly like the Sentry
  /// DSN. If it is ever abused, mint a new client and change this value.
  ///
  /// One consequence outlives that choice. OpenPanel checks `__revenue`
  /// *before* `ignoreCorsAndSecret`, so an event carrying that property is
  /// refused however the client is configured, unless the project sets
  /// `allowUnsafeRevenueTracking`. Nothing here sends one.
  static const clientId = String.fromEnvironment(
    'OPENPANEL_CLIENT_ID',
    defaultValue: 'c048a7b5-68b3-476d-acdb-c944fdaadede',
  );

  /// Whether this build can send at all.
  static bool get availableInBuild => url.isNotEmpty && clientId.isNotEmpty;

  /// How many events are held before a send is forced.
  ///
  /// **OpenPanel has no batch endpoint** — one POST per event — so queueing is
  /// not a batching win, it is a wake-up one: crumbs arrive while a screen is
  /// being built, and firing a request inside that is worse than firing ten a
  /// couple of minutes later. Events carry `__timestamp`, which is the field
  /// OpenPanel's own SDK adds to anything it had to hold, so the delay does
  /// not move them.
  static const _maxBatch = 50;

  /// How often a partial queue goes out anyway.
  static const _flushEvery = Duration(minutes: 2);

  /// Dropped rather than queued once the queue is this long.
  ///
  /// Reached only when sending has been failing, and the newest events are the
  /// ones kept: a device offline for an hour must not spend memory remembering
  /// that, and analytics is the one thing here worth nothing if it costs
  /// anything.
  static const _maxQueue = 500;

  /// Where the identity is kept. See the class doc for why this is `PrefStore`
  /// and not a setting.
  static const _idKey = 'openpanel_profile_id';

  static final _queue = <Map<String, Object?>>[];
  static Timer? _timer;
  static Dio? _dio;
  static String? _profileId;

  /// Properties attached to every event, set from [Diag.tag].
  static final _superProps = <String, String>{};

  /// Whether events are being collected right now.
  static bool get started => _profileId != null;

  /// The persistent identity this destination needs and Aptabase does not.
  /// Null when collection is off or this build has no endpoint.
  static String? get profileId => _profileId;

  /// Begins a run's collection, minting the identity on first use. Idempotent.
  static Future<void> start() async {
    if (started) return;
    if (!availableInBuild) return;
    var id = PrefStore.shared.get<String>(_idKey);
    if (id == null || id.isEmpty) {
      // 128 bits from `Random.secure`, so two installs switching this on in
      // the same millisecond are not one profile, and so it cannot be guessed
      // from anything about the device.
      final rnd = Random.secure();
      id = List.generate(
        16,
        (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await PrefStore.shared.set(_idKey, id);
    }
    _profileId = id;
    // Sent because OpenPanel derives the session from it and files anything it
    // cannot parse as server traffic — which stores the event, opens no
    // session, and leaves the dashboard reporting zero users. See
    // [DiagnosticsPlatform.userAgent]. Resolved once here rather than per
    // request; it is a platform call and the answer cannot change within a run.
    final ua = await DiagnosticsPlatform.userAgent();
    _dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'openpanel-client-id': clientId, 'User-Agent': ?ua},
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
  /// The identity goes with it, so "off" means "forget which install this
  /// was" rather than "pause".
  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    _superProps.clear();
    _profileId = null;
    _dio?.close(force: true);
    _dio = null;
    await PrefStore.shared.remove(_idKey);
  }

  /// Records one event. Never blocks, never throws.
  static void capture(String event, Map<String, String> props) {
    if (!started) return;
    if (_queue.length >= _maxQueue) _queue.removeAt(0);
    _queue.add({
      'type': 'track',
      'payload': {
        'name': event,
        'profileId': _profileId,
        'properties': {
          // When it happened, not when it was sent. Everything here is held
          // for up to [_flushEvery], so without this the whole queue would
          // land at one instant.
          '__timestamp': DateTime.now().toUtc().toIso8601String(),
          // Which release an answer is about. Every question this is here to
          // answer is really "in this version", and a build number is not
          // reconstructable from anything else in the payload.
          'build': '${BuildData.build}',
          ..._superProps,
          ...props,
        },
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

  /// Sends what is queued, one request per event — there is no batch endpoint.
  ///
  /// Best effort: a failure drops the event rather than retrying it, because a
  /// retry queue is a way to send the same event twice and to keep a failing
  /// request alive across the moment consent is withdrawn.
  ///
  /// Sequential rather than concurrent, and it gives up on the first failure:
  /// fifty parallel requests from a phone that just came back online is a
  /// worse thing to do than fifty slow ones, and one failure means the rest of
  /// this round would fail too. Nothing is waiting on the result.
  static Future<void> flush() async {
    final dio = _dio;
    if (dio == null || _queue.isEmpty) return;
    final batch = List<Map<String, Object?>>.from(_queue);
    _queue.clear();
    for (final event in batch) {
      try {
        await dio.post<void>('/track', data: event);
      } catch (e) {
        // Not through `Diag`: this is the sink's own failure, and reporting it
        // as a diagnostic would make every offline launch produce an event
        // about being unable to send events.
        Loggers.app.warning('OpenPanelAnalytics.flush: $e');
        return;
      }
    }
  }
}

/// Turns [Diag] into OpenPanel events, at `full` only.
///
/// A second sink beside [AptabaseSink], reading the same crumbs. See
/// [OpenPanelAnalytics] for why both exist and why only one of them stores an
/// identifier.
final class OpenPanelSink extends DiagnosticsSink {
  const OpenPanelSink();

  /// The event name a crumb becomes.
  ///
  /// `category.message`, so `nav.push` and `server.ssh connect` — the same
  /// names [AptabaseSink] uses, deliberately, so one dataset can be read
  /// against the other. [kScreenView] is the one exception, and it is one this
  /// backend imposes rather than one worth having.
  static String eventName(Breadcrumb crumb) =>
      '${crumb.category.name}.${crumb.message}';

  /// The name OpenPanel counts a page view under.
  ///
  /// **A literal, not a convention.** `session-buffer.ts` increments a
  /// session's `screen_view_count` only for an event named exactly this *and*
  /// carrying a path, so a differently-named event describing the same thing
  /// is not a page view as far as the server is concerned. Sent as `nav.push`
  /// it left the Pages view empty and `screen_view_count` at zero — which is
  /// also what `bounce_rate` and `views_per_session` are computed from, so
  /// three of the overview's metrics read zero rather than reading wrong.
  static const kScreenView = 'screen_view';

  /// Where OpenPanel reads the path from.
  ///
  /// One of the server's `GLOBAL_PROPERTIES`: lifted out of the properties map
  /// into a column of its own, so it does not also survive as an event
  /// property. `__timestamp`, which [OpenPanelAnalytics.capture] already
  /// sends, is another.
  static const _kPathProp = '__path';

  @override
  void breadcrumb(Breadcrumb crumb) {
    if (!DiagnosticsUpload.level.sendsAnalytics) return;
    final data = crumb.data ?? const <String, String>{};
    final path = screenViewPath(crumb);
    if (path == null) {
      OpenPanelAnalytics.capture(eventName(crumb), data);
      return;
    }
    OpenPanelAnalytics.capture(kScreenView, {
      ...data,
      _kPathProp: path,
    }..remove('route'));
  }

  /// The route a crumb is a page view of, or null when it is not one.
  ///
  /// **`push` only.** `AppRouteObserver.didPop` reports the route being
  /// *removed*, so a pop's `route` names the page being left rather than the
  /// one arrived at — counting it would file every page view under whichever
  /// page the user just closed. The cost is that going back does not count as
  /// a view of what it goes back to, which the observer cannot currently say:
  /// its listeners are handed one `RouteSettings`, not the pair.
  static String? screenViewPath(Breadcrumb crumb) {
    if (crumb.category != DiagCategory.nav) return null;
    if (crumb.message != 'push') return null;
    // `-` is what the crumb carries for a route with no name. A page view with
    // no path is not counted anyway, and would show up in Pages as a blank.
    final route = crumb.data?['route'];
    if (route == null || route.isEmpty || route == '-') return null;
    return route;
  }

  /// A tag is a fact about the whole run, so it becomes a super property.
  ///
  /// Unlike [AptabaseSink], which drops these: Aptabase collects the ones it
  /// can act on itself, while OpenPanel takes whatever is attached.
  @override
  void tag(String key, String? value) {
    if (!DiagnosticsUpload.level.sendsAnalytics) return;
    OpenPanelAnalytics.setSuperProp(key, value);
  }

  /// Not sent. An error is Sentry's question, and a stack trace is not
  /// something this backend can do anything with.
  @override
  void error(Object error, StackTrace? stack, {String? source}) {}

  /// Not sent, for the reason [SentrySink.log] gives: the log is written for a
  /// developer on the device and is not audited for publication.
  @override
  void log(DiagLevel level, String message, {String? logger}) {}

  @override
  Future<void> flush() => OpenPanelAnalytics.flush();
}
