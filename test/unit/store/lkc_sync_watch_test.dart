import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/misc.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSync sync;
  late ValueNotifier<int> user;
  late ValueNotifier<bool> toggle;
  late bool signedIn;
  late int changes;
  late bool openFails;
  late Completer<void>? opening;
  late LkcSyncWatch watch;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    sync = _FakeSync();
    user = ValueNotifier(0);
    toggle = ValueNotifier(true);
    signedIn = true;
    changes = 0;
    openFails = false;
    opening = null;
    watch = LkcSyncWatch(
      user: user,
      signedIn: () => signedIn,
      open: () async {
        await opening?.future;
        if (openFails) throw StateError('offline');
        return sync;
      },
      toggle: toggle,
      onRemoteChange: () => changes++,
      bakFileName: Miscs.bakFileName,
      retryAfter: Duration.zero,
    );
  });

  tearDown(() => watch.dispose());

  Future<void> start() async {
    watch.start();
    await pumpEventQueue();
  }

  test('syncs on connecting and on the backup changing, nothing else', () async {
    await start();
    expect(sync.listening, isTrue);

    sync.emit(const LkcSyncEvent(connected: true));
    await pumpEventQueue();
    expect(changes, 1);

    sync.emit(LkcSyncEvent(connected: false, name: Miscs.bakFileName, etag: 'e2'));
    await pumpEventQueue();
    expect(changes, 2);

    sync.emit(const LkcSyncEvent(connected: false, name: 'blob-00.age', etag: 'e'));
    sync.emit(const LkcSyncEvent(connected: false, lost: 'reset'));
    await pumpEventQueue();
    expect(changes, 2);
  });

  test('the switch stops and starts listening', () async {
    await start();
    toggle.value = false;
    await pumpEventQueue();
    expect(sync.listening, isFalse);
    expect(sync.stops, 1);

    toggle.value = true;
    await pumpEventQueue();
    expect(sync.listening, isTrue);
    expect(sync.listens, 2);
  });

  test('listens in the foreground only', () async {
    await start();
    // A desktop window out of focus is still in front of the user.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpEventQueue();
    expect(sync.listening, isTrue);
    expect(sync.listens, 1);

    // Stepwise, as the platform reports it.
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await pumpEventQueue();
    expect(sync.listening, isFalse);

    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await pumpEventQueue();
    expect(sync.listening, isTrue);
    expect(sync.listens, 2);
  });

  test('on a desktop, listens behind other windows too', () async {
    await watch.dispose();
    watch = LkcSyncWatch(
      user: user,
      signedIn: () => signedIn,
      open: () async => sync,
      toggle: toggle,
      onRemoteChange: () => changes++,
      bakFileName: Miscs.bakFileName,
      inBackground: true,
    );
    await start();
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await pumpEventQueue();
    expect(sync.listening, isTrue);
    expect(sync.listens, 1);
  });

  test('signing out stops listening', () async {
    await start();
    signedIn = false;
    user.value++;
    await pumpEventQueue();
    expect(sync.listening, isFalse);
  });

  test('homebase ending the stream of a refused session is not listened to again', () async {
    await start();
    signedIn = false;
    sync.end();
    await pumpEventQueue();
    expect(sync.listens, 1);

    signedIn = true;
    user.value++;
    await pumpEventQueue();
    expect(sync.listening, isTrue, reason: 'a later sign-in listens again');
  });

  test('a stream that ends while signed in keeps the session and listens again', () async {
    await start();
    sync.end();
    await pumpEventQueue();
    expect(sync.listens, 2);
    expect(sync.listening, isTrue);
  });

  test('listening that cannot start is tried again', () async {
    openFails = true;
    await start();
    expect(sync.listens, 0);
    openFails = false;
    await pumpEventQueue();
    expect(sync.listening, isTrue);
  });

  test('switched off while opening: never listens', () async {
    final gate = opening = Completer<void>();
    watch.start();
    toggle.value = false;
    gate.complete();
    await pumpEventQueue();
    expect(sync.listens, 0);
  });

  test('disposed: stops and ignores later changes', () async {
    await start();
    await watch.dispose();
    expect(sync.listening, isFalse);

    toggle.value = false;
    toggle.value = true;
    await pumpEventQueue();
    expect(sync.listens, 1);
  });
}

final class _FakeSync implements LkcSync {
  StreamController<LkcSyncEvent>? _events;
  var listens = 0;
  var stops = 0;

  bool get listening => _events != null;

  void emit(LkcSyncEvent event) => _events!.add(event);

  void end() {
    final events = _events;
    _events = null;
    events?.close();
  }

  @override
  Stream<LkcSyncEvent> listen() {
    // Another listen takes the place of the one before.
    end();
    listens++;
    return (_events = StreamController()).stream;
  }

  @override
  void stopListening() {
    if (_events == null) return;
    stops++;
    end();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
