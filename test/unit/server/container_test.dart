// The app's side of containers: what it carries from `sbm_ffi::api::container`
// and the words it draws a row in. The commands and parsers themselves are
// `sbm_parser::container`'s, whose tests hold the fixtures this file used to.

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/container.dart';
import 'package:server_box/data/model/container/disk_usage.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/src/rust/api/container.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

Future<List<ContainerPs>> _ps(
  String runtime,
  String ps, {
  String? stats,
  String? version,
}) async => (await ffi.containerParsePs(
  runtimeName: runtime,
  ps: ps,
  stats: stats,
  version: version,
)).map(ContainerPs.fromFfi).toList();

Future<List<ContainerImg>> _images(String runtime, String raw) async =>
    (await ffi.containerParseImages(
      runtimeName: runtime,
      raw: raw,
    )).map(ContainerImg.fromFfi).toList();

void main() {
  setUpAll(initRustLibForTest);

  group('run arguments', () {
    test('keep quoted values and quote every part again', () {
      final args = parseContainerRunArgs(
        '''-e "GREETING=hello world" -v '/host path:/container path' '' ''',
      );
      expect(args, [
        '-e',
        'GREETING=hello world',
        '-v',
        '/host path:/container path',
        '',
      ]);

      expect(
        ffi.containerRunCommand(
          runtimeName: 'docker',
          image: 'safe; touch /tmp/image-pwned; #',
          name: 'safe; touch /tmp/name-pwned; #',
          extraArgs: parseContainerRunArgs('-p 8080:80'),
        ),
        "docker run -itd --name 'safe; touch /tmp/name-pwned; #' "
        "'-p' '8080:80' 'safe; touch /tmp/image-pwned; #'",
      );
    });

    test('shell operators stay ordinary arguments', () {
      expect(
        ffi.containerRunCommand(
          runtimeName: 'podman',
          image: 'alpine',
          name: '',
          extraArgs: parseContainerRunArgs(
            r'--label x=$(touch /tmp/pwned) ; echo owned',
          ),
        ),
        "podman run -itd '--label' 'x=\$(touch' '/tmp/pwned)' ';' 'echo' "
        "'owned' 'alpine'",
      );
    });

    test('an unterminated quote is a FormatException', () {
      expect(
        () => parseContainerRunArgs('''-e "unfinished'''),
        throwsFormatException,
      );
    });
  });

  group('rows', () {
    test('carry what docker ps said, stats worded in the app language', () async {
      final items = await _ps(
        'docker',
        'CONTAINER ID\tSTATUS\tNAMES\tIMAGE\tPROJECT\tDIR\tPORTS\n'
            '0e9e2ef860d2\tUp 2 hours\thbbs\tnginx:alpine\tweb\t/opt/web\t'
            '0.0.0.0:8080->80/tcp, :::8080->80/tcp\n'
            'fa1215b4be74\tExited (0) 7 seconds ago\tjob\talpine\n',
        stats:
            '{"ID":"0e9e2ef860d2","CPUPerc":"1.5%","MemUsage":"10MiB / 1GiB",'
            '"NetIO":"1kB / 2kB","BlockIO":"3MB / 4MB"}',
      );

      expect(items, hasLength(2));
      final web = items.first;
      expect(web.name, 'hbbs');
      expect(web.project, 'web');
      expect(web.ports, '8080→80');
      expect(web.status, ContainerStatus.running);
      expect(web.cpu, '1.5%');
      expect(web.mem, '10MiB / 1GiB');
      expect(web.net, '↓ 1kB / ↑ 2kB');
      expect(web.disk, 'Read 3MB / Write 4MB');

      final job = items.last;
      expect(job.status, ContainerStatus.exited);
      expect(job.cpu, isNull);
      expect(job.net, isNull);
    });

    test('word Podman\'s average beside its CPU', () async {
      final items = await _ps(
        'podman',
        '{"Id":"abc123","Exited":false,"Names":["worker"]}\tUp 3 hours',
        stats:
            '{"Id":"abc123","CPU":1,"AvgCPU":0,"MemLimit":1073741824,'
            '"MemUsage":1,"NetInput":512,"NetOutput":256,"BlockInput":0,'
            '"BlockOutput":0}',
        version: '5.0.0',
      );

      final worker = items.single;
      expect(worker.rawStatus, 'Up 3 hours');
      expect(worker.cpu, '1.0% / ${libL10n.pingAvg} 0.0%');
      expect(worker.net, '↓ 512 B / ↑ 256 B');
    });
  });

  group('images', () {
    test('carry dangling and usage from the parse', () async {
      final images = await _images(
        'docker',
        '{"ID":"abc","Repository":"nginx","Tag":"alpine","Size":"63.7MB",'
            '"CreatedAt":"2 weeks ago","Containers":"2"}\n'
            '{"ID":"def","Repository":"redis","Tag":"7","Size":"39.9MB",'
            '"CreatedAt":"12 days ago","Containers":"N/A"}\n'
            '{"ID":"b77","Repository":"<none>","Tag":"<none>","Size":"648MB",'
            '"CreatedAt":"3 months ago","Containers":"N/A"}',
      );

      expect(images.map((i) => i.isDangling), [false, false, true]);
      expect(images.map((i) => i.isUnused), [false, false, true]);
      expect(images[1].containersCount, isNull);
      expect(images.first.createdAt, '2 weeks ago');
      expect(images.first.size, '63.7MB');
    });

    test('Podman carries its creation time and a rendered size', () async {
      final image = (await _images(
        'podman',
        '[{"Id":"abc","Names":["docker.io/library/nginx:latest"],'
            '"Size":1048576,"Created":1720000000,"Containers":0}]',
      )).single;

      expect(image.repository, 'docker.io/library/nginx');
      expect(image.tag, 'latest');
      expect(image.created, 1720000000);
      expect(image.createdAt, isNull);
      expect(image.size, '1 MB');
      expect(image.isUnused, isTrue);
    });

    test('an unknown use stays unknown unless a container confirms it', () async {
      final images = await _images(
        'docker',
        '{"ID":"aaaaaaaaaaaa","Repository":"example/old","Tag":"stable",'
            '"Containers":"0"}\n'
            '{"ID":"bbbbbbbbbbbb","Repository":"registry.example.com/team/api",'
            '"Tag":"latest","Containers":"N/A"}',
      );

      expect(countUnusedTaggedImages(images, const ['api']), isNull);
      expect(
        countUnusedTaggedImages(images, const [
          'registry.example.com/team/api:latest',
          null,
        ]),
        1,
      );
    });
  });

  test('disk usage', () {
    final usage = ContainerDiskUsage.fromFfi(
      ffi.containerParseDiskUsage(
        raw:
            '{"Type":"Images","TotalCount":"12","Reclaimable":"809MB (56%)"}\n'
            '{"Type":"Local Volumes","TotalCount":"2","Reclaimable":"100MB"}',
      )!,
    );

    expect(usage, const ContainerDiskUsage(
      imageCount: 12,
      reclaimableBytes: 909000000,
    ));
    expect(ffi.containerParseDiskUsage(raw: 'garbage'), isNull);
  });

  test('every state offers the menu sbm_parser decides', () {
    expect(ContainerMenu.items(ContainerStatus.running), [
      ContainerMenu.stop,
      ContainerMenu.restart,
      ContainerMenu.rm,
      ContainerMenu.logs,
      ContainerMenu.terminal,
    ]);
    for (final status in [ContainerStatus.exited, ContainerStatus.unknown]) {
      expect(ContainerMenu.items(status), [
        ContainerMenu.start,
        ContainerMenu.rm,
        ContainerMenu.logs,
      ]);
    }
    expect(ContainerMenu.items(ContainerStatus.paused), [
      ContainerMenu.rm,
      ContainerMenu.logs,
    ]);
  });

  group('error detail', () {
    test('stream errors hide partial stdout but keep stderr', () {
      final error = StateError('stdout connection lost');
      expect(
        containerExecErrorDetail(
          ExecResult(
            exitCode: 0,
            stdout: '{"partial": true}',
            stderr: '',
            streamError: error,
          ),
        ),
        '$error',
      );
      expect(
        containerExecErrorDetail(
          ExecResult(
            exitCode: 0,
            stdout: '{"partial": true}',
            stderr: 'permission denied',
            streamError: error,
          ),
        ),
        'permission denied',
      );
    });

    test('incomplete output hides partial stdout', () {
      expect(
        containerExecErrorDetail(
          const ExecResult(
            exitCode: 0,
            stdout: '{"partial": true}',
            stderr: '',
            outputIncomplete: true,
          ),
        ),
        isNot(contains('partial')),
      );
    });

    test('drops the batch markers and repeated lines', () {
      expect(
        containerExecErrorDetail(
          const ExecResult(
            exitCode: 127,
            stdout: 'SrvBoxContainerSep_1_0\nSrvBoxContainerSep_1_0',
            stderr: 'sh: docker: not found\nsh: docker: not found',
          ),
        ),
        'sh: docker: not found',
      );
    });
  });
}
