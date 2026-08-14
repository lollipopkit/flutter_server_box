import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';

class _Escalation implements SftpEscalation {
  _Escalation({
    this.available = true,
    this.always = false,
    this.answer = true,
    this.fails = false,
  });

  @override
  final bool available;

  @override
  final bool always;

  /// What [confirmRetry] answers.
  final bool answer;

  /// Whether [run] throws, as it does when the user declines the password.
  final bool fails;

  var asked = 0;
  var escalated = 0;
  var noted = 0;
  final commands = <String>[];

  @override
  Future<bool> confirmRetry() async {
    asked++;
    return answer;
  }

  @override
  Future<void> run(String command) async {
    escalated++;
    commands.add(command);
    if (fails) throw StateError('no password');
  }

  @override
  void onEscalated() => noted++;
}

void main() {
  group('isPermissionDenied', () {
    test('recognises what servers actually send', () {
      // Four spellings, because that is how many the app had to learn.
      expect(isPermissionDenied('Permission denied'), isTrue);
      expect(isPermissionDenied('Access denied'), isTrue);
      expect(isPermissionDenied('SftpStatusError: code 3'), isTrue);
      expect(isPermissionDenied('failure'), isTrue);
    });

    test('leaves other failures alone', () {
      expect(isPermissionDenied('No such file'), isFalse);
      expect(isPermissionDenied('Connection closed'), isFalse);
      expect(isPermissionDenied(null), isFalse);
    });
  });

  group('runWithEscalation', () {
    test('does not ask when nothing was refused', () async {
      final escalation = _Escalation();

      await runWithEscalation(
        escalation: escalation,
        normal: () async {},
        sudoCommand: () => 'rm -f -- /x',
      );

      expect(escalation.asked, 0);
      expect(escalation.escalated, 0);
    });

    test('asks, then runs the command as root', () async {
      final escalation = _Escalation();

      await runWithEscalation(
        escalation: escalation,
        normal: () async => throw StateError('Permission denied'),
        sudoCommand: () => 'rm -f -- /etc/x',
      );

      expect(escalation.asked, 1);
      expect(escalation.commands, ['rm -f -- /etc/x']);
      // So a "sudo mode" switch can turn itself on rather than asking again
      // for the next file in the same directory.
      expect(escalation.noted, 1);
    });

    test('a declined retry leaves the original error standing', () async {
      final escalation = _Escalation(answer: false);

      await expectLater(
        runWithEscalation(
          escalation: escalation,
          normal: () async => throw StateError('Permission denied'),
          sudoCommand: () => 'rm -f -- /etc/x',
        ),
        throwsA(isA<StateError>()),
      );

      expect(escalation.escalated, 0);
    });

    test('a failure that is not about permission is never escalated', () async {
      final escalation = _Escalation();

      await expectLater(
        runWithEscalation(
          escalation: escalation,
          normal: () async => throw StateError('No such file'),
          sudoCommand: () => 'rm -f -- /etc/x',
        ),
        throwsA(isA<StateError>()),
      );

      expect(escalation.asked, 0);
      expect(escalation.escalated, 0);
    });

    test('nothing is asked of a session that is already root', () async {
      final escalation = _Escalation(available: false);

      await expectLater(
        runWithEscalation(
          escalation: escalation,
          normal: () async => throw StateError('Permission denied'),
          sudoCommand: () => 'rm -f -- /etc/x',
        ),
        throwsA(isA<StateError>()),
      );

      expect(escalation.asked, 0);
    });

    test('with sudo always on, the plain attempt is skipped', () async {
      final escalation = _Escalation(always: true);
      var tried = false;

      await runWithEscalation(
        escalation: escalation,
        normal: () async => tried = true,
        sudoCommand: () => 'rm -f -- /etc/x',
      );

      // The point of the switch: somewhere the user knows they cannot write,
      // every operation would otherwise begin with a refusal.
      expect(tried, isFalse);
      expect(escalation.escalated, 1);
      expect(escalation.asked, 0);
    });

    test('no escalation at all means the refusal stands', () async {
      // What a transfer running in an isolate gets: nobody to ask.
      await expectLater(
        runWithEscalation(
          normal: () async => throw StateError('Permission denied'),
          sudoCommand: () => 'rm -f -- /etc/x',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a declined password surfaces rather than being swallowed', () async {
      final escalation = _Escalation(fails: true);

      await expectLater(
        runWithEscalation(
          escalation: escalation,
          normal: () async => throw StateError('Permission denied'),
          sudoCommand: () => 'rm -f -- /etc/x',
        ),
        throwsA(isA<StateError>()),
      );

      expect(escalation.noted, 0, reason: 'nothing was escalated successfully');
    });
  });
}
