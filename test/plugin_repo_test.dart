/// Reading a repository index, and deciding what may be installed from it.
///
/// The two things worth testing here are the ones that decide what runs on
/// somebody's servers: which version an app of this age picks, and whether the
/// bytes are the ones the index named.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/provider/plugin/repo_source.dart';

String _index(List<Map<String, Object?>> plugins, {int schema = 1}) =>
    jsonEncode({'schema': schema, 'plugins': plugins});

/// A digest-shaped string. The value does not matter where the test is about
/// selection rather than about verification.
const _someDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, Object?> _release(
  String version,
  int abi, {
  String? sha256 = _someDigest,
}) => {
  'version': version,
  'abi': abi,
  'url': 'https://example.invalid/$version.sbp',
  'sha256': ?sha256,
};

void main() {
  group('the index', () {
    test('a schema this build does not read is refused whole', () {
      // Not half-read: the fields it does not know about might be the ones
      // that decide something.
      expect(
        () => PluginIndex.parse(_index(const [], schema: 99)),
        throwsA(isA<PluginRepoError>()),
      );
      expect(
        () => PluginIndex.parse(jsonEncode({'plugins': []})),
        throwsA(isA<PluginRepoError>()),
      );
    });

    test('a listing that will not read costs that listing', () {
      final index = PluginIndex.parse(
        _index([
          {'id': 'a.b', 'versions': [_release('1.0.0', 1)]},
          {'no': 'id'},
          // Nothing installable is not a listing: an entry that cannot be
          // acted on is worse than one that is not there.
          {'id': 'c.d', 'versions': const []},
        ]),
      );

      expect(index.plugins.map((p) => p.id), ['a.b']);
    });

    test('what is not JSON, and what is not an object', () {
      expect(() => PluginIndex.parse('{'), throwsA(isA<PluginRepoError>()));
      expect(() => PluginIndex.parse('[]'), throwsA(isA<PluginRepoError>()));
    });
  });

  group('picking a version', () {
    PluginListing listing(List<Map<String, Object?>> versions) =>
        PluginIndex.parse(
          _index([
            {'id': 'a.b', 'name': 'A', 'versions': versions},
          ]),
        ).plugins.single;

    /// The whole point of an index carrying several: an older app has to find
    /// one it can run rather than download the newest and be told no by the
    /// manifest parser afterwards.
    test('the newest at or below this app ABI', () {
      final l = listing([
        _release('1.0.0', 1),
        _release('2.0.0', 2),
        _release('3.0.0', 3),
      ]);

      expect(l.bestFor(1)?.version, '1.0.0');
      expect(l.bestFor(2)?.version, '2.0.0');
      expect(l.bestFor(9)?.version, '3.0.0');
    });

    test('an app too old for everything gets nothing', () {
      expect(listing([_release('2.0.0', 5)]).bestFor(1), isNull);
    });

    /// So a listing can say "there is a newer one and this app is too old",
    /// which is a different thing from "you are up to date".
    test('it can name what it could not offer', () {
      final l = listing([_release('1.0.0', 1), _release('2.0.0', 5)]);

      expect(l.bestFor(1)?.version, '1.0.0');
      expect(l.tooNewFor(1).map((r) => r.version), ['2.0.0']);
      expect(l.tooNewFor(9), isEmpty);
    });

    /// The order the index gave is not trusted, and a string comparison puts
    /// `1.10` before `1.9` — which would pin every install to whichever
    /// version happened to sort last.
    test('versions compare by number, not as strings', () {
      expect(PluginVersion.compare('1.10.0', '1.9.0'), greaterThan(0));
      expect(PluginVersion.compare('1.2.0', '1.10.0'), lessThan(0));
      expect(PluginVersion.compare('2.0.0', '10.0.0'), lessThan(0));
      expect(PluginVersion.compare('1.0.0', '1.0.0'), 0);

      expect(
        listing([_release('1.9.0', 1), _release('1.10.0', 1)])
            .bestFor(1)
            ?.version,
        '1.10.0',
      );
    });

    /// A pre-release is below the release of the same number, which is what
    /// calling it one means.
    test('a pre-release sorts below the release', () {
      expect(PluginVersion.compare('1.0.0-beta', '1.0.0'), lessThan(0));
      expect(PluginVersion.compare('1.0.0', '1.0.0-beta'), greaterThan(0));
      expect(PluginVersion.compare('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
    });
  });

  _sourceTests();

  group('the digest', () {
    test('it is the sha256 of the bytes, lowercase hex', () {
      // `echo -n abc | shasum -a 256`
      expect(
        PluginDigest.of(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('it matches the bytes it names and nothing else', () {
      final bytes = utf8.encode('a plugin');
      final digest = PluginDigest.of(bytes);

      expect(PluginDigest.matches(digest, bytes), isTrue);
      expect(PluginDigest.matches(digest.toUpperCase(), bytes), isTrue);
      expect(PluginDigest.matches(digest, utf8.encode('a plugin ')), isFalse);
      expect(PluginDigest.matches('short', bytes), isFalse);
      expect(PluginDigest.matches('', bytes), isFalse);
    });

    /// A release with no digest is not an inconvenience to route around — it
    /// is the case where nothing about the bytes is checked at all, and the
    /// only honest thing is to say so before asking.
    test('a release says whether it can be verified', () {
      final index = PluginIndex.parse(
        _index([
          {
            'id': 'a.b',
            'versions': [
              _release('1.0.0', 1),
              _release('1.1.0', 1, sha256: null),
              _release('1.2.0', 1, sha256: 'not-a-digest'),
            ],
          },
        ]),
      );
      final releases = {
        for (final r in index.plugins.single.releases) r.version: r,
      };

      expect(releases['1.0.0']!.verifiable, isTrue);
      expect(releases['1.1.0']!.verifiable, isFalse);
      // Present but the wrong length is not a digest either.
      expect(releases['1.2.0']!.verifiable, isFalse);
    });
  });
}

/// What `PluginRepoSource` refuses, without a network.
///
/// The digest rule is the whole security model here — there are no signatures
/// — so the two answers that matter are "no digest, ask first" and "wrong
/// digest, never".
void _sourceTests() {
  group('fetching', () {
    const digested = PluginRelease(
      version: '1.0.0',
      abi: 1,
      url: 'https://example.invalid/p.sbp',
      sha256: _someDigest,
    );
    const undigested = PluginRelease(
      version: '1.0.0',
      abi: 1,
      url: 'https://example.invalid/p.sbp',
    );

    test('a package with no digest is not downloaded by default', () async {
      // Refused before the request: there is nothing to check the answer
      // against, and asking afterwards would mean the bytes are already here.
      await expectLater(
        PluginRepoSource().download(undigested),
        throwsA(
          isA<PluginTrustRefused>()
              .having((e) => e.issue, 'issue', PluginTrustIssue.noDigest)
              .having((e) => e.skippable, 'skippable', isTrue),
        ),
      );
    });

    /// A mismatch is not an absence of assurance, it is assurance that
    /// something is wrong — so there is no answer the user could give.
    test('a mismatch is not skippable', () {
      const refusal = PluginTrustRefused(PluginTrustIssue.digestMismatch);

      expect(refusal.skippable, isFalse);
    });

    test('an index has to be reached over https', () async {
      for (final url in ['http://example.invalid/index.json', 'not a url']) {
        await expectLater(
          PluginRepoSource().index(url),
          throwsA(isA<PluginRepoError>()),
          reason: url,
        );
      }
    });

    /// Something served by this machine is not crossing a network, which is
    /// the same rule the monitor agent applies to its own plaintext listener.
    test('loopback is allowed without tls', () async {
      // It will fail to connect, and that is a different error from the one
      // the scheme check raises.
      await expectLater(
        PluginRepoSource().index('http://127.0.0.1:1/index.json'),
        throwsA(
          isA<PluginRepoError>().having(
            (e) => e.message,
            'message',
            contains('could not be reached'),
          ),
        ),
      );
    });

    test('a package address has to be https too', () async {
      await expectLater(
        PluginRepoSource().download(
          const PluginRelease(
            version: '1',
            abi: 1,
            url: 'http://example.invalid/p.sbp',
            sha256: _someDigest,
          ),
        ),
        throwsA(isA<PluginRepoError>()),
      );
      expect(digested.verifiable, isTrue);
    });

    /// The example in the source is what a repository is told to serve, so it
    /// has to be something the parser accepts.
    test('the documented index is one this build reads', () {
      final index = parseExampleIndex();

      expect(index.plugins.single.id, 'app.serverbox.diskusage');
      expect(index.plugins.single.bestFor(2)?.version, '1.0.0');
      // And an app older than the release finds nothing rather than the wrong
      // thing.
      expect(index.plugins.single.bestFor(1), isNull);
    });
  });
}
