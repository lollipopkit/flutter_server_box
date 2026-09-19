// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Actions on _ServerPageState {
  /// [context] is the tapped widget's, not the state's.
  ///
  /// `PaneScope` is installed by the layout this page builds, so it is a
  /// descendant of the state's own context — and an inherited lookup only
  /// travels upwards. Asking from the state would always answer "no pane".
  ///
  /// [inPlace] is for a layout that knows the answer [_opensInPlace] cannot
  /// give. That one asks the window's width, which is right for the list and
  /// wrong for the full-screen pager: it draws no grid and no detail, so a tap
  /// in a wide window selected the server and started the card's growth with
  /// nothing on screen to show either.
  void _onTapCard(BuildContext context, ServerState srv, {bool? inPlace}) {
    // Held on a pointer, a tap is the start of choosing several rather than
    // the opening of one — the convention every file manager has.
    if (_modifierHeld) {
      _toggleSelected(srv.spi.id);
      return;
    }
    if (srv.needsInteractiveAuth) {
      TryLimiter.reset(srv.spi.id);
      ref.read(serversProvider.notifier).refresh(spi: srv.spi);
      return;
    }
    // The one place that knows about the layout. With room for it, opening a
    // server means growing its card into the page; without, it means pushing
    // one — and the detail cannot tell the difference either way.
    //
    // Opened even when it has nothing to show yet. On one screen, jumping
    // straight to the edit form is the only useful thing a tap can do for a
    // server that has never connected. In place it is not: the detail says why
    // it is empty, and the list is still there, which is what lets someone
    // work through several servers that are all failing.
    if (inPlace ?? _opensInPlace(context)) {
      _openDetail(srv.spi.id);
      return;
    }

    if (srv.canViewDetails) {
      ServerDetailPage.route.go(context, SpiRequiredArgs(srv.spi));
    } else {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
  }

  /// Shows actions for one server without leaving the list.
  ///
  /// [ctx] is the pressed card's, and [at] where a pointer was — null for a
  /// long press, which has a finger over the spot.
  ///
  /// A machine that has never connected offers only what is true of it: the
  /// editor, because changing the configuration is the only thing that could
  /// help.
  void _onLongPressCard(
    BuildContext ctx,
    ServerState srv, {
    Offset? at,
    ServerListDensity density = ServerListDensity.cards,
  }) {
    if (srv.conn == ServerConn.disconnected && srv.status.err == null) {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
      return;
    }

    // Pointer input provides an anchor; narrow touch layouts use a sheet.
    final sheet = at == null && !_opensInPlace(ctx);
    final id = srv.spi.id;

    _keys.requestFocus();
    setState(() => _menuId = id);
    unawaited(
      showServerActions(
        context,
        ref,
        srv,
        // Anchor the menu to the pressed row when possible.
        at: at ?? (sheet ? null : _anchorUnder(ctx)),
        sheet: sheet,
        // Said inside the menu only where the menu is not beside the thing it
        // is about: a sheet is at the bottom of the window, and a 44pt tile
        // has no room for identifying information beyond the name. A card or
        // a row has said it already, right under the menu and highlighted.
        header: sheet || density == ServerListDensity.grid
            ? serverMenuHead(srv)
            : null,
        // Touch users enter multi-selection through the menu.
        onSelect: isMobile ? () => _toggleSelected(srv.spi.id) : null,
      ).whenComplete(() {
        // Do not clear a newer menu's highlight.
        if (!mounted || _menuId != id) return;
        setState(() => _menuId = null);
      }),
    );
  }

  /// The bottom left of whatever was pressed, in the window's coordinates.
  Offset? _anchorUnder(BuildContext ctx) {
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset(0, box.size.height));
  }

  /// The three ways a server gets onto this device, in one place.
  ///
  /// The two import paths used to live in two different settings groups — a
  /// scan under SSH preferences, a file under Backup — and which one a person
  /// needed depended on what the *sender* had picked, which they have no way
  /// of knowing before opening the app. Both are ways of acquiring a server,
  /// which is what this button is for, and it puts them opposite the share
  /// button on a server's own page.
  ///
  /// The cost is a tap: this used to open the editor directly. Adding a server
  /// is rare enough that finding the other two is worth more than saving it.
  Future<void> _onTapAddServer() async {
    final way = await context.showRoundDialog<_AddServerWay>(
      title: libL10n.add,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final way in _AddServerWay.values)
            if (way.available)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(way.icon),
                title: Text(way.label),
                onTap: () => context.popDialog(way),
              ),
        ],
      ),
      actions: Btn.cancel().toList,
    );
    if (way == null || !mounted) return;

    switch (way) {
      case _AddServerWay.manual:
        ServerEditPage.route.go(context);
      case _AddServerWay.qr:
        await ServerShareUi.receiveFromQr(context, ref);
      case _AddServerWay.file:
        await ServerShareUi.receiveFromFile(context, ref);
    }
  }

  /// Opens a server something else asked for — today the Agent's `open_server`.
  ///
  /// Deliberately not [_onTapCard]: a tap is a person deciding what to look
  /// at, and its answer to a server that has never connected is to offer the
  /// edit form instead. A request names a server, so this shows that server's
  /// page whatever state it is in, error and all. [split] is passed in rather
  /// than looked up — see the call site.
  void _openRequestedServer(String id, bool split) {
    if (!ref.read(serversProvider).servers.containsKey(id)) return;
    if (split) {
      // No card flight, unlike a tap: that animation carries the card the
      // finger was on into the pane, and is measured from where that card is.
      // Nothing was touched here, so there is nothing to fly — and handing it
      // this page's own context would launch the whole page instead.
      ref.read(serverSelectionProvider.notifier).select(id);
      return;
    }
    ServerDetailPage.route.go(
      context,
      SpiRequiredArgs(ref.read(serverProvider(id)).spi),
    );
  }
}

