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

  test('a console accepts input like a tab session', () {
    // A virtual machine's graphical console lives in `consoles`; resolving
    // input through `sessions` alone dropped every key and pointer event.
    var state = const RemoteDesktopSessionsState();
    state = state.put(RemoteDesktopSessionView(profile: profile('tab')));
    state = state.putConsole(RemoteDesktopSessionView(profile: profile('vm')));
    expect(state.acceptsInput('tab'), isTrue);
    expect(state.acceptsInput('vm'), isTrue);
    expect(state.acceptsInput('missing'), isFalse);

    state = state.put(state.byId('vm')!.copyWith(viewOnly: true));
    expect(state.consoles['vm']!.viewOnly, isTrue);
    expect(state.acceptsInput('vm'), isFalse);
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

  // #1835: a failure the server named is the same on every attempt, and a
  // session taken over by another connection would take it back.
  test('a named failure is not retried, an unnamed disconnect is', () {
    const retries = RemoteDesktopSessions.retriesAfter;
    expect(
      retries(
        ffi.RemoteDesktopEndReason.serverDisconnected,
        null,
        lastErrorRetryable: false,
      ),
      isTrue,
    );
    expect(
      retries(
        ffi.RemoteDesktopEndReason.serverDisconnected,
        ffi.RemoteDesktopFailure.replacedByOtherConnection,
        lastErrorRetryable: false,
      ),
      isFalse,
    );
    expect(
      retries(
        ffi.RemoteDesktopEndReason.configurationError,
        ffi.RemoteDesktopFailure.standardRdpSecurityOnly,
        lastErrorRetryable: true,
      ),
      isFalse,
    );
  });

  test('a failure is set and cleared with the end reason', () {
    final ended = RemoteDesktopSessionView(profile: profile('one')).copyWith(
      endReason: ffi.RemoteDesktopEndReason.serverDisconnected,
      failure: ffi.RemoteDesktopFailure.idleTimeout,
    );
    expect(ended.failure, ffi.RemoteDesktopFailure.idleTimeout);
    expect(ended.copyWith(viewOnly: true).failure, ended.failure);
    final unnamed = ended.copyWith(
      endReason: ffi.RemoteDesktopEndReason.transportError,
    );
    expect(unnamed.failure, isNull);
    expect(ended.copyWith(clearEndReason: true).failure, isNull);
  });
}
