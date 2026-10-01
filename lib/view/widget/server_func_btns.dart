import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/iperf.dart';
import 'package:server_box/view/page/port_forward.dart';
import 'package:server_box/view/page/process.dart';
import 'package:server_box/view/page/scheduled_tasks.dart';
import 'package:server_box/view/page/services.dart';
import 'package:server_box/view/page/ssh/snippet_run.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/users.dart';
import 'package:server_box/view/widget/edge_fade_scroll.dart';
import 'package:server_box/view/widget/server_power.dart';

/// One entry of the function row, and whether this connection can serve it.
/// [reason] says why it is not [available], in the words a tap and a hover
/// show; null when it is.
typedef ServerFuncEntry = ({ServerFuncBtn btn, bool available, String? reason});

/// Left over on either side of the bar, so the page it floats above is still
/// visible past it and it never reads as a second edge to the window.
const kFuncBarSideRoom = 100.0;

/// One row of buttons with their labels: a 17pt icon over a line of 11pt text,
/// plus the buttons' own inset and the row's, and a little over.
const kFuncBarHeight = 56.0;

/// What a page keeps clear below its last card, so the bar is never over
/// something that cannot be scrolled out from under it.
const kFuncBarInset = kFuncBarHeight + 26;

/// The row of things that can be done to a server, floating over its page.
///
/// Takes the entries rather than working them out, so that what is drawn is
/// the same list the page decided there was room for.
class ServerFuncBar extends StatelessWidget {
  const ServerFuncBar({super.key, required this.spi, required this.btns});

