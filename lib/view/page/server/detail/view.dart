import 'dart:async';
import 'dart:math' as math;
import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart' as server_model;
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

part 'misc.dart';

class ServerDetailPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;
  const ServerDetailPage({super.key, required this.args});

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route = AppRouteArg(
    page: ServerDetailPage.new,
    path: '/servers/detail',
  );
}

/// Left over on either side of the bar, so the page it floats above is still
/// visible past it and it never reads as a second edge to the window.
const _kFuncBarSideRoom = 100.0;

/// One row of buttons with their labels: a 17pt icon over a line of 11pt text,
/// plus the buttons' own inset and the row's, and a little over.
const _kFuncBarHeight = 56.0;

/// What the grid keeps clear below its last card, so the bar is never over
/// something that cannot be scrolled out from under it.
const _kFuncBarInset = _kFuncBarHeight + 26;

class _ServerDetailPageState extends ConsumerState<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  /// Keyed by the enum, not paired positionally with `ServerDetailCards.names`.
  ///
  /// The positional form threw `Iterables do not have same length` at runtime
  /// whenever a card was added or removed and only one of the two lists was
  /// updated, and a reordering of either silently paired a card with the wrong
  /// builder. Here a mistake is at worst one missing card.
  late final _cardBuildMap =
      <ServerDetailCards, Widget? Function(ServerState)>{
        ServerDetailCards.about: _buildAbout,
        ServerDetailCards.cpu: _buildCPUView,
        ServerDetailCards.mem: _buildMemView,
        ServerDetailCards.swap: _buildSwapView,
        ServerDetailCards.gpu: _buildGpuView,
        ServerDetailCards.disk: _buildDiskView,
        ServerDetailCards.smart: _buildDiskSmart,
        ServerDetailCards.net: _buildNetView,
        ServerDetailCards.sensor: _buildSensors,
        ServerDetailCards.temp: _buildTemperature,
        ServerDetailCards.battery: _buildBatteries,
        ServerDetailCards.pve: _buildPve,
        ServerDetailCards.bmc: _buildBmc,
        ServerDetailCards.custom: _buildCustomCmd,
      };

  late Size _size;
  final List<String> _cardsOrder = [];

  final _settings = Stores.setting;
  final _netSortType = ValueNotifier(_NetSortType.device);

  /// Shared by the grid and the bar floating over it, which is how the bar
  /// knows to get out of the way.
  final _scrollCtrl = ScrollController();
  late final _collapse = _settings.collapseUIDefault.fetch();
  late final _textFactor = TextScaler.linear(_settings.textFactor.fetch());
  late final _cpuViewAsProgress = _settings.cpuViewAsProgress.fetch();
  late final _displayCpuIndex = _settings.displayCpuIndex.fetch();

  @override
  void dispose() {
    super.dispose();
    _netSortType.dispose();
    _scrollCtrl.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size = MediaQuery.sizeOf(context);
  }

  @override
  void initState() {
    super.initState();
    final order = _settings.detailCardOrder.fetch();
    final disabled = _settings.detailCardDisabled.fetch();
    order.removeWhere(
      (e) => !ServerDetailCards.names.contains(e) || disabled.contains(e),
    );
    _cardsOrder.addAll(order);

    // Prefill the trend buffer from whatever history the source already has,
    // so the chart cards aren't blank on a freshly opened page. A no-op for
    // sources without ServerCapabilities.storedHistory (i.e. SSH), which
    // simply accumulate from here on.
    unawaited(
      ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .seedHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverProvider(widget.args.spi.id));
    if (!_hasContent(serverState)) {
      return _buildNothingYet(serverState);
    }
    return _buildMainPage(serverState);
  }

  /// A server that has not reported anything yet.
  ///
  /// Used to be the word "empty" on its own, which was survivable when this
  /// page could only be reached by opening it deliberately. Beside a list it
  /// is where every server that fails to connect ends up, so it has to say why
  /// and offer the one action that helps.
  Widget _buildNothingYet(ServerState si) {
    final err = si.status.err;
    // `connected` counts: the SSH path sits there through system detection and
    // the script install, two round trips during which there is still nothing
    // to show. Reading it as "not busy" put "Empty" and a Retry button in
    // front of a server that was in the middle of connecting — and disagreed
    // with the server card, which has always treated the three as one state.
    final busy =
        si.conn == server_model.ServerConn.connecting ||
        si.conn == server_model.ServerConn.connected ||
        si.conn == server_model.ServerConn.loading;

    return Scaffold(
      appBar: _buildAppBar(si),
      // Scrolls, and shows the error in full. The card elsewhere on this page
      // clips to two lines because it sits above the data it is annotating;
      // here the error is the entire content, and a truncated address or
      // errno is the part someone needs.
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
        children: [
          if (err != null)
            CardX(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: SimpleMarkdown(data: _errMarkdown(err)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(13),
              child: Text(
                // "Empty" is what a server that answered and had nothing to
                // say would be. One that has not answered yet is connecting,
                // and saying so is the difference between waiting and
                // wondering.
                busy ? l10n.waitConnection : libL10n.empty,
                style: UIs.textGrey,
                textAlign: TextAlign.center,
              ),
            ),
          UIs.height13,
          // Centred, or the column stretches it into something that reads as
          // a list row rather than a button.
          Center(
            child: busy
                ? SizedLoading.medium
                : Btn.elevated(
                    text: libL10n.retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    // The icon variant lays its row out at max size, so
                    // without this the button fills whatever it is given and
                    // reads as a list row.
                    mainAxisSize: MainAxisSize.min,
                    gap: 8,
                    onTap: () => _reconnect(si),
                  ),
          ),
        ],
      ),
    );
  }

  /// The error as markdown: what to do about it, then what was actually said.
  String _errMarkdown(Err err) {
    return '''
${err.solution ?? libL10n.unknown}

```sh
${err.message ?? 'null'}
```
''';
  }

  /// Clears the retry limiter first: the user asking again *is* the new
  /// information, and without this the request is dropped by the backoff that
  /// the previous failures installed.
  void _reconnect(ServerState si) {
    TryLimiter.reset(si.spi.id);
    ref.read(serversProvider.notifier).refresh(spi: si.spi);
  }

  /// Whether there is anything to render.
  ///
  /// Losing the connection must not empty the page: the status already
  /// fetched is still the most recent thing known about the server, and the
  /// error card below explains why it stopped updating. Collapsing to the
  /// placeholder on `ServerConn.failed` threw both away, so a monitor going
  /// offline looked identical to a server that had never been opened.
  ///
  /// `more` is the "has ever been fetched" signal — every successful status
  /// apply populates it on both transports, and `keepStatusWhenErr` in
  /// `ServerNotifier` already relies on that.
  bool _hasContent(ServerState state) {
    if (state.status.more.isNotEmpty) return true;
    // Having a connection is not having anything to show. Read as "connected
    // is enough", this page opened onto a grid of empty cards — dashes where
    // the CPU goes, `0% of 1 KB` for the disk — for as long as the first fetch
    // took, which on a server that is merely slow is a while. `finished` is
    // the state that means a status came back; it is only ever left for
    // another *later* fetch, so the page does not flicker back on refresh.
    return state.conn == server_model.ServerConn.finished;
  }

  Widget _buildMainPage(ServerState si) {
    // Every ServerFuncBtn (terminal / sftp / container / process / snippet /
    // iperf / systemd / portForward) needs a shell. Hide the whole row on
    // transports without one instead of offering buttons that can only fail.
    // `terminal` rather than `shell`: an agent's passwordless PTY earns the
    // row too, and `btns` decides what belongs in it
    final buildFuncs = si.capabilities.terminal;
    final logo = _buildLogo(si);
    final children = <Widget>[?logo, ?_buildErrCard(si)];
    for (final card in _cardsOrder) {
      final child = _cardBuildMap[ServerDetailCards.fromName(card)]
          ?.call(si);
      if (child != null) {
        children.add(child);
      }
    }

    return Scaffold(
      appBar: _buildAppBar(si),
      body: SafeArea(
        child: Stack(
          children: [
            PageColumns(
              controller: _scrollCtrl,
              bottomInset: buildFuncs ? _kFuncBarInset : 0,
              children: children,
            ),
            // Over the page rather than at the top of it. These act on the
            // server, not on any one card, so they belong within reach the
            // whole way down instead of scrolling off after the first chart.
            if (buildFuncs)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HideOnScroll(
                  controller: _scrollCtrl,
                  child: _buildFuncBar(si),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The row of things that can be done to this server, floating over it.
  Widget _buildFuncBar(ServerState si) {
    return LayoutBuilder(
      builder: (_, cons) => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: ConstrainedBox(
            // The row takes the width it needs up to this; beyond it, it
            // scrolls. Stretched across a desktop window it would stop being a
            // group of buttons and become a band across the page.
            constraints: BoxConstraints(
              maxWidth: (cons.maxWidth - _kFuncBarSideRoom).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Material(
              // Raised off the page, because it is the one thing here that is
              // not part of what the page is showing.
              elevation: 3,
              shadowColor: Colors.black26,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(19),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: _kFuncBarHeight,
                child: ServerFuncBtns(spi: si.spi, granted: si.remoteAccess),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Why the status stopped updating. Sits above the cards, which keep
  /// showing the last successful reading — stale data with a visible reason
  /// beats a blank page.
  Widget? _buildErrCard(ServerState si) {
    final err = si.status.err;
    if (err == null) return null;

    final solution = err.solution;
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
        title: Text(libL10n.error, style: UIs.text15),
        subtitle: Text(
          solution ?? err.message ?? libL10n.unknown,
          style: UIs.text12Grey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 17),
        onTap: () => _showErrDetail(err),
      ),
    );
  }

  void _showErrDetail(Err err) {
    final md = _errMarkdown(err);
    context.showRoundDialog(
      title: libL10n.error,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: [
        TextButton(onPressed: () => Pfs.copy(md), child: Text(libL10n.copy)),
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }

  CustomAppBar _buildAppBar(ServerState si) {
    // At the root of a detail pane there is nothing to pop, so no back button
    // is drawn and there is no way to hand the width back to the list. Null
    // everywhere else, where the implicit back button is the way out.
    final closeDetail = PaneScope.closeDetailOf(context);
    return CustomAppBar(
      leading: closeDetail == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: libL10n.close,
              onPressed: closeDetail,
            ),
      title: Text(
        si.spi.name,
        style: TextStyle(
          fontSize: 20,
          color: context.isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: libL10n.share,
          onPressed: () => _showShareQr(si.spi),
        ),
        IconButton(tooltip: libL10n.edit, 
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final delete = await ServerEditPage.route.go(
              context,
              args: SpiRequiredArgs(si.spi),
            );
            if (delete == true) {
              context.pop();
            }
          },
        ),
      ],
    );
  }

  /// Not `QrShareBtn`: the code encodes the whole record, passwords included,
  /// so the dialog has to say so before anyone points a camera at it.
  void _showShareQr(Spi spi) {
    context.showRoundDialog(
      title: libL10n.share,
      child: ConstrainedBox(
        // The QR fills whatever width it is given and the hint is one long
        // line, so without a cap the paragraph's intrinsic width sets the
        // dialog's — on a desktop window that is a QR code the height of the
        // screen. A max, not a fixed width: a narrow phone gets less.
        constraints: const BoxConstraints(maxWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.shareServerRiskTip,
                style: UIs.text13Grey,
                textAlign: TextAlign.start,
              ),
              UIs.height13,
              QrView(
                data: spi.toJsonString(),
                tip: spi.name,
                tip2: '${libL10n.server} ~ ServerBox',
              ),
            ],
          ),
        ),
      ),
      actions: Btnx.oks,
    );
  }

  Widget? _buildLogo(ServerState si) {
    final logoUrl = si.getLogoUrl(context);
    // Null, not an empty placeholder: the wrapping Padding was laid out either
    // way, leaving a band of dead space above the first card on every server
    // without a logo configured.
    if (logoUrl == null) return null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: LayoutBuilder(
        builder: (_, cons) {
          final height = cons.maxWidth * 0.3;
          if (logoUrl.isSvgUrl) {
            return SvgPicture.network(
              logoUrl,
              height: height,
              width: cons.maxWidth,
              fit: BoxFit.contain,
            );
          }
          return ExtendedImage.network(
            logoUrl,
            cache: true,
            height: height,
            width: cons.maxWidth,
          );
        },
      ),
    );
  }

  Widget? _buildAbout(ServerState si) {
    final ss = si.status;
    return ExpandTile(
      key: ValueKey(ss.more.hashCode), // Use hashCode to avoid perf issue
      leading: const Icon(MingCute.information_fill, size: 20),
      initiallyExpanded: _getInitExpand(ss.more.entries.length),
      title: Text(libL10n.about),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      children: ss.more.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key.i18n,
                    style: UIs.text13,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    e.value,
                    style: UIs.text13Grey,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ).cardx;
  }

  /// CPU: the live figure, its breakdown, the per-core bars, its own trend,
  /// and the model last.
  ///
  /// Separate from RAM again. They shared a card briefly, which put two 27pt
  /// figures eight lines apart with one chart between them and never read as
  /// a single subject. Apart, each figure is identified by what surrounds it:
  /// the CPU breakdown here, the total beside the RAM one.
  Widget? _buildCPUView(ServerState si) {
    final ss = si.status;
    final cpuPercent = ss.cpu.usedPercent(coreIdx: 0)?.toInt();

    final details = [
      _buildDetailPercent(ss.cpu.user, 'user'),
      UIs.width13,
      _buildDetailPercent(ss.cpu.idle, 'idle'),
    ];
    if (ss.system == SystemType.linux) {
      details.addAll([
        UIs.width13,
        _buildDetailPercent(ss.cpu.sys, 'sys'),
        UIs.width13,
        _buildDetailPercent(ss.cpu.iowait, 'io'),
      ]);
    }

    // The model string never changes while the page is open, so it sits after
    // the readings that do
    final children = <Widget>[
      if (_cpuViewAsProgress) ..._buildCPUProgress(ss.cpu),
      ?_buildCpuChart(si),
      if (ss.cpu.brand.isNotEmpty)
        Column(
          children: ss.cpu.brand.entries.map(_buildCpuModelItem).toList(),
        ).paddingOnly(top: 13),
    ];

    return ExpandTile(
      title: Align(
        alignment: Alignment.centerLeft,
        child: _buildAnimatedText(
          ValueKey(cpuPercent),
          cpuPercent == null ? '--' : '$cpuPercent%',
          UIs.text27,
        ),
      ),
      childrenPadding: const EdgeInsets.symmetric(vertical: 13),
      initiallyExpanded: _getInitExpand(1),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: details),
      children: children,
    ).cardx;
  }

  /// RAM, laid out to mirror the CPU card so the two read as one scale.
  ///
  ///
  /// No progress bar: it restated the same percentage the figure and the trend
  /// already carried, and its full-width fill was the heaviest mark on the card.
  Widget? _buildMemView(ServerState si) {
    final ss = si.status;
    if (ss.mem.total == 0) return null;

    final free = ss.mem.free / ss.mem.total * 100;
    final avail = ss.mem.availPercent * 100;
    final usedStr = (ss.mem.usedPercent * 100).toStringAsFixed(0);

    return ExpandTile(
      title: Row(
        children: [
          _buildAnimatedText(ValueKey(usedStr), '$usedStr%', UIs.text27),
          UIs.width7,
          Text(
            'of ${(ss.mem.total * 1024).bytes2Str}',
            style: UIs.text13Grey,
          ),
        ],
      ),
      childrenPadding: const EdgeInsets.symmetric(vertical: 13),
      initiallyExpanded: _getInitExpand(1),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDetailPercent(free, 'free'),
          UIs.width13,
          _buildDetailPercent(avail, 'avail'),
        ],
      ),
      children: [?_buildMemChart(si)],
    ).cardx;
  }

  Widget _buildCpuModelItem(MapEntry<String, int> e) {
    final name = e.key
        .replaceFirst('Intel(R)', '')
        .replaceFirst('AMD', '')
        .replaceFirst('with Radeon Graphics', '');
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LayoutBuilder(
          builder: (_, cons) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cons.maxWidth * .7),
              child: Text(
                name,
                style: UIs.text13,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          },
        ),
        Text(
          'x ${e.value}',
          style: UIs.text13Grey,
          overflow: TextOverflow.clip,
        ),
      ],
    );
    return child.paddingSymmetric(horizontal: 17);
  }

  /// [percent] is null before a second sample exists, i.e. there is no window
  /// to compute a share over — rendered as "--" so it can't be mistaken for a
  /// measured 0%
  Widget _buildDetailPercent(double? percent, String timeType) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          percent == null ? '--' : '${percent.toStringAsFixed(1)}%',
          style: UIs.text12,
          textScaler: _textFactor,
        ),
        Text(timeType, style: UIs.text12Grey, textScaler: _textFactor),
      ],
    );
  }

  List<Widget> _buildCPUProgress(Cpus cs) {
    const kMaxColumn = 2;
    const kRowThreshold = 4;
    const kCoresCountThreshold = kMaxColumn * kRowThreshold;
    final children = <Widget>[];
    final displayCpuIndexSetting = _displayCpuIndex;

    if (cs.coresCount > kCoresCountThreshold) {
      final numCoresToDisplay = cs.coresCount - 1;
      final numRows = (numCoresToDisplay + kMaxColumn - 1) ~/ kMaxColumn;

      for (var i = 0; i < numRows; i++) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < kMaxColumn; j++) {
          final coreListIndex = i * kMaxColumn + j;
          if (coreListIndex >= numCoresToDisplay) break;

          final coreNumberOneBased = coreListIndex + 1;

          if (displayCpuIndexSetting) {
            rowChildren.add(Text('$coreNumberOneBased', style: UIs.text13Grey));
          }
          rowChildren.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildProgress(
                  cs.usedPercent(coreIdx: coreNumberOneBased),
                ),
              ),
            ),
          );
        }
        if (rowChildren.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(children: rowChildren.joinWith(UIs.width7).toList()),
            ),
          );
        }
      }
    } else {
      for (var i = 1; i < cs.coresCount; i++) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 17),
            child: _buildProgress(cs.usedPercent(coreIdx: i)),
          ),
        );
      }
    }

    return children;
  }


  Widget _buildProgress(double? percent) {
    // Indeterminate while there is no reading, instead of a full-width 0 bar
    final percentWithinOne = percent == null
        ? null
        : percent.clamp(0, 100) / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: UIs.halfAlpha,
      color: UIs.primaryColor,
    );
  }

  Widget? _buildSwapView(ServerState si) {
    final ss = si.status;
    if (ss.swap.total == 0) return null;

    final used = ss.swap.usedPercent * 100;
    final cached = ss.swap.cached / ss.swap.total * 100;

    final percentW = Row(
      children: [
        Text('${used.toStringAsFixed(0)}%', style: UIs.text27),
        UIs.width7,
        Text('of ${(ss.swap.total * 1024).bytes2Str} ', style: UIs.text13Grey),
      ],
    );

    return Padding(
      padding: UIs.roundRectCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [percentW, _buildDetailPercent(cached, 'cached')],
          ),
          UIs.height13,
          _buildProgress(used),
        ],
      ),
    ).cardx;
  }

  Widget? _buildGpuView(ServerState si) {
    final ss = si.status;
    final hasNvidia = ss.nvidia != null && ss.nvidia!.isNotEmpty;
    final hasAmd = ss.amd != null && ss.amd!.isNotEmpty;

    if (!hasNvidia && !hasAmd) return null;

    final children = <Widget>[];

    // Add NVIDIA GPUs
    if (hasNvidia) {
      children.addAll(ss.nvidia!.map((e) => _buildNvidiaGpuItem(e)));
    }

    // Add AMD GPUs
    if (hasAmd) {
      children.addAll(ss.amd!.map((e) => _buildAmdGpuItem(e)));
    }

    return ExpandTile(
      title: const Text('GPU'),
      leading: const Icon(Icons.memory, size: 17),
      initiallyExpanded: _getInitExpand(children.length, 3),
      children: children,
    ).cardx;
  }

  Widget _buildNvidiaGpuItem(NvidiaSmiItem item) {
    final mem = item.memory;
    return ListTile(
      title: Text(item.name, style: UIs.text13),
      leading: Text(
        '${item.percent}%\n${item.temp} °C',
        style: UIs.text12Grey,
        textScaler: _textFactor,
        textAlign: TextAlign.center,
      ),
      subtitle: Text(
        '${item.power} - FAN ${item.fanSpeed}%\n${mem.used} / ${mem.total} ${mem.unit}',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 17),
      trailing: _buildGpuInfoButton(() => _onTapNvidiaGpuItem(item)),
    );
  }

  Widget _buildAmdGpuItem(AmdSmiItem item) {
    final mem = item.memory;
    return ListTile(
      title: Text('${item.name} (AMD)', style: UIs.text13),
      leading: Text(
        '${item.utilization}%\n${item.temp} °C',
        style: UIs.text12Grey,
        textScaler: _textFactor,
        textAlign: TextAlign.center,
      ),
      subtitle: Text(
        '${item.power} - FAN ${item.fanSpeed} RPM\n${item.clockSpeed} MHz\n${mem.used} / ${mem.total} ${mem.unit}',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 17),
      trailing: _buildGpuInfoButton(() => _onTapAmdGpuItem(item)),
    );
  }

  Widget _buildGpuProcessItem(NvidiaSmiMemProcess process) {
    return _buildGpuProcessTile(
      name: process.name,
      subtitle: 'PID: ${process.pid} - ${process.memory} MiB',
      onTap: () => _onTapGpuProcessItem(process),
    );
  }

  Widget _buildAmdGpuProcessItem(AmdSmiMemProcess process) {
    return _buildGpuProcessTile(
      name: process.name,
      subtitle:
          'PID: ${process.pid} - ${_formatAmdGpuProcessMemory(process.memory)}',
      onTap: () => _onTapAmdGpuProcessItem(process),
    );
  }

  Widget _buildGpuInfoButton(VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: libL10n.about, 
          onPressed: onPressed,
          icon: const Icon(Icons.info_outline, size: 17),
        ),
      ],
    );
  }

  Widget _buildGpuProcessTile({
    required String name,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        name,
        style: UIs.text12,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: _textFactor,
      ),
      subtitle: Text(subtitle, style: UIs.text12Grey, textScaler: _textFactor),
      trailing: InkWell(
        onTap: onTap,
        child: const Icon(Icons.info_outline, size: 17),
      ),
    );
  }

  Widget? _buildDiskView(ServerState si) {
    final ss = si.status;
    final mounts = <Widget>[];

    // Create widgets for each top-level disk
    for (int idx = 0; idx < ss.disk.length; idx++) {
      final disk = ss.disk[idx];
      mounts.add(_buildDiskItemWithHierarchy(disk, ss, 0));
    }

    if (mounts.isEmpty) return null;

    // Laid out like the Network card, and for the same reason: a host reports
    // as many mounts as it has, most of them loop devices and container
    // layers, and the throughput trend put after that list was never seen.
    final children = <Widget>[
      ?_buildDiskChart(si),
      ExpandTile(
        title: Text(libL10n.device, style: UIs.text13Grey),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.only(bottom: 7),
        children: mounts,
      ),
    ];

    return ExpandTile(
      title: Text(libL10n.disk),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(ServerDetailCards.disk.icon, size: 17),
      initiallyExpanded: _getInitExpand(1),
      children: children,
    ).cardx;
  }

  Widget _buildDiskItemWithHierarchy(
    Disk disk,
    server_model.ServerStatus ss,
    int depth,
  ) {
    // Create a list to hold this disk and its children
    final items = <Widget>[];

    // Add the current disk
    items.add(_buildDiskItem(disk, ss, depth));

    // Recursively add child disks with increased indentation
    if (disk.children.isNotEmpty) {
      for (final childDisk in disk.children) {
        items.add(_buildDiskItemWithHierarchy(childDisk, ss, depth + 1));
      }
    }

    return Column(children: items);
  }

  Widget _buildDiskItem(Disk disk, server_model.ServerStatus ss, int depth) {
    final (read, write) = ss.diskIO.getSpeed(disk.path);
    final text = () {
      final use = '${l10n.used} ${disk.used.kb2Str} / ${disk.size.kb2Str}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();

    return Padding(
      padding: EdgeInsets.only(
        left: 17.0 + (depth * 15.0), // Indent based on depth
        right: 17.0,
        top: 5.0,
        bottom: 5.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disk.mount.isEmpty
                      ? disk.path
                      : '${disk.path} (${disk.mount})',
                  style: UIs.text12,
                  textScaler: _textFactor,
                ),
                Text(text, style: UIs.text12Grey, textScaler: _textFactor),
              ],
            ),
          ),
          if (disk.size > BigInt.zero)
            SizedBox(
              height: 41,
              width: 41,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: disk.usedPercent / 100,
                    strokeWidth: 5,
                    backgroundColor: UIs.halfAlpha,
                    color: UIs.primaryColor,
                  ),
                  Text('${disk.usedPercent}%', style: UIs.text12Grey),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildDiskSmart(ServerState si) {
    final smarts = si.status.diskSmart;
    if (smarts.isEmpty) return null;
    return CardX(
      child: ExpandTile(
        title: Text(l10n.diskHealth),
        leading: Icon(ServerDetailCards.smart.icon, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(smarts.length),
        children: smarts.map(_buildDiskSmartItem).toList(),
      ),
    );
  }

  Widget _buildDiskSmartItem(DiskSmart smart) {
    final healthStatus = _getDiskHealthStatus(smart);

    return ListTile(
      dense: true,
      leading: healthStatus.icon,
      title: Text(smart.device, style: UIs.text13, textScaler: _textFactor),
      trailing: Text(
        healthStatus.text,
        style: UIs.text13.copyWith(fontWeight: FontWeight.bold),
        textScaler: _textFactor,
      ),
      subtitle: _buildDiskSmartDetails(smart),
      onTap: () => _onTapDiskSmartItem(smart),
    );
  }

  ({String text, Color color, Widget icon}) _getDiskHealthStatus(
    DiskSmart smart,
  ) {
    if (smart.healthy == null) {
      return (
        text: libL10n.unknown,
        color: Colors.orange,
        icon: const Icon(Icons.help_outline, color: Colors.orange, size: 18),
      );
    } else if (smart.healthy!) {
      return (
        text: 'PASS',
        color: Colors.green,
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
      );
    } else {
      return (
        text: 'FAIL',
        color: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red, size: 18),
      );
    }
  }

  Widget? _buildDiskSmartDetails(DiskSmart smart) {
    final details = <String>[];

    if (smart.model != null) {
      details.add(smart.model!);
    }

    if (smart.temperature != null) {
      details.add('${smart.temperature!.toStringAsFixed(1)}°C');
    }

    if (smart.powerOnHours != null) {
      final hours = smart.powerOnHours!;
      details.add('$hours ${libL10n.hour}');
    }

    if (smart.ssdLifeLeft != null) {
      details.add('Life left: ${smart.ssdLifeLeft}%');
    }

    if (details.isEmpty) return null;

    return Text(
      details.join(' | '),
      style: UIs.text12Grey,
      textScaler: _textFactor,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _onTapDiskSmartItem(DiskSmart smart) {
    final details = <String>[];

    if (smart.model != null) details.add('Model: ${smart.model}');
    if (smart.serial != null) details.add('Serial: ${smart.serial}');
    if (smart.temperature != null) {
      details.add('Temperature: ${smart.temperature!.toStringAsFixed(1)}°C');
    }

    if (smart.powerOnHours != null) {
      details.add('Power On: ${smart.powerOnHours} ${libL10n.hour}');
    }
    if (smart.powerCycleCount != null) {
      details.add('Power Cycle: ${smart.powerCycleCount}');
    }

    if (smart.ssdLifeLeft != null) {
      details.add('Life Left: ${smart.ssdLifeLeft}%');
    }
    if (smart.lifetimeWritesGiB != null) {
      details.add('Lifetime Write: ${smart.lifetimeWritesGiB} GiB');
    }
    if (smart.lifetimeReadsGiB != null) {
      details.add('Lifetime Read: ${smart.lifetimeReadsGiB} GiB');
    }
    if (smart.averageEraseCount != null) {
      details.add('Avg. Erase: ${smart.averageEraseCount}');
    }
    if (smart.unsafeShutdownCount != null) {
      details.add('Unsafe Shutdown: ${smart.unsafeShutdownCount}');
    }

    final criticalAttrs = [
      'Reallocated_Sector_Ct',
      'Current_Pending_Sector',
      'Offline_Uncorrectable',
      'UDMA_CRC_Error_Count',
    ];

    for (final attrName in criticalAttrs) {
      final attr = smart.getAttribute(attrName);
      if (attr != null && attr.rawValue != null) {
        final value = attr.rawValue.toString();
        details.add('${attrName.replaceAll('_', ' ')}: $value');
      }
    }

    if (details.isEmpty) {
      return;
    }

    final markdown = details.join('\n\n- ');
    context.showRoundDialog(
      title: smart.device,
      child: MarkdownBody(
        data: '- $markdown',
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(p: UIs.text13Grey, h2: UIs.text15),
      ),
      actions: Btnx.oks,
    );
  }

  Widget? _buildNetView(ServerState si) {
    final ss = si.status;
    final ns = ss.netSpeed;
    final children = <Widget>[];
    final devices = ns.devices;
    if (devices.isEmpty) return null;

    devices.sort(_netSortType.value.getSortFunc(ns));

    // Chart first, interfaces behind a disclosure that starts closed. A host
    // routinely reports twenty-odd interfaces, nearly all of them idle
    // tunnels; putting the trend after that list buried it.
    final chart = _buildNetChart(si);
    if (chart != null) children.add(chart);
    children.add(
      ExpandTile(
        title: Text(libL10n.device, style: UIs.text13Grey),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.only(bottom: 7),
        children: devices.map((e) => _buildNetSpeedItem(ns, e)).toList(),
      ),
    );

    return ExpandTile(
      leading: Icon(ServerDetailCards.net.icon, size: 17),
      title: Row(
        children: [
          Text(libL10n.net),
          UIs.width13,
          _netSortType.listenVal(
            (val) => InkWell(
              onTap: () => _netSortType.value = val.next,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 377),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Row(
                  children: [
                    const Icon(Icons.sort, size: 17),
                    UIs.width7,
                    Text(val.name, style: UIs.text13Grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: _getInitExpand(1),
      children: children,
    ).cardx;
  }

  Widget _buildNetSpeedItem(NetSpeed ns, String device) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded, not intrinsic: the totals line grows with the numbers
          // ("502.4 MB | 502.4 MB" on a busy loopback) and pushed the
          // fixed-width speed column past the right edge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device,
                  style: UIs.text12,
                  textScaler: _textFactor,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.left,
                ),
                Text(
                  '${ns.sizeIn(device: device)} | ${ns.sizeOut(device: device)}',
                  style: UIs.text12Grey,
                  textScaler: _textFactor,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: Text(
              '${ns.speedOut(device: device)} ↑\n${ns.speedIn(device: device)} ↓',
              textAlign: TextAlign.end,
              style: UIs.text13Grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildTemperature(ServerState si) {
    final ss = si.status;
    if (ss.temps.isEmpty) return null;

    final devices = ss.temps.devices;
    // Chart only. Sensor names and readings are what the chart's legend
    // carries once there is more than one line; with a single sensor there is
    // no legend, so its reading goes in the header instead. Either way a list
    // above the chart would restate it.
    final chart = _buildTempChart(si);
    if (chart == null) return null;

    // The chart plots one sensor per component, so a host with more than that
    // has readings it isn't showing. Saying "4 / 20" and opening the full set
    // on tap keeps a curated view from reading as the whole one.
    final plotted = _tempSeries(si).length;
    final hidden = devices.length > plotted;

    final Widget? note;
    if (devices.length == 1) {
      note = Text(
        '${ss.temps.get(devices.first)?.toStringAsFixed(1)}°C',
        style: UIs.text13Grey,
      );
    } else if (hidden) {
      note = InkWell(
        onTap: () => _showAllTemps(ss),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$plotted / ${devices.length}', style: UIs.text13Grey),
            UIs.width7,
            const Icon(Icons.list, size: 15, color: Colors.grey),
          ],
        ),
      );
    } else {
      note = null;
    }

    return CardX(
      child: ExpandTile(
        title: Text(libL10n.temperature),
        leading: const Icon(Icons.ac_unit, size: 20),
        initiallyExpanded: _getInitExpand(1),
        // The chart already carries whatever space its axis needs
        childrenPadding: EdgeInsets.symmetric(vertical: 10),
        trailing: note,
        children: [chart],
      ),
    );
  }

  Widget? _buildBatteries(ServerState si) {
    final ss = si.status;
    if (ss.batteries.isEmpty) return null;

    final children = ss.batteries.map(_buildBatteryItem).toList();
    final chart = _buildBatteryChart(si);
    if (chart != null) children.add(chart);

    return CardX(
      child: ExpandTile(
        title: Text(libL10n.battery),
        leading: const Icon(Icons.battery_charging_full, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(ss.batteries.length, 2),
        children: children,
      ),
    );
  }

  Widget _buildBatteryItem(Battery battery) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${battery.name}', style: UIs.text15),
              Text(
                '${battery.status.name} - ${battery.cycle}',
                style: UIs.text13Grey,
              ),
            ],
          ),
          Text(
            '${battery.percent?.toStringAsFixed(0)}%',
            style: UIs.text13Grey,
          ),
        ],
      ),
    );
  }

  Widget? _buildSensors(ServerState si) {
    final ss = si.status;
    if (ss.sensors.isEmpty) return UIs.placeholder;
    return CardX(
      child: ExpandTile(
        title: Text(libL10n.sensors),
        leading: const Icon(Icons.thermostat, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(ss.sensors.length, 2),
        children: ss.sensors.map(_buildSensorItem).toList(),
      ),
    );
  }

  Widget _buildSensorItem(SensorItem si) {
    if (si.summary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        child: Text(si.device),
      );
    }

    final itemW = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(si.device, style: UIs.text15),
            UIs.width7,
            Text('(${si.adapter.raw})', style: UIs.text13Grey),
          ],
        ),
        Text(si.summary!, style: UIs.text13Grey),
      ],
    ).expanded();

    return InkWell(
      onTap: () => _onTapSensorItem(si),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            itemW,
            UIs.width7,
            const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget? _buildPve(ServerState si) {
    final addr = si.spi.custom?.pveAddr;
    if (addr == null || addr.isEmpty) return null;
    return CardX(
      child: ListTile(
        title: const Text('PVE'),
        leading: const Icon(FontAwesome.server_solid, size: 17),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => PvePage.route.go(context, PvePageArgs(spi: si.spi)),
      ),
    );
  }

  /// What the BMC says, which is worth showing precisely when the host is not
  /// saying anything.
  ///
  /// Absent unless configured: a card that appeared on every server to say
  /// "not configured" would be a row of noise on the machines that have no BMC,
  /// which is most of them.
  Widget? _buildBmc(ServerState si) {
    if (si.spi.bmc == null) return null;
    final bmc = ref.watch(bmcProvider(si.spi));

    final subtitle = switch (bmc) {
      BmcState(failure: final failure?) => Text(
        _bmcFailureText(failure, bmc.failureDetail),
        style: UIs.textGrey,
      ),
      BmcState(hasData: false, isBusy: true) => Text(
        libL10n.loadingEllipsis,
        style: UIs.textGrey,
      ),
      _ => Text(_bmcPowerText(bmc.powerState), style: UIs.textGrey),
    };

    final children = <Widget>[];
    final system = bmc.topology?.system;
    if (system != null) {
      // The service's own property names, shown as it named them: they are
      // protocol identifiers, and translating them would invite drift between
      // what the card says and what the BMC's own interface says
      for (final (label, value) in [
        ('Model', system.model),
        ('BIOS', system.biosVersion),
        ('Serial', system.serial),
        ('Health', system.health),
      ]) {
        if (value == null || value.isEmpty) continue;
        children.add(
          ListTile(
            dense: true,
            title: Text(label, style: UIs.text13),
            trailing: Text(value, style: UIs.text13Grey),
          ),
        );
      }
    }

    final sensors = bmc.sensors;
    if (sensors.watts case final watts?) {
      children.add(
        ListTile(
          dense: true,
          title: Text(l10n.power, style: UIs.text13),
          trailing: Text('${watts.toStringAsFixed(0)} W', style: UIs.text13Grey),
        ),
      );
    }
    for (final reading in [...sensors.temperatures, ...sensors.fans]) {
      children.add(
        ListTile(
          dense: true,
          title: Text(reading.name, style: UIs.text13),
          trailing: Text(
            '${reading.value.toStringAsFixed(reading.unit == 'Cel' ? 1 : 0)}'
            '${reading.unit == 'Cel' ? '°C' : ' ${reading.unit ?? ''}'}',
            style: UIs.text13Grey,
          ),
        ),
      );
    }
    if (bmc.hasData) children.add(_buildBmcPower(si));

    // Said rather than left to look like the whole truth
    if (bmc.sensorsTruncated) {
      children.add(
        ListTile(
          dense: true,
          title: Text(l10n.bmcSensorsTruncated, style: UIs.text13Grey),
        ),
      );
    }

    // The same reason, for the same kind of cut: discovery takes the first of
    // each collection, so a blade enclosure showed node 1's power state with
    // nothing to say the other nodes existed — and a power action there
    // targets that node alone.
    if (bmc.topology?.hasMultipleSystems == true) {
      children.add(
        ListTile(
          dense: true,
          title: Text(l10n.bmcMultipleSystems, style: UIs.text13Grey),
        ),
      );
    }

    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.developer_board, size: 17),
        title: const Text('BMC'),
        subtitle: subtitle,
        initiallyExpanded: _getInitExpand(children.length),
        children: children,
      ),
    );
  }

  /// The power actions this particular service allows, and no others.
  ///
  /// Asked of `plan`, which resolves an intent against
  /// `ResetType@Redfish.AllowableValues`. An intent the service allows nothing
  /// for is not shown: offering a button that fails when pressed is worse than
  /// never having offered it, and `Nmi` and `PowerCycle` are advertised
  /// unimplemented often enough that this is not hypothetical.
  Widget _buildBmcPower(ServerState si) {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final available = [
      for (final intent in PowerIntent.values)
        if (notifier.plan(intent) != null) intent,
    ];
    if (available.isEmpty) return UIs.placeholder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final intent in available)
            OutlinedButton(
              onPressed: () => _onTapBmcPower(si, intent),
              child: Text(_bmcIntentText(intent)),
            ),
        ],
      ),
    );
  }

  Future<void> _onTapBmcPower(ServerState si, PowerIntent intent) async {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final request = notifier.plan(intent);
    if (request == null) return;

    // The one thing in this app that can take a running server away from
    // whoever is on it. The dialog names the ResetType actually chosen, not the
    // intent, because they differ — a "restart" is ForceRestart on hardware
    // that has no graceful one, and that is worth seeing before agreeing.
    final ok = await context.showRoundDialog<bool>(
      title: _bmcIntentText(intent),
      child: Text(l10n.bmcPowerConfirm(si.spi.name, request.resetType)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;

    final result = await notifier.power(intent);
    switch (result) {
      case BmcPowerResult.confirmed:
        Toast.success(l10n.bmcPowerDone);
      // Accepted is not done, and saying so would be reporting the request
      // back as though it were the result
      case BmcPowerResult.accepted:
        Toast.warn(l10n.bmcPowerAccepted);
      case BmcPowerResult.notSupported:
        Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
      case BmcPowerResult.failed:
        Toast.error(libL10n.fail);
    }
  }

  String _bmcIntentText(PowerIntent intent) => switch (intent) {
    PowerIntent.on => l10n.bmcPowerOnAction,
    PowerIntent.gracefulShutdown => l10n.bmcShutdown,
    PowerIntent.forceOff => l10n.bmcForceOff,
    PowerIntent.restart => l10n.bmcRestart,
    PowerIntent.powerCycle => l10n.bmcPowerCycle,
  };

  String _bmcPowerText(PowerState state) => switch (state) {
    PowerState.on => l10n.bmcPowerOn,
    PowerState.off => l10n.bmcPowerOff,
    PowerState.poweringOn || PowerState.poweringOff => libL10n.loadingEllipsis,
    PowerState.paused => 'Paused',
    PowerState.unknown => libL10n.unknown,
  };

  String _bmcFailureText(RedfishFailure failure, String? detail) =>
      switch (failure) {
        RedfishFailure.certificateRejected => l10n.bmcCertRejected,
        RedfishFailure.unauthorized => l10n.bmcUnauthorized,
        RedfishFailure.noCredential => l10n.bmcAccountMissing,
        RedfishFailure.notAService => l10n.bmcNotAService,
        RedfishFailure.noSystem => l10n.bmcNoSystem,
        // Names the resource, because it is an answer about one resource
        RedfishFailure.forbidden => '${libL10n.fail}: ${detail ?? ''}',
        RedfishFailure.unreachable => detail ?? libL10n.fail,
      };

  Widget? _buildCustomCmd(ServerState si) {
    final ss = si.status;
    if (ss.customCmds.isEmpty) return null;
    return CardX(
      child: ExpandTile(
        leading: const Icon(MingCute.command_line, size: 17),
        title: Text(l10n.customCmd),
        initiallyExpanded: _getInitExpand(ss.customCmds.length),
        children: ss.customCmds.entries.map(_buildCustomCmdItem).toList(),
      ),
    );
  }

  Widget _buildCustomCmdItem(MapEntry<String, String> cmd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: KvRow(
        k: cmd.key,
        v: cmd.value,
        vBuilder: () {
          if (!cmd.value.contains('\n')) return null;
          return GestureDetector(
            onTap: () => _onTapCustomItem(cmd),
            child: const Icon(Icons.info_outline, size: 17, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedText(Key key, String text, TextStyle style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 277),
      child: Text(key: key, text, style: style, textScaler: _textFactor),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
