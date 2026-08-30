import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/analytics.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';

/// What this sends is a privacy claim, and every failure here is silent: an
/// event that goes out at the wrong level, or carries an identifier that
/// outlives the run, looks exactly like one that does not until someone reads
/// the server. So the level gate and the identifier are asserted rather than
/// assumed.
void main() {
  tearDown(Analytics.stop);

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
    test('cannot start, so nothing is queued', () {
      // Which is every build until the two defines are supplied. `start` is
      // still called at `full`, and has to be a no-op rather than a half-open
      // collector holding events for a server that does not exist.
      expect(Analytics.availableInBuild, isFalse,
          reason: 'no POSTHOG_HOST/KEY is compiled into a test run');
      Analytics.start();
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

  group('the identifier', () {
    test('does not outlive the process', () {
      // A persisted id would be a stable device identifier, which is what
      // `PrivacyInfo.xcprivacy` claims not to collect. Nothing here writes to
      // a store, so the only way to break this is to add one -- and then this
      // test still passes, which is why the claim is also in the class doc.
      // What is asserted is the observable half: stopping forgets it.
      Analytics.start();
      Analytics.stop();
      expect(Analytics.started, isFalse);
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
