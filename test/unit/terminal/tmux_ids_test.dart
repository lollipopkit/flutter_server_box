import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxSessionId', () {
    test('parses valid session ids', () {
      expect(TmuxSessionId.parse(r'$0').value, r'$0');
      expect(TmuxSessionId.tryParse(r'$42')?.value, r'$42');
    });

    test('rejects malformed session ids', () {
      expect(TmuxSessionId.tryParse(r'$evil'), isNull);
      expect(TmuxSessionId.tryParse('@0'), isNull);
      expect(TmuxSessionId.tryParse(r'$'), isNull);
      expect(() => TmuxSessionId.parse(r'$evil'), throwsArgumentError);
    });
  });

  group('TmuxWindowId', () {
    test('parses valid window ids', () {
      expect(TmuxWindowId.parse('@0').value, '@0');
      expect(TmuxWindowId.tryParse('@42')?.value, '@42');
    });

    test('rejects malformed window ids', () {
      expect(TmuxWindowId.tryParse('@evil'), isNull);
      expect(TmuxWindowId.tryParse(r'$0'), isNull);
      expect(TmuxWindowId.tryParse('@'), isNull);
      expect(() => TmuxWindowId.parse('@evil'), throwsArgumentError);
    });
  });

  group('TmuxPaneId', () {
    test('parses valid pane ids', () {
      expect(TmuxPaneId.parse('%0').value, '%0');
      expect(TmuxPaneId.tryParse('%42')?.value, '%42');
    });

    test('rejects malformed pane ids', () {
      expect(TmuxPaneId.tryParse('%evil'), isNull);
      expect(TmuxPaneId.tryParse('@0'), isNull);
      expect(TmuxPaneId.tryParse('%'), isNull);
      expect(() => TmuxPaneId.parse('%evil'), throwsArgumentError);
    });

    test('the plain constructors check too', () {
      expect(
        () => TmuxSessionId("\$0'; kill-server; display-message '"),
        throwsArgumentError,
      );
      expect(() => TmuxWindowId('@0;'), throwsArgumentError);
      expect(() => TmuxPaneId("%0'"), throwsArgumentError);
    });
  });

  test('ids of the same kind compare by value', () {
    expect(TmuxSessionId(r'$1'), TmuxSessionId(r'$1'));
    expect(TmuxWindowId('@1'), TmuxWindowId('@1'));
    expect(TmuxPaneId('%1'), TmuxPaneId('%1'));
    expect(TmuxSessionId(r'$1').hashCode, TmuxSessionId(r'$1').hashCode);
  });
}
