import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server_picker.dart' as picker;
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/plugin/http.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/widget/plugin/dialog.dart';

/// The app doing what a plugin asked for. PLUGINS.md section 4.3.
///
/// Everything here is the app's existing way of doing the thing — the server
/// picker a snippet uses, the dialog the settings pages use, the toast
/// everything uses. A plugin gets no second implementation of any of them,
/// which is what keeps a plugin's dialog looking like the app's and behaving
/// the way the user expects.
///
/// The permission checks are not here and never were: the runtime installs an
/// ungranted function as a throwing stub. What is here is the work.
class AppPluginHostOps implements PluginHostOps {
  const AppPluginHostOps(this.ref);

  final Ref ref;

  /// Where a dialog goes.
  ///
  /// The root navigator, because a plugin's surface may be inside a pane or a
  /// tab and a dialog raised on that navigator would be trapped in it. Null
  /// when nothing is on screen, which a plugin has to be able to be told
  /// rather than left waiting for.
  BuildContext? get _context => AppNavigator.context;

  @override
  Future<PluginFetchResult> fetch({
    required String url,
    required String method,
    Map<String, String> headers = const {},
    String? body,
    String bodyEncoding = 'utf8',
    String? pinSha256,
    bool probeCert = false,
    Duration? timeout,
  }) {
    final at = timeout ?? PluginHttp.defaultTimeout;
    if (probeCert) {
      final uri = Uri.parse(url);
      return PluginHttp.probe(
        uri.host,
        // The scheme's own, so a plugin naming `https://bmc.example` does not
        // have to say 443 for the review step and nothing else.
        uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443),
        timeout: at,
      );
    }
    return PluginHttp.fetch(
      url: url,
      method: method,
      headers: headers,
      body: body,
      bodyEncoding: bodyEncoding,
      pinSha256: pinSha256,
      timeout: at,
    );
  }

  /// How long a plugin's command may run when it named no `timeoutMs`.
  ///
  /// There has to be one. Without it a plugin whose command never returns
  /// holds a host call until the runtime's own ceiling and then reports a
  /// timeout that names the wrong thing — and a plugin author has no reason to
  /// think an absent field means "for ever".
  static const defaultExecTimeout = Duration(minutes: 5);

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
    Future<void>? cancel,
  }) async {
    // `ensureExec` is the one place that decides how a command reaches a
    // server — SSH or a monitor agent's `/exec`, with the fallback — so a
    // plugin's command travels the same way the app's own do and needs to know
    // about neither.
    final exec = await ref.read(serverProvider(serverId).notifier).ensureExec();

    // One future for both, because the transport takes one and the two mean
    // the same thing to it. Which of them fired is remembered here, since that
    // is the whole difference the plugin sees.
    final stop = Completer<void>();
    var end = PluginExecEnd.finished;
    void stopWith(PluginExecEnd why) {
      if (stop.isCompleted) return;
      end = why;
      stop.complete();
    }

    // `timeoutMs` used to be accepted and then dropped: `run` was called with
    // no `cancel` at all, so a plugin asking for two minutes got whatever the
    // transport happened to allow. It is honoured here, and it is the only
    // bound a plugin that never calls `sb.server.cancel` has.
    final timer = Timer(
      timeout ?? defaultExecTimeout,
      () => stopWith(PluginExecEnd.timedOut),
    );
    // Unawaited on purpose: a cancel that never comes must not hold the run.
    unawaited(cancel?.then((_) => stopWith(PluginExecEnd.cancelled)));

    try {
      final result = await exec.run(script, cancel: stop.future);
      return PluginExecResult(
        code: result.exitCode ?? -1,
        stdout: result.stdout,
        stderr: result.stderr,
        end: end,
        // The transport's own answer, never a guess: see [ExecCancelKind].
        stoppedCommand: PluginExecResult.stoppedBy(exec.cancelKind),
      );
    } finally {
      timer.cancel();
    }
  }

  @override
  void toast(String text, String kind) {
    final level = switch (kind) {
      'success' => ToastLevel.success,
      'warn' => ToastLevel.warn,
      'error' => ToastLevel.error,
      _ => ToastLevel.none,
    };
    Toast.show(text, level: level);
  }

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
    PluginNode? node,
    PluginL10n strings = PluginL10n.empty,
    bool sheet = false,
  }) async {
    final context = _context;
    if (context == null) return (cancelled: true, values: const <String, String>{});

    if (node != null) {
      return _promptWithNode(
        context,
        title: title,
        message: message,
        node: node,
        strings: strings,
        sheet: sheet,
      );
    }

    final controllers = {
      for (final field in fields)
        field.key: TextEditingController(text: field.value),
    };
    try {
      final ok = await context.showRoundDialog<bool>(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message, style: UIs.textGrey),
              UIs.height13,
            ],
            for (final field in fields)
              Input(
                controller: controllers[field.key],
                label: field.label,
                obscureText: field.secret,
              ),
          ],
        ),
        actions: Btnx.cancelOk,
      );
      // The dialog's own buttons close the dialog; this is the caller, and it
      // reads the answer rather than acting inside one of them.
      if (ok != true) {
        return (cancelled: true, values: const <String, String>{});
      }
      return (
        cancelled: false,
        values: {
          for (final e in controllers.entries) e.key: e.value.text,
        },
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  /// The general case: a body the plugin drew.
  ///
  /// The values come back keyed by each control's `change` message, because
  /// the plugin is blocked waiting for this and cannot process events while it
  /// is up — see `PluginNodeDialog`.
  Future<PluginPromptResult> _promptWithNode(
    BuildContext context, {
    required String title,
    required PluginNode node,
    required PluginL10n strings,
    String? message,
    bool sheet = false,
  }) async {
    final key = GlobalKey<PluginNodeDialogState>();
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null) ...[
          Text(message, style: UIs.textGrey),
          UIs.height13,
        ],
        PluginNodeDialog(key: key, node: node, strings: strings),
      ],
    );

    final ok = sheet
        ? await _sheet(context, title: title, body: body)
        : await context.showRoundDialog<bool>(
            title: title,
            child: body,
            actions: Btnx.cancelOk,
          );
    // The values are read from the state before the route is gone; `values` is
    // a copy, so nothing here holds a widget's map after it is disposed.
    final values = key.currentState?.values ?? const <String, String>{};
    if (ok != true) return (cancelled: true, values: const <String, String>{});
    return (cancelled: false, values: values);
  }

  /// The same thing from the bottom, which is where a form belongs on a phone:
  /// the keyboard has somewhere to go, and the sheet is as tall as it needs.
  Future<bool?> _sheet(
    BuildContext context, {
    required String title,
    required Widget body,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 17,
          right: 17,
          top: 17,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 17,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: UIs.text15Bold),
            UIs.height13,
            Flexible(child: body),
            UIs.height13,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 7,
              children: [
                Btn.text(text: libL10n.cancel, onTap: () => ctx.pop(false)),
                Btn.text(text: libL10n.ok, onTap: () => ctx.pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Future<String?> pickServer() async {
    final context = _context;
    if (context == null) return null;
    // The app's own picker, so somebody with thirty servers gets the search
    // and the tags rather than a dropdown a plugin would have had to describe.
    final spi = await picker.pickServer(context);
    return spi?.id;
  }

  @override
  Future<String?> clipboardRead() => Pfs.paste();

  @override
  Future<void> clipboardWrite(String text) async => Pfs.copy(text);

  @override
  Future<List<PluginServerSummary>> listServers() async {
    // The order the server tab shows them in, so a plugin's fleet view and the
    // app's own list read the same way round.
    final state = ref.read(serversProvider);
    return [
      for (final id in state.serverOrder)
        if (state.servers[id] case final spi?) (id: id, name: spi.name),
    ];
  }

  @override
  Future<void> openTerminal(
    String serverId, {
    String? cmd,
    bool run = false,
  }) async {
    final context = _context;
    if (context == null) return;
    final spi = ref.read(serversProvider).servers[serverId];
    if (spi == null) return;
    await SSHPage.route.go(
      context,
      SshPageArgs(
        source: ServerSource(spi),
        initCmd: cmd,
        // A plugin asking for a command to be *sent* is asking for something
        // the user did not type. The default leaves it in the prompt, which is
        // the same promise the app's own package-upgrade button makes.
        initCmdRun: run,
      ),
    );
  }

  @override
  Future<void> openServer(String serverId) async {
    final context = _context;
    if (context == null) return;
    final spi = ref.read(serversProvider).servers[serverId];
    if (spi == null) return;
    await ServerDetailPage.route.go(context, SpiRequiredArgs(spi));
  }

  @override
  Future<void> goTab(String tab) async {
    final target = AppTab.values.firstWhereOrNull((t) => t.name == tab);
    // A tab this build has no case for. Silently going nowhere would leave a
    // plugin thinking it had navigated.
    if (target == null) throw ArgumentError.value(tab, 'tab', 'no such tab');
    // A request rather than a command: the home page owns its page controller
    // and the animation that goes with it.
    ref.read(homeTabRequestProvider.notifier).go(target);
  }

  @override
  void crumb(String pluginId, String name, String level) {
    // The plugin's name and the level, and the plugin's id — never anything
    // the plugin passed as a value, because there is nowhere for it to.
    Diag.crumb(
      SbDiag.plugin,
      name,
      level: level == 'warning' ? DiagLevel.warning : DiagLevel.info,
      data: {'plugin': pluginId},
    );
  }
}
