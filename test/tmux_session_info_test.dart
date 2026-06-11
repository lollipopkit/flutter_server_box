import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxSessionInfo.tryParse', () {
    test('parses full format line', () {
      final info = TmuxSessionInfo.tryParse('main|3|1|2024-01-01|2024-01-02');
      expect(info, isNotNull);
      expect(info!.name, 'main');
      expect(info.windows, 3);
      expect(info.attached, true);
      expect(info.createdAt, '2024-01-01');
      expect(info.lastAttached, '2024-01-02');
    });

    test('parses unattached session', () {
      final info = TmuxSessionInfo.tryParse('dev|1|0|2024-01-01|2024-01-02');
      expect(info, isNotNull);
      expect(info!.name, 'dev');
      expect(info.windows, 1);
      expect(info.attached, false);
    });

    test('parses minimal format (name only)', () {
      final info = TmuxSessionInfo.tryParse('test');
      expect(info, isNotNull);
      expect(info!.name, 'test');
      expect(info.windows, 0);
      expect(info.attached, false);
    });

    test('returns null for empty line', () {
      expect(TmuxSessionInfo.tryParse(''), isNull);
    });

    test('handles invalid window count gracefully', () {
      final info = TmuxSessionInfo.tryParse('test|abc|0');
      expect(info, isNotNull);
      expect(info!.windows, 0);
    });

    test('displayName includes windows and attached status', () {
      final attached = TmuxSessionInfo(
        name: 'main',
        windows: 3,
        attached: true,
      );
      expect(attached.displayName, 'main · 3 windows · (attached)');

      final detached = TmuxSessionInfo(
        name: 'dev',
        windows: 1,
        attached: false,
      );
      expect(detached.displayName, 'dev · 1 window');
    });

    test('displayName handles zero windows', () {
      final info = TmuxSessionInfo(
        name: 'empty',
        windows: 0,
        attached: false,
      );
      expect(info.displayName, 'empty');
    });

    test('parses multiple sessions from list output', () {
      const output = '''main|3|1|2024-01-01|2024-01-02
dev|1|0|2024-01-01|2024-01-02
work|5|0|2024-01-03|2024-01-04''';
      final sessions = output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map(TmuxSessionInfo.tryParse)
          .whereType<TmuxSessionInfo>()
          .toList();
      expect(sessions, hasLength(3));
      expect(sessions[0].name, 'main');
      expect(sessions[1].name, 'dev');
      expect(sessions[2].name, 'work');
    });
  });
}
