import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/provider/container.dart';

void main() {
  test('shellSingleQuote escapes untrusted command arguments', () {
    expect(shellSingleQuote('abc'), "'abc'");
    expect(shellSingleQuote("abc'; touch /tmp/pwn; echo '"),
        "'abc'\\''; touch /tmp/pwn; echo '\\'''",);
  });

  test('buildContainerBulkCmd joins quoted container ids', () {
    expect(buildContainerBulkCmd('start', ['a', 'b']), "start 'a' 'b'");
    expect(buildContainerBulkCmd('stop', ['a']), "stop 'a'");
    expect(buildContainerBulkCmd('restart', ['a', 'b', 'c']),
        "restart 'a' 'b' 'c'");
  });

  test('buildContainerBulkCmd escapes hostile container ids', () {
    expect(buildContainerBulkCmd('start', ["a'; touch /pwn; echo '"]),
        "start 'a'\\''; touch /pwn; echo '\\'''");
  });

  test('buildContainerBulkCmd returns null for empty ids', () {
    expect(buildContainerBulkCmd('start', []), null);
  });

  test('docker ps parse', () {
    const raw = '''
CONTAINER ID\tSTATUS\tNAMES\tIMAGE
0e9e2ef860d2\tUp 2 hours\thbbs\trustdesk/rustdesk-server:latest
9a4df3ed340c\tUp 41 minutes\thbbr\trustdesk/rustdesk-server:latest
fa1215b4be74\tUp 12 hours\tfirefly\tuusec/firefly:latest
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

  test('docker ps parse extracts compose project and working dir', () {
    const raw =
        '0e9e2ef860d2\tUp 2 hours\tcmp-web\tnginx:alpine\tnginx\t/opt/nginx';
    final ps = DockerPs.parse(raw);
    expect(ps.project, 'nginx');
    expect(ps.workingDir, '/opt/nginx');
  });

  test('docker ps parse handles empty compose project and working dir', () {
    const raw = '0e9e2ef860d2\tUp 2 hours\tcmp-standalone\talpine\t\t';
    final ps = DockerPs.parse(raw);
    expect(ps.project, null);
    expect(ps.workingDir, null);
  });

  test('docker ps parse stays backward compatible without project field', () {
    const raw = '0e9e2ef860d2\tUp 2 hours\tcmp-standalone\talpine';
    final ps = DockerPs.parse(raw);
    expect(ps.project, null);
    expect(ps.workingDir, null);
  });

  test('podman ps parse extracts compose project and working dir from labels',
      () {
    final ps = PodmanPs.fromJson({
      'Id': '0e9e2ef860d2',
      'Exited': false,
      'Image': 'nginx:alpine',
      'Names': ['cmp-web'],
      'Labels': {
        'com.docker.compose.project': 'nginx',
        'com.docker.compose.project.working_dir': '/opt/nginx',
        'other': 'x',
      },
    });
    expect(ps.project, 'nginx');
    expect(ps.workingDir, '/opt/nginx');
  });

  test('podman ps parse handles missing labels', () {
    final ps = PodmanPs.fromJson({
      'Id': '0e9e2ef860d2',
      'Exited': false,
      'Image': 'alpine',
      'Names': ['cmp-standalone'],
    });
    expect(ps.project, null);
    expect(ps.workingDir, null);
  });

  test('docker ps parse handles long swarm container names', () {
    const name =
        'apps-all-stack_komari-agent.zdngp1z1t23llz9l30s86tq3g.fjmkg9amn0u76tbln96mmzlq2';
    const image = 'registry.example.com/team/komari-agent:2026.07.10';
    final ps = DockerPs.parse('0e9e2ef860d2\tUp 2 hours\t$name\t$image');

    expect(name.length, greaterThan(50));
    expect(ps.id, '0e9e2ef860d2');
    expect(ps.state, 'Up 2 hours');
    expect(ps.names, name);
    expect(ps.image, image);
  });

  test('docker ps parse reports malformed rows', () {
    expect(
      () => DockerPs.parse('0e9e2ef860d2\tUp 2 hours\thbbs'),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', contains('Docker ps row'))
            .having(
              (e) => e.message,
              'message',
              contains('expected at least 4'),
            ),
      ),
    );
  });

  test('docker ps command uses human-readable status with compose project', () {
    final cmd = ContainerCmdType.ps.exec(ContainerType.docker);

    expect(
      cmd,
      'docker ps -a --format '
      '"{{.ID}}\\t{{.Status}}\\t{{.Names}}\\t{{.Image}}\\t'
      '{{.Label \\"com.docker.compose.project\\"}}\\t'
      '{{.Label \\"com.docker.compose.project.working_dir\\"}}"',
    );
  });

  test('docker ps status detection', () {
    // Test various Docker container states
    final testCases = [
      // Running states
      {'state': 'Up 2 minutes', 'status': ContainerStatus.running},
      {'state': 'Up 1 hour', 'status': ContainerStatus.running},
      {
        'state': 'UP 30 seconds',
        'status': ContainerStatus.running,
      }, // Case insensitive
      {
        'state': 'up 5 days',
        'status': ContainerStatus.running,
      }, // Case insensitive
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
        reason: 'State "${testCase['state']}" should be ${expectedStatus.name}',
      );

      // Test status.isRunning method
      expect(
        ps.status.isRunning,
        expectedStatus.isRunning,
        reason:
            'State "${testCase['state']}" isRunning should match status.isRunning',
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
        reason:
            'Exited "${testCase['exited']}" should be ${expectedStatus.name}',
      );

      // Test status.isRunning method
      expect(
        ps.status.isRunning,
        expectedStatus.isRunning,
        reason:
            'Exited "${testCase['exited']}" isRunning should match status.isRunning',
      );
    }
  });

  test('container status utility methods', () {
    expect(ContainerStatus.running.isRunning, true);
    expect(ContainerStatus.exited.isRunning, false);
    expect(ContainerStatus.created.isRunning, false);
  });

  group('DockerImg usage markers', () {
    test('normal tagged image in use is not unused/dangling', () {
      final img = DockerImg.fromJson({
        'ID': 'abc123',
        'Repository': 'nginx',
        'Tag': 'alpine',
        'Size': '63.7MB',
        'CreatedAt': '2 weeks ago',
        'Containers': '2',
      });
      expect(img.isDangling, false);
      expect(img.isUnused, false);
    });

    test('tagged image with unknown container count is not marked unused', () {
      final img = DockerImg.fromJson({
        'ID': 'def456',
        'Repository': 'redis',
        'Tag': '7-alpine',
        'Size': '39.9MB',
        'CreatedAt': '12 days ago',
        'Containers': 'N/A',
      });
      expect(img.isDangling, false);
      expect(img.containersCount, null);
      expect(img.isUnused, false);
    });

    test('dangling image is unused and dangling', () {
      final img = DockerImg.fromJson({
        'ID': 'b771e9afbece',
        'Repository': '<none>',
        'Tag': '<none>',
        'Size': '648MB',
        'CreatedAt': '3 months ago',
        'Containers': 'N/A',
      });
      expect(img.isDangling, true);
      expect(img.isUnused, true);
    });
  });

  group('PodmanImg usage markers', () {
    test('normal tagged image in use is not unused/dangling', () {
      final img = PodmanImg.fromJson({
        'Id': 'abc123',
        'repository': 'nginx',
        'tag': 'alpine',
        'Size': 63700000,
        'Created': 1720000000,
        'Containers': 2,
      });
      expect(img.isDangling, false);
      expect(img.isUnused, false);
    });

    test('tagged image with no containers is unused but not dangling', () {
      final img = PodmanImg.fromJson({
        'Id': 'def456',
        'repository': 'redis',
        'tag': '7-alpine',
        'Size': 39900000,
        'Created': 1721000000,
        'Containers': 0,
      });
      expect(img.isDangling, false);
      expect(img.isUnused, true);
    });

    test('dangling image is unused and dangling', () {
      final img = PodmanImg.fromJson({
        'Id': 'b771e9afbece',
        'repository': '<none>',
        'tag': '<none>',
        'Size': 648000000,
        'Created': 1710000000,
        'Containers': 0,
      });
      expect(img.isDangling, true);
      expect(img.isUnused, true);
    });
  });

  group('PodmanImg fromJson field handling', () {
    test('falls back to Names when lowercase repository/tag missing', () {
      final img = PodmanImg.fromJson({
        'Id': 'abc123',
        'Names': ['docker.io/library/nginx:latest'],
        'Size': 63700000,
        'Created': 1720000000,
        'Containers': 2,
      });
      expect(img.isDangling, true);
    });

    test('handles missing optional numeric fields', () {
      final img = PodmanImg.fromJson({
        'Id': 'abc123',
        'repository': 'nginx',
        'tag': 'alpine',
      });
      expect(img.size, null);
      expect(img.created, null);
      expect(img.containers, null);
      expect(img.isDangling, false);
      expect(img.isUnused, false);
    });
  });

  group('DockerImg fromJson field handling', () {
    test('empty Repository falls back to Names', () {
      final img = DockerImg.fromJson({
        'ID': 'abc123',
        'Repository': '',
        'Names': ['nginx'],
        'Tag': 'latest',
        'Size': '63.7MB',
        'CreatedAt': '2 weeks ago',
        'Containers': '2',
      });
      expect(img.repository, 'nginx');
      expect(img.isDangling, false);
    });

    test('empty Names list does not produce literal null repository', () {
      final img = DockerImg.fromJson({
        'ID': 'abc123',
        'Repository': '',
        'Names': <String>[],
        'Tag': 'latest',
        'Size': '63.7MB',
        'CreatedAt': '2 weeks ago',
        'Containers': '2',
      });
      expect(img.repository, isNot('null'));
      expect(img.repository, isNotEmpty);
    });

    test('whitespace-leading Names entries fall through to valid name', () {
      final img = DockerImg.fromJson({
        'ID': 'abc123',
        'Repository': '',
        'Names': ['', '   ', 'nginx'],
        'Tag': 'latest',
        'Size': '63.7MB',
        'CreatedAt': '2 weeks ago',
        'Containers': '2',
      });
      expect(img.repository, 'nginx');
      expect(img.repository, isNot('<none>'));
      expect(img.isDangling, false);
    });

    test('all-empty Names entries fall back to none', () {
      final img = DockerImg.fromJson({
        'ID': 'abc123',
        'Repository': '',
        'Names': ['', '   '],
        'Tag': 'latest',
        'Size': '63.7MB',
        'CreatedAt': '2 weeks ago',
        'Containers': '2',
      });
      expect(img.repository, '<none>');
      expect(img.isDangling, true);
    });
  });

  group('PodmanPs stats parsing', () {
    test('accepts JSON integer values for numeric fields', () {
      final podman = PodmanPs(id: 'test');
      podman.parseStats(
        '{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,'
        '"NetInput":0,"NetOutput":0,"BlockInput":0,"BlockOutput":0}',
        '5.0.0',
      );
      expect(podman.cpu, isNotNull);
      expect(podman.mem, isNotNull);
      expect(podman.net, isNotNull);
      expect(podman.disk, isNotNull);
    });

    test('handles missing network interfaces and non-int counters', () {
      final podman = PodmanPs(id: 'test');
      podman.parseStats(
        '{"CPU":1.5,"AvgCPU":0.5,"MemLimit":1073741824,"MemUsage":1,'
        '"Network":{"eth0":{"RxBytes":1024,"TxBytes":"2048"},'
        '"nulliface":null},'
        '"BlockInput":0,"BlockOutput":0}',
        '5.0.0',
      );
      expect(podman.cpu, isNotNull);
      expect(podman.net, isNotNull);
    });

    test('handles top-level network fields when version is missing', () {
      final podman = PodmanPs(id: 'test');
      podman.parseStats(
        '{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,'
        '"NetInput":512,"NetOutput":256,"BlockInput":0,"BlockOutput":0}',
      );
      expect(podman.net, '↓ 512 B / ↑ 256 B');
    });
  });
}
