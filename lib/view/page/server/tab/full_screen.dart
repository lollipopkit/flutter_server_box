// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

/// Full screen: entered by turning a phone to landscape (the `fullScreen`
/// setting) or from the bar's button, where it takes the window as well.
extension _FullScreen on _ServerPageState {
  /// Whether full screen shows every server, by default where there is room.
  bool get _fsShowsAll =>
      _fsAll ?? MediaQuery.sizeOf(context).shortestSide >= 600;

  /// Says whether full screen is on, for the window's chrome to follow — see
  /// [ServerFullScreen]. Applied after the frame, as [_publishImmersive] is.
  void _publishFullScreen(bool on) {
    if (_fsPublished == on) return;
    _fsPublished = on;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Every time in, the screen is the readings alone.
      if (on) _fsBar.value = false;
      ref.read(serverFullScreenProvider.notifier).set(on);
    });
  }

  Widget _buildFullScreen({required bool manual}) {
    _publishImmersive(true);
    final burnIn = Stores.setting.fullScreenJitter.fetch();
    // Every wrapper is there whether it acts or not, so switching burn-in or
    // entering by the button keeps the pager and the cards as they are.
    return Material(
      type: MaterialType.transparency,
      child: PopScope(
        canPop: !(manual && BackScope.of(context)),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && manual) unawaited(_exitFullScreen());
        },
        child: CallbackShortcuts(
          bindings: {
            if (manual)
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  unawaited(_exitFullScreen()),
          },
          child: Focus(
            focusNode: _fsKeys,
            child: ServerFullScreenTheme.burnIn(
              context,
              on: burnIn,
              // Never split: there is no list here for a detail to sit
              // beside.
              child: _ServerOpenRequest(
                split: false,
                onOpen: _openRequestedServer,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_fsBar, _tag]),
                  builder: (context, _) {
                    final order = _fullScreenOrder();
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _fsBar.value = !_fsBar.value,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ValueListenableBuilder<Offset>(
                            valueListenable: _offsetNotifier,
                            builder: (context, offset, child) => Padding(
                              padding: const EdgeInsets.all(_kBurnInShift),
                              child: Transform.translate(
                                offset: offset,
                                child: child,
                              ),
                            ),
                            // Clear of the bar while it is showing, so it
                            // covers nothing.
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.only(
                                top: _fsBar.value ? ServerFullScreenBar.height : 0,
                              ),
                              child: SafeArea(child: _buildFullScreenBody(order)),
                            ),
                          ),
                          if (_fsBar.value)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _buildFullScreenBar(order, manual: manual),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The servers in the tag picked, in the order of the settings.
  List<String> _fullScreenOrder() {
    final state = ref.watch(serversProvider);
    final tag = _tag.value;
    if (tag == TagSwitcher.kDefaultTag) return state.serverOrder;
    return [
      for (final id in state.serverOrder)
        if (state.servers[id]?.tags?.contains(tag) == true) id,
    ];
  }

  Widget _buildFullScreenBody(List<String> order) {
    if (order.isEmpty) {
      _clearLandscapeController();
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }
    if (_fsShowsAll) return _buildFullScreenAll(order);
    return _buildFullScreenOne(order);
  }

  Widget _buildFullScreenOne(List<String> order) {
    _syncLandscapeSelection(order);
    final controller = _landscapePageController(order);
    return PageView.builder(
      controller: controller,
      key: ValueKey(order.join(',')),
      itemCount: order.length,
      onPageChanged: (idx) => _onLandscapePageChanged(idx, order),
      itemBuilder: (_, idx) {
        final id = order[idx];
        final srv = ref.watch(serverProvider(id));
        return KeyedSubtree(
          key: ValueKey(id),
          child: Builder(
            builder: (context) {
              if (!serverCardHasBody(srv)) {
                return Center(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 495,
                      child: _fullScreenCard(context, srv, toOne: false),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(11),
                child: GestureDetector(
                  onLongPress: () => _onLongPressCard(context, srv),
                  onSecondaryTapUp: (d) =>
                      _onLongPressCard(context, srv, at: d.globalPosition),
                  child: ServerFullScreenOne(
                    srv: srv,
                    promoted: _promotedOf(id),
                    onPromote: (kind) => _promote(id, kind),
                    onOpen: () => _onTapCard(context, srv, inPlace: false),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFullScreenAll(List<String> order) {
    return LayoutBuilder(
      builder: (context, cons) {
        final n = serverFullScreenColumns(cons.maxWidth - 34);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < n; c++)
                Expanded(
                  child: Column(
                    children: [
                      for (var i = c; i < order.length; i += n)
                        Builder(
                          builder: (context) => _fullScreenCard(
                            context,
                            ref.watch(serverProvider(order[i])),
                            toOne: true,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// A server's card; [toOne] makes a tap show it alone rather than open it.
  Widget _fullScreenCard(
    BuildContext context,
    ServerState srv, {
    required bool toOne,
  }) {
    final id = srv.spi.id;
    return ServerCard(
      key: ValueKey(id),
      srv: srv,
      promoted: _promotedOf(id),
      onPromote: (kind) => _promote(id, kind),
      expanded: ServerCardExpanded.reader(id),
      onToggleExpanded: () => _toggleExpanded(id),
      onTap: () => toOne && serverCardHasBody(srv)
          ? _showFullScreenOne(id)
          : _onTapCard(context, srv, inPlace: false),
      onLongPress: () => _onLongPressCard(context, srv),
      highlighted: id == _menuId,
    ).onSecondary((at) => _onLongPressCard(context, srv, at: at));
  }

  Widget _buildFullScreenBar(List<String> order, {required bool manual}) {
    final all = _fsShowsAll;
    final Widget leading;
    if (all) {
      final connected = order
          .where(
            (id) => ref.watch(
              serverProvider(id).select((s) => s.conn == ServerConn.finished),
            ),
          )
          .length;
      leading = Row(
        children: [
          Flexible(
            child: Text(
              _tag.value == TagSwitcher.kDefaultTag
                  ? l10n.fullScreenAllServers
                  : '#${_tag.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          UIs.width13,
          Text(
            l10n.fullScreenConnectedFmt(connected, order.length),
            style: UIs.text13Grey.copyWith(fontFeatures: kTabularFigures),
          ),
        ],
      );
    } else {
      final seen = _landscapeSeenId;
      final at = seen == null ? -1 : order.indexOf(seen);
      leading = at < 0
          ? UIs.placeholder
          : SessionSwitcherLabel(
              name: ref.read(serversProvider).servers[seen]?.name ?? seen!,
              position: at + 1,
              total: order.length,
              icon: BoxIcons.bx_server,
              onTap: () => _pickFullScreenServer(order, seen!),
            );
    }
    return ServerFullScreenBar(
      leading: leading,
      actions: [
        if (all) ...[
          ServerFullScreenAction(
            icon: MingCute.hashtag_line,
            label: libL10n.tag,
            onTap: () => _showTagSheet(_tags.value.toList()),
          ),
          ServerFullScreenAction(
            icon: Icons.crop_landscape,
            label: l10n.fullScreenOneServer,
            onTap: () => _showFullScreenOne(null),
          ),
        ] else
          ServerFullScreenAction(
            icon: Icons.grid_view,
            label: l10n.fullScreenAllServers,
            onTap: _showFullScreenAll,
          ),
        ServerFullScreenAction(
          icon: Icons.settings,
          label: libL10n.setting,
          onTap: () => ref.read(settingsRequestProvider.notifier).go(),
        ),
        if (manual)
          ServerFullScreenAction(
            icon: Icons.fullscreen_exit,
            label: l10n.fullScreenExit,
            onTap: _exitFullScreen,
          ),
      ],
    );
  }
}

extension _FullScreenActions on _ServerPageState {
  Future<void> _enterFullScreen() async {
    _fsManual.value = true;
    // Deliberately, as [_keys] is: this tab is kept alive behind the others.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fsKeys.requestFocus();
    });
    if (!isDesktop) return;
    try {
      _fsWindowWasFull = await windowManager.isFullScreen();
      if (!_fsWindowWasFull) await windowManager.setFullScreen(true);
    } catch (e, s) {
      Loggers.app.warning('Window full screen', e, s);
    }
  }

  /// Leaves full screen; [window] is false when the window has already left.
  Future<void> _exitFullScreen({bool window = true}) async {
    if (!_fsManual.value) return;
    _fsManual.value = false;
    if (!isDesktop || !window || _fsWindowWasFull) return;
    try {
      await windowManager.setFullScreen(false);
    } catch (e, s) {
      Loggers.app.warning('Window full screen', e, s);
    }
  }

  /// One server at a time, from [id] or from the one last shown.
  void _showFullScreenOne(String? id) {
    if (id != null) _landscapeSeenId = id;
    _dropLandscapeController();
    setState(() => _fsAll = false);
  }

  void _showFullScreenAll() => setState(() => _fsAll = true);

  Future<void> _pickFullScreenServer(List<String> order, String current) async {
    final picked = await showServerSwitcher(
      context,
      ids: order,
      current: current,
    );
    if (picked == null || !mounted) return;
    final idx = order.indexOf(picked);
    final ctrl = _landscapeController;
    if (idx < 0 || ctrl == null || !ctrl.hasClients) return;
    ctrl.jumpToPage(idx);
  }

  void _clearLandscapeController() {
    _landscapeSeenId = null;
    _dropLandscapeController();
  }

  /// A new controller starts at [_landscapeSeenId].
  void _dropLandscapeController() {
    final controller = _landscapeController;
    _landscapeController = null;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  void _syncLandscapeSelection(List<String> order) {
    // Keep the same server in view when order mutates (reorder/delete).
    // PageView is index-based, so without this a reorder silently switches
    // the visible server. Track by id and jump the controller to that id's
    // new index post-frame.
    final seen = _landscapeSeenId;
    if (seen != null && order.contains(seen)) {
      final targetIdx = order.indexOf(seen);
      final ctrl = _landscapeController;
      if (ctrl != null && ctrl.hasClients) {
        final current = ctrl.page?.round();
        if (current != null &&
            current != targetIdx &&
            current >= 0 &&
            current < order.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _landscapeController == ctrl && ctrl.hasClients) {
              ctrl.jumpToPage(targetIdx);
            }
          });
        }
      }
    } else if (seen != null) {
      final ctrl = _landscapeController;
      final page = ctrl != null && ctrl.hasClients
          ? ctrl.page?.round()
          : ctrl?.initialPage;
      final index = (page ?? 0).clamp(0, order.length - 1).toInt();
      _landscapeSeenId = order[index];
    } else {
      _landscapeSeenId = order.first;
    }
  }

  PageController _landscapePageController(List<String> order) {
    final seen = _landscapeSeenId;
    _landscapeController ??= PageController(
      initialPage: seen == null ? 0 : math.max(0, order.indexOf(seen)),
    );
    // Clamp controller if order shrank
    final itemCount = order.length;
    if (_landscapeController!.hasClients) {
      final page = _landscapeController!.page;
      if (page != null && page.round() >= itemCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _landscapeController != null &&
              _landscapeController!.hasClients) {
            _landscapeController!.jumpToPage(itemCount - 1);
          }
        });
      }
    }
    return _landscapeController!;
  }

  void _onLandscapePageChanged(int index, List<String> order) {
    if (index >= 0 && index < order.length) {
      // The bar names the server shown.
      setState(() => _landscapeSeenId = order[index]);
    }
  }
}
