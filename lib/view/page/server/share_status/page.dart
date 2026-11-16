import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';
import 'package:server_box/view/page/server/share_status/data.dart';
import 'package:server_box/view/page/server/share_status/poster.dart';

/// A server's status as a poster to share, or as text to paste.
final class ServerStatusSharePage extends ConsumerStatefulWidget {
  const ServerStatusSharePage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: ServerStatusSharePage.new,
    path: '/server/share_status',
  );

  @override
  ConsumerState<ServerStatusSharePage> createState() => _State();
}

enum _Tab { content, range, privacy }

/// The ranges a poster offers: what this app has watched, and three windows
/// an agent keeping history answers for.
const _ranges = [HistoryRange.live, HistoryRange.h1, HistoryRange.h24, HistoryRange.d7];

/// The options go beside the poster from this width: the poster, its margins
/// and [_sideWidth] side by side.
const _sideFrom = StatusPosterCard.width + 26 + _sideWidth;
const _sideWidth = 340.0;

/// How wide the saved image is, in pixels.
const _imageWidth = 1080.0;

final class _State extends ConsumerState<ServerStatusSharePage> {
  final _poster = GlobalKey();
  final _shown = PosterSection.values.toSet()..removeAll(PosterSection.offByDefault);
  var _tab = _Tab.content;
  var _range = HistoryRange.live;
  final _windows = <HistoryRange, HistoryRangeAnswer>{};
  final _busy = <HistoryRange>{};
  var _hideName = false;
  var _hideSystem = false;
  var _sharing = false;

  String get _id => widget.args.spi.id;

