import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemePackages;
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Skills;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_host.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_records.dart';
import 'package:server_box/data/store/sync_skills.dart';
import 'package:server_box/data/store/sync_themes.dart';

import '../../helpers/fsbt.dart';
import '../../helpers/spi_fixture.dart';

/// LK Cloud's log, in memory: batches numbered as appended, once per key.
final class _Log implements SyncLogTransport {
  final batches = <(int, Uint8List)>[];
  final keys = <String, int>{};
  ({int seq, Uint8List body})? snap;

  /// Batches below this are gone: a read from under it is sent to [snap].
  var floor = 0;
  var compactAfter = 1 << 30;
  var failNext = false;

  /// Live batches refused past this until a snapshot covers them.
  var fullAfter = 1 << 30;

  @override
  Future<({String log, int seq, bool compact})> append(String key, Uint8List body) async {
    if (failNext) {
      failNext = false;
      // Taken, and the answer lost.
      _take(key, body);
      throw const SocketException('lost');
    }
    if (!keys.containsKey(key) && batches.length - (snap?.seq ?? 0) >= fullAfter) throw const SyncLogFull();
    final seq = _take(key, body);
    return (log: 'L1', seq: seq, compact: batches.length > compactAfter);
  }

  int _take(String key, Uint8List body) => keys[key] ??= (batches..add((batches.length + 1, body))).length;

  @override
  Future<SyncLogPage> read(int after, String? log) async {
    if (after < floor) return const SyncLogPage.compacted(log: 'L1');
    final rest = batches.where((b) => b.$1 > after).toList();
    return SyncLogPage(log: batches.isEmpty ? null : 'L1', batches: rest.take(2).toList(), more: rest.length > 2);
  }

  @override
  Future<bool> putSnapshot(int seq, Uint8List body) async {
    if ((snap?.seq ?? 0) >= seq) return false;
    snap = (seq: seq, body: body);
    return true;
  }

  @override
  Future<({String log, int seq, Uint8List body})?> snapshot() async =>
      snap == null ? null : (log: 'L1', seq: snap!.seq, body: snap!.body);

  final blobStore = <String, ({Uint8List body, DateTime at})>{};

  @override
  Future<void> putBlob(String name, Uint8List body) async => blobStore.putIfAbsent(name, () => (body: body, at: DateTime.now()));

  @override
  Future<Uint8List?> getBlob(String name) async => blobStore[name]?.body;

  @override
  Future<List<({String name, DateTime? at})>> blobs(String prefix) async => [
    for (final MapEntry(:key, :value) in blobStore.entries)
      if (key.startsWith(prefix)) (name: key, at: value.at),
  ];

  @override
  Future<void> deleteBlob(String name) async => blobStore.remove(name);
}

/// No encryption: what is under test is what goes into it.
final class _Clear implements SyncSeal {
  @override
  Future<Uint8List> open(Uint8List sealed) async => sealed;
  @override
  Future<Uint8List> seal(Uint8List plain) async => plain;

  @override
  String nameOf(List<int> data) => syncBlobName(secret: 'test', data: data);

  @override
  Future<bool> refresh() async => false;
}

/// A key per device, and the account's keys as `identity.age` holds them.
final class _Keyed implements SyncSeal {
  _Keyed(this.remote) : held = [...remote];

  final List<String> remote;
  List<String> held;

  @override
  Future<Uint8List> seal(Uint8List plain) async => Uint8List.fromList([...utf8.encode('${held.first}|'), ...plain]);

  @override
  Future<Uint8List> open(Uint8List sealed) async {
    final bar = sealed.indexOf(124);
    if (!held.contains(utf8.decode(sealed.sublist(0, bar)))) throw const FormatException('not ours');
    return Uint8List.sublistView(sealed, bar + 1);
  }

  @override
  String nameOf(List<int> data) => syncBlobName(secret: held.first, data: data);

  @override
  Future<bool> refresh() async {
    if (remote.every(held.contains)) return false;
    held = {...remote, ...held}.toList();
    return true;
  }

  Future<void> rotate(String next) async {
    remote.insert(0, next);
    held = [...remote];
  }
}

