// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

extension _Bulk on _ServerPageState {
  /// Puts [id] in or out of the set, and ends selecting when it empties.
  void _toggleSelected(String id) {
    _keys.requestFocus();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _endSelecting() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  /// The bar while a set is being built up — see [ServerSelectionBar].
  PreferredSizeWidget _buildSelectionBar(List<String> filtered) {
    return ServerSelectionBar(
      count: _selected.length,
      total: filtered.length,
      onClose: _endSelecting,
      onConnect: () => _bulk((spi) {
        ref.read(serversProvider.notifier).refresh(spi: spi);
      }),
      onDisconnect: () => _bulk((spi) {
        ref.read(serversProvider.notifier).closeServer(id: spi.id);
      }),
      onTag: _bulkTag,
      onMove: _bulkMove,
      onDelete: _bulkDelete,
    );
  }

  /// Runs [each] over the chosen machines and then stops choosing.
  ///
  /// Stopping is the point: an action that left the set selected would leave
  /// the page in a state whose only purpose was to reach the action.
  void _bulk(void Function(Spi spi) each) {
    final servers = ref.read(serversProvider).servers;
    for (final id in _selected.toList()) {
      final spi = servers[id];
      if (spi != null) each(spi);
    }
    _endSelecting();
  }

  /// Adds one tag to every chosen machine.
  ///
  /// Adds rather than replaces: a tag is one of the things a server is, and a
  /// bulk edit that cleared the others would be a way to lose them quietly.
  Future<void> _bulkTag() async {
    final tag = await context.showRoundDialog<String>(
      title: libL10n.tag,
      child: Input(
        autoFocus: true,
        type: TextInputType.text,
        hint: libL10n.tag,
        onSubmitted: (value) => context.popDialog(value.trim()),
      ),
      actions: Btn.cancel().toList,
    );
    if (tag == null || tag.isEmpty || !mounted) return;

    final notifier = ref.read(serversProvider.notifier);
    final servers = ref.read(serversProvider).servers;
    for (final id in _selected.toList()) {
      final spi = servers[id];
      if (spi == null) continue;
      final tags = {...?spi.tags, tag}.toList();
      try {
        await notifier.updateServer(spi, spi.copyWith(tags: tags));
      } catch (e, st) {
        if (mounted) context.showErrDialog(e, st);
        return;
      }
    }
    _endSelecting();
  }

  /// Moves the chosen machines to one end of the arrangement.
  ///
  /// Both ends and nothing between them. A position to insert at is a number
  /// nobody has — the list being looked at is the whole of what is known about
  /// where things are — and "up one" applied to five machines at once is five
  /// separate answers about what it did.
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
    final moved = moveInOrder(order, _selected, toTop: toTop);
    if (moved.equals(order)) {
      _endSelecting();
      return;
    }

    await ref.read(serversProvider.notifier).updateServerOrder(moved);
    if (!mounted) return;

    // The arrangement is only on screen under `manual`: under any of the
    // comparisons this would be a move with nothing to see, which reads as
    // the action having failed rather than as the sort having hidden it.
    const manual = ServerSortOrder(ServerSortField.manual, ascending: true);
    if (!manual.isCurrentFor(_tag.value)) {
      manual.save(_tag.value);
      _sortVersion.notify();
    }
    _endSelecting();
  }

  /// The one that cannot be undone, so it says how many.
  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} ${libL10n.server}($count)'),
      ),
      actions: Btn.ok(red: true).toList,
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(serversProvider.notifier);
    for (final id in _selected.toList()) {
      try {
        await notifier.delServer(id);
      } catch (e, st) {
        if (mounted) context.showErrDialog(e, st);
        return;
      }
    }
    _endSelecting();
  }
}
