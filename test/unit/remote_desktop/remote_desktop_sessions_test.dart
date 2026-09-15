import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;

void main() {
  RemoteDesktopProfile profile(String id) => RemoteDesktopProfile.defaults(
    id: id,
    serverId: 'server',
    name: id,
    protocol: RemoteDesktopProtocol.vnc,
  );

  test('session state selects and removes sessions deterministically', () {
    var state = const RemoteDesktopSessionsState();
    state = state.put(RemoteDesktopSessionView(profile: profile('one')));
    state = state.put(RemoteDesktopSessionView(profile: profile('two')));
    state = state.select('one');
    expect(state.activeId, 'one');

    state = state.remove('one');
    expect(state.activeId, 'two');
    expect(state.sessions.keys, ['two']);
  });

  test('session diagnostics never include frame or saved credentials', () {
    final secret = profile('one').copyWith(password: 'secret');
    final view = RemoteDesktopSessionView(
      profile: secret,
      connectionState: ffi.RemoteDesktopConnectionState.connected,
      frameBgra: Uint8List.fromList([1, 2, 3, 4]),
      error: 'failed',
    );
    final text = view.toString();
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('[1, 2, 3, 4]')));
    expect(text, contains('hasFrame: true'));
  });

  test('cursor bitmap can be cleared when the server restores default', () {
    final cursor = RemoteDesktopCursor(
      useDefault: false,
      rgba: Uint8List.fromList([0, 0, 0, 0]),
      width: 1,
      height: 1,
    );
    final cleared = cursor.copyWith(useDefault: true, clearBitmap: true);
    expect(cleared.useDefault, isTrue);
    expect(cleared.rgba, isNull);
  });
}
