import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/container/ps.dart';

void main() {
  test('docker ps parse', () {
    const raw = '''
CONTAINER ID    STATUS                         NAMES                                              IMAGE                                              
0e9e2ef860d2    Up 2 hours                     hbbs                                               rustdesk/rustdesk-server:latest                    
9a4df3ed340c    Up 41 minutes                  hbbr                                               rustdesk/rustdesk-server:latest                    
fa1215b4be74    Up 12 hours                    firefly                                            uusec/firefly:latest
''';
    final lines = raw.split('\n');
    const ids = ['0e9e2ef860d2', '9a4df3ed340c', 'fa1215b4be74'];
    const names = ['hbbs', 'hbbr', 'firefly'];
    const images = [
      'rustdesk/rustdesk-server:latest',
      'rustdesk/rustdesk-server:latest',
      'uusec/firefly:latest'
    ];
    const states = ['Up 2 hours', 'Up 41 minutes', 'Up 12 hours'];
    for (var idx = 1; idx < lines.length; idx++) {
      final raw = lines[idx];
      if (raw.isEmpty) continue;
      final ps = DockerPs.parse(raw);
      expect(ps.id, ids[idx - 1]);
      expect(ps.names, names[idx - 1]);
      expect(ps.image, images[idx - 1]);
      expect(ps.state, states[idx - 1]);
      expect(ps.running, true);
    }
  });
}
