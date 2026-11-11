import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/service/ssh_discovery_sources.dart';
import 'package:server_box/core/ssh/host_key_probe.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/view/widget/column_inset.dart';

part 'actions.dart';
part 'same_machine.dart';

enum _Phase { idle, running, done, failed }

final class _SourceState {
  _Phase phase = _Phase.idle;
  String? scope;
  List<DiscoveredSshHost> hosts = const [];
  SshDiscoveryException? error;

  /// The file picked after [SshDiscoveryException.needsFile], used again.
  String? file;
  final token = TextEditingController();
  final filter = TextEditingController();
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
    @visibleForTesting this.probe,
  }) : onPick = null;

  const SshDiscoveryView.pick({super.key, required this.onPick, this.sources})
    : probe = null,
      header = const [],
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

  /// [probeHostKey] when null.
  final Future<HostKeyId?> Function(SshCredential ssh, {String? prefer})?
  probe;

  bool get _picking => onPick != null;

  @override
  ConsumerState<SshDiscoveryView> createState() => _SshDiscoveryViewState();
}

final class _SshDiscoveryViewState extends ConsumerState<SshDiscoveryView> {
  List<SshDiscovery> _sources = const [];
  final _states = <String, _SourceState>{};
  String? _current;

  /// Keyed by [_keyOf].
  final _selected = <String, DiscoveredSshHost>{};
  final _added = <String>{};

  /// Checked hosts whose host key turned out to be a server's already.
  final _known = <String>{};
  bool _selfSelected = false;
  bool _selfAdded = false;
  bool _adding = false;

