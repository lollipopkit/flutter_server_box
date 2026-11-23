// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Actions on _ServerPageState {
  void _onTapCard(BuildContext context, ServerState srv, {bool? inPlace}) {
    if (_modifierHeld) {
      _toggleSelected(ServerCardItem.keyOf(srv.spi.id));
      return;
    }
    if (srv.needsInteractiveAuth) {
      TryLimiter.reset(srv.spi.id);
      ref.read(serversProvider.notifier).refresh(spi: srv.spi);
      return;
    }
    if (inPlace ?? _opensInPlace(context)) {
      _openDetail(ServerCardItem(srv.spi));
      return;
    }

    if (srv.canViewDetails) {
      ServerDetailPage.route.go(context, SpiRequiredArgs(srv.spi));
    } else {
      ServerEditPage.route.go(context, args: ServerEditArgs(srv.spi));
    }
  }

  void _onTapBmcCard(BuildContext context, BmcTarget target) {
    if (_modifierHeld) {
      _toggleSelected(BmcCardItem.keyOf(target.id));
      return;
    }
    if (_opensInPlace(context)) {
      _openDetail(BmcCardItem(target));
      return;
    }
    BmcDetailPage.route.go(context, BmcTargetRequiredArgs(target));
  }

  void _onLongPressCard(
    BuildContext ctx,
    ServerState srv, {
    Offset? at,
    ServerListDensity density = ServerListDensity.cards,
  }) {
    if (srv.conn == ServerConn.disconnected && srv.status.err == null) {
      ServerEditPage.route.go(context, args: ServerEditArgs(srv.spi));
      return;
    }

    final sheet = at == null && !_opensInPlace(ctx);
    final key = ServerCardItem.keyOf(srv.spi.id);

    _keys.requestFocus();
    setState(() => _menuId = key);
    unawaited(
      showServerActions(
        context,
        ref,
        srv,
        at: at ?? (sheet ? null : contextMenuAnchorBelow(ctx)),
        header: sheet || density == ServerListDensity.grid
            ? serverMenuHead(srv)
            : null,
        onSelect: isMobile ? () => _toggleSelected(key) : null,
      ).whenComplete(() {
        if (!mounted || _menuId != key) return;
        setState(() => _menuId = null);
      }),
    );
  }

  void _onLongPressBmcCard(
    BuildContext ctx,
    BmcTarget target, {
    Offset? at,
  }) {
    final sheet = at == null && !_opensInPlace(ctx);
    final key = BmcCardItem.keyOf(target.id);

    _keys.requestFocus();
    setState(() => _menuId = key);
    final actions = <ContextMenuAction>[
      ContextMenuAction(
        text: libL10n.refresh,
        icon: Icons.refresh,
        onTap: () => unawaited(
          ref.read(bmcSummaryProvider(target.id).notifier).refresh(force: true),
        ),
      ),
      ContextMenuAction(
        text: libL10n.edit,
        icon: Icons.edit_outlined,
        onTap: () => unawaited(
          BmcTargetEditPage.route.go(
            context,
            args: BmcTargetEditArgs(target: target),
          ),
        ),
      ),
      ContextMenuAction(
        text: libL10n.logs,
        icon: Icons.receipt_long,
        onTap: () => unawaited(
          BmcLogsPage.route.go(context, BmcTargetRequiredArgs(target)),
        ),
      ),
      ContextMenuAction(
        text: l10n.bmcDrives,
        icon: Icons.storage,
        onTap: () => unawaited(
          BmcDrivesPage.route.go(context, BmcTargetRequiredArgs(target)),
        ),
      ),
      if (isMobile)
        ContextMenuAction(
          text: libL10n.select,
          icon: Icons.check_box_outlined,
          onTap: () => _toggleSelected(key),
        ),
      ContextMenuAction(
        text: libL10n.delete,
        icon: Icons.delete_outline,
        destructive: true,
        onTap: () => unawaited(_deleteBmcTarget(target)),
      ),
    ];

    unawaited(
      showContextMenu(
        ctx,
        actions,
        at: at ?? (sheet ? null : contextMenuAnchorBelow(ctx)),
      ).whenComplete(() {
        if (!mounted || _menuId != key) return;
        setState(() => _menuId = null);
      }),
    );
  }

  Future<void> _deleteBmcTarget(BmcTarget target) async {
    final ok = await context.showSheet<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} ${target.name}')),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    if (ref.read(bmcSelectionProvider) == target.id) {
      _closeDetail();
    }
    ref.read(bmcTargetsProvider.notifier).delete(target.id);
  }

  void _onTapAddServer(BuildContext anchor) => showContextMenu(
    anchor,
    _addServerMenu(),
    at: contextMenuAnchorBelow(anchor),
  );

  List<ContextMenuAction> _addServerMenu() => addStatusItemMenu(context, ref);

  void _openRequestedServer(String id, bool split) {
    final spi = ref.read(serversProvider).servers[id];
    if (spi == null) return;
    if (split) {
      _openDetail(ServerCardItem(spi));
      return;
    }
    ServerDetailPage.route.go(
      context,
      SpiRequiredArgs(ref.read(serverProvider(id)).spi),
    );
  }
}

class _ServerOpenRequest extends ConsumerStatefulWidget {
  const _ServerOpenRequest({
    required this.split,
    required this.onOpen,
    required this.child,
  });

  final bool split;
  final void Function(String serverId, bool split) onOpen;
  final Widget child;

  @override
  ConsumerState<_ServerOpenRequest> createState() => _ServerOpenRequestState();
}

class _ServerOpenRequestState extends ConsumerState<_ServerOpenRequest> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  void _drain() {
    if (!mounted) return;
    final id = ref.read(serverDetailRequestProvider);
    if (id == null) return;
    ref.read(serverDetailRequestProvider.notifier).done();
    widget.onOpen(id, widget.split);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(serverDetailRequestProvider, (_, _) => _drain());
    return widget.child;
  }
}

bool get _modifierHeld {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight) ||
      keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);
}

extension _Utils on _ServerPageState {
  List<StatusCardItem> _filterItems(List<StatusCardItem> items) {
    final tag = _tag.value;
    if (tag == TagSwitcher.kDefaultTag) return _filterItemsByQuery(items);

    return _filterItemsByQuery([
      for (final item in items)
        if (item.tags.contains(tag)) item,
    ]);
  }

  List<StatusCardItem> _filterItemsByQuery(List<StatusCardItem> items) {
    final needle = _search.needle;
    if (needle.isEmpty) return items;

    return [
      for (final item in items)
        if (item.name.toLowerCase().contains(needle) ||
            item.displayAddr.toLowerCase().contains(needle))
          item,
    ];
  }

  ServerMetricKind? _promotedOf(String id) => ServerPromoted.of(id);

  void _promote(String id, ServerMetricKind kind) {
    if (ServerPromoted.put(id, kind)) setState(() {});
  }

  void _toggleExpanded(String id) {
    ServerCardExpanded.toggle(id);
    setState(() {});
  }

  void _updateOffset() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    final r = math.Random();
    double next() => (r.nextDouble() * 2 - 1) * _kBurnInShift;
    _offsetNotifier.value = Offset(next(), next());
  }

  void _startAvoidJitterTimer() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _updateOffset();
      } else {
        _timer?.cancel();
      }
    });
  }
}
