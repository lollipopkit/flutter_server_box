import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/ssh/ask_ai_layout.dart';

void main() {
  group('askAiPanelPlacementForWidth', () {
    test('uses bottom sheet on phone and narrow tablet widths', () {
      expect(askAiPanelPlacementForWidth(390), AskAiPanelPlacement.bottomSheet);
      expect(askAiPanelPlacementForWidth(799), AskAiPanelPlacement.bottomSheet);
    });

    test('uses side panel on desktop and wide tablet widths', () {
      expect(askAiPanelPlacementForWidth(800), AskAiPanelPlacement.sidePanel);
      expect(askAiPanelPlacementForWidth(1440), AskAiPanelPlacement.sidePanel);
    });
  });

  group('askAiHistoryPresentationForWidth', () {
    test('uses a bottom sheet on compact widths', () {
      expect(
        askAiHistoryPresentationForWidth(390),
        AskAiHistoryPresentation.bottomSheet,
      );
      expect(
        askAiHistoryPresentationForWidth(799),
        AskAiHistoryPresentation.bottomSheet,
      );
    });

    test('uses a dialog on wide tablets and desktop', () {
      expect(
        askAiHistoryPresentationForWidth(800),
        AskAiHistoryPresentation.dialog,
      );
      expect(
        askAiHistoryPresentationForWidth(1440),
        AskAiHistoryPresentation.dialog,
      );
    });
  });
}
