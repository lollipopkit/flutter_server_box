import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/app_link.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/tab.dart';

void main() {
  group('AppLink.parse', () {
    test('a server page', () {
      final link = AppLink.parse('serverbox://server/abc') as ServerLink;
      expect(link.id, 'abc');
      expect(link.func, isNull);
    });

    test('a server function, by its function-row name', () {
      final link = AppLink.parse('serverbox://server/abc/files') as ServerLink;
      expect(link.func, ServerFuncBtn.files);
    });

    test('an unknown function is no link, not the server page', () {
      expect(AppLink.parse('serverbox://server/abc/rm'), isNull);
      expect(AppLink.parse('serverbox://server/abc/files/x'), isNull);
      expect(AppLink.parse('serverbox://server'), isNull);
    });

    test('an empty segment is refused, not skipped', () {
      // Skipping it read these as other, valid links.
      expect(AppLink.parse('serverbox://server//files'), isNull);
      expect(AppLink.parse('serverbox://server/abc//power'), isNull);
      expect(AppLink.parse('serverbox://tab//file'), isNull);
    });

    test('one trailing slash is still the same link', () {
      final link = AppLink.parse('serverbox://server/abc/files/') as ServerLink;
      expect(link.id, 'abc');
      expect(link.func, ServerFuncBtn.files);
      expect(AppLink.parse('serverbox://add-server/?host=h'), isA<AddServerLink>());
    });

    test('the scheme and the kind are case-insensitive', () {
      expect(AppLink.parse('ServerBox://SERVER/abc'), isA<ServerLink>());
    });

    test('an id keeps its case and its `+` and `-`', () {
      const id = 'aB+c-9';
      final uri = const ServerLink(id).toUri().toString();
      expect((AppLink.parse(uri) as ServerLink).id, id);
    });

    test('add-server needs a host and drops a bad port', () {
      expect(AppLink.parse('serverbox://add-server?user=root'), isNull);
      final link =
          AppLink.parse(
                'serverbox://add-server?host=example.com&port=70000&user=root',
              )
              as AddServerLink;
      expect(link.host, 'example.com');
      expect(link.port, isNull);
      expect(link.user, 'root');
    });

    test('add-server ignores anything secret', () {
      final link =
          AppLink.parse('serverbox://add-server?host=h&password=p&key=k')
              as AddServerLink;
      expect(link.toUri().queryParameters.keys, ['host']);
    });

    test('a tab by its name', () {
      expect((AppLink.parse('serverbox://tab/file') as TabLink).tab, AppTab.file);
      expect(AppLink.parse('serverbox://tab/nope'), isNull);
    });

    test('a snippet, with and without a server', () {
      final bare = AppLink.parse('serverbox://snippet/s1') as SnippetLink;
      expect(bare.serverId, isNull);
      final on =
          AppLink.parse('serverbox://snippet/s1?server=a%2Bb') as SnippetLink;
      expect(on.serverId, 'a+b');
    });

    test('anything else is null, never a throw', () {
      for (final raw in [
        '',
        'https://server/abc',
        'serverbox://',
        'serverbox://unknown/abc',
        'serverbox://server/%E0%A4%A',
        'serverbox:[',
      ]) {
        expect(AppLink.parse(raw), isNull, reason: raw);
      }
    });
  });

  test('every link reads back as itself', () {
    final links = <AppLink>[
      const ServerLink('abc'),
      const ServerLink('abc', func: ServerFuncBtn.terminal),
      const AddServerLink(host: 'h', port: 2222, user: 'u', name: 'n a m e'),
      const TabLink(AppTab.virt),
      const SnippetLink('s1'),
      const SnippetLink('s1', serverId: 'a+b'),
    ];
    for (final link in links) {
      final back = AppLink.parse(link.toUri().toString());
      expect(back?.toUri(), link.toUri(), reason: '$link');
    }
  });
}
