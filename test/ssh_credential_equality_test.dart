/// [SshCredential] as a value: two that compare equal must hash alike.
///
/// The two are not derived from the same fields, which is how they came apart.
/// A jump server is stored as `jumpId` by old records and by `~/.ssh/config`
/// import, and as `jumpIds` by everything written since; `==` compares the
/// normalised [SshCredential.resolvedJumpIds] while `hashCode` hashed the two
/// raw fields. So the same single jump server had two spellings that were equal
/// and hashed differently — and a `Set` or `Map` keyed on one could not find
/// the other.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  const legacy = SshCredential(ip: '10.0.0.1', user: 'me', jumpId: 'j-1');
  const current = SshCredential(
    ip: '10.0.0.1',
    user: 'me',
    jumpIds: ['j-1'],
  );

  test('the two jump representations are one credential', () {
    expect(legacy.resolvedJumpIds, ['j-1']);
    expect(current.resolvedJumpIds, ['j-1']);
    expect(legacy, current);
  });

  test('and hash alike, which is what a Set depends on', () {
    expect(legacy.hashCode, current.hashCode);
    expect({legacy}.contains(current), isTrue);
    expect({current, legacy}, hasLength(1));
    expect({legacy: 1}[current], 1);
  });

  test('a different jump server is still a different credential', () {
    const elsewhere = SshCredential(
      ip: '10.0.0.1',
      user: 'me',
      jumpIds: ['j-2'],
    );
    expect(elsewhere, isNot(current));
    expect(elsewhere.hashCode, isNot(current.hashCode));
  });

  test('and so is a different file transport', () {
    // Not in `isSameAs` — the same session carries either protocol — but a
    // change all the same, and `==` says so. What hashes it must too.
    const scp = SshCredential(
      ip: '10.0.0.1',
      user: 'me',
      jumpIds: ['j-1'],
      fileTransport: SshFileTransport.scp,
    );
    expect(scp, isNot(current));
    expect(scp.hashCode, isNot(current.hashCode));
    expect(scp.isSameAs(current), isTrue);
  });

  test('no jump server at all hashes as no jump server', () {
    const a = SshCredential(ip: '10.0.0.1', user: 'me');
    const b = SshCredential(ip: '10.0.0.1', user: 'me', jumpIds: []);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