  @override
  Widget build(BuildContext context) {
    final srv = ref.watch(serverProvider(_id));
    final stored = srv.capabilities.storedHistory;
    // A server that stops keeping history (its agent switched off) leaves
    // only what this app watched.
    if (!stored) _range = HistoryRange.live;
    final window = _range == HistoryRange.live
        ? MetricWindow.live(srv.status.history)
        : MetricWindow.of(_windows[_range]?.samples ?? const []);
    final poster = StatusPoster.of(srv, window);
    final tabs = [_Tab.content, if (stored) _Tab.range, _Tab.privacy];
    if (!tabs.contains(_tab)) _tab = _Tab.content;

    final preview = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(13, 4, 13, 17),
      child: Center(
        // Scaled down on a phone narrower than the poster, never reflowed:
        // the preview is the image.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: _poster,
            child: StatusPosterCard(
              poster: poster,
              shown: _shown,
              range: _range.label,
              hideName: _hideName,
              hideSystem: _hideSystem,
              dot: serverStateDot(srv),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.shareStatus)),
      // By the room the page has, which a window resized or split changes
      // while it is open.
      body: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= _sideFrom
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: preview),
                  SizedBox(width: _sideWidth, child: _side(poster, stored)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: preview),
                  _panel(poster, tabs),
                ],
              ),
      ),
    );
  }

  /// Every option at once, beside the poster: a wide window has the height
  /// the tabs below it exist to save.
  Widget _side(StatusPoster poster, bool stored) {
    final scheme = Theme.of(context).colorScheme;
    Widget head(String text) => Padding(
      padding: const EdgeInsets.only(top: 17, bottom: 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.primary,
        ),
      ),
    );
    // A `Material`, not a decorated box: the switches' ink is drawn on it.
    return Material(
      color: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 13),
                children: [
                  head(libL10n.content),
                  _contentTab(poster),
                  if (stored) ...[head(libL10n.time), _rangeTab()],
                  head(l10n.privacy),
                  _privacyTab(),
                ],
              ),
            ),
            const Divider(height: 1),
            _actions(poster),
          ],
        ),
      ),
    );
  }

  Widget _panel(StatusPoster poster, List<_Tab> tabs) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTabController(
              key: ValueKey(tabs.length),
              length: tabs.length,
              initialIndex: tabs.indexOf(_tab),
              child: TabBar(
                onTap: (i) => setState(() => _tab = tabs[i]),
                tabs: [
                  for (final t in tabs)
                    Tab(
                      text: switch (t) {
                        _Tab.content => libL10n.content,
                        _Tab.range => libL10n.time,
                        _Tab.privacy => l10n.privacy,
                      },
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(13),
                child: switch (_tab) {
                  _Tab.content => _contentTab(poster),
                  _Tab.range => _rangeTab(),
                  _Tab.privacy => _privacyTab(),
                },
              ),
            ),
            const Divider(height: 1),
            _actions(poster),
          ],
        ),
      ),
    );
  }

  Widget _actions(StatusPoster poster) {
    // Not over a window still loading, or one that failed: the badge would
    // name a range the figures are not of.
    final ready = _range == HistoryRange.live || _windows.containsKey(_range);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 9,
        children: [
          TextButton.icon(
            onPressed: ready ? () => _copy(poster) : null,
            icon: const Icon(Icons.content_copy, size: 18),
            label: Text(libL10n.copy),
          ),
          FilledButton.icon(
            onPressed: !ready || _sharing ? null : () => _share(poster),
            icon: Icon(isDesktop ? Icons.save_alt : Icons.share, size: 18),
            label: Text(isDesktop ? libL10n.save : libL10n.share),
          ),
        ],
      ),
    );
  }

  Widget _contentTab(StatusPoster poster) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final s in PosterSection.values)
          if (poster.sections.containsKey(s))
            FilterChip(
              avatar: Icon(s.icon, size: 17),
              label: Text(s.label),
              showCheckmark: false,
              selected: _shown.contains(s),
              onSelected: (on) => setState(() => on ? _shown.add(s) : _shown.remove(s)),
            ),
      ],
    );
  }

  Widget _rangeTab() {
    return SegmentedButton<HistoryRange>(
      segments: [
        for (final r in _ranges)
          ButtonSegment(
            value: r,
            label: _busy.contains(r)
                ? const SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(r.label),
          ),
      ],
      selected: {_range},
      onSelectionChanged: (s) => _selectRange(s.first),
    );
  }

  Widget _privacyTab() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.visibility_off),
          title: Text(l10n.hideServerName),
          value: _hideName,
          onChanged: (v) => setState(() => _hideName = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.badge),
          title: Text(l10n.hideSystemVersion),
          value: _hideSystem,
          onChanged: (v) => setState(() => _hideSystem = v),
        ),
      ],
    );
  }

  /// Asks the agent for the window once; it is kept until the page is left.
  Future<void> _selectRange(HistoryRange range) async {
    setState(() => _range = range);
    final minutes = range.minutes;
    if (minutes == null || _windows.containsKey(range) || _busy.contains(range)) return;
    setState(() => _busy.add(range));
    try {
      final to = DateTime.now();
      final samples = await ref
          .read(serverProvider(_id).notifier)
          .fetchHistoryRange(
            minutes: minutes,
            maxPoints: kHistoryRangePoints,
            from: to.subtract(Duration(minutes: minutes)),
            to: to,
          );
      if (!mounted) return;
      setState(() => _windows[range] = (samples: samples, at: to));
    } catch (e, s) {
      Loggers.app.warning('Share status history ${range.label}', e, s);
      if (!mounted) return;
      Toast.error('$e');
      if (_range == range) setState(() => _range = HistoryRange.live);
    } finally {
      if (mounted) setState(() => _busy.remove(range));
    }
  }

  void _copy(StatusPoster poster) {
    final text = poster.summary(
      shown: _shown,
      range: _range.label,
      hideName: _hideName,
      hideSystem: _hideSystem,
    );
    Pfs.copy(text);
    Toast.success(libL10n.success);
  }

  Future<void> _share(StatusPoster poster) async {
    setState(() => _sharing = true);
    try {
      final png = await _png();
      if (png == null || !mounted) return;
      final name = 'serverbox-${_hideName ? 'status' : _fileSafe(poster.name)}-'
          '${DateTime.now().millisecondsSinceEpoch ~/ 1000}.png';
      if (isDesktop) {
        // A folder, then the file written here, as the rescue page's export
        // does: macOS's save panel needs a sandbox entitlement this app,
        // unsandboxed, does not declare.
        final dir = await FilePicker.getDirectoryPath(dialogTitle: libL10n.save);
        if (dir == null) return;
        final path = dir.joinPath(name);
        await File(path).writeAsBytes(png);
        Toast.success(libL10n.saved);
        await Pfs.revealPath(path);
        return;
      }
      // One directory, emptied each time: the share sheet reads the file
      // after this returns, so it cannot be removed here.
      final dir = Directory('${Directory.systemTemp.path}/serverbox-poster');
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(png);
      await Pfs.sharePaths(paths: [file.path]);
    } catch (e, s) {
      Loggers.app.warning('Share status', e, s);
      if (mounted) context.showErrSheet(e, s);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// The poster at [_imageWidth] pixels across, whatever it is scaled to here.
  Future<Uint8List?> _png() async {
    final boundary = _poster.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: _imageWidth / StatusPosterCard.width);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

String _fileSafe(String name) {
  final safe = name.replaceAll(RegExp(r'[^\w.-]+'), '_');
  return safe.isEmpty ? 'status' : safe;
}
