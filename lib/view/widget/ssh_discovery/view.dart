import 'dart:io';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';

part 'actions.dart';

enum _Phase { idle, scanning, done }

final class _SourceState {
  _Phase phase = _Phase.idle;
  String? scope;
  List<DiscoveredSshHost> hosts = const [];
}

/// The hosts every [SshDiscovery] in [sources] finds, one tab per source.
///
/// [SshDiscoveryView.batch] checks hosts off and adds them all as servers;
/// [SshDiscoveryView.pick] hands one back to fill in a form.
final class SshDiscoveryView extends ConsumerStatefulWidget {
  const SshDiscoveryView.batch({
    super.key,
    this.header = const [],
    this.columnWidth,
    this.thisDevice = true,
    this.sources,
  }) : onPick = null;

  const SshDiscoveryView.pick({super.key, required this.onPick, this.sources})
    : header = const [],
      columnWidth = null,
      thisDevice = false;

  /// Scrolls with the list, above it.
  final List<Widget> header;

  /// The content column the list and the add bar are centred in; null fills
  /// the width.
  final double? columnWidth;

  /// Offers the device running the app, above the sources.
  final bool thisDevice;

  final ValueChanged<DiscoveredSshHost>? onPick;

  /// [SshDiscovery.available] when null.
  final List<SshDiscovery>? sources;

  bool get _picking => onPick != null;

  @override
  ConsumerState<SshDiscoveryView> createState() => _SshDiscoveryViewState();
}

final class _SshDiscoveryViewState extends ConsumerState<SshDiscoveryView> {
  late final List<SshDiscovery> _sources =
      widget.sources ?? SshDiscovery.available;
  late final _states = {for (final s in _sources) s.id: _SourceState()};
  late String? _current = _sources.firstOrNull?.id;

  /// Keyed by [DiscoveredSshHost.address].
  final _selected = <String, DiscoveredSshHost>{};
  final _added = <String>{};
  bool _selfSelected = false;
  bool _selfAdded = false;
  bool _adding = false;

