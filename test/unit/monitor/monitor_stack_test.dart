import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';

void main() {
  group('MonitorWebApp.deployed', () {
    test('keeps deployed apps and reads what a non-admin is told', () {
      final apps = MonitorWebApp.deployed({
        'apps': [
          {
            'manifest': {
              'id': 'futo.immich',
              'title': {'en': 'Immich', 'zh-CN': 'Immich 相册'},
              'description': {'en': 'Photos'},
              'homepage': 'https://immich.app',
              'version': '1.1',
            },
            'stack': {'state': 'installed', 'version': '1.0'},
            'proxy': true,
            'health': {'state': 'unhealthy', 'failing': ['server'], 'checked_at': '2026-10-13T00:00:00Z'},
          },
          {
            // In the catalog, not deployed.
            'manifest': {'id': 'jellyfin.jellyfin', 'title': {'en': 'Jellyfin'}},
            'stack': null,
            'proxy': false,
          },
          {
            'manifest': {'id': 'x.y', 'title': {'en': 'Y'}},
            'stack': {'state': 'installing', 'version': '1'},
            'proxy': false,
            'health': null,
          },
        ],
      });
      expect(apps.map((a) => a.id), ['futo.immich', 'x.y']);
      final immich = apps.first;
      expect(immich.proxy, isTrue);
      expect(immich.health, 'unhealthy');
      expect(immich.failing, ['server']);
      expect(immich.descriptionIn('de'), 'Photos');
      expect(immich.homepage, 'https://immich.app');
      expect(immich.updatable, isTrue);
      expect(apps.last.state, 'installing');
      expect(apps.last.health, isNull);
    });

    test('a title in the locale, its language, else English', () {
      const app = MonitorWebApp(
        id: 'a.b',
        title: {'en': 'Notes', 'zh': '笔记', 'zh-TW': '筆記'},
        state: 'installed',
      );
      expect(app.titleIn('zh-TW'), '筆記');
      expect(app.titleIn('zh-CN'), '笔记');
      expect(app.titleIn('de'), 'Notes');
    });
  });

  group('MonitorStackEntry.uri', () {
    test('the agent host on the proxy port', () {
      final entry = MonitorStackEntry.fromJson({
        'ticket': 't1',
        'port': 3781,
        'tls': true,
        'path': '/web/',
        'enter': '/__sbm/enter',
        'url': null,
      });
      expect(
        entry.uri(Uri.parse('https://box.example.com:3770')).toString(),
        'https://box.example.com:3781/__sbm/enter?ticket=t1&next=%2Fweb%2F',
      );
    });

    test("the app's own host when apps are taken by host", () {
      final entry = MonitorStackEntry.fromJson({
        'ticket': 't2',
        'port': 3781,
        'tls': false,
        'path': '/',
        'enter': '/__sbm/enter',
        'url': 'https://futo-immich.apps.example.com',
      });
      expect(
        entry.uri(Uri.parse('http://10.0.0.2:3770')).toString(),
        'https://futo-immich.apps.example.com/__sbm/enter?ticket=t2&next=%2F',
      );
    });
  });
}
