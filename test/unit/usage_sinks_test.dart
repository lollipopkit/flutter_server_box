import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/aptabase.dart';
import 'package:server_box/core/service/openpanel.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this sends is a privacy claim, and every failure here is silent: an
/// event that goes out at the wrong level, or carries an identifier that
/// outlives the run, looks exactly like one that does not until someone reads
/// the server. So the level gate and the identifier are asserted rather than
/// assumed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDown(() async {
    await AptabaseAnalytics.stop();
    await OpenPanelAnalytics.stop();
  });

  group('the level decides', () {
    test('only full counts what the app is used for', () {
      expect(DiagnosticsLevel.none.sendsAnalytics, isFalse);
      expect(DiagnosticsLevel.basic.sendsAnalytics, isFalse);
      expect(DiagnosticsLevel.full.sendsAnalytics, isTrue);
    });

    test('the default never counts, on any platform', () {
      // Android is `none` and everything else `basic`; neither sends.
      expect(defaultDiagnosticsLevel.sendsAnalytics, isFalse);
    });
  });

  group('without a started collector', () {
    test('capturing is a no-op rather than an error', () async {
      // Which is every build until the two defines are supplied. `start` is
      // still called at `full`, and has to be a no-op rather than a half-open
      // collector holding events for a server that does not exist.
      expect(AptabaseAnalytics.availableInBuild, isFalse,
          reason: 'no APTABASE_HOST/APP_KEY in a test run');
      await AptabaseAnalytics.start();
      expect(AptabaseAnalytics.started, isFalse);
      AptabaseAnalytics.capture('nav.push', const {'route': '/'});
      expect(AptabaseAnalytics.started, isFalse);
    });

    test('the sink flush is a no-op rather than a throw', () async {
      // `Aptabase` exposes no flush -- it sends on its own timer and on
      // `onInactive`, the same edge `Diag.flush` is awaited on.
      await expectLater(const AptabaseSink().flush(), completes);
    });
  });

  group('a crumb becomes an event', () {
    test('named category.message, so the event list stays finite', () {
      // Both halves are fixed phrases by `Breadcrumb`'s own rule -- values go
      // in `data` -- which is what makes these groupable at all. A name built
      // from a value would be a new event per server.
      expect(
        AptabaseSink.eventName(
          const Breadcrumb(category: DiagCategory.nav, message: 'push'),
        ),
        'nav.push',
      );
      expect(
        AptabaseSink.eventName(
          const Breadcrumb(
            category: DiagCategory('server'),
            message: 'ssh connect',
            data: {'via': 'jump'},
          ),
        ),
        'server.ssh connect',
      );
    });

    test('and carries the crumb data as properties', () {
      // Not asserted through the wire, which needs a server: what matters here
      // is that the sink reads `data` rather than reformatting the message,
      // since `data` is the half `Redact` has already been applied to.
      const crumb = Breadcrumb(
        category: DiagCategory('server'),
        message: 'ssh connect',
        data: {'via': 'proxy', 'host': 'lan-1'},
      );
      expect(crumb.data, containsPair('via', 'proxy'));
    });
  });

  group('stopping', () {
    test('does not flush what the SDK was holding', () async {
      // Withdrawing consent must not be the thing that sends the last batch.
      AptabaseAnalytics.capture('nav.push', const {'route': '/'});
      await AptabaseAnalytics.stop();
      expect(AptabaseAnalytics.started, isFalse);
    });
  });

  group('the two destinations', () {
    test('read the same crumb into the same event name', () {
      // Deliberately identical, so one dataset can be read against the other.
      const crumb = Breadcrumb(
        category: DiagCategory('server'),
        message: 'ssh connect',
      );
      expect(
        OpenPanelSink.eventName(crumb),
        AptabaseSink.eventName(crumb),
      );
    });

    test('but a route push is a page view to OpenPanel alone', () {
      // The name is the server's, not a choice: `session-buffer.ts` counts a
      // page view only for an event named exactly this, and `bounce_rate` and
      // `views_per_session` are computed from that count.
      expect(OpenPanelSink.kScreenView, 'screen_view');

      const push = Breadcrumb(
        category: DiagCategory.nav,
        message: 'push',
        data: {'route': '/settings'},
      );
      expect(OpenPanelSink.screenViewPath(push), '/settings');
      // Aptabase is untouched by the rename -- it has no such concept, and a
      // page view there is an event like any other.
      expect(AptabaseSink.eventName(push), 'nav.push');
    });

    test('and a pop is not, because it names the page being left', () {
      // `AppRouteObserver.didPop` reports the route being removed. Counting it
      // would file a view under whichever page the user just closed.
      const pop = Breadcrumb(
        category: DiagCategory.nav,
        message: 'pop',
        data: {'route': '/settings'},
      );
      expect(OpenPanelSink.screenViewPath(pop), isNull);

      // Nor is a push with nothing to point at: `-` is what the crumb carries
      // for an unnamed route, and it would show in Pages as a blank row.
      const unnamed = Breadcrumb(
        category: DiagCategory.nav,
        message: 'push',
        data: {'route': '-'},
      );
      expect(OpenPanelSink.screenViewPath(unnamed), isNull);

      // And nothing outside `nav` is one, whatever it carries.
      const other = Breadcrumb(
        category: DiagCategory('server'),
        message: 'push',
        data: {'route': '/settings'},
      );
      expect(OpenPanelSink.screenViewPath(other), isNull);
    });

    test('OpenPanel is the configured one, Aptabase is not', () {
      // OpenPanel's endpoint is committed, like the Sentry DSN. Aptabase's is
      // not: the code is kept but there is no instance behind it, so it stays
      // a no-op until a build supplies one.
      expect(OpenPanelAnalytics.availableInBuild, isTrue);
      expect(AptabaseAnalytics.availableInBuild, isFalse,
          reason: 'no APTABASE_HOST/APP_KEY is compiled in');
    });

    test('nothing is stored until collection actually starts', () {
      // `availableInBuild` says a build *could* send; only `start` mints the
      // profile, and that happens at `full` alone.
      expect(OpenPanelAnalytics.started, isFalse);
      expect(OpenPanelAnalytics.profileId, isNull);
    });

    test('stopping OpenPanel erases its profile', () async {
      // Seeded directly: `start` needs an endpoint compiled in, which a test
      // run has none of. What matters is that `stop` clears the place the
      // identity lives -- `PrefStore`, not `Stores.setting`, because
      // `BackupV2` restores every setting and would hand a second device the
      // same profile.
      await PrefStore.shared.set('openpanel_profile_id', 'deadbeef');

      await OpenPanelAnalytics.stop();

      expect(PrefStore.shared.get<String>('openpanel_profile_id'), isNull);
    });
  });
}