/// Opens whatever was requested while this layout is the one on screen.
///
/// A widget rather than a method on the page so that it can be given [split]
/// by the builder that decided it, and so that it is mounted and unmounted
/// with the layout it belongs to.
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
    // The request that brought this tab into existence was made before there
    // was anything here to hear it, so the first thing to do is look.
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

/// Whether a key that turns a tap into "add this one too" is down.
///
/// Read from the hardware rather than from a gesture's details, which carry no
/// modifiers: this is the only place it is asked, and a tap is synchronous
/// with the key being held.
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
  /// The list narrowed by both of the things that narrow it: the tag picked in
  /// the bar, and whatever is typed into it.
  List<String> _filterServers(List<String> order) {
    final tag = _tag.value;
    if (tag == TagSwitcher.kDefaultTag) return _filterByQuery(order);

    final servers = ref.read(serversProvider).servers;
    return _filterByQuery([
      for (final id in order)
        if (servers[id]?.tags?.contains(tag) == true) id,
    ]);
  }

  /// The list narrowed by the search alone.
  ///
  /// Its own step because the rail uses this one without the tag: it groups by
  /// tag rather than filtering to one, so a tag picked in the grid must not
  /// take rows out of it — a search must, since that is what was just typed.
  List<String> _filterByQuery(List<String> order) {
    final needle = _search.needle;
    if (needle.isEmpty) return order;

    final servers = ref.read(serversProvider).servers;
    return order.where((id) {
      final spi = servers[id];
      if (spi == null) return false;
      // Name and address, which is what a server is known by and what it is
      // reached at — the same two the editor asks for first.
      return spi.name.toLowerCase().contains(needle) ||
          spi.displayAddr.toLowerCase().contains(needle);
    }).toList();
  }

  /// Which reading [id]'s card draws in full, or null for whichever the
  /// machine reports first.
  ServerMetricKind? _promotedOf(String id) => ServerPromoted.of(id);

  void _promote(String id, ServerMetricKind kind) {
    if (ServerPromoted.put(id, kind)) setState(() {});
  }

  void _updateOffset() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    final x = MediaQuery.sizeOf(context).height * 0.03;
    final r = math.Random().nextDouble();
    final n = math.Random().nextBool() ? 1 : -1;
    _offsetNotifier.value = x * r * n;
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

/// The ways a server gets onto this device.
///
/// An enum rather than three buttons so the list, the icons and the labels are
/// one thing — and so a platform that cannot offer one of them (a desktop has
/// no camera to scan with) drops it in a single place.
enum _AddServerWay {
  manual,
  qr,
  file;

  bool get available => switch (this) {
    // `isMobile` matches where the scanner page can actually open one.
    _AddServerWay.qr => isMobile,
    _ => true,
  };

  IconData get icon => switch (this) {
    _AddServerWay.manual => Icons.edit,
    _AddServerWay.qr => Icons.qr_code_scanner,
    _AddServerWay.file => Icons.file_present,
  };

  String get label => switch (this) {
    _AddServerWay.manual => libL10n.manual,
    _AddServerWay.qr => l10n.shareScanQr,
    _AddServerWay.file => l10n.shareImportFile,
  };
}
