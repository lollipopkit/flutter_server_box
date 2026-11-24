// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Bulk on _ServerPageState {
  /// Puts [cardKey] in or out of the set, and ends selecting when it empties.
  void _toggleSelected(String cardKey) {
    _keys.requestFocus();
    setState(() {
      if (!_selected.remove(cardKey)) _selected.add(cardKey);
    });
  }

  void _endSelecting() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  List<String> get _selectedServerIds => [
    for (final key in _selected)
      if (key.startsWith('srv:')) key.substring(4),
  ];

  List<String> get _selectedBmcIds => [
    for (final key in _selected)
      if (key.startsWith('bmc:')) key.substring(4),
  ];

  List<int> get _selectedUptimerIds => [
    for (final key in _selected)
      if (key.startsWith('up:')) ?int.tryParse(key.substring(3)),
  ];

  /// The bar while a set is being built up — actions are intersected by the
  /// selected card types.
  PreferredSizeWidget _buildSelectionBar(List<StatusCardItem> filtered) {
    final allServers =
        _selected.isNotEmpty && _selected.every((k) => k.startsWith('srv:'));
    return ServerSelectionBar(
      count: _selected.length,
      total: filtered.length,
      onClose: _endSelecting,
      onConnect: allServers
          ? () => _bulkServers((spi) {
              ref.read(serverConnectionsProvider).refresh(spi: spi);
            })
          : null,
      onDisconnect: allServers
          ? () => _bulkServers((spi) {
              ref.read(serverConnectionsProvider).closeServer(id: spi.id);
            })
          : null,
      onTag: _bulkTag,
      onMove: allServers ? _bulkMove : null,
      onDelete: _bulkDelete,
    );
  }

  void _bulkServers(void Function(Spi spi) each) {
    final servers = ref.read(serversProvider).servers;
    for (final id in _selectedServerIds) {
      final spi = servers[id];
      if (spi != null) each(spi);
    }
    _endSelecting();
  }

  Future<void> _bulkTag() async {
    final tag = await context.showSheet<String>(
      title: libL10n.tag,
      child: Input(
        autoFocus: true,
        type: TextInputType.text,
        hint: libL10n.tag,
        onSubmitted: (value) => context.popSheet(value.trim()),
      ),
      actions: Btn.cancel().toList,
    );
    if (tag == null || tag.isEmpty || !mounted) return;

    final serverNotifier = ref.read(serversProvider.notifier);
    final servers = ref.read(serversProvider).servers;
    for (final id in _selectedServerIds) {
      final spi = servers[id];
      if (spi == null) continue;
      final tags = {...?spi.tags, tag}.toList();
      try {
        await serverNotifier.updateServer(spi, spi.copyWith(tags: tags));
      } catch (e, st) {
        if (mounted) context.showErrSheet(e, st);
        return;
      }
      if (!mounted) return;
    }

    final bmcNotifier = ref.read(bmcTargetsProvider.notifier);
    final bmcs = ref.read(bmcTargetsProvider).targets;
    for (final id in _selectedBmcIds) {
      final target = bmcs[id];
      if (target == null) continue;
      final tags = {...?target.tags, tag}.toList();
      bmcNotifier.setTags(id, tags);
    }

    final uptimerIds = _selectedUptimerIds;
    if (uptimerIds.isNotEmpty) {
      try {
        await ref.read(uptimerProvider.notifier).assignGroup(uptimerIds, tag);
      } catch (e, st) {
        if (mounted) context.showErrSheet(e, st);
        return;
      }
      if (!mounted) return;
    }
    _endSelecting();
  }

  Future<void> _bulkMove() async {
    final toTop = await showRowsSheet<bool>(
      context,
      rows: (ctx) => [
        SheetChoiceTile(
          icon: Icons.vertical_align_top,
          title: l10n.moveToTop,
          selected: false,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
        SheetChoiceTile(
          icon: Icons.vertical_align_bottom,
          title: l10n.moveToBottom,
          selected: false,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
      ],
    );
    if (toTop == null || !mounted) return;

    final order = ref.read(serversProvider).serverOrder;
    final moved = moveInOrder(order, _selectedServerIds.toSet(), toTop: toTop);
    if (moved.equals(order)) {
      _endSelecting();
      return;
    }

    await ref.read(serversProvider.notifier).updateServerOrder(moved);
    if (!mounted) return;

    const manual = ServerSortOrder(ServerSortField.manual, ascending: true);
    if (!manual.isCurrentFor(_tag.value)) {
      manual.save(_tag.value);
      unawaited(_sortVersion.notify());
    }
    _endSelecting();
  }

  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await context.showSheet<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} ($count)'),
      ),
      actions: Btn.ok(red: true).toList,
    );
    if (confirmed != true || !mounted) return;

    final serverNotifier = ref.read(serversProvider.notifier);
    for (final id in _selectedServerIds) {
      try {
        await serverNotifier.delServer(id);
      } catch (e, st) {
        if (mounted) context.showErrSheet(e, st);
        return;
      }
      if (!mounted) return;
    }
    final bmcNotifier = ref.read(bmcTargetsProvider.notifier);
    for (final id in _selectedBmcIds) {
      bmcNotifier.delete(id);
    }
    final uptimerNotifier = ref.read(uptimerProvider.notifier);
    var deletedUptimers = 0;
    for (final id in _selectedUptimerIds) {
      try {
        await uptimerNotifier.deleteMonitor(id, refreshAfter: false);
        deletedUptimers++;
        if (mounted) {
          setState(() => _selected.remove(UptimerCardItem.keyOf(id)));
        }
      } catch (e, st) {
        if (deletedUptimers > 0) {
          unawaited(uptimerNotifier.refresh(force: true));
        }
        if (mounted) context.showErrSheet(e, st);
        return;
      }
      if (!mounted) return;
    }
    if (deletedUptimers > 0) {
      unawaited(uptimerNotifier.refresh(force: true));
    }
    _endSelecting();
  }
}
