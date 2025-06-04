import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk_smart.dart';

const _raw = '''
{ "device": {"name": "/dev/sda"}, "smart_status": {"passed": true}, "temperature": {"current": 35} }
{ "device": {"name": "/dev/nvme0n1"}, "smart_status": {"passed": false}, "temperature": {"current": 40} }
''';

void main() {
  test('parse disk smart', () {
    final list = DiskSmart.parse(_raw);
    expect(list.length, 2);
    expect(list.first.device, '/dev/sda');
    expect(list.first.healthy, true);
    expect(list.first.temperature, 35);
    expect(list.last.device, '/dev/nvme0n1');
    expect(list.last.healthy, false);
    expect(list.last.temperature, 40);
  });
}