Future<void> _device() async {
  KvStore.onEdit = null;
  await Future<void>.delayed(Duration.zero);
  if (SqliteDb.isOpen) {
    await getIt.reset();
    await SqliteDb.close();
  }
  SqliteDb.openInMemory();
  await Stores.init();
  SyncRecorder.resetForTest();
  SyncRecorder.install();
}

LogSync _sync(_Log log, {bool settings = true}) =>
    LogSync(log, _Clear(), carries: (c) => settings || (c != 'kv:setting' && c != 'theme'));

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-log-sync-');
    Paths.doc = dir.path;
    Paths.img = dir.path.joinPath('img');
    addTearDown(() => dir.delete(recursive: true));
  });

  tearDown(() async {
    KvStore.onEdit = null;
    await Future<void>.delayed(Duration.zero);
    await getIt.reset();
    await SqliteDb.close();
  });

  const snippet = Snippet(id: 'sn1', name: 'uptime', script: 'uptime');

  test("one device's edits reach another, and its edits back", () async {
    final log = _Log();
    await _device();
    Stores.snippet.put(snippet);
    Stores.setting.timeout.put(17);
    await _sync(log).sync();
    expect(log.batches, isNotEmpty);

    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
    expect(Stores.setting.timeout.fetch(), 17);

    Stores.snippet.delete(snippet);
    Stores.setting.timeout.put(30);
    await _sync(log).sync();

    // A third device reads everything both sent.
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNull);
    expect(Stores.setting.timeout.fetch(), 30);
    expect(SyncRecords.read('snippet', snippet.id), isNull);
  });

  test('an older op does not overwrite a newer edit here', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    await _sync(log).sync();

    await _device();
    final sync = _sync(log);
    // Edited here after the other device: its op loses.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    Stores.setting.timeout.put(25);
    await sync.sync();
    expect(Stores.setting.timeout.fetch(), 25);
  });

  test('settings stay unless they are carried', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    Stores.snippet.put(snippet);
    await _sync(log, settings: false).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull);
    expect(Stores.setting.timeout.fetch(), isNot(17));
  });

  test('a snapshot is written when asked for, and read by a device behind it', () async {
    final log = _Log()..compactAfter = 0;
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log).sync();
    expect(log.snap?.seq, log.batches.length);

    log.floor = log.batches.length;
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
  });

  test('a batch whose answer was lost is sent again under its key', () async {
    final log = _Log();
    await _device();
    final sync = _sync(log);
    Stores.setting.timeout.put(17);
    await sync.sync();
    final before = log.batches.length;

    Stores.snippet.put(snippet);
    log.failNext = true;
    await expectLater(sync.sync(), throwsA(isA<SocketException>()));
    expect(log.batches, hasLength(before + 1));
    await sync.sync();
    expect(log.batches, hasLength(before + 1), reason: 'the same key is taken once, and nothing sent twice');
  });

  test('a finished benchmark reaches the next device, one running does not', () async {
    final log = _Log();
    await _device();
    final spi = spiFixture(name: 'web', id: 'srv1', ip: '10.0.0.2');
    Stores.server.put(spi);
    BenchmarkRun run(String id, BenchmarkStatus status) => BenchmarkRun(
      id: id,
      serverId: spi.id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      finishedAt: status == BenchmarkStatus.running ? null : DateTime.fromMillisecondsSinceEpoch(2000),
      status: status,
      options: const YabsOptions(),
      runDir: '/tmp/b',
      resultJson: '{}',
    );
    Stores.benchmark.put(run('done', BenchmarkStatus.completed));
    Stores.benchmark.put(run('going', BenchmarkStatus.running));
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.benchmark.get('done')?.resultJson, '{}');
    expect(Stores.benchmark.get('going'), isNull);
    Stores.benchmark.remove('done');
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.benchmark.get('done'), isNull);
  });

  test('a server carries its container host and PVE settings', () async {
    final log = _Log();
    await _device();
    final spi = spiFixture(name: 'web', id: 'srv1', ip: '10.0.0.2', tags: ['prod']);
    Stores.server.put(spi);
    Stores.container.put(spi.id, ContainerType.podman, 'unix:///run/podman.sock');
    Stores.pve.put(spi.id, PveConfig.example);
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.server.fetchOneRaw(spi.id)?.tags, ['prod']);
    expect(Stores.container.fetch(spi.id, ContainerType.podman), 'unix:///run/podman.sock');
    expect(Stores.pve.fetch(spi.id), PveConfig.example);
  });

  test('a batch nothing here can read is passed over; a newer format stops the read, not the send', () async {
    final log = _Log()..batches.add((1, Uint8List.fromList([1, 2, 3])));
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log).sync();
    expect(LogSync.behind(1), isFalse);
    expect(log.batches.length, greaterThan(1));
    expect(LogSync.tooNew.value, isFalse);

    final sent = log.batches.length;
    log.batches.add((sent + 1, Uint8List.fromList(gzip.encode('{"v":99,"ops":[]}'.codeUnits))));
    Stores.setting.timeout.put(9);
    await expectLater(_sync(log).sync(), throwsA(isA<SyncLogTooNew>()));
    expect(log.batches.length, sent + 2, reason: 'the edit is sent all the same');
    expect(LogSync.behind(sent + 1), isTrue);
    expect(LogSync.tooNew.value, isTrue, reason: 'shown on the backup page');

    LogSync.forget();
    expect(LogSync.tooNew.value, isFalse);
  });

  test('a full log is compacted, then the batch sent', () async {
    final log = _Log()..fullAfter = 1;
    await _device();
    final sync = _sync(log);
    Stores.snippet.put(snippet);
    await sync.sync();
    Stores.setting.timeout.put(9);
    await sync.sync();
    expect(log.snap?.seq, 1);
    expect(log.batches, hasLength(2));
  });

  test('a device that left settings out still writes the snapshot when asked', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    await _sync(log).sync();

    log.compactAfter = 0;
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log, settings: false).sync();
    expect(log.snap, isNotNull);
    // With what it took and did not apply: a device reading only it has both.
    log.floor = log.snap!.seq;
    await _device();
    await _sync(log).sync();
    expect(Stores.setting.timeout.fetch(), 17);
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull);
  });

  test("this device's own append moves the cursor when nothing is between", () async {
    final log = _Log();
    await _device();
    final sync = _sync(log);
    Stores.snippet.put(snippet);
    await sync.sync();
    expect(LogSync.behind(log.batches.length), isFalse);
  });

  test('two records named alike: the later keeps the name, the other is suffixed alike everywhere', () async {
    final log = _Log();
    await _device();
    Stores.snippet.put(const Snippet(id: 'aaaaaaaa1', name: 'up', script: 'uptime'));
    await _sync(log).sync();

    await _device();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    Stores.snippet.put(const Snippet(id: 'bbbbbbbb2', name: 'up', script: 'w'));
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw('bbbbbbbb2')?.name, 'up');
    expect(Stores.snippet.fetchOneRaw('aaaaaaaa1')?.name, 'up (aaaaaa)');

    // A third device reads them the other way round and comes to the same.
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw('bbbbbbbb2')?.name, 'up');
    expect(Stores.snippet.fetchOneRaw('aaaaaaaa1')?.name, 'up (aaaaaa)');
  });

  test('a large record goes as a blob, and one nothing names is swept with a snapshot', () async {
    final log = _Log();
    log.blobStore['op-stale.age'] = (body: Uint8List(1), at: DateTime.now().subtract(const Duration(days: 3)));
    await _device();
    final big = 'x' * (SyncEngine.inlineMax + 1);
    Stores.setting.set('bigNote', big);
    await _sync(log).sync();
    expect(log.blobStore.keys.where((k) => k != 'op-stale.age'), hasLength(1));

    await _device();
    await _sync(log).sync();
    expect(Stores.setting.get<String>('bigNote'), big);

    log.compactAfter = 0;
    Stores.setting.timeout.put(9);
    await _sync(log).sync();
    expect(log.snap, isNotNull);
    expect(log.blobStore.containsKey('op-stale.age'), isFalse);
    expect(log.blobStore, hasLength(1), reason: 'the one the snapshot names stays');
  });

  test('a replaced key: devices that held the old one take the new, and one that joins reads all', () async {
    final log = _Log();
    final account = ['k1'];
    await _device();
    final a = _Keyed(account);
    Stores.snippet.put(snippet);
    await LogSync(log, a).sync();

    // Another device, behind, holding k1 only.
    final behind = _Keyed(account);

    final sync = LogSync(log, a);
    await sync.rotate(() => a.rotate('k2'));
    expect(log.snap, isNotNull);
    Stores.setting.timeout.put(21);
    await sync.sync();

    await _device();
    await LogSync(log, behind).sync();
    expect(behind.held.first, 'k2');
    expect(Stores.setting.timeout.fetch(), 21);
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull);

    // A device that joins after has both keys from the account's file.
    await _device();
    await LogSync(log, _Keyed(account)).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull);
    expect(Stores.setting.timeout.fetch(), 21);
  });

  test('a device that leaves records out carries them on in its snapshot', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    await _sync(log).sync();
    // Settings off here: taken as they came, not applied, and still in the
    // snapshot it writes (here as it replaces the key).
    await _device();
    await _sync(log, settings: false).rotate(() async {});
    expect(Stores.setting.timeout.fetch(), isNot(17));
    // The batches the snapshot covers are gone: a device joining now reads
    // the snapshot alone, and has the setting.
    log.floor = log.snap!.seq;
    await _device();
    await _sync(log).sync();
    expect(Stores.setting.timeout.fetch(), 17);
  });

  test('a large record carried on is sealed again under a key replaced here', () async {
    final log = _Log();
    final account = ['k1'];
    final big = 'x' * (SyncEngine.inlineMax + 1);
    await _device();
    Stores.setting.set('bigNote', big);
    await LogSync(log, _Keyed(account)).sync();

    // Settings off here: kept as they came, and in the snapshot the
    // replaced key writes.
    await _device();
    final b = _Keyed(account);
    await LogSync(log, b, carries: (c) => c != 'kv:setting' && c != 'theme').rotate(() => b.rotate('k2'));
    final passed = SqliteDb.instance.select('SELECT d FROM sync_passed;').single['d'] as String;
    expect(passed, isNot(contains(r'$blob')));

    // A device holding the new key alone reads it from the snapshot.
    log.floor = log.snap!.seq;
    await _device();
    await LogSync(log, _Keyed(['k2'])).sync();
    expect(Stores.setting.get<String>('bigNote'), big);
  });

  test('a picked file missing for a while, or an unreadable skills lock, removes nothing elsewhere', () async {
    final log = _Log();
    final skills = await Directory.systemTemp.createTemp('sbm-skills-lock-');
    addTearDown(() => skills.delete(recursive: true));
    Skills.root = skills.path;
    await _device();
    await Directory(Paths.img).create(recursive: true);
    final picked = File(Paths.img.joinPath('ssh_bg_2.png'))..writeAsBytesSync([4, 5]);
    Stores.setting.sshBgImage.put(picked.path);
    Skills.import('notes', {
      'lock': {'name': 'notes', 'description': 'Takes notes.', 'hash': 'h1'},
      'files': {'SKILL.md': base64Encode(utf8.encode('---\nname: notes\n---\n'))},
    });
    await _sync(log).sync();
    final sent = log.batches.length;

    final lock = File('${skills.path}/.lock.json');
    final readable = lock.readAsStringSync();
    picked.deleteSync();
    lock.writeAsStringSync('{');
    Skills.root = skills.path;
    await _sync(log).sync();
    expect(log.batches.length, sent, reason: 'nothing sent as gone');

    // Readable again as it was: nothing in it is a new edit here.
    lock.writeAsStringSync(readable);
    Skills.root = skills.path;
    await _sync(log).sync();
    expect(log.batches.length, sent, reason: 'nothing sent again');
    Skills.remove('notes');
  });

  test('the same record under two ids (restored before ids existed) is one record, not two', () async {
    final log = _Log();
    await _device();
    Stores.snippet.put(const Snippet(id: 'aaaaaaaa1', name: 'deploy', script: 'make deploy'));
    await _sync(log).sync();

    await _device();
    Stores.snippet.put(const Snippet(id: 'bbbbbbbb2', name: 'deploy', script: 'make deploy'));
    await _sync(log).sync();
    expect(Stores.snippet.fetch().map((e) => e.name), ['deploy']);

    // An edit of it where it is `aaaaaaaa1` lands on `bbbbbbbb2` here.
    final edit = _Log()..batches.addAll(log.batches);
    final h = syncTick(device: BigInt.from(99), last: '', nowMs: BigInt.from(SyncClock.now() + 1000));
    edit.batches.add((edit.batches.length + 1, Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode({
      'v': 1,
      'ops': [
        {'c': 'snippet', 'id': 'aaaaaaaa1', 'h': h, 'd': {'id': 'aaaaaaaa1', 'name': 'deploy', 'script': 'make release'}},
      ],
    }))))));
    await _sync(edit).pull();
    expect(Stores.snippet.fetch().map((e) => (e.id, e.script)), [('bbbbbbbb2', 'make release')]);

    // A third device holds it once too.
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetch(), hasLength(1));
  });

  test("a snapshot names the batch's blob for the same op, so the sweep keeps it", () async {
    final log = _Log();
    await _device();
    Stores.setting.set('bigNote', 'y' * (SyncEngine.inlineMax + 1));
    await _sync(log).sync();
    final named = log.blobStore.keys.single;
    log.blobStore[named] = (body: log.blobStore[named]!.body, at: DateTime.now().subtract(const Duration(days: 3)));

    log.compactAfter = 0;
    Stores.setting.timeout.put(9);
    await _sync(log).sync();
    expect(log.snap, isNotNull);
    expect(log.blobStore.keys, [named]);
  });

  test("the snapshot sync takes another device's record of the same name as another record", () async {
    await _device();
    Stores.snippet.put(const Snippet(id: 'phone0001', name: 'a', script: 'from the phone'));
    final changed = Stores.snippet.merge({
      'mac000001': const Snippet(id: 'mac000001', name: 'a', script: 'from the mac').toJson(),
      EntityStore.lastModKey: {'mac000001': SyncClock.now() + 1000},
    }, force: false);
    expect(changed, isFalse, reason: 'the name is taken here: left to the log, which suffixes one');
    expect(Stores.snippet.fetchOneRaw('phone0001')?.script, 'from the phone');
  });

  test('a theme installed on one device is installed on the next, with its own package', () async {
    final log = _Log();
    addTearDown(() => SyncThemes.root = null);
    Future<void> device(String name) async {
      final dir = await Directory.systemTemp.createTemp('sbm-themes-$name-');
      addTearDown(() => dir.delete(recursive: true));
      SyncThemes.root = dir.path;
      await _device();
      initThemeHost();
    }

    await device('a');
    final theme = await ThemePackages.install(fsbtOf('example.amethyst', 'Amethyst'), rootDirectory: SyncThemes.root);
    await _sync(log).sync();

    await device('b');
    expect(ThemePackages.installed(theme.installationId, rootDirectory: SyncThemes.root), isNull);
    await _sync(log).sync();
    expect(ThemePackages.installed(theme.installationId, rootDirectory: SyncThemes.root)?.name, 'Amethyst');

    // Chosen elsewhere: this device points its own keys at its copy, and a
    // preset whose theme is not here yet is left as it is, not undone.
    Stores.setting.appThemePreset.put(theme.preset);
    SyncThemes.reselect();
    expect(Stores.setting.appThemePackage.fetch(), theme.installationId);
    Stores.setting.appThemePreset.put(ThemePackages.presetOf('0' * 64));
    final preset = Stores.setting.appThemePreset.fetch();
    SyncThemes.reselect();
    expect(Stores.setting.appThemePreset.fetch(), preset);

    // Left alone where the settings do not sync.
    await device('c');
    await _sync(log, settings: false).sync();
    expect(ThemePackages.installed(theme.installationId, rootDirectory: SyncThemes.root), isNull);
  });

  test('a picked file reaches the next device as its own copy, and its removal too', () async {
    final log = _Log();
    await _device();
    await Directory(Paths.img).create(recursive: true);
    final picked = File(Paths.img.joinPath('ssh_bg_1.png'))..writeAsBytesSync([1, 2, 3]);
    Stores.setting.sshBgImage.put(picked.path);
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    final copy = Stores.setting.sshBgImage.fetch();
    expect(copy, isNot(picked.path));
    expect(File(copy).readAsBytesSync(), [1, 2, 3]);
    final batches = log.batches.length;
    await _sync(log).sync();
    expect(log.batches.length, batches, reason: 'what came in is not sent back');

    Stores.setting.sshBgImage.put('');
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.setting.sshBgImage.fetch(), isEmpty);
  });

  test('a skill installed on one device is installed on the next, and removed', () async {
    final log = _Log();
    Future<void> device(String name) async {
      final dir = await Directory.systemTemp.createTemp('sbm-skills-$name-');
      addTearDown(() => dir.delete(recursive: true));
      Skills.root = dir.path;
      await _device();
    }

    await device('a');
    Skills.import('notes', {
      'lock': {'name': 'notes', 'description': 'Takes notes.', 'hash': 'h1'},
      'files': {'SKILL.md': base64Encode(utf8.encode('---\nname: notes\n---\n'))},
    });
    await _sync(log).sync();

    await device('b');
    await _sync(log).sync();
    expect(Skills.byDir('notes')?.description, 'Takes notes.');
    expect(Skills.filesOf('notes'), ['SKILL.md']);
    Skills.remove('notes');
    await _sync(log).sync();

    await device('c');
    await _sync(log).sync();
    expect(Skills.byDir('notes'), isNull);
  });

  test('a skill changed here is sent at once; one a sync installs is not sent back', () async {
    final dir = await Directory.systemTemp.createTemp('sbm-skills-follow-');
    addTearDown(() => dir.delete(recursive: true));
    Skills.root = dir.path;
    await _device();
    SyncSkills.follow();
    var woken = 0;
    void wake() => woken++;
    SyncRecorder.onLocal.add(wake);
    addTearDown(() => SyncRecorder.onLocal.remove(wake));

    Skills.import('notes', {
      'lock': {'name': 'notes', 'description': 'Takes notes.', 'hash': 'h1'},
      'files': {'SKILL.md': base64Encode(utf8.encode('---\nname: notes\n---\n'))},
    });
    await Future<void>.delayed(Duration.zero);
    expect(woken, 1);
    final stamped = SqliteDb.instance.select("SELECT hlc FROM sync_record WHERE c = 'skill' AND id = 'notes';");
    expect(stamped, hasLength(1));

    woken = 0;
    SyncSkills.install([
      (c: SyncSkills.c, id: 'other', h: '${'0' * 12}${'0' * 4}${'1' * 16}', d: {
        'lock': {'name': 'other', 'description': 'Other.', 'hash': 'h2'},
        'files': {'SKILL.md': base64Encode(utf8.encode('---\nname: other\n---\n'))},
      }),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(woken, 0, reason: 'what came from elsewhere is not an edit here');
    Skills.remove('notes');
    Skills.remove('other');
  });

  test('a theme here at another version is kept, and the selection points at it', () async {
    final log = _Log();
    addTearDown(() => SyncThemes.root = null);
    Future<void> device(String name) async {
      final dir = await Directory.systemTemp.createTemp('sbm-themes-$name-');
      addTearDown(() => dir.delete(recursive: true));
      SyncThemes.root = dir.path;
      await _device();
      initThemeHost();
    }

    await device('a');
    final v2 = await ThemePackages.install(fsbtOf('example.amethyst', 'Amethyst 2'), rootDirectory: SyncThemes.root);
    Stores.setting.appThemePreset.put(v2.preset);
    await _sync(log).sync();

    await device('b');
    final v1 = await ThemePackages.install(fsbtOf('example.amethyst', 'Amethyst'), rootDirectory: SyncThemes.root);
    await _sync(log).sync();
    expect(ThemePackages.installed(v2.installationId, rootDirectory: SyncThemes.root), isNull);
    expect(Stores.setting.appThemePreset.fetch(), v2.preset, reason: 'the choice is not rewritten');
    expect(Stores.setting.appThemePackage.fetch(), v1.installationId);
  });

  test('themes that cannot be read now are sent later, not skipped', () async {
    final log = _Log();
    addTearDown(() => SyncThemes.readForTest = null);
    await _device();
    final sync = _sync(log);
    Stores.setting.timeout.put(9);
    await sync.sync();

    SyncRecorder.record('theme', 'abc');
    Stores.snippet.put(snippet);
    SyncThemes.readForTest = () async => null;
    await sync.sync();
    expect(SyncRecorder.pending(''), hasLength(greaterThanOrEqualTo(2)));
    final sentBefore = log.batches.length;

    SyncThemes.readForTest = () async => {'abc': {'id': 'example.x', 'name': 'X', 'bundled': 'example.x'}};
    await sync.sync();
    expect(log.batches.length, sentBefore + 1);
    await _device();
    await _sync(log, settings: false).pull();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull, reason: 'what came after the unread theme went too');
  });
}
