import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';

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
      'uusec/firefly:latest',
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
      expect(ps.status, ContainerStatus.running);
      expect(ps.status.isRunning, true);
    }
  });

  test('docker ps status detection', () {
    // Test various Docker container states
    final testCases = [
      // Running states
      {'state': 'Up 2 minutes', 'status': ContainerStatus.running},
      {'state': 'Up 1 hour', 'status': ContainerStatus.running},
      {'state': 'UP 30 seconds', 'status': ContainerStatus.running}, // Case insensitive
      {'state': 'up 5 days', 'status': ContainerStatus.running}, // Case insensitive
      
      // Non-running states
      {'state': 'Exited (0) 5 minutes ago', 'status': ContainerStatus.exited},
      {'state': 'Created', 'status': ContainerStatus.created},
      {'state': 'Paused', 'status': ContainerStatus.paused},
      {'state': 'Restarting', 'status': ContainerStatus.restarting},
      {'state': 'Removing', 'status': ContainerStatus.removing},
      {'state': 'Dead', 'status': ContainerStatus.dead},
      
      // Edge cases
      {'state': null, 'status': ContainerStatus.unknown},
      {'state': '', 'status': ContainerStatus.unknown},
      {'state': 'Some Unknown Status', 'status': ContainerStatus.unknown},
    ];

    for (final testCase in testCases) {
      final ps = DockerPs(id: 'test', state: testCase['state'] as String?);
      final expectedStatus = testCase['status'] as ContainerStatus;
      expect(
        ps.status, 
        expectedStatus, 
        reason: 'State "${testCase['state']}" should be ${expectedStatus.name}'
      );
      
      // Test status.isRunning method
      expect(
        ps.status.isRunning,
        expectedStatus.isRunning,
        reason: 'State "${testCase['state']}" isRunning should match status.isRunning'
      );
    }
  });

  test('podman ps status detection', () {
    final testCases = [
      {'exited': false, 'status': ContainerStatus.running},
      {'exited': true, 'status': ContainerStatus.exited},
      {'exited': null, 'status': ContainerStatus.unknown},
    ];

    for (final testCase in testCases) {
      final ps = PodmanPs(id: 'test', exited: testCase['exited'] as bool?);
      final expectedStatus = testCase['status'] as ContainerStatus;
      expect(
        ps.status,
        expectedStatus,
        reason: 'Exited "${testCase['exited']}" should be ${expectedStatus.name}'
      );
      
      // Test status.isRunning method
      expect(
        ps.status.isRunning,
        expectedStatus.isRunning,
        reason: 'Exited "${testCase['exited']}" isRunning should match status.isRunning'
      );
    }
  });

  test('container status utility methods', () {
    expect(ContainerStatus.running.isRunning, true);
    expect(ContainerStatus.exited.isRunning, false);
    expect(ContainerStatus.created.isRunning, false);
    
    expect(ContainerStatus.exited.canStart, true);
    expect(ContainerStatus.created.canStart, true);
    expect(ContainerStatus.running.canStart, false);
    
    expect(ContainerStatus.running.canStop, true);
    expect(ContainerStatus.paused.canStop, true);
    expect(ContainerStatus.exited.canStop, false);
    
    expect(ContainerStatus.running.canRestart, true);
    expect(ContainerStatus.removing.canRestart, false);
    expect(ContainerStatus.unknown.canRestart, false);
  });
}
