// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Actions on _ServerPageState {
  /// [context] is the tapped widget's, not the state's.
  ///
  /// `PaneScope` is installed by the layout this page builds, so it is a
  /// descendant of the state's own context — and an inherited lookup only
  /// travels upwards. Asking from the state would always answer "no pane".
  void _onTapCard(BuildContext context, ServerState srv) {
    if (srv.needsInteractiveAuth) {
      TryLimiter.reset(srv.spi.id);
      ref.read(serversProvider.notifier).refresh(spi: srv.spi);
      return;
    }
    // The one place that knows about the layout. With a pane on screen,
    // opening a server means selecting it; without one it means pushing, and
    // the page that opens cannot tell the difference either way.
    //
    // Selected even when it has nothing to show yet. On one screen, jumping
    // straight to the edit form is the only useful thing a tap can do for a
    // server that has never connected. Beside a list it is not: the detail
    // page says why it is empty, and staying on the list is what lets someone
    // work through several servers that are all failing.
    if (PaneScope.isSplit(context)) {
      // Only the first selection reshapes the list, from a grid across the
      // window to a column beside the pane. That is the move worth animating;
      // picking another server afterwards leaves every row where it was.
      final reshapes = ref.read(serverSelectionProvider) == null;
      ref.read(serverSelectionProvider.notifier).select(srv.spi.id);
      if (reshapes) _flyCardIntoPane(context, srv);
      return;
    }

    if (srv.canViewDetails) {
      ServerDetailPage.route.go(context, SpiRequiredArgs(srv.spi));
    } else {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
  }

  void _onLongPressCard(ServerState srv) {
    if (srv.conn == ServerConn.finished) {
      final id = srv.spi.id;
      final cardStatus = _getCardNoti(id);
      cardStatus.value = cardStatus.value.copyWith(
        flip: !cardStatus.value.flip,
      );
    } else {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
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

  double? _calcCardHeight(ServerConn cs, bool flip) {
    if (_textFactorDouble != 1.0) return null;
    if (cs != ServerConn.finished) {
      return _ServerPageState._kCardHeightMin;
    }
    if (flip) {
      return _ServerPageState._kCardHeightFlip;
    }
    return _ServerPageState._kCardHeightNormal;
  }


  _CardNotifier _getCardNoti(String id) =>
      _cardsStatus.putIfAbsent(id, () => _CardNotifier(const _CardStatus()));

  void _updateOffset() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    final x = MediaQuery.sizeOf(context).height * 0.03;
    final r = math.Random().nextDouble();
    final n = math.Random().nextBool() ? 1 : -1;
    _offsetNotifier.value = x * r * n;
  }

  void _updateTextScaler(double val) {
    _textFactorDouble = val;
    _textFactor = TextScaler.linear(_textFactorDouble);
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

extension _ServerX on ServerState {
  bool get needsInteractiveAuth {
    final error = status.err;
    return error is SSHErr && error.type == SSHErrType.interactiveAuth;
  }

  String? _getTopRightStr(Spi spi) {
    if (status.err != null) {
      return libL10n.viewErr;
    }
    switch (conn) {
      case ServerConn.disconnected:
        return null;
      case ServerConn.finished:
        // Highest priority of temperature display
        final cmdTemp = () {
          final val = status.customCmds['server_card_top_right'];
          if (val == null) return null;
          // This returned value is used on server card top right, so it should
          // be a single line string.
          return val.split('\n').lastOrNull;
        }();
        final temperatureVal = () {
          // Second priority
          final preferTempDev = spi.custom?.preferTempDev;
          if (preferTempDev != null) {
            final preferTemp = status.sensors
                .firstWhereOrNull((e) => e.device == preferTempDev)
                ?.summary
                ?.split(' ')
                .firstOrNull;
            if (preferTemp != null) {
              return double.tryParse(preferTemp.replaceFirst('°C', ''));
            }
          }
          // Last priority
          final temp = status.temps.first;
          if (temp != null) {
            return temp;
          }
          return null;
        }();
        final upTime = status.more[StatusCmdType.uptime];
        final items = [
          cmdTemp ??
              (temperatureVal != null
                  ? '${temperatureVal.toStringAsFixed(1)}°C'
                  : null),
          upTime,
        ];
        final str = items.where((e) => e != null && e.isNotEmpty).join(' | ');
        if (str.isEmpty) return libL10n.empty;
        return str;
      case ServerConn.loading:
        return null;
      case ServerConn.connected:
        return null;
      case ServerConn.connecting:
        return null;
      case ServerConn.failed:
        return libL10n.fail;
    }
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
