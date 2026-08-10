enum AskAiPanelPlacement { bottomSheet, sidePanel }

const askAiSidePanelBreakpoint = 800.0;

AskAiPanelPlacement askAiPanelPlacementForWidth(double width) {
  return width >= askAiSidePanelBreakpoint
      ? AskAiPanelPlacement.sidePanel
      : AskAiPanelPlacement.bottomSheet;
}
