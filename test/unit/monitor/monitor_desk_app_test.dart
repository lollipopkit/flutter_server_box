import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_desk_app.dart';

void main() {
  test('approved desk apps, their titles and where they open', () {
    final apps = MonitorDeskApp.approved({
      'apps': [
        {
          'id': 'serverbox.kernel',
          'manifest': {
            'title': {'en': 'Kernels', 'zh-CN': '内核'},
          },
          'approved_permissions': ['process', 'root'],
        },
        // Waiting for approval: cannot be opened.
        {
          'id': 'acme.notes',
          'manifest': {'title': 'Notes'},
          'approved_permissions': null,
        },
        {'id': 'acme.plain', 'manifest': {'title': 'Plain'}, 'approved_permissions': <String>[]},
      ],
    });
    expect(apps.map((a) => a.id), ['serverbox.kernel', 'acme.plain']);
    expect(apps.first.titleIn('zh-CN'), '内核');
    expect(apps.first.titleIn('de'), 'Kernels');
    expect(apps.last.titleIn('en'), 'Plain');
    final uri = apps.first.uri(Uri.parse('https://10.0.0.2:3770/panel?x=1#y'));
    expect(uri.toString(), 'https://10.0.0.2:3770/?app=serverbox.kernel');
  });
}
