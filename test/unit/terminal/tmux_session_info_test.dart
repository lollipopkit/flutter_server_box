import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxSessionInfo.tryParse', () {
    test('parses full escaped format', () {
      final info = TmuxSessionInfo.tryParse(
        r'$0	main\|with:colon	3	1	2024-01-01	2024-01-02	activity',
      );

      expect(info, isNotNull);
      expect(info!.id, TmuxSessionId(r'$0'));
      expect(info.name, 'main|with:colon');
      expect(info.windows, 3);
      expect(info.attached, isTrue);
      expect(info.createdAt, '2024-01-01');
      expect(info.lastAttached, '2024-01-02');
      expect(info.activity, 'activity');
    });

    test('keeps unicode names', () {
      final info = TmuxSessionInfo.tryParse(r'$1	unicode\344\275\240	1	0');

      expect(info, isNotNull);
      expect(info!.name, 'unicode你');
      expect(info.attached, isFalse);
    });

    test('rejects malformed identity and counts', () {
      expect(TmuxSessionInfo.tryParse(''), isNull);
      expect(TmuxSessionInfo.tryParse(r'main	1	1'), isNull);
      expect(TmuxSessionInfo.tryParse(r'$0	main	x	1'), isNull);
      expect(TmuxSessionInfo.tryParse(r'$0	busy	1	garbage'), isNull);
      expect(TmuxSessionInfo.tryParse(r'$0	busy	1	'), isNull);
    });
  });
}