  final Spi spi;
  final List<ServerFuncEntry> btns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cons) => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: ConstrainedBox(
            // The row takes the width it needs up to this; beyond it, it
            // scrolls. Stretched across a desktop window it would stop being a
            // group of buttons and become a band across the page.
            constraints: BoxConstraints(
              maxWidth: (cons.maxWidth - kFuncBarSideRoom).clamp(
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
                height: kFuncBarHeight,
                child: ServerFuncBtns(spi: spi, btns: btns),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The row of buttons, as a list that is added to and taken from rather than
/// redrawn.
///
/// The row outlives the machine it acts on — the server tab floats one over
/// every machine it opens — so what changes when the machine does is the list,
/// not the widget. An entry the new machine cannot serve leaves its place and
/// takes one at the end; the entries between it and there close the gap by
/// sliding, because that is what happens to a list when something is removed
/// from the middle of it. Redrawn instead, the whole row said every button had
/// changed when one had.
class ServerFuncBtns extends StatefulWidget {
  const ServerFuncBtns({super.key, required this.spi, required this.btns});

  final Spi spi;

  /// Every entry in the user's order, from [serverFuncBtnsFor], the ones this
  /// connection cannot serve last.
  ///
  /// Passed in rather than worked out here, because the page that hosts this
  /// row has to know whether there will be any of them before it lays out room
  /// for it. Answering that question twice is how the two answers came to
  /// disagree.
  final List<ServerFuncEntry> btns;

  @override
  State<ServerFuncBtns> createState() => _ServerFuncBtnsState();
}

/// How long one entry takes to open its place in the row, or to close it.
const _kSlotDuration = Durations.medium1;

/// One entry's place in the row, and how much of it there is.
///
/// Identified by the button, never by where it sits: the same entry at a
/// different index is one that moved, and the whole point of this is to tell
/// that apart from one that was replaced.
class _Slot {
  _Slot(this.btn, this.entry, this.ctrl, this.onGone) {
    curve = CurvedAnimation(
      parent: ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    ctrl.addStatusListener(_onStatus);
  }

  final ServerFuncBtn btn;
  ServerFuncEntry entry;
  final AnimationController ctrl;
  late final CurvedAnimation curve;

  /// Called once the place has finished closing, which is the only point at
  /// which this can be taken out of the row without anything jumping.
  final void Function(_Slot) onGone;

  /// Whether this is on its way out. An entry asked for again while it is
  /// closing turns around rather than being built afresh.
  bool leaving = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && leaving) onGone(this);
  }

  void dispose() {
    ctrl.removeStatusListener(_onStatus);
    curve.dispose();
    ctrl.dispose();
  }
}

class _ServerFuncBtnsState extends State<ServerFuncBtns>
    with TickerProviderStateMixin {
  /// The row as drawn: what is wanted, in the order it is wanted, with what is
  /// on its way out left at the index it had.
  final _slots = <_Slot>[];

  /// [_kSlotDuration], or shorter with less motion asked for: a place opening
  /// pushes the rest of the row along.
  var _slotDuration = _kSlotDuration;

  @override
  void initState() {
    super.initState();
    // The first row is not an arrival. A bar that dealt its own buttons out
    // every time it appeared would do it once per machine opened.
    for (final e in widget.btns) {
      _slots.add(_Slot(e.btn, e, _controller(1), _remove));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slotDuration = context.motion(_kSlotDuration);
    for (final slot in _slots) {
      slot.ctrl.duration = _slotDuration;
    }
  }

  @override
  void didUpdateWidget(ServerFuncBtns old) {
    super.didUpdateWidget(old);
    if (listEquals(old.btns, widget.btns)) return;
    setState(_sync);
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  AnimationController _controller(double value) =>
      AnimationController(vsync: this, duration: _slotDuration, value: value);

  void _remove(_Slot slot) {
    if (!mounted) return;
    setState(() {
      _slots.remove(slot);
      slot.dispose();
    });
  }

  void _sync() {
    final wanted = widget.btns;
    final wantedBtns = {for (final e in wanted) e.btn};

    // Anything no longer asked for closes its place where it stands, rather
    // than jumping to the end of the row first.
    final closing = <int, _Slot>{};
    for (final (at, slot) in _slots.indexed) {
      if (wantedBtns.contains(slot.btn)) continue;
      closing[at] = slot;
      if (slot.leaving) continue;
      slot.leaving = true;
      slot.ctrl.reverse();
    }

    final next = <_Slot>[];
    for (final e in wanted) {
      final live = _slots.firstWhereOrNull((s) => s.btn == e.btn);
      if (live == null) {
        next.add(_Slot(e.btn, e, _controller(0), _remove)..ctrl.forward());
        continue;
      }
      // Including one that was closing: asked for again, it opens back up from
      // wherever it had got to.
      live.entry = e;
      live.leaving = false;
      live.ctrl.forward();
      next.add(live);
    }

    // The ones still closing go back in at the index they held, so the gap
    // they leave is the gap that closes.
    for (final at in closing.keys.toList()..sort()) {
      next.insert(at.clamp(0, next.length), closing[at]!);
    }

    _slots
      ..clear()
      ..addAll(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_slots.isEmpty) return UIs.placeholder;

    // It has to say how wide it is. A shrink-wrapping viewport
    // takes the width of what is in it and no more — and, once whatever holds
    // it runs out of room to give, scrolls instead of overflowing. One line
    // either way.
    //
    // Faded at whichever end it is scrolling past, the way the settings tabs
    // are: a button cut in half by the bar's edge reads as the last one, and
    // this row is the only way to reach half of what a server can do.
    return EdgeFadeScroll(
      builder: (context, controller) => ListView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        // Each slot carries the gap after it, so the gap closes with the slot
        // rather than being left behind as a hole. That is one gap too many at
        // the end, taken back off the right inset.
        padding: const EdgeInsets.fromLTRB(
          _kPad,
          _kVPadTop,
          _kPad - _kGap,
          _kVPadBottom,
        ),
        children: [
          for (final slot in _slots)
            SizeTransition(
              key: ValueKey(slot.btn),
              axis: Axis.horizontal,
              // From its leading edge: a place opening from its middle pushes
              // the row both ways at once.
              alignment: Alignment.centerLeft,
              sizeFactor: slot.curve,
              child: FadeTransition(
                opacity: slot.curve,
                child: Padding(
                  padding: const EdgeInsets.only(right: _kGap),
                  child: Consumer(
                    builder: (_, ref, _) =>
                        widget._buildItem(context, slot.entry, ref),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Between two buttons.
const _kGap = 7.0;

/// Between the buttons and the ends of the row.
///
/// The buttons carry a little of their own, so this is what is left to make
/// the row read as a group with a border around it rather than as buttons that
/// happen to be near an edge.
const _kPad = 8.0;

/// Above the icons. The buttons bring their own tap target, which is most of
/// the row's height; this is only what keeps them off the border.
const _kVPadTop = 5.0;

/// Below the labels, and less than [_kVPadTop]: a line of text carries its own
/// space under it, so matching the two reads as more room below than above.
const _kVPadBottom = 1.0;

extension ServerFuncBtnsBuild on ServerFuncBtns {
  Widget _buildItem(
    BuildContext context,
    ServerFuncEntry entry,
    WidgetRef ref,
  ) {
    final e = entry.btn;
    // An entry this connection cannot serve stays on the row, dimmed and at
    // the end of it, and says so when tapped. Dropped, it left a row whose
    // length changed with the server and no answer to "where did the terminal
    // go" — which is the agent's doing, not this app's, and is worth one
    // sentence.
    final available = entry.available;
    // What would make it available, where the agent's operator can: the same
    // words on hover and on a tap.
    final reason = available
        ? null
        : entry.reason ?? l10n.funcUnavailableFmt(e.toStr);
    // The label is part of the button, not a caption under one. An
    // `IconButton` with a `Text` beneath it left the word inert, so half of
    // what looks like a target did nothing when tapped.
    final item = InkWell(
      onTap: reason == null
          ? () => runServerFunc(e, spi, context, ref)
          : () => Toast.show(reason),
      borderRadius: BorderRadius.circular(10),
      // Animated, because an entry that keeps its place and only changes what
      // it can do is the one case where nothing about the row moves: without
      // this the single thing that did change is the one thing that jumped.
      child: AnimatedOpacity(
        opacity: available ? 1 : 0.4,
        duration: _kSlotDuration,
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.icon, size: 17),
              const SizedBox(height: 4),
              // One line whatever it is given. A place in this row closes by
              // being clipped to nothing, and a label that answered a narrow
              // box by wrapping instead would make the bar taller on the way
              // — which is the one measurement of it that has to hold.
              Text(
                e.toStr,
                style: UIs.text11Grey,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ],
          ),
        ),
      ),
    );
    return reason == null ? item : Tooltip(message: reason, child: item);
  }
}

/// Which entries a connection can actually serve, in the order the user
/// arranged them.
///
/// A function rather than a method on the row, because the page that hosts the
/// row needs the same answer before it builds one — and it used to ask a
/// coarser question of its own (`capabilities.terminal`), which hid the whole
/// row on a monitor server whose agent serves files but grants no shell. That
/// server could still be browsed from the Files tab, so the row was the only
/// thing missing, and nothing said why.
List<ServerFuncEntry> serverFuncBtnsFor(
  Spi spi,
  MonitorRemoteAccess? granted,
) {
  final ordered = () {
    try {
      final vals = <ServerFuncBtn>[];
      final list = Stores.setting.serverFuncBtns.fetch();
      for (final stored in list) {
        final btn = ServerFuncBtn.byStored(stored);
        if (btn != null) vals.add(btn);
      }
      return vals;
    } catch (e) {
      return ServerFuncBtn.values;
    }
  }();

  // An entry the connection cannot serve would open a page that can never
  // load, so it is dimmed and moved to the end of the row rather than opened
  // or dropped: nothing the user could do here would make it work — it is the
  // agent's decision, or the transport's — but a row that silently gets
  // shorter leaves no way to ask what happened to it.
  //
  // The row is one line at every width and scrolls, so the entries that follow
  // cost nothing but the scroll they are past.
  final available = <ServerFuncEntry>[];
  final rest = <ServerFuncEntry>[];
  for (final btn in ordered) {
    final ok = btn.availableOn(spi, granted);
    final entry = (
      btn: btn,
      available: ok,
      reason: ok ? null : btn.unavailableReason(spi, granted),
    );
    (entry.available ? available : rest).add(entry);
  }
  return [...available, ...rest];
}

/// Does what one entry of the function row does.
///
/// A function rather than a method on the row, because the row is not the only
/// place a server's functions are reached from: the list offers the same set
/// behind a long press, and two copies of "what Terminal does" is how the two
/// come to do different things.
void runServerFunc(
  ServerFuncBtn value,
  Spi spi,
  BuildContext context,
  WidgetRef ref,
) async {
    switch (value) {
      case ServerFuncBtn.files:
        // Only the SFTP backend needs a connection opened first. A server
        // whose files come from its agent's API has none to open, and asking
        // for one fails on a host whose sshd this app cannot reach — which is
        // the case that API exists for. The same predicate `ServerFilePage`
        // picks the backend with, so the connection made here is the one the
        // page then uses.
        // Nor does this device, whose files are read in place.
        if (!spi.local &&
            !serverFilesUseAgent(
              spi,
              ref.read(serverProvider(spi.id)).remoteAccess,
            ) &&
            !await _ensureSshClient(context, spi.id, ref)) {
          return;
        }
        if (!context.mounted) return;
        // Into the file tab rather than over whatever is on screen, so two
        // servers can be open at once and neither is lost by opening the other.
        ref.read(sftpRequestsProvider.notifier).add(spi);
        ref.read(homeTabRequestProvider.notifier).go(AppTab.file);
        break;
      case ServerFuncBtn.snippet:
        final snippetState = ref.read(snippetProvider);
        if (snippetState.snippets.isEmpty) {
          Toast.show(libL10n.empty);
          return;
        }
        final snippets = await context.showPickWithTagDialog<Snippet>(
          title: libL10n.snippet,
          tags: snippetState.tags.vn,
          itemsBuilder: (e) {
            if (e == TagSwitcher.kDefaultTag) {
              return snippetState.snippets;
            }
            return snippetState.snippets
                .where((element) => element.tags?.contains(e) ?? false)
                .toList();
          },
          display: (e) => e.name,
        );
        if (snippets == null || snippets.isEmpty) return;
        final snippet = snippets.firstOrNull;
        if (snippet == null) return;
        if (!context.mounted) return;
        await confirmAndRunSnippet(context, ref, spi, snippet);
        break;
      case ServerFuncBtn.container:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        unawaited(ContainerPage.route.go(context, args));
        break;
      case ServerFuncBtn.process:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        unawaited(ProcessPage.route.go(context, args));
        break;
      case ServerFuncBtn.terminal:
        _gotoSSH(spi, ref);
        break;
      case ServerFuncBtn.iperf:
        // Only a form until it is submitted, and what it opens then is a
        // terminal — so nothing to connect here either.
        final args = SpiRequiredArgs(spi);
        unawaited(IPerfPage.route.go(context, args));
        break;
      case ServerFuncBtn.systemd:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        unawaited(ServicesPage.route.go(context, args));
        break;
      case ServerFuncBtn.power:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        // One button for three commands: three entries of their own would be
        // three of the few this row has space for, spent on the same thing.
        await ServerPower.pick(context, ref, spi);
        break;
      case ServerFuncBtn.portForward:
        // No connection first: a forward is dialled over SSH or the agent's
        // relay when it starts, and says there why it could not.
        final args = SpiRequiredArgs(spi);
        unawaited(PortForwardPage.route.go(context, args));
        break;
      case ServerFuncBtn.users:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        unawaited(UsersPage.route.go(context, args));
        break;
      case ServerFuncBtn.scheduledTasks:
        if (!await _ensureExec(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        unawaited(ScheduledTasksPage.route.go(context, args));
        break;
      case ServerFuncBtn.remoteDesktop:
        // A monitor-backed server has nothing to connect here: the agent dials
        // the target when the session opens, and the profile page works without
        // it. Asking for an SSH client whenever SSH happens to be configured
        // would refuse the transport this button was just made available on —
        // a server carrying both can fall through to the agent, and only
        // `_openTunnel` knows which one the session will end up using.
        final hasOtherWayIn = spi.sshOn == null || spi.monitorOn != null;
        if (!hasOtherWayIn && !await _ensureSshClient(context, spi.id, ref)) {
          return;
        }
        if (!context.mounted) return;
        // Into the tab, on this server, rather than a page of its own over the
        // detail page: sessions live in the tab, and a pushed copy of its list
        // had nowhere to go back to.
        ref.read(remoteDesktopServerRequestProvider.notifier).go(spi.id);
        ref.read(homeTabRequestProvider.notifier).go(AppTab.remoteDesktop);
        break;
  }
}

/// Opens a terminal on [spi] in the SSH tab.
///
/// One way in. A terminal opened from here used to be a page pushed over
/// whatever was on screen, unknown to the SSH tab and its sessions, so the
/// same server opened twice gave two shells that could not see each other and
/// only one of which survived a relaunch.
void _gotoSSH(Spi spi, WidgetRef ref) {
  ref.read(terminalRequestsProvider.notifier).add(spi);
  ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
}

/// Opens whatever connection running a command needs, before opening a page
/// that runs one.
///
/// Which transport that turns out to be is [ServerNotifier.ensureExec]'s
/// business — over SSH it connects a client, through a monitor agent there is
/// nothing to connect, so for that transport this only reports what the page
/// would have reported anyway. It is not a permission check: an agent that has
/// since switched its grant off answers 403 to the first command, inside the
/// page. Connecting here rather than only reporting a missing connection: the
/// SSH path builds its client during the status fetch, so a server the user
/// has not looked at yet has none, and "wait for the connection" would be
/// advice that never comes true.
Future<bool> _ensureExec(BuildContext context, String id, WidgetRef ref) {
  return _ensure(context, id, ref, (n) => n.ensureExec());
}

/// Makes sure an SSH connection exists before opening a page that needs the
/// byte streams only it can carry — SFTP and port forwarding.
///
/// Only ever called for a server whose [ServerCapabilities.byteStream] is
/// true: port forwarding is hidden without it, and the file entry asks before
/// calling this, since it is also offered where the files arrive over the
/// agent's own API and there is no stream to open.
Future<bool> _ensureSshClient(BuildContext context, String id, WidgetRef ref) {
  return _ensure(context, id, ref, (n) => n.ensureShellClient());
}

/// Returns false — after telling the user why — when [connect] could not.
/// Callers must re-check `context.mounted` before navigating, since this can
/// await a real connection attempt.
Future<bool> _ensure(
  BuildContext context,
  String id,
  WidgetRef ref,
  Future<void> Function(ServerNotifier) connect,
) async {
  final notifier = ref.read(serverProvider(id).notifier);

  // Said only when there is going to be a connection — a transport with no
  // persistent session never waits for one, so announcing it there put "wait
  // for the connection" on screen at the same moment the page it was about
  // opened.
  if (ref.read(serverProvider(id)).execWillConnect && context.mounted) {
    Toast.show(l10n.waitConnection);
  }
  try {
    await connect(notifier);
    return true;
  } catch (e, s) {
    Loggers.app.warning('Connect $id for a server function', e, s);
    if (context.mounted) {
      Toast.error(
        e is SSHErr ? (e.message ?? e.type.name) : e.toString(),
      );
    }
    return false;
  }
}

/// Shows [snippet] as it will run on [spi], and runs it only once the user
/// confirms — behind a countdown, since this is what a `serverbox://` link
/// reaches too, and a link can come from anywhere.
///
/// The function row picks the snippet first; a link names it.
Future<void> confirmAndRunSnippet(
  BuildContext context,
  WidgetRef ref,
  Spi spi,
  Snippet snippet,
) async {
  final fmted = snippet.fmtWithSpi(spi);
  final sure = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: SingleChildScrollView(
      child: SimpleMarkdown(data: '```shell\n$fmted\n```'),
    ),
    actions: [
      CountDownBtn(
        onTap: () => context.popDialog(true),
        text: libL10n.run,
        afterColor: Colors.red,
      ),
    ],
  );
  if (sure != true) return;
  if (!context.mounted) return;
  // Run here rather than on a page pushed over this one: a snippet is
  // usually one command, and watching it finish should not mean leaving
  // the server you are looking at. No pre-check — the dialog connects
  // and reports its own failures, the same as tapping
  // [ServerFuncBtn.terminal].
  final session = await showSnippetRun(
    context,
    ref,
    spi: spi,
    snippet: snippet,
  );
  // Answered "carry on with it": the shell and everything it printed
  // move to a tab, still connected.
  if (session == null) return;
  // Nowhere left to send it. Hanging up beats leaving a shell running
  // with nothing that can ever show it again.
  if (!context.mounted) {
    session.close();
    return;
  }
  ref.read(terminalRequestsProvider.notifier).add(spi, session: session);
  ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
}
