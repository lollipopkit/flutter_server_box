import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/test_db.dart';

/// The account is the record the management page edits, so what that page
/// promises has to hold in the store: a rename keeps every reference, a
/// duplicate name is refused, and a delete does not take servers with it.
void main() {
  late BmcCredentialStore creds;
  late ServerStore servers;

  setUp(() async {
    await openTestDb();
    creds = BmcCredentialStore();
    servers = ServerStore();
  });

  tearDown(() async => SqliteDb.close());

  const rackA = BmcCredential(
    id: 'cred-1',
    name: 'rack-a',
    user: 'ADMIN',
    pwd: 'calvin',
  );

  Spi serverOn(String id, String addr, {String? credId = 'cred-1'}) => Spi(
    id: id,
    name: id,
    ssh: SshCredential(ip: '10.0.0.$id', port: 22, user: 'root'),
    bmc: BmcCfg(addr: addr, credId: credId),
  );

  test('round trips', () {
    creds.put(rackA);
    creds.invalidate();

    final got = creds.fetchOneRaw('cred-1')!;
    expect(got.name, 'rack-a');
    expect(got.user, 'ADMIN');
    expect(got.pwd, 'calvin');
  });

  test('a rename keeps every server pointing at it', () {
    creds.put(rackA);
    servers.put(serverOn('1', 'https://10.0.0.9'));
    servers.put(serverOn('2', 'https://10.0.0.10'));

    // The id is what the servers hold, so this is one UPDATE. It is the whole
    // reason the id is not the name: a private key's id *was* its name, and
    // renaming one detached every server using it.
    creds.update(rackA, rackA.copyWith(name: 'rack-a-renamed'));
    creds.invalidate();
    servers.invalidate();

    expect(creds.fetchOneRaw('cred-1')!.name, 'rack-a-renamed');
    expect(servers.fetchOneRaw('1')!.bmc?.credId, 'cred-1');
    expect(servers.fetchOneRaw('2')!.bmc?.credId, 'cred-1');
  });

  test('a password rotation is one write, not one per server', () {
    creds.put(rackA);
    servers.put(serverOn('1', 'https://10.0.0.9'));
    servers.put(serverOn('2', 'https://10.0.0.10'));

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

  test('serversUsing counts only the servers that name it', () {
    creds.put(rackA);
    creds.put(const BmcCredential(id: 'cred-2', name: 'rack-b', user: 'root'));
    servers.put(serverOn('1', 'https://10.0.0.9'));
    servers.put(serverOn('2', 'https://10.0.0.10', credId: 'cred-2'));
    servers.put(
      const Spi(
        id: '3',
        name: '3',
        ssh: SshCredential(ip: '10.0.0.3', port: 22, user: 'root'),
      ),
    );

    expect(creds.serversUsing('cred-1'), 1);
    expect(creds.serversUsing('cred-2'), 1);
  });

  test('clearing the password is stored, not read as unchanged', () {
    creds.put(rackA);
    creds.update(rackA, rackA.copyWith(pwd: null));
    creds.invalidate();
    expect(creds.fetchOneRaw('cred-1')!.pwd, isNull);
  });

  test('deleting leaves the servers, without an account', () {
    creds.put(rackA);
    servers.put(serverOn('1', 'https://10.0.0.9'));

    creds.deleteById('cred-1');
    servers.invalidate();

    // What the delete confirmation says will happen. `ON DELETE SET NULL`:
    // losing an account must not lose the machines it opened.
    final got = servers.fetchOneRaw('1')!;
    expect(got.bmc?.addr, 'https://10.0.0.9');
    expect(got.bmc?.credId, isNull);
    expect(got.bmc?.isComplete, isFalse);
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
