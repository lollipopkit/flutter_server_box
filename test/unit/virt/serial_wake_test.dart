import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/serial_wake.dart';
import 'package:xterm/xterm.dart';

/// What the two consoles print on connecting, as captured: PVE 9.2's
/// termproxy for a QEMU serial port, and libvirt 11.3's `virsh console` typed
/// into a shell on the host.
const _pve = 'starting serial terminal on interface serial0\r\n';
const _libvirt =
    "\$ virsh console --force 'cirros-run'\r\n"
    "Connected to domain 'cirros-run'\r\n"
    'Escape character is ^] (Ctrl + ])\r\n'
    '\r\n';

void main() {
  /// A terminal, what it sends, and a wake on it.
  (Terminal, List<String>, SerialWake) setUp(String printed) {
    final sent = <String>[];
    final terminal = Terminal()..onOutput = sent.add;
    terminal.write(printed);
    return (terminal, sent, SerialWake(terminal));
  }

  test('PVE: still after the banner, counts down, then Enter', () {
    fakeAsync((time) {
      final (_, sent, wake) = setUp(_pve);
      expect(wake.remaining, isNull, reason: 'not still for long enough');
      time.elapse(const Duration(seconds: 1));
      expect(wake.remaining, 3);
      time.elapse(const Duration(seconds: 2));
      expect(wake.remaining, 1);
      expect(sent, isEmpty);
      time.elapse(const Duration(seconds: 1));
      expect(sent, ['\r']);
      expect(wake.remaining, isNull);
      wake.dispose();
    });
  });

  test('any serial port, and libvirt with its blank line', () {
    fakeAsync((time) {
      for (final printed in [
        'starting serial terminal on interface serial3\r\n',
        _libvirt,
        // libvirt before "(Ctrl + ])" was added
        "Connected to domain 'x'\r\nEscape character is ^]\r\n",
      ]) {
        final (_, sent, wake) = setUp(printed);
        time.elapse(const Duration(seconds: 4));
        expect(sent, ['\r'], reason: printed);
        wake.dispose();
      }
    });
  });

  test('once per banner: a guest that does not answer is left alone', () {
    fakeAsync((time) {
      final (terminal, sent, wake) = setUp(_pve);
      time.elapse(const Duration(seconds: 4));
      // The guest echoes nothing back; a resize redraws the same screen.
      terminal.resize(100, 30);
      time.elapse(const Duration(seconds: 10));
      expect(sent, ['\r']);
      wake.dispose();
    });
  });

  test('output during the countdown stops it; the prompt it was for', () {
    fakeAsync((time) {
      final (terminal, sent, wake) = setUp(_pve);
      time.elapse(const Duration(seconds: 2));
      expect(wake.remaining, isNotNull);
      terminal.write('\r\nUbuntu 24.04 LTS web tty1\r\n\r\nweb login: ');
      expect(wake.remaining, isNull);
      time.elapse(const Duration(seconds: 10));
      expect(sent, isEmpty);
      wake.dispose();
    });
  });

  test('a new wake on the same terminal remembers what was answered', () {
    fakeAsync((time) {
      // A console left and taken up again: the view makes a new wake.
      final (terminal, sent, wake) = setUp(_pve);
      time.elapse(const Duration(seconds: 1));
      wake
        ..cancel()
        ..dispose();
      final again = SerialWake(terminal);
      time.elapse(const Duration(seconds: 10));
      expect(sent, isEmpty);
      expect(again.remaining, isNull);
      again.dispose();
    });
  });

  test('cancel, and now', () {
    fakeAsync((time) {
      final (_, sent, wake) = setUp(_pve);
      time.elapse(const Duration(seconds: 1));
      wake.cancel();
      time.elapse(const Duration(seconds: 10));
      expect(sent, isEmpty);
      wake.dispose();

      final (_, sentNow, now) = setUp(_pve);
      time.elapse(const Duration(seconds: 1));
      now.now();
      expect(sentNow, ['\r']);
      time.elapse(const Duration(seconds: 10));
      expect(sentNow, ['\r']);
      now.dispose();
    });
  });

  test('not armed: something typed, another last line, a full-screen app', () {
    fakeAsync((time) {
      for (final printed in [
        // Typed after the banner, not yet sent.
        '${_pve}root',
        // A prompt is already there.
        '${_pve}web login: ',
        // The banner words inside another line.
        'echo starting serial terminal on interface serial0\r\n',
        // Too far up: other output since.
        '$_pve\r\nsomething\r\n',
        // A shell, not a console.
        'user@host:~\$ \r\n',
        // Drawn in the alternate buffer.
        '\x1b[?1049h$_pve',
      ]) {
        final (_, sent, wake) = setUp(printed);
        time.elapse(const Duration(seconds: 10));
        expect(sent, isEmpty, reason: printed);
        expect(wake.remaining, isNull);
        wake.dispose();
      }
    });
  });
}
