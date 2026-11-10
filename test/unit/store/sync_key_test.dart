import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
void _restart() {
  SyncKeyring.resetForTest();
  SyncKeyring.init(label: 'ServerBox sync key');
}

/// A file no key here opens: said by [SyncKeyring], or by a key itself.
final _unreadable = throwsA(
  anyOf(
    isA<SyncError>().having((e) => e.kind, 'kind', SyncEngineErrorKind.unreadable),
    isA<SyncEngineError>().having((e) => e.kind, 'kind', SyncEngineErrorKind.unreadable),
  ),
);

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
    _restart();
  });
  tearDown(() {
    SecureProp.legacyApart = null;
    SyncKeyring.resetForTest();
  });

  test('the first device puts a key there, sealed with the password at epoch 0', () async {
    final file = MemoryKeyFile();
    final key = await SyncKeyring.ofFiles(file);
    final opened = await _opened(file, 'a');
    expect(opened.epoch, 0);
    expect(opened.keys.single, startsWith('AGE-SECRET-KEY-1'));
    expect(await key.open(sealed: key.seal(plain: Uint8List.fromList([1]))), [1]);
  });

  test('two devices that made a key at once end with both, sealing with one', () async {
    final file = MemoryKeyFile();
    final a = await SyncKeyring.ofFiles(file);
    final sealedByA = a.seal(plain: Uint8List.fromList([1]));
    final keysOfA = (await _opened(file, 'a')).keys;

    // B did not see A's file yet, and wrote over it.
    _restart();
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'a'});
    file.blind = true;
    final b = await SyncKeyring.ofFiles(file);
    file.blind = false;
    final sealedByB = b.seal(plain: Uint8List.fromList([2]));
    await expectLater(b.open(sealed: sealedByA), _unreadable, reason: 'nothing of A in the file B reads');

    // A, on its keys, meets B's file: puts its own back beside B's.
    _restart();
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'a', 'syncIdentity.${file.id}': keysOfA.join('\n')});
    final again = await SyncKeyring.ofFiles(file);
    expect(await again.open(sealed: sealedByB), [2]);
    expect(await again.open(sealed: sealedByA), [1]);
    expect((await _opened(file, 'a')).keys, hasLength(2));
  });

  test('a password the file does not open syncs nothing, kept keys or not, until it is the one there', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;
    // The others changed it to `b`.
    file.put(await _sealed('b', keys, 1));

    _restart();
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncPasswordMismatch>()));
    expect(SyncKeyring.passwordMismatch.value, {file.id});
    // Within the minute a check stands: refused again without asking.
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncPasswordMismatch>()));

    await _password('b');
    await SyncKeyring.recheck();
    expect(SyncKeyring.passwordMismatch.value, isEmpty);
    expect((await SyncKeyring.ofFiles(file)).nameOf(data: [0]), isNotEmpty);
    expect(file.writes, 1, reason: 'only the first key was written');
  });

  test('a password changed here seals the file again at once, at the next epoch', () async {
    final file = MemoryKeyFile();
    final key = await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    await SyncKeyring.passwordChanged('a');
    await _password('c');
    await SyncKeyring.recheck();

    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
    expect(SyncKeyring.passwordMismatch.value, isEmpty);
    expect(await key.open(sealed: key.seal(plain: Uint8List.fromList([3]))), [3]);
  });

  test('a change made offline seals the file at the next launch', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    file.offline = true;
    await SyncKeyring.passwordChanged('a');
    await _password('c');
    await SyncKeyring.recheck();
    expect(await _pending(), isNotNull, reason: 'still to be sealed again');

    _restart();
    file.offline = false;
    await SyncKeyring.ofFiles(file);
    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('a change here meets one made elsewhere since: not sealed over, said', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    // Changed here to `c` with the file out of reach.
    file.offline = true;
    await SyncKeyring.passwordChanged('a');
    await _password('c');
    await SyncKeyring.recheck();
    // Meanwhile another device changed it to `b`.
    file.offline = false;
    file.put(await _sealed('b', keys, 1));

    _restart();
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncPasswordMismatch>()));
    await _expectFile(file, 'b', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('changed away and back elsewhere: the epoch says so, though the old password opens it', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    file.offline = true;
    await SyncKeyring.passwordChanged('a');
    await _password('c');
    await SyncKeyring.recheck();
    // Another device: a to b, then b to a.
    file.offline = false;
    file.put(await _sealed('a', keys, 2));

    _restart();
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncPasswordMismatch>()));
    expect((await _opened(file, 'a')).epoch, 2);
  });

  test('a password the keychain brings before the other device sealed the file again is only a candidate', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    // Changed to `b` on another device, which has not sealed the file yet.
    await _password('b');
    await SyncKeyring.recheck();
    expect(SyncKeyring.passwordMismatch.value, {file.id});
    expect((await _opened(file, 'a')).epoch, 0, reason: 'not sealed with it here');

    // That device seals it.
    file.put(await _sealed('b', keys, 1));
    await SyncKeyring.recheck();
    expect(SyncKeyring.passwordMismatch.value, isEmpty);
  });

  test('a device whose password was refused puts nothing where the file went', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;
    file.put(await _sealed('b', keys, 1));
    await SyncKeyring.recheck();
    expect(SyncKeyring.passwordMismatch.value, {file.id});

    file.body = null;
    await SyncKeyring.recheck();
    expect(file.body, isNull);
    expect(SyncKeyring.passwordMismatch.value, {file.id});

    // The person enters another: that one is the remote's now.
    await _password('d');
    await SyncKeyring.recheck();
    expect((await _opened(file, 'd')).keys, keys);
  });

  test('a remote gone from this device leaves nothing of its password behind', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    file.offline = true;
    await SyncKeyring.passwordChanged('a');
    expect(await _pending(), isNotNull);

    await SyncKeyring.forget(file.id);
    expect(await _pending(), isNull);
    expect(const PrefProp<String>('sync_key_epochs').get(), isNull);
  });

  test('beside what was synced, none is made where the key file has not arrived yet', () async {
    final file = MemoryKeyFile()..holdsSynced = true;
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncKeyNotHere>()));
    expect(file.writes, 0);
  });

  test('a change with the sync off keeps nothing of the password before', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    SyncKeyring.release(file.id);
    await SyncKeyring.passwordChanged('a');
    expect(await _pending(), isNull);
  });

  test('a synced backup picked to restore opens with a kept key, nothing synced', () async {
    final file = MemoryKeyFile();
    final sealed = (await SyncKeyring.ofFiles(file)).seal(plain: Uint8List.fromList([9]));
    _restart();
    expect(await SyncKeyring.openKept(sealed), [9]);
    await expectLater(SyncKeyring.openAny(sealed), _unreadable, reason: 'no sync on here');
  });

  test('nor with a password the remote refuses', () async {
    final file = MemoryKeyFile();
    final key = await SyncKeyring.ofFiles(file);
    final sealed = key.seal(plain: Uint8List.fromList([9]));
    file.put(await _sealed('b', (await _opened(file, 'a')).keys, 1));
    await SyncKeyring.recheck();
    expect(SyncKeyring.passwordMismatch.value, {file.id});
    await expectLater(SyncKeyring.openKept(sealed), _unreadable);
  });

  test('a change made while the file is out of reach since launch seals it once reached', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    _restart();
    file.offline = true;
    await expectLater(SyncKeyring.ofFiles(file), throwsA(isA<SyncError>()));
    await SyncKeyring.passwordChanged('a');
    await _password('c');
    file.offline = false;
    await SyncKeyring.recheck();
    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(SyncKeyring.passwordMismatch.value, isEmpty);
  });

  test('a change while a check is on its way seals the file with the new password', () async {
    final file = MemoryKeyFile();
    final key = await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;

    file.held = Completer();
    final checking = key.check(force: true);
    await Future<void>.delayed(Duration.zero);
    await SyncKeyring.passwordChanged('a');
    await _password('c');
    final rechecked = SyncKeyring.recheck();
    file.held!.complete();
    file.held = null;
    await checking;
    await rechecked;

    await _expectFile(file, 'c', epoch: 1, keys: keys);
    expect(await _pending(), isNull);
  });

  test('a device that opened the file puts its keys back where it went; a restore puts none', () async {
    final file = MemoryKeyFile();
    await SyncKeyring.ofFiles(file);
    final keys = (await _opened(file, 'a')).keys;
    file.body = null;
    file.holdsSynced = true;

    _restart();
    await expectLater(SyncKeyring.ofFiles(file, create: false), throwsA(isA<SyncKeyNotHere>()));
    expect(file.body, isNull);
    await SyncKeyring.passwordChanged('a');
    expect(await _pending(), isNull, reason: 'the restore left nothing to seal again');
    await SyncKeyring.recheck();
    await SyncKeyring.ofFiles(file);
    await _expectFile(file, 'a', epoch: 0, keys: keys);
  });
}