  static const _minPad = 17.0;
  static const _filterFrom = 7;
  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 14);

  bool get _offersThisDevice =>
      widget.thisDevice && !widget._picking && LocalServer.isSupported;

  int get _selectedCount => _selected.length + (_selfSelected ? 1 : 0);

  static String _keyOf(SshDiscovery source, DiscoveredSshHost h) =>
      '${source.id}/${h.key}';

  @override
  void initState() {
    super.initState();
    final given = widget.sources;
    if (given != null) {
      _setSources(given);
    } else {
      availableSshDiscoveries().then((sources) {
        if (mounted) setState(() => _setSources(sources));
      });
    }
  }

  @override
  void dispose() {
    for (final st in _states.values) {
      st.token.dispose();
      st.filter.dispose();
    }
    super.dispose();
  }

  void _setSources(List<SshDiscovery> sources) {
    _sources = sources;
    for (final s in sources) {
      final st = _states[s.id] = _SourceState();
      s.scope().then((scope) {
        if (mounted && st.phase != _Phase.done) {
          setState(() => st.scope = scope);
        }
      }, onError: (Object e, StackTrace t) {
        Loggers.app.warning('Discovery scope of ${s.id}', e, t);
      });
    }
    final first = sources.firstOrNull;
    if (first != null) _show(first);
  }

  /// Makes [source] the current tab, and starts it when it runs on its own.
  void _show(SshDiscovery source) {
    _current = source.id;
    if (source.auto && _states[source.id]!.phase == _Phase.idle) {
      // After the frame that shows it: this runs from `initState` and from
      // inside a `setState`.
      Future.microtask(() => _run(source));
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
                horizontal: columnInset(cons.maxWidth, column: width),
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
      onSelected: (id) =>
          setState(() => _show(_sources.firstWhere((s) => s.id == id))),
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
    void toggle() => setState(() => _selfSelected = !_selfSelected);
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
        onChanged: toggle,
      ),
      onTap: _selfAdded || exists ? null : toggle,
    );
  }

  List<Widget> _buildSource(BuildContext context, SshDiscovery source) {
    final st = _states[source.id]!;
    return switch (st.phase) {
      _Phase.done => _buildResults(context, source, st),
      _Phase.failed => [_buildError(context, source, st)],
      _ when source.credential != null => _buildCredential(context, source, st),
      _ => [
        _card(
          context,
          [
            ListTile(
              leading: Icon(source.icon),
              title: Text(source.label),
              subtitle: st.scope == null
                  ? null
                  : Text(st.scope!, style: UIs.textGrey),
              trailing: st.phase == _Phase.running
                  ? Text(l10n.discoveryScanning, style: UIs.text12Grey)
                  : FilledButton.tonal(
                      onPressed: () => _run(source),
                      child: Text(l10n.discoveryScan),
                    ),
            ),
          ],
          footer: st.phase == _Phase.running ? const _Progress() : null,
        ),
      ],
    };
  }

  List<Widget> _buildCredential(
    BuildContext context,
    SshDiscovery source,
    _SourceState st,
  ) {
    final credential = source.credential!;
    final running = st.phase == _Phase.running;
    return [
      _card(
        context,
        [
          Padding(
            padding: const EdgeInsets.fromLTRB(_minPad, 13, 13, 13),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: st.token,
                    obscureText: true,
                    enabled: !running,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: credential.label,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _run(source),
                  ),
                ),
                UIs.width13,
                FilledButton.tonal(
                  onPressed: running ? null : () => _run(source),
                  child: Text(
                    running ? l10n.discoveryScanning : l10n.connect,
                  ),
                ),
              ],
            ),
          ),
        ],
        footer: running ? const _Progress() : null,
      ),
      if (credential.hint case final hint?) _note(hint),
    ];
  }

  Widget _buildError(
    BuildContext context,
    SshDiscovery source,
    _SourceState st,
  ) {
    final err = st.error;
    return _card(context, [
      ListTile(
        leading: Icon(source.icon),
        title: Text(err?.message ?? libL10n.fail),
        subtitle: err?.tip == null
            ? null
            : Text(err!.tip!, style: UIs.textGrey),
        trailing: FilledButton.tonal(
          onPressed: () => err?.needsFile == true
              ? _pickFile(source)
              : _retry(source),
          child: Text(
            err?.needsFile == true ? l10n.discoveryChooseFile : libL10n.retry,
          ),
        ),
      ),
    ]);
  }

  List<Widget> _buildResults(
    BuildContext context,
    SshDiscovery source,
    _SourceState st,
  ) {
    final servers = ref.watch(serversProvider).servers.values;
    bool exists(DiscoveredSshHost h) =>
        _known.contains(_keyOf(source, h)) || servers.any(h.isServer);
    final query = st.filter.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? st.hosts
        : st.hosts.where(
            (h) => [
              h.server.name,
              h.address,
              ?h.detail,
            ].any((e) => e.toLowerCase().contains(query)),
          ).toList();
    // What "select all" acts on: the rows on screen that can be checked.
    final free = [
      for (final h in shown)
        if (!_added.contains(_keyOf(source, h)) && !exists(h)) h,
    ];
    final allSelected =
        free.isNotEmpty &&
        free.every((h) => _selected.containsKey(_keyOf(source, h)));
    return [
      if (st.hosts.length >= _filterFrom)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
          child: TextField(
            controller: st.filter,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.discoveryFilter,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
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
            if (!widget._picking && free.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  for (final h in free) {
                    final key = _keyOf(source, h);
                    allSelected ? _selected.remove(key) : _selected[key] = h;
                  }
                }),
                child: Text(
                  allSelected ? libL10n.clear : l10n.discoverySelectAll,
                ),
              ),
            if (source.credential != null)
              TextButton(
                onPressed: () => _disconnect(source),
                child: Text(l10n.disconnect),
              )
            else
              TextButton(
                onPressed: () => _run(source),
                child: Text(l10n.discoveryScanAgain),
              ),
          ],
        ),
      ),
      if (shown.isNotEmpty)
        _card(context, [
          for (final h in shown) _buildHost(context, source, h, exists(h)),
        ]),
    ];
  }

  Widget _buildHost(
    BuildContext context,
    SshDiscovery source,
    DiscoveredSshHost h,
    bool exists,
  ) {
    final key = _keyOf(source, h);
    final user = h.server.ssh?.user;
    final address = [
      if (!h.unnamed) '${user == null || user == 'root' ? '' : '$user@'}${h.host}',
      if (h.port != 22) '${h.port}',
    ].join(':');
    final subtitle = [
      if (address.isNotEmpty) address,
      ?h.detail,
    ].join(' · ');
    final added = _added.contains(key);
    void toggle() => setState(() {
      if (_selected.remove(key) == null) _selected[key] = h;
    });
    final offline = h.online == false;
    final online = switch (h.online) {
      null => null,
      final on => _OnlineState(on),
    };
    // Faded, the whole row: a state worth reading at a glance down a list.
    Widget dim(Widget child) =>
        offline ? Opacity(opacity: .5, child: child) : child;
    return ListTile(
      leading: dim(const Icon(Icons.dns_outlined)),
      title: dim(Text(h.server.name, style: h.unnamed ? _mono : null)),
      subtitle: subtitle.isEmpty
          ? null
          : dim(
              Text(
                subtitle,
                style: UIs.textGrey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?online,
          if (online != null) UIs.width7,
          if (widget._picking)
            const Icon(Icons.chevron_right)
          else
            _trailing(
              context,
              added: added,
              exists: exists,
              selected: _selected.containsKey(key),
              onChanged: toggle,
            ),
        ],
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

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(_minPad, 5, _minPad, 0),
    child: Text(text, style: UIs.text12Grey),
  );

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

/// A dot and a word: filled in the accent when online, hollow when not.
final class _OnlineState extends StatelessWidget {
  const _OnlineState(this.online);

  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = online ? scheme.primary : scheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? color : null,
            border: online ? null : Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          online ? l10n.discoveryOnline : l10n.discoveryOffline,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: online ? FontWeight.w500 : null,
          ),
        ),
      ],
    );
  }
}

final class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) =>
      const LinearProgressIndicator(minHeight: 3);
}

/// Asks for one discovered host, in a dialog. Null when dismissed.
Future<DiscoveredSshHost?> pickDiscoveredHost(BuildContext context) {
  return context.showSheet<DiscoveredSshHost>(
    title: l10n.discoverSshServers,
    child: SizedBox(
      width: 400,
      height: 380,
      child: Builder(
        builder: (ctx) =>
            SshDiscoveryView.pick(onPick: (h) => ctx.popSheet(h)),
      ),
    ),
    actions: [Btn.cancel()],
  );
}

/// The batch view in a sheet, for [sources] alone when given.
Future<void> showSshDiscoverySheet(
  BuildContext context, {
  List<SshDiscovery>? sources,
}) {
  return showResizableSheet<void>(
    context,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * ResizableSheet.restFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 9),
            child: Text(
              l10n.discoverSshServers,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: SshDiscoveryView.batch(
                thisDevice: sources == null,
                sources: sources,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
