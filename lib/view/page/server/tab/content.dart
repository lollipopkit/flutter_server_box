part of 'tab.dart';

extension on _ServerPageState {
  Widget _buildServerCardTitle(Server s) {
    return Padding(
      padding: const EdgeInsets.only(left: 7, right: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(s.spi.name, style: UIs.text13Bold, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Icon(Icons.keyboard_arrow_right, size: 17, color: Colors.grey),
          const Spacer(),
          _buildTopRightText(s),
          _buildTopRightWidget(s),
        ],
      ),
    );
  }

  Widget _buildTopRightWidget(Server s) {
    final (child, onTap) = switch (s.conn) {
      ServerConn.connecting || ServerConn.loading || ServerConn.connected => (
        SizedBox.square(
          dimension: _ServerPageState._kCardHeightMin,
          child: SizedLoading(_ServerPageState._kCardHeightMin, strokeWidth: 3, padding: 3),
        ),
        null,
      ),
      ServerConn.failed => (
        const Icon(Icons.refresh, size: 21, color: Colors.grey),
        () {
          TryLimiter.reset(s.spi.id);
          ServerProvider.refresh(spi: s.spi);
        },
      ),
      ServerConn.disconnected => (
        const Icon(MingCute.link_3_line, size: 19, color: Colors.grey),
        () => ServerProvider.refresh(spi: s.spi),
      ),
      ServerConn.finished => (
        const Icon(MingCute.unlink_2_line, size: 17, color: Colors.grey),
        () => ServerProvider.closeServer(id: s.spi.id),
      ),
    };

    // Or the loading icon will be rescaled.
    final wrapped = child is SizedBox
        ? child
        : SizedBox(height: _ServerPageState._kCardHeightMin, width: 27, child: child);
    if (onTap == null) return wrapped.paddingOnly(left: 10);
    return InkWell(borderRadius: BorderRadius.circular(7), onTap: onTap, child: wrapped).paddingOnly(left: 5);
  }

  Widget _buildTopRightText(Server s) {
    final hasErr = s.status.err != null;
    final str = s._getTopRightStr(s.spi);
    if (str == null) return UIs.placeholder;
    return GestureDetector(
      onTap: () {
        if (!hasErr) return;
        _showFailReason(s.status);
      },
      child: Text(str, style: UIs.text13Grey),
    );
  }

  void _showFailReason(ServerStatus ss) {
    final md =
        '''
${ss.err?.solution ?? l10n.unknown}

```sh
${ss.err?.message ?? 'null'}
''';
    context.showRoundDialog(
      title: libL10n.error,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: [TextButton(onPressed: () => Pfs.copy(md), child: Text(libL10n.copy))],
    );
  }

  Widget _buildDisk(ServerStatus ss, String id) {
    final cardNoti = _getCardNoti(id);
    return cardNoti.listenVal((v) {
      final isSpeed = v.diskIO ?? !Stores.setting.serverTabPreferDiskAmount.fetch();

      final (r, w) = ss.diskIO.cachedAllSpeed;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 377),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildIOData(
          isSpeed ? '${l10n.read}:\n$r' : 'Total:\n${ss.diskUsage?.size.kb2Str}',
          isSpeed ? '${l10n.write}:\n$w' : 'Used:\n${ss.diskUsage?.used.kb2Str}',
          onTap: () {
            cardNoti.value = v.copyWith(diskIO: !isSpeed);
          },
          key: ValueKey(isSpeed),
        ),
      );
    });
  }

  Widget _buildNet(ServerStatus ss, String id) {
    final cardNoti = _getCardNoti(id);
    final type = cardNoti.value.net ?? Stores.setting.netViewType.fetch();
    final device = ServerProvider.pick(id: id)?.value.spi.custom?.netDev;
    final (a, b) = type.build(ss, dev: device);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 377),
      transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),
      child: _buildIOData(
        a,
        b,
        onTap: () => cardNoti.value = cardNoti.value.copyWith(net: type.next),
        key: ValueKey(type),
      ),
    );
  }

  Widget _buildIOData(String up, String down, {void Function()? onTap, Key? key, int maxLines = 2}) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          up,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
          textScaler: _textFactor,
          maxLines: maxLines,
        ),
        const SizedBox(height: 3),
        Text(
          down,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
          textScaler: _textFactor,
          maxLines: maxLines,
        ),
      ],
    );
    if (onTap == null) return child;
    return IconButton(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      onPressed: onTap,
      icon: child,
    );
  }
}
