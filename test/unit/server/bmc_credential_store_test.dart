import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/bmc_target.dart';
import 'package:server_box/data/store/entity_store.dart';

import '../../helpers/test_db.dart';

void main() {
  late BmcCredentialStore creds;
  late BmcTargetStore targets;

  setUp(() async {
    await openTestDb();
    creds = BmcCredentialStore();
    targets = BmcTargetStore();
  });

  tearDown(() async => SqliteDb.close());

  const rackA = BmcCredential(
    id: 'cred-1',
    name: 'rack-a',
    user: 'ADMIN',
    pwd: 'calvin',
  );

  BmcTarget targetOn(String id, String addr, {String? credId = 'cred-1'}) =>
      BmcTarget(id: id, name: id, addr: addr, credId: credId);

  test('round trips', () {
    creds.put(rackA);
    creds.invalidate();

    final got = creds.fetchOneRaw('cred-1')!;
    expect(got.name, 'rack-a');
    expect(got.user, 'ADMIN');
    expect(got.pwd, 'calvin');
  });

  test('a rename keeps every target pointing at it', () {
    creds.put(rackA);
    targets.put(targetOn('1', 'https://10.0.0.9'));
    targets.put(targetOn('2', 'https://10.0.0.10'));

    creds.update(rackA, rackA.copyWith(name: 'rack-a-renamed'));
    creds.invalidate();
    targets.invalidate();

    expect(creds.fetchOneRaw('cred-1')!.name, 'rack-a-renamed');
    expect(targets.fetchOneRaw('1')!.credId, 'cred-1');
    expect(targets.fetchOneRaw('2')!.credId, 'cred-1');
  });

  test('a password rotation is one write, not one per target', () {
    creds.put(rackA);
    targets.put(targetOn('1', 'https://10.0.0.9'));
    targets.put(targetOn('2', 'https://10.0.0.10'));

    creds.update(rackA, rackA.copyWith(pwd: 'rotated'));
    creds.invalidate();

    expect(creds.fetchOneRaw('cred-1')!.pwd, 'rotated');
    expect(creds.serversUsing('cred-1'), 2);
  });

  test('two accounts cannot share a name', () {
    creds.put(rackA);
    expect(
      () => creds.put(
        const BmcCredential(id: 'cred-2', name: 'rack-a', user: 'root'),
      ),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('serversUsing counts only the targets that name it', () {
    creds.put(rackA);
    creds.put(const BmcCredential(id: 'cred-2', name: 'rack-b', user: 'root'));
    targets.put(targetOn('1', 'https://10.0.0.9'));
    targets.put(targetOn('2', 'https://10.0.0.10', credId: 'cred-2'));
    targets.put(targetOn('3', 'https://10.0.0.11', credId: null));

    expect(creds.serversUsing('cred-1'), 1);
    expect(creds.serversUsing('cred-2'), 1);
  });

  test('clearing the password is stored, not read as unchanged', () {
    creds.put(rackA);
    creds.update(rackA, rackA.copyWith(pwd: null));
    creds.invalidate();
    expect(creds.fetchOneRaw('cred-1')!.pwd, isNull);
  });

  test('deleting leaves the targets, without an account', () {
    creds.put(rackA);
    targets.put(targetOn('1', 'https://10.0.0.9'));

    creds.deleteById('cred-1');
    targets.invalidate();

    final got = targets.fetchOneRaw('1')!;
    expect(got.addr, 'https://10.0.0.9');
    expect(got.credId, isNull);
    expect(got.isComplete, isFalse);
  });

  test('a backup carries the account and reads it back', () {
    creds.put(rackA);
    final stored = creds.getAllMap();

    creds.deleteById('cred-1');
    creds.merge(stored, force: true);
    creds.invalidate();

    final got = creds.fetchOneRaw('cred-1');
    expect(got?.name, 'rack-a');
    expect(got?.pwd, 'calvin');
  });

  test('restoring the same backup twice is a no-op, not a name collision', () {
    creds.put(rackA);
    final stored = creds.getAllMap();

    // `reconcile` keeps the local id when the name is already here. Without it
    // the second restore inserts a second record under a name the schema says
    // is unique, and fails.
    creds.merge(stored, force: true);
    creds.merge(stored, force: true);
    creds.invalidate();

    expect(creds.fetch(), hasLength(1));
    expect(creds.fetchOneRaw('cred-1')?.name, 'rack-a');
  });
}
