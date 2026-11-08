import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/sync_key.dart';

/// A key file as another device seals it.
Future<Uint8List> _sealed(String pwd, List<String> keys, int epoch) async =>
    utf8.encode(await AgeCryptor.encrypt(utf8.encode(['# ServerBox sync key, epoch $epoch', ...keys].join('\n')), pwd));

/// [file] opened as another device opens it: its epoch and keys.
Future<({int epoch, List<String> keys})> _opened(MemoryKeyFile file, String pwd) async {
  final lines = utf8.decode(await AgeCryptor.decrypt(file.body!, pwd)).split('\n');
  final epoch = int.parse(RegExp(r'epoch (\d+)$').firstMatch(lines.first)!.group(1)!);
  return (epoch: epoch, keys: lines.skip(1).toList());
}

Future<void> _expectFile(MemoryKeyFile file, String pwd, {required int epoch, required List<String> keys}) async {
  final opened = await _opened(file, pwd);
  expect(opened.epoch, epoch);
  expect(opened.keys, keys);
}

Future<void> _password(String pwd) => const FlutterSecureStorage().write(key: SecureStoreProps.bakPwd.key, value: pwd);

Future<String?> _pending() => const FlutterSecureStorage().read(key: 'syncKeyPending');

/// The app ending and starting again: what is kept stays.
void _restart() => SyncKey.resetForTest();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initRustLibForTest);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    // The store keeps its instance across tests.
    await const PrefProp<String>('sync_key_epochs').remove();
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'a'});
    SecureProp.resetRateLimits();
    // The mock keeps one map whatever the store's options: one store here.
    SecureProp.legacyApart = false;
  });
  tearDown(() {
    SecureProp.legacyApart = null;
    SyncKey.resetForTest();
  });

  test('the first device puts a key there, sealed with the password at epoch 0', () async {
    final file = MemoryKeyFile();
    final key = await SyncKey.of(file);
    final opened = await _opened(file, 'a');
    expect(opened.epoch, 0);
    expect(opened.keys.single, startsWith('AGE-SECRET-KEY-1'));
    expect(await key.open(await key.seal(Uint8List.fromList([1]))), [1]);
  });

  test('two devices that made a key at once end with both, sealing with one', () async {
    final file = MemoryKeyFile();
    final a = await SyncKey.of(file);
    final sealedByA = await a.seal(Uint8List.fromList([1]));

    // B did not see A's file yet, and wrote over it.
    _restart();
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'a'});
    file.blind = true;
    final b = await SyncKey.of(file);
    file.blind = false;
    final sealedByB = await b.seal(Uint8List.fromList([2]));
    await expectLater(a.open(sealedByB), throwsFormatException);

    // A, on its keys, meets B's file: puts its own back beside B's.
    expect(await a.refresh(), isTrue);
    expect(await a.open(sealedByB), [2]);
    expect(await b.refresh(), isTrue);
    expect(await b.open(sealedByA), [1]);
    expect(a.nameOf([0]), b.nameOf([0]), reason: 'both seal with the same key now');
    expect(await a.refresh(), isFalse);
  });

  test('a password the file does not open syncs nothing, kept keys or not, until it is the one there', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;
    // The others changed it to `b`.
    file.put(await _sealed('b', keys, 1));

    _restart();
    await expectLater(SyncKey.of(file), throwsA(isA<SyncPasswordMismatch>()));
    expect(SyncKey.passwordMismatch.value, {file.id});
    // Within the minute a check stands: refused again without asking.
    await expectLater(SyncKey.of(file), throwsA(isA<SyncPasswordMismatch>()));

    await _password('b');
    await SyncKey.recheck();
    expect(SyncKey.passwordMismatch.value, isEmpty);
    expect((await SyncKey.of(file)).nameOf([0]), isNotEmpty);
    expect(file.writes, 1, reason: 'only the first key was written');
  });

  test('a password changed here seals the file again at once, at the next epoch', () async {
    final file = MemoryKeyFile();
    final key = await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    await SyncKey.passwordChanged('a');
    await _password('c');
    await SyncKey.recheck();

    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
    expect(SyncKey.passwordMismatch.value, isEmpty);
    expect(await key.open(await key.seal(Uint8List.fromList([3]))), [3]);
  });

  test('a change made offline seals the file at the next launch', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    file.offline = true;
    await SyncKey.passwordChanged('a');
    await _password('c');
    await SyncKey.recheck();
    expect(await _pending(), isNotNull, reason: 'still to be sealed again');

    _restart();
    file.offline = false;
    await SyncKey.of(file);
    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('a change here meets one made elsewhere since: not sealed over, said', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    // Changed here to `c` with the file out of reach.
    file.offline = true;
    await SyncKey.passwordChanged('a');
    await _password('c');
    await SyncKey.recheck();
    // Meanwhile another device changed it to `b`.
    file.offline = false;
    file.put(await _sealed('b', keys, 1));

    _restart();
    await expectLater(SyncKey.of(file), throwsA(isA<SyncPasswordMismatch>()));
    await _expectFile(file, 'b', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('changed away and back elsewhere: the epoch says so, though the old password opens it', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    file.offline = true;
    await SyncKey.passwordChanged('a');
    await _password('c');
    await SyncKey.recheck();
    // Another device: a to b, then b to a.
    file.offline = false;
    file.put(await _sealed('a', keys, 2));

    _restart();
    await expectLater(SyncKey.of(file), throwsA(isA<SyncPasswordMismatch>()));
    expect((await _opened(file, 'a')).epoch, 2);
  });

  test('a password the keychain brings before the other device sealed the file again is only a candidate', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    // Changed to `b` on another device, which has not sealed the file yet.
    await _password('b');
    await SyncKey.recheck();
    expect(SyncKey.passwordMismatch.value, {file.id});
    expect((await _opened(file, 'a')).epoch, 0, reason: 'not sealed with it here');

    // That device seals it.
    file.put(await _sealed('b', keys, 1));
    await SyncKey.recheck();
    expect(SyncKey.passwordMismatch.value, isEmpty);
  });

  test('a device whose password was refused puts nothing where the file went', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;
    file.put(await _sealed('b', keys, 1));
    await SyncKey.recheck();
    expect(SyncKey.passwordMismatch.value, {file.id});

    file.body = null;
    await SyncKey.recheck();
    expect(file.body, isNull);
    expect(SyncKey.passwordMismatch.value, {file.id});

    // The person enters another: that one is the remote's now.
    await _password('d');
    await SyncKey.recheck();
    expect((await _opened(file, 'd')).keys, keys);
  });

  test('a remote gone from this device leaves nothing of its password behind', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    file.offline = true;
    await SyncKey.passwordChanged('a');
    expect(await _pending(), isNotNull);

    await SyncKey.forget(file.id);
    expect(await _pending(), isNull);
    expect(const PrefProp<String>('sync_key_epochs').get(), isNull);
  });

  test('beside what was synced, none is made where the key file has not arrived yet', () async {
    final file = MemoryKeyFile()..holdsSynced = true;
    await expectLater(SyncKey.of(file), throwsA(isA<SyncKeyNotHere>()));
    expect(file.writes, 0);
  });

  test('a change with the sync off keeps nothing of the password before', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    SyncKey.release(file.id);
    await SyncKey.passwordChanged('a');
    expect(await _pending(), isNull);
  });

  test('a synced backup picked to restore opens with a kept key, nothing synced', () async {
    final file = MemoryKeyFile();
    final sealed = await (await SyncKey.of(file)).seal(Uint8List.fromList([9]));
    _restart();
    expect(await SyncKey.openKept(sealed), [9]);
    await expectLater(SyncKey.openAny(sealed), throwsFormatException, reason: 'no sync on here');
  });

  test('nor with a password the remote refuses', () async {
    final file = MemoryKeyFile();
    final key = await SyncKey.of(file);
    final sealed = await key.seal(Uint8List.fromList([9]));
    file.put(await _sealed('b', (await _opened(file, 'a')).keys, 1));
    await SyncKey.recheck();
    expect(SyncKey.passwordMismatch.value, {file.id});
    await expectLater(SyncKey.openKept(sealed), throwsFormatException);
  });

  test('a change made while the file is out of reach since launch seals it once reached', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    _restart();
    file.offline = true;
    await expectLater(SyncKey.of(file), throwsStateError);
    await SyncKey.passwordChanged('a');
    await _password('c');
    file.offline = false;
    await SyncKey.recheck();
    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(SyncKey.passwordMismatch.value, isEmpty);
  });

  test('a change while a check is on its way seals the file with the new password', () async {
    final file = MemoryKeyFile();
    final key = await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;

    file.held = Completer();
    final checking = key.check(force: true);
    await Future<void>.delayed(Duration.zero);
    await SyncKey.passwordChanged('a');
    await _password('c');
    final rechecked = SyncKey.recheck();
    file.held!.complete();
    file.held = null;
    await checking;
    await rechecked;

    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('a device that opened the file puts its keys back where it went; a restore puts none', () async {
    final file = MemoryKeyFile();
    await SyncKey.of(file);
    final keys = (await _opened(file, 'a')).keys;
    file.body = null;
    file.holdsSynced = true;

    _restart();
    await expectLater(SyncKey.of(file, create: false), throwsA(isA<SyncKeyNotHere>()));
    expect(file.body, isNull);
    await SyncKey.recheck();
    await SyncKey.of(file);
    await _expectFile(file, 'a', epoch: 0, keys: keys);
  });

  test('a new key seals from then on; the one before still opens', () async {
    final file = MemoryKeyFile();
    final key = await SyncKey.of(file);
    final before = await key.seal(Uint8List.fromList([5]));
    final old = (await _opened(file, 'a')).keys.single;

    await key.rotate();
    final opened = await _opened(file, 'a');
    expect(opened.epoch, 0);
    expect(opened.keys, hasLength(2));
    expect(opened.keys.last, old);
    expect(await key.open(before), [5]);
    await expectLater(
      AgeCryptor.decryptWith(await key.seal(Uint8List.fromList([6])), old),
      throwsFormatException,
    );
  });
}
