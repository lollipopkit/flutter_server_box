enum AskAiPanelPlacement { bottomSheet, sidePanel }

enum AskAiHistoryPresentation { bottomSheet, dialog }

const askAiSidePanelBreakpoint = 800.0;

AskAiPanelPlacement askAiPanelPlacementForWidth(double width) {
  return width >= askAiSidePanelBreakpoint
      ? AskAiPanelPlacement.sidePanel
      : AskAiPanelPlacement.bottomSheet;
}

AskAiHistoryPresentation askAiHistoryPresentationForWidth(double width) {
  return width >= askAiSidePanelBreakpoint
      ? AskAiHistoryPresentation.dialog
      : AskAiHistoryPresentation.bottomSheet;
}