  static const _minPad = 17.0;
  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 14);

  bool get _offersThisDevice =>
      widget.thisDevice && !widget._picking && LocalServer.isSupported;

  int get _selectedCount => _selected.length + (_selfSelected ? 1 : 0);

  @override
  void initState() {
    super.initState();
    for (final source in _sources) {
      source.scope().then((scope) {
        if (mounted) setState(() => _states[source.id]!.scope = scope);
      }, onError: (Object e, StackTrace s) {
        Loggers.app.warning('Discovery scope of ${source.id}', e, s);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final width = widget.columnWidth;
        final pad = width == null
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: math.max((cons.maxWidth - width) / 2, _minPad),
              );
        final list = ListView(
          padding: pad.copyWith(bottom: width == null ? 0 : 26),
          children: [...widget.header, ..._buildContent(context)],
        );
        if (widget._picking) return list;
        return Column(
          children: [
            Expanded(child: list),
            if (_selectedCount > 0) _buildAddBar(context, pad),
          ],
        );
      },
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final source = _sources.firstWhereOrNull((s) => s.id == _current);
    return [
      if (_offersThisDevice) ...[
        _card(context, [_buildThisDevice(context)]),
        UIs.height13,
      ],
      if (_sources.length > 1) ...[_buildTabs(), UIs.height13],
      if (source != null) ..._buildSource(context, source),
    ];
  }

  Widget _buildTabs() {
    return SegmentedTabs<String>(
      expand: true,
      selected: _current!,
      onSelected: (id) => setState(() => _current = id),
      segments: [
        for (final s in _sources)
          SegmentedTab(
            value: s.id,
            icon: s.icon,
            label: switch (_states[s.id]!) {
              final st when st.phase == _Phase.done =>
                '${s.label} ${st.hosts.length}',
              _ => s.label,
            },
          ),
      ],
    );
  }

  Widget _buildThisDevice(BuildContext context) {
    final exists = ref.watch(serversProvider).servers.values.any((e) => e.local);
    return ListTile(
      leading: const Icon(Icons.computer),
      title: Text(l10n.thisDevice),
      subtitle: Text(
        '${Platform.localHostname} · ${l10n.localServerNoSsh}',
        style: UIs.textGrey,
      ),
      trailing: _trailing(
        context,
        added: _selfAdded,
        exists: exists,
        selected: _selfSelected,
        onChanged: () => setState(() => _selfSelected = !_selfSelected),
      ),
      onTap: _selfAdded || exists
          ? null
          : () => setState(() => _selfSelected = !_selfSelected),
    );
  }

  List<Widget> _buildSource(BuildContext context, SshDiscovery source) {
    final st = _states[source.id]!;
    if (st.phase != _Phase.done) {
      final scanning = st.phase == _Phase.scanning;
      return [
        _card(context, [
          ListTile(
            leading: Icon(source.icon),
            title: Text(source.label),
            subtitle: st.scope == null
                ? null
                : Text(st.scope!, style: UIs.textGrey),
            trailing: scanning
                ? Text(l10n.discoveryScanning, style: UIs.text12Grey)
                : FilledButton.tonal(
                    onPressed: () => _scan(source),
                    child: Text(l10n.discoveryScan),
                  ),
          ),
        ], footer: scanning ? const LinearProgressIndicator(minHeight: 3) : null),
      ];
    }

    final servers = ref.watch(serversProvider).servers.values;
    bool exists(DiscoveredSshHost h) => servers.any((e) => _isHost(e, h));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(_minPad, 0, 4, 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                [?st.scope, l10n.discoveryFound(st.hosts.length)].join(' · '),
                style: UIs.text12Grey,
              ),
            ),
            TextButton(
              onPressed: () => _scan(source),
              child: Text(l10n.discoveryScanAgain),
            ),
          ],
        ),
      ),
      if (st.hosts.isNotEmpty)
        _card(context, [
          for (final h in st.hosts) _buildHost(context, h, exists(h)),
        ]),
    ];
  }

  Widget _buildHost(BuildContext context, DiscoveredSshHost h, bool exists) {
    final name = h.name;
    final subtitle = [if (name != null) h.address, ?h.detail].join(' · ');
    final added = _added.contains(h.address);
    void toggle() => setState(() {
      if (_selected.remove(h.address) == null) _selected[h.address] = h;
    });
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: Text(name ?? h.address, style: name == null ? _mono : null),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: UIs.textGrey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: widget._picking
          ? const Icon(Icons.chevron_right)
          : _trailing(
              context,
              added: added,
              exists: exists,
              selected: _selected.containsKey(h.address),
              onChanged: toggle,
            ),
      onTap: widget._picking
          ? () => widget.onPick!(h)
          : added || exists
          ? null
          : toggle,
    );
  }

  Widget _trailing(
    BuildContext context, {
    required bool added,
    required bool exists,
    required bool selected,
    required VoidCallback onChanged,
  }) {
    if (added) {
      return Text(
        l10n.discoveryAdded,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (exists) return Text(l10n.discoveryExists, style: UIs.text12Grey);
    return Checkbox(
      value: selected,
      onChanged: _adding ? null : (_) => onChanged(),
    );
  }

  Widget _buildAddBar(BuildContext context, EdgeInsets pad) {
    final n = _selectedCount;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Hairline.color(context))),
      ),
      child: Padding(
        padding: pad.add(const EdgeInsets.fromLTRB(4, 9, 4, 13)),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(l10n.discoverySelected(n), style: UIs.textGrey),
              ),
            ),
            FilledButton(
              onPressed: _adding ? null : _addSelected,
              child: Text(l10n.discoveryAddN(n)),
            ),
          ],
        ),
      ),
    );
  }

  /// Rows on one surface, a hairline between each two.
  static Widget _card(
    BuildContext context,
    List<Widget> rows, {
    Widget? footer,
  }) {
    final line = Divider(
      height: Hairline.thickness,
      thickness: Hairline.thickness,
      indent: _minPad,
      endIndent: _minPad,
      color: Hairline.color(context),
    );
    return CardX(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, row) in rows.indexed) ...[if (i > 0) line, row],
          ?footer,
        ],
      ),
    );
  }
}

/// Whether [spi] is already a server for [h].
bool _isHost(Spi spi, DiscoveredSshHost h) =>
    !spi.local && spi.ssh?.ip == h.host && spi.ssh?.port == h.port;

/// Asks for one discovered host, in a dialog. Null when dismissed.
Future<DiscoveredSshHost?> pickDiscoveredHost(BuildContext context) {
  return context.showRoundDialog<DiscoveredSshHost>(
    title: l10n.discoverSshServers,
    child: SizedBox(
      width: 400,
      height: 380,
      child: Builder(
        builder: (ctx) =>
            SshDiscoveryView.pick(onPick: (h) => ctx.popDialog(h)),
      ),
    ),
    actions: [Btn.cancel()],
  );
}
