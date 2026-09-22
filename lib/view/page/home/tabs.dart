part of '../home.dart';

/// Which tab is open: the pages the tabs are, moving between them, and
/// where the app was left.
extension _HomePageTabs on _HomePageState {
  /// Every tab's page, kept alive behind the settings.
  Widget _buildTabPages() {
    // Kept mounted behind the settings rather than swapped out for them: a tab
    // holds a terminal, a scroll position and a navigator of its own, and all
    // three would end here. `Offstage` does not lay its child out, so nothing
    // is resized to zero and back on the way through either.
    return Offstage(
      offstage: _tabsHidden,
      child: TickerMode(
        enabled: !_tabsHidden,
        child: _crossed(
          leaving: true,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _tabs.length,
            physics: const NeverScrollableScrollPhysics(),
            // Each tab keeps its own stack, so a page opened inside one — a
            // server's details, its files — covers the tab and not the window.
            // The bar or rail that got you here stays put, and coming back to a
            // tab returns you to where you were in it.
            itemBuilder: (_, index) => NestedNavigator(
              key: ValueKey(_tabs[index]),
              // The top inset lands on the tab's own content and not on the
              // navigator around it, which is the whole point: a page pushed
              // here is a sibling route, outside this `SafeArea`, so it reaches
              // the top of the window and animates across the status bar.
              // Wrapping the navigator instead would inset the pushed page too
              // and put the seam back.
              //
              // Here rather than in each tab because a tab is not one shape:
              // three of them put a `Scaffold` *inside* a pane splitter, so the
              // splitter's own divider is above any app bar that could have
              // spent the inset.
              rootBuilder: (_) =>
                  SafeArea(bottom: false, child: _tabs[index].page),
            ),
            onPageChanged: (value) {
              FocusScope.of(context).unfocus();
              if (!_switchingPage) {
                _selectIndex.value = value;
                _rememberTab(value);
              }
              _syncFullscreenSystemUi();
            },
          ),
        ),
      ),
    );
  }

  /// Files the tab at [index] as where the app was left.
  ///
  /// By name. A position stops meaning the same thing the moment the tabs are
  /// reordered or one is hidden, and the reorder is a setting the user makes
  /// between launches.
  void _rememberTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _lastTab.put(_tabs[index].name);
  }

  /// Where to reopen, or null to leave it on the first tab.
  ///
  /// A name this build cannot place, or a tab since hidden, is nothing to go
  /// back to rather than a position to clamp.
  int? _savedTabIndex() {
    final name = _lastTab.fetch();
    if (name.isNotEmpty) {
      final at = _tabs.indexWhere((tab) => tab.name == name);
      return at < 0 ? null : at;
    }
    // TODO: delete with `HistoryStore.homeTabIndex`. An install upgrading from
    // a build that stored the position has one and no name; reading it once
    // is what keeps that launch on the tab it was left on.
    final saved = Stores.history.homeTabIndex.fetch();
    if (saved < 0 || saved >= _tabs.length) return null;
    return saved;
  }

  void _onDestinationSelected(int index) {
    if (index < 0 || index >= _tabs.length) return;
    // A tab is a tab even when the settings are the thing on screen: picking
    // one has to put them away, which is the same move as picking the tab you
    // were already on.
    _closeSettings();
    if (_selectIndex.value == index) return;
    _selectIndex.value = index;
    _rememberTab(index);
    _switchingPage = true;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 677),
      curve: Curves.fastLinearToSlowEaseIn,
    );
    Future.delayed(const Duration(milliseconds: 677), () {
      _switchingPage = false;
    });
  }
}
