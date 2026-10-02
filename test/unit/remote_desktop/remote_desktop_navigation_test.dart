import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';

import '../../helpers/rust_lib_helper.dart';

/// The rules are `sbm_parser::desktop`'s (`desktop_compat.rs` holds these
/// cases too); this checks the editor reaches them and phrases the answer.
void main() {
  setUpAll(initRustLibForTest);

  test('profile form requires the RDP username', () {
    expect(
      validateRemoteDesktopProfileInput(
        name: 'Desktop',
        host: '127.0.0.1',
        port: 3389,
        protocol: RemoteDesktopProtocol.rdp,
        username: '',
        password: '',
      ),
      contains('username'),
    );
  });

  test('classic VNC passwords are at most eight ASCII bytes', () {
    String? validate(String password) => validateRemoteDesktopProfileInput(
      name: 'Desktop',
      host: '127.0.0.1',
      port: 5900,
      protocol: RemoteDesktopProtocol.vnc,
      username: '',
      password: password,
    );

    expect(validate('12345678'), isNull);
    expect(validate('123456789'), isNotNull);
    expect(validate('密码'), isNotNull);
  });

  test('a host the agent could not dial is refused', () {
    expect(
      validateRemoteDesktopProfileInput(
        name: 'Desktop',
        host: 'a b',
        port: 5900,
        protocol: RemoteDesktopProtocol.vnc,
        username: '',
        password: '',
      ),
      isNotNull,
    );
  });
}
