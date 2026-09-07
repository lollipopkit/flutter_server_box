import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server_picker.dart' as picker;
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/detail/view.dart';

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
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  }) async {
    // `ensureExec` is the one place that decides how a command reaches a
    // server — SSH or a monitor agent's `/exec`, with the fallback — so a
    // plugin's command travels the same way the app's own do and needs to know
    // about neither.
    final exec = await ref.read(serverProvider(serverId).notifier).ensureExec();
    final result = await exec.run(script);
    return (
      code: result.exitCode ?? -1,
      stdout: result.stdout,
      stderr: result.stderr,
    );
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
  }) async {
    final context = _context;
    if (context == null) return (cancelled: true, values: const <String, String>{});

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
