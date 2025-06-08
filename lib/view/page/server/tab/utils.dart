// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Actions on _ServerPageState {
  void _onTapCard(Server srv) {
    if (srv.canViewDetails) {
      // _splitViewCtrl.replace(ServerDetailPage(
      //   key: ValueKey(srv.spi.id),
      //   args: SpiRequiredArgs(srv.spi),
      // ));
      ServerDetailPage.route.go(context, SpiRequiredArgs(srv.spi));
    } else {
      // _splitViewCtrl.replace(ServerEditPage(
      //   key: ValueKey(srv.spi.id),
      //   args: SpiRequiredArgs(srv.spi),
      // ));
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
  }

  void _onLongPressCard(Server srv) {
    if (srv.conn == ServerConn.finished) {
      final id = srv.spi.id;
      final cardStatus = _getCardNoti(id);
      cardStatus.value = cardStatus.value.copyWith(flip: !cardStatus.value.flip);
    } else {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
  }

  void _onTapAddServer() {
    //   final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    //   if (isMobile) {
    ServerEditPage.route.go(context);
    //   } else {
    //     _splitViewCtrl.replace(const ServerEditPage(
    //       key: ValueKey('addServer'),
    //     ));
    //   }
  }
}

extension _Operation on _ServerPageState {
  void _onTapSuspend(Server srv) {
    _askFor(
      func: () async {
        if (Stores.setting.showSuspendTip.fetch()) {
          await context.showRoundDialog(title: libL10n.attention, child: Text(l10n.suspendTip));
          Stores.setting.showSuspendTip.put(false);
        }
        srv.client?.execWithPwd(ShellFunc.suspend.exec(srv.spi.id), context: context, id: srv.id);
      },
      typ: l10n.suspend,
      name: srv.spi.name,
    );
  }

  void _onTapShutdown(Server srv) {
    _askFor(
      func: () => srv.client?.execWithPwd(ShellFunc.shutdown.exec(srv.spi.id), context: context, id: srv.id),
      typ: l10n.shutdown,
      name: srv.spi.name,
    );
  }

  void _onTapReboot(Server srv) {
    _askFor(
      func: () => srv.client?.execWithPwd(ShellFunc.reboot.exec(srv.spi.id), context: context, id: srv.id),
      typ: l10n.reboot,
      name: srv.spi.name,
    );
  }

  void _onTapEdit(Server srv) {
    if (srv.canViewDetails) {
      ServerDetailPage.route.go(context, SpiRequiredArgs(srv.spi));
    } else {
      ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi));
    }
  }
}

extension _Utils on _ServerPageState {
  List<String> _filterServers(List<String> order) {
    final tag = _tag.value;
    if (tag == TagSwitcher.kDefaultTag) return order;
    return order.where((e) {
      final tags = ServerProvider.pick(id: e)?.value.spi.tags;
      if (tags == null) return false;
      return tags.contains(tag);
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
    if (Stores.setting.moveServerFuncs.fetch()) {
      return _ServerPageState._kCardHeightMoveOutFuncs;
    }
    return _ServerPageState._kCardHeightNormal;
  }

  void _askFor({required void Function() func, required String typ, required String name}) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('$typ ${l10n.server}($name)')),
      actions: Btn.ok(
        onTap: () {
          context.pop();
          func();
        },
      ).toList,
    );
  }

  _CardNotifier _getCardNoti(String id) =>
      _cardsStatus.putIfAbsent(id, () => _CardNotifier(const _CardStatus()));

  void _updateOffset() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    final x = MediaQuery.sizeOf(context).height * 0.03;
    final r = math.Random().nextDouble();
    final n = math.Random().nextBool() ? 1 : -1;
    _offset = x * r * n;
  }

  void _updateTextScaler(double val) {
    _textFactorDouble = val;
    _textFactor = TextScaler.linear(_textFactorDouble);
  }

  void _startAvoidJitterTimer() {
    if (!Stores.setting.fullScreenJitter.fetch()) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _updateOffset();
        setState(() {});
      } else {
        _timer?.cancel();
      }
    });
  }
}

extension _ServerX on Server {
  String? _getTopRightStr(Spi spi) {
    if (status.err != null) {
      return l10n.viewErr;
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
          cmdTemp ?? (temperatureVal != null ? '${temperatureVal.toStringAsFixed(1)}°C' : null),
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
