import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

/// Suspending, shutting down or rebooting a server.
///
/// Shared because two places offer it — the flipped server card and the
/// function-button row — and none of the interesting part is the button: the
/// confirmation, the sudo password that turns out to be needed, and reading
/// the result rather than assuming it worked.
abstract final class ServerPower {
  /// The three, in the order they get less drastic to be wrong about.
  static const funcs = [
    ShellFunc.suspend,
    ShellFunc.reboot,
    ShellFunc.shutdown,
  ];

  static String label(ShellFunc func) => switch (func) {
    ShellFunc.suspend => libL10n.suspend,
    ShellFunc.reboot => libL10n.reboot,
    ShellFunc.shutdown => libL10n.shutdown,
    _ => func.name,
  };

  static IconData icon(ShellFunc func) => switch (func) {
    ShellFunc.suspend => Icons.stop,
    ShellFunc.reboot => Icons.restart_alt,
    ShellFunc.shutdown => Icons.power_off,
    _ => Icons.power_settings_new,
  };

  /// Asks which of the three, then does it.
  ///
  /// For the function-button row, which has one button for all three — three
  /// buttons of its own would be three of the eight entries a user can fit on
  /// that row spent on the same thing.
  static Future<void> pick(
    BuildContext context,
    WidgetRef ref,
    Spi spi,
  ) async {
    final func = await context.showPickSingleDialog<ShellFunc>(
      title: l10n.power,
      items: funcs,
      display: label,
    );
    if (func == null || !context.mounted) return;
    await confirmAndRun(context, ref, spi, func);
  }

  /// Confirms, then runs it.
  static Future<void> confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    Spi spi,
    ShellFunc func,
  ) async {
    // Said once, and before the confirmation rather than after it: it is a
    // reason someone might answer no.
    if (func == ShellFunc.suspend && Stores.setting.showSuspendTip.fetch()) {
      await context.showRoundDialog(
        title: libL10n.attention,
        child: Text(l10n.suspendTip),
      );
      Stores.setting.showSuspendTip.put(false);
      if (!context.mounted) return;
    }

    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${label(func)} ${libL10n.server}(${spi.name})'),
      ),
      actions: Btnx.cancelOk,
    );
    if (sure != true || !context.mounted) return;
    await _run(context, ref, spi, func);
  }

  static Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Spi spi,
    ShellFunc func,
  ) async {
    try {
      final notifier = ref.read(serverProvider(spi.id).notifier);
      // It is the *script* these run, so the script has to be there: a monitor
      // server's status never writes one, and a shell that cannot find it
      // exits 127 quietly, which reads as a machine that ignored the request.
      final exec = await notifier.ensureScriptExec();
      final cmd = func.exec(
        spi.id,
        systemType: ref.read(serverProvider(spi.id)).status.system,
        customDir: spi.custom?.scriptDir,
      );

      // Tried without one first. The script only reaches for `sudo` when the
      // account is not root, and an account with NOPASSWD needs nothing after
      // that — asking up front would put a password prompt in front of
      // everyone to serve the ones who need it.
      var result = await exec.runWithSudo(cmd);
      if (result.exitCode == kSudoPasswordRejected) {
        if (!context.mounted) return;
        final pwd = await _askPassword(context, spi);
        // Closing the prompt is an answer: they did not want to after all.
        if (pwd == null) return;
        result = await exec.runWithSudo(cmd, password: pwd);
      }

      // Checked rather than assumed: powering a machine down and being told
      // nothing is indistinguishable from it having worked, right up until the
      // status keeps refreshing.
      if (!result.succeeded && context.mounted) {
        final said = result.combined.trim();
        context.showSnackBar(said.isEmpty ? libL10n.fail : said);
      }
    } catch (e, s) {
      Loggers.app.warning('${func.name} ${spi.name}', e, s);
      if (context.mounted) context.showSnackBar('$e');
    }
  }

  static Future<String?> _askPassword(BuildContext context, Spi spi) async {
    final remember = Stores.setting.rememberPwdInMem.fetch();
    final pwd = await context.showPwdDialog(
      title: libL10n.pwd,
      label: spi.ssh?.user ?? '',
      // Its own key rather than the SSH one: sudo's password and the account's
      // SSH password are not always the same thing.
      id: '${spi.id}_sudo',
      remember: remember,
    );
    return (pwd == null || pwd.isEmpty) ? null : pwd;
  }
}
