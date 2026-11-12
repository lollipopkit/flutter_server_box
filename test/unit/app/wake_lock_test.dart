import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/wake_lock.dart';

void main() {
  late ValueNotifier<bool> general;
  late ValueNotifier<bool> terminal;
  late List<bool> applied;
  late WakeLock lock;

  setUp(() {
    general = ValueNotifier(false);
    terminal = ValueNotifier(true);
    applied = [];
    lock = WakeLock(general: general, terminal: terminal, apply: applied.add);
  });

  test('a terminal holds it only with its setting on', () {
    terminal.value = false;
    lock.start();
    lock.terminalOpened();
    expect(applied, isEmpty);

    terminal.value = true;
    expect(applied, [true]);
    terminal.value = false;
    expect(applied, [true, false]);
  });

  test('held until the last terminal closes', () {
    lock.start();
    lock.terminalOpened();
    lock.terminalOpened();
    lock.terminalClosed();
    expect(applied, [true]);
    lock.terminalClosed();
    expect(applied, [true, false]);
  });

  test('closing a terminal leaves the general lock held', () {
    general.value = true;
    lock.start();
    lock.terminalOpened();
    lock.terminalClosed();
    expect(applied, [true]);

    general.value = false;
    expect(applied, [true, false]);
  });

  test('a terminal opened before start holds it', () {
    lock.terminalOpened();
    expect(applied, [true]);
  });

  test('stop releases it', () {
    general.value = true;
    lock.start();
    lock.stop();
    general.value = false;
    general.value = true;
    expect(applied, [true, false]);
  });
}
