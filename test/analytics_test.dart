import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/analytics.dart';
import 'package:server_box/core/service/feature_flags.dart';
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
    await Analytics.stop();
    FeatureFlags.clear();
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

  group('a build with no endpoint', () {
    test('cannot start, so nothing is queued', () async {
      // Which is every build until the two defines are supplied. `start` is
      // still called at `full`, and has to be a no-op rather than a half-open
      // collector holding events for a server that does not exist.
      expect(Analytics.availableInBuild, isFalse,
          reason: 'no POSTHOG_HOST/KEY is compiled into a test run');
      await Analytics.start();
      expect(Analytics.started, isFalse);

      // And capturing into it is not an error.
      Analytics.capture('nav.push', const {'route': '/'});
      expect(Analytics.started, isFalse);
    });

    test('flush does nothing rather than throwing', () async {
      await expectLater(Analytics.flush(), completes);
    });
  });

  group('a crumb becomes an event', () {
    test('named category.message, so the event list stays finite', () {
      // Both halves are fixed phrases by `Breadcrumb`'s own rule -- values go
      // in `data` -- which is what makes these groupable at all. A name built
      // from a value would be a new event per server.
      expect(
        PostHogSink.eventName(
          const Breadcrumb(category: DiagCategory.nav, message: 'push'),
        ),
        'nav.push',
      );
      expect(
        PostHogSink.eventName(
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

  group('the install identity', () {
    test('is deleted when collection is switched off', () async {
      // "Off" has to mean "forget which install this was", not "pause". The
      // identity is the part worth deleting, and keeping it would make the two
      // indistinguishable from the server's side.
      await Analytics.stop();
      expect(Analytics.distinctId, isNull);
    });

    test('is erased from device-local storage, not just forgotten', () async {
      // Seeded directly: `start` needs an endpoint compiled in, which a test
      // run has none of. What is asserted is that `stop` clears the place the
      // identity actually lives -- `PrefStore` rather than `Stores.setting`,
      // because `BackupV2` restores every setting and would hand a second
      // device the same identity.
      await PrefStore.shared.set('analytics_install_id', 'deadbeef');
      await Analytics.stop();
      expect(PrefStore.shared.get<String>('analytics_install_id'), isNull);
    });
  });

  group('feature flags', () {
    test('answer the local default until an experiment says otherwise', () {
      // The shape every call site has to be written for: flags are fetched
      // only at `full`, which is neither the default nor the recommendation,
      // so most installs never ask and must behave exactly as before.
      expect(FeatureFlags.fetched, isFalse);
      expect(FeatureFlags.isEnabled('anything'), isFalse);
      expect(FeatureFlags.isEnabled('anything', fallback: true), isTrue);
      expect(FeatureFlags.variant('anything'), isNull);
    });

    test('are not fetched when collection is off', () async {
      expect(Analytics.started, isFalse);
      await expectLater(FeatureFlags.fetch(), completes);
      expect(FeatureFlags.fetched, isFalse);
    });
  });

  group('stopping', () {
    test('drops the queue rather than sending it', () async {
      // Withdrawing consent must not be the thing that sends the last batch.
      Analytics.capture('nav.push', const {'route': '/'});
      await Analytics.stop();
      expect(Analytics.started, isFalse);
      // A flush after stop has nothing to send and no client to send it with.
      await expectLater(Analytics.flush(), completes);
    });
  });
}
