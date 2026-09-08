import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/known_identifiers.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// The last thing an event passes through before it leaves the device.
///
/// This is the half of diagnostics nobody audits by reading it: a crumb is
/// written to be published and goes through `Redact` where it is made, while an
/// error's text is written by whoever threw it. `Spi.toString` used to be
/// `Spi<user@host:port>`, Riverpod names a family provider after its argument,
/// and one `UnmountedRefException` uploaded a server's address and login as its
/// title. Both halves are covered here: what the event carries, and what it
/// must no longer carry about the device itself.
void main() {
  final servers = [
    spiFixture(name: 'prod-db', id: 'a', ip: '198.51.100.24', user: 'deploy'),
    Spi(
      name: 'agent-box',
      id: 'b',
      monitorHttp: const MonitorHttpCredential(addr: 'https://10.0.0.7:3770'),
      bmc: const BmcCfg(addr: 'https://10.0.0.9'),
    ),
  ];
  final identifiers = KnownIdentifiers.of(servers);

  sentry.SentryEvent scrubbed(sentry.SentryEvent event) =>
      DiagnosticsUpload.scrub(event, identifiers);

  test('an exception message does not carry an address or an account', () {
    // The shape of the event this exists for, with the reporter's own address
    // swapped for a documentation one (RFC 5737). Nothing in this repository
    // gets to hold a real user's host, which is the same rule the code under
    // test is about.
    final event = scrubbed(
      sentry.SentryEvent(
        exceptions: [
          sentry.SentryException(
            type: 'UnmountedRefException',
            value:
                'Cannot use the Ref of servicesProvider('
                'Spi<deploy@198.51.100.24:22>) after it has been disposed.',
          ),
        ],
      ),
    );

    final value = event.exceptions!.single.value!;
    expect(value, isNot(contains('198.51.100.24')));
    expect(value, isNot(contains('deploy')));
    expect(value, contains('<host-1>'));
    expect(value, contains('<user-1>'));
    expect(
      value,
      contains('servicesProvider'),
      reason: 'what is left has to still say where the failure was',
    );
  });

  test('the message, its template and its params are all covered', () {
    final event = scrubbed(
      sentry.SentryEvent(
        message: sentry.SentryMessage(
          'could not reach prod-db',
          template: 'could not reach %s',
          params: ['prod-db', 22],
        ),
      ),
    );

    final message = event.message!;
    expect(message.formatted, 'could not reach <server-1>');
    expect(message.template, 'could not reach %s');
    expect(message.params, ['<server-1>', 22]);
  });

  test('a breadcrumb is covered too, message and data alike', () {
    // Crumbs are already redacted where they are made. This is about the ones
    // a package places, and about a `data` value someone adds later without
    // thinking of this file.
    final event = scrubbed(
      sentry.SentryEvent(
        breadcrumbs: [
          sentry.Breadcrumb(
            message: 'GET https://10.0.0.7:3770/api/v1/status',
            data: {'host': '10.0.0.7', 'attempt': 2},
          ),
        ],
      ),
    );

    final crumb = event.breadcrumbs!.single;
    expect(crumb.message, isNot(contains('10.0.0.7')));
    expect(crumb.data!['host'], '<agent-2>');
    expect(crumb.data!['attempt'], 2, reason: 'a non-string is left alone');
  });

  test('a value nested inside a crumb is reached too', () {
    // `Diag.crumb` takes a `Map<String, String>`, so one level is all there is
    // today — but the field the SDK exposes is `Map<String, dynamic>`, and a
    // value put a level down would be a hole nothing would notice.
    final event = scrubbed(
      sentry.SentryEvent(
        breadcrumbs: [
          sentry.Breadcrumb(
            message: 'x',
            data: {
              'tried': ['10.0.0.7', 'prod-db'],
              'via': {
                'jump': {'host': '198.51.100.24'},
                'attempts': 3,
              },
            },
          ),
        ],
      ),
    );

    final data = event.breadcrumbs!.single.data!;
    expect(data['tried'], ['<agent-2>', '<server-1>']);
    expect((data['via'] as Map)['jump'], {'host': '<host-1>'});
    expect(
      (data['via'] as Map)['attempts'],
      3,
      reason: 'a number keeps its type through the round trip',
    );
  });

  test('a map key is text as much as a value is', () {
    final event = scrubbed(
      sentry.SentryEvent(
        breadcrumbs: [
          sentry.Breadcrumb(
            message: 'x',
            data: {
              'prod-db': 'reachable',
              'nested': {'10.0.0.9': 'refused', 7: 'left alone'},
            },
          ),
        ],
        tags: {'prod-db': 'agent-box'},
      ),
    );

    final data = event.breadcrumbs!.single.data!;
    expect(data.keys, contains('<server-1>'));
    expect(data['<server-1>'], 'reachable');
    final nested = data['nested'] as Map;
    expect(nested['<bmc-2>'], 'refused');
    expect(nested[7], 'left alone', reason: 'a key that is not text is kept');
    expect(event.tags, {'<server-1>': '<server-2>'});
  });

  test('two keys reducing to one token keep both entries', () {
    // The agent's address and the host inside it are two keys and one
    // replacement. Overwriting would have made the map come out shorter than
    // it went in, which is a diagnostic silently rewritten rather than
    // redacted.
    final event = scrubbed(
      sentry.SentryEvent(
        breadcrumbs: [
          sentry.Breadcrumb(
            message: 'x',
            data: {
              'https://10.0.0.7:3770': 'first',
              '10.0.0.7': 'second',
            },
          ),
        ],
      ),
    );

    final data = event.breadcrumbs!.single.data!;
    expect(data, hasLength(2));
    expect(data['<agent-2>'], 'first');
    expect(data['<agent-2> #2'], 'second');
  });

  test('a const map handed to the SDK is replaced, not written through', () {
    // The failure mode is an `Unsupported operation` thrown out of `beforeSend`,
    // which the SDK catches by sending the event unscrubbed.
    final event = sentry.SentryEvent(
      breadcrumbs: [
        sentry.Breadcrumb(message: 'x', data: const {'host': '10.0.0.7'}),
      ],
      message: sentry.SentryMessage('x', params: const ['prod-db']),
    );

    expect(() => scrubbed(event), returnsNormally);
    expect(event.breadcrumbs!.single.data!['host'], '<agent-2>');
    expect(event.message!.params, ['<server-1>']);
  });

  test('the BMC and the agent are the user\'s infrastructure as well', () {
    final event = scrubbed(
      sentry.SentryEvent(
        message: sentry.SentryMessage(
          'https://10.0.0.9 refused, so did https://10.0.0.7:3770',
        ),
      ),
    );

    expect(event.message!.formatted, contains('<bmc-2>'));
    expect(event.message!.formatted, contains('<agent-2>'));
    expect(event.message!.formatted, isNot(contains('10.0.0.')));
  });

  test('nothing describes the device it came from', () {
    // Neither is set while `sendDefaultPii` is false. Cleared regardless, for
    // the same reason that option is set explicitly: a later SDK changing its
    // mind about the default would be silent.
    final event = scrubbed(
      sentry.SentryEvent(
        user: sentry.SentryUser(id: 'someone', ipAddress: '2001:db8::1'),
        serverName: 'someones-macbook.local',
      ),
    );

    expect(event.user, isNull);
    expect(event.serverName, isNull);
  });

  test('an install with no servers still has its device fields cleared', () {
    // Nothing to substitute is not the same as nothing to do: what the event
    // says about the *device* is removed whether or not there are records.
    final event = DiagnosticsUpload.scrub(
      sentry.SentryEvent(
        user: sentry.SentryUser(ipAddress: '2001:db8::1'),
        message: sentry.SentryMessage('prod-db is gone'),
      ),
      const {},
    );

    expect(event.user, isNull);
    expect(
      event.message!.formatted,
      'prod-db is gone',
      reason: 'with no records to match, text goes out as written',
    );
  });

  /// Here rather than beside the model because this is what the `toString` is
  /// *for*: it is not a display string — `Spi.displayAddr` is, and the pages
  /// wanting an address call it — it is what Riverpod, an assertion and a
  /// package's error message quote when they name a server.
  group('a Spi describes itself without disclosing anything', () {
    test('no address, no account, no name', () {
      final text = servers.first.toString();

      expect(text, isNot(contains('198.51.100.24')));
      expect(text, isNot(contains('deploy')));
      expect(text, isNot(contains('prod-db')));
    });

    test('one machine still reads as one machine', () {
      // The point of an identifier here: a report has to be followable through
      // a single server, and two of them have to be tellable apart.
      expect(servers.first.toString(), servers.first.toString());
      expect(
        servers.first.toString(),
        isNot(servers.last.toString()),
      );
      expect(
        servers.first.copyWith(name: 'renamed').toString(),
        servers.first.toString(),
        reason: 'the id is what it is about, not anything the user typed',
      );
    });
  });

  /// The wrapper `beforeSend` is actually given, where the decision to send at
  /// all is made.
  group('reading the records to scrub against', () {
    test('an event nothing could be checked against is dropped', () {
      // No store registered, which is an error raised from an isolate that
      // never opened one, or while the app is coming down. The records are the
      // whole of what separates a report from a disclosure, so an event that
      // could not be checked against them is not sent unscrubbed instead.
      expect(
        DiagnosticsUpload.scrubWithStoredIdentifiers(
          sentry.SentryEvent(
            message: sentry.SentryMessage('could not reach prod-db'),
          ),
        ),
        isNull,
      );
    });

    test('an install with no servers is not that case', () async {
      // It has nothing to substitute, which is an answer rather than a
      // failure — otherwise a fresh install would report nothing at all.
      await openTestDb();
      getIt.registerSingleton<ServerStore>(ServerStore());
      addTearDown(closeTestDb);
      addTearDown(getIt.reset);

      final event = DiagnosticsUpload.scrubWithStoredIdentifiers(
        sentry.SentryEvent(
          user: sentry.SentryUser(ipAddress: '2001:db8::1'),
          message: sentry.SentryMessage('nothing here to match'),
        ),
      );

      expect(event, isNotNull);
      expect(event!.user, isNull);
      expect(event.message!.formatted, 'nothing here to match');
    });
  });

  test('text this install cannot attribute is left as it is', () {
    // Precise, not pattern-based: a package name in a stack trace looks like a
    // domain, and a machine called `nas` looks like nothing at all.
    final event = scrubbed(
      sentry.SentryEvent(
        message: sentry.SentryMessage('package:server_box/main.dart 1.2.3.4'),
      ),
    );

    expect(event.message!.formatted, 'package:server_box/main.dart 1.2.3.4');
  });
}
