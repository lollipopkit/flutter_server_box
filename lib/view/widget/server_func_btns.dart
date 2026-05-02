import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/iperf.dart';
import 'package:server_box/view/page/port_forward.dart';
import 'package:server_box/view/page/process.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/systemd.dart';

class ServerFuncBtns extends StatelessWidget {
  const ServerFuncBtns({super.key, required this.spi});

  final Spi spi;

  @override
  Widget build(BuildContext context) {
    final btns = this.btns;
    if (btns.isEmpty) return UIs.placeholder;

    return SizedBox(
      height: 77,
      child: ListView.builder(
        itemCount: btns.length,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 13),
        itemBuilder: (context, index) {
          final value = btns[index];
          final item = Consumer(
            builder: (_, ref, _) => _buildItem(context, value, ref),
          );
          return item.paddingSymmetric(horizontal: 7);
        },
      ),
    );
  }
}

extension ServerFuncBtnsBuild on ServerFuncBtns {
  Widget _buildItem(BuildContext context, ServerFuncBtn e, WidgetRef ref) {
    final move = Stores.setting.moveServerFuncs.fetch();
    if (move) {
      return IconButton(
        onPressed: () => _onTapMoreBtns(e, context, ref),
        padding: EdgeInsets.zero,
        tooltip: e.toStr,
        icon: Icon(e.icon, size: 15),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _onTapMoreBtns(e, context, ref),
            padding: EdgeInsets.zero,
            icon: Icon(e.icon, size: 17),
          ),
          Text(e.toStr, style: UIs.text11Grey),
        ],
      ),
    );
  }
}

extension ServerFuncBtnsUtils on ServerFuncBtns {
  List<ServerFuncBtn> get btns {
    try {
      final vals = <ServerFuncBtn>[];
      final list = Stores.setting.serverFuncBtns.fetch();
      for (final idx in list) {
        if (idx < 0 || idx >= ServerFuncBtn.values.length) continue;
        vals.add(ServerFuncBtn.values[idx]);
      }
      return vals;
    } catch (e) {
      return ServerFuncBtn.values;
    }
  }
}

extension ServerFuncBtnsActions on ServerFuncBtns {
  void _onTapMoreBtns(
    ServerFuncBtn value,
    BuildContext context,
    WidgetRef ref,
  ) async {
    switch (value) {
      case ServerFuncBtn.sftp:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SftpPageArgs(spi: spi);
        SftpPage.route.go(context, args);

        break;
      case ServerFuncBtn.snippet:
        final snippetState = ref.read(snippetProvider);
        if (snippetState.snippets.isEmpty) {
          context.showSnackBar(libL10n.empty);
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
        final fmted = snippet.fmtWithSpi(spi);
        final sure = await context.showRoundDialog<bool>(
          title: libL10n.attention,
          child: SingleChildScrollView(
            child: SimpleMarkdown(data: '```shell\n$fmted\n```'),
          ),
          actions: [
            CountDownBtn(
              onTap: () => context.pop(true),
              text: libL10n.run,
              afterColor: Colors.red,
            ),
          ],
        );
        if (sure != true) return;
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SshPageArgs(spi: spi, initSnippet: snippet);
        SSHPage.route.go(context, args);
        break;
      case ServerFuncBtn.container:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SpiRequiredArgs(spi);
        ContainerPage.route.go(context, args);
        break;
      case ServerFuncBtn.process:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SpiRequiredArgs(spi);
        ProcessPage.route.go(context, args);
        break;
      case ServerFuncBtn.terminal:
        _gotoSSH(spi, context);
        break;
      case ServerFuncBtn.iperf:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SpiRequiredArgs(spi);
        IPerfPage.route.go(context, args);
        break;
      case ServerFuncBtn.systemd:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SpiRequiredArgs(spi);
        SystemdPage.route.go(context, args);
        break;
      case ServerFuncBtn.portForward:
        if (!_checkClient(context, spi.id, ref)) return;
        final args = SpiRequiredArgs(spi);
        PortForwardPage.route.go(context, args);
        break;
    }
  }
}

void _gotoSSH(Spi spi, BuildContext context) async {
  // run built-in ssh on macOS due to incompatibility
  if (isMobile || isMacOS) {
    final args = SshPageArgs(spi: spi);
    SSHPage.route.go(context, args);
    return;
  }

  final extraArgs = <String>[];
  if (spi.port != 22) {
    extraArgs.addAll(['-p', '${spi.port}']);
  }

  await _copyDesktopSshPasswordIfNeeded(spi, context);

  File? tempKeyFile;
  final shouldGenKey = spi.keyId != null;

  try {
    if (shouldGenKey) {
      final path = await () async {
        final tempKeyFileName = 'srvbox_pk_${spi.keyId}';

        /// For security reason, save the private key file to app doc path
        return Paths.doc.joinPath(tempKeyFileName);
      }();
      final file = File(path);
      tempKeyFile = file;
      if (await file.exists()) {
        await file.delete();
      }
      final keyContent = getPrivateKey(spi.keyId!);
      final keyContentWithNewline = keyContent.endsWith('\n')
          ? keyContent
          : '$keyContent\n';
      await file.writeAsString(keyContentWithNewline);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', path]);
      }
      extraArgs.addAll(['-i', path]);
    }

    final sshCommand = ['ssh'] + extraArgs + ['${spi.user}@${spi.ip}'];
    final system = Pfs.type;
    switch (system) {
      case Pfs.windows:
        await Process.start('cmd', ['/c', 'start'] + sshCommand);
        break;
      case Pfs.linux:
        final scriptDir = await Directory.systemTemp.createTemp(
          'srvbox_launch_term_',
        );
        final scriptFile = File(scriptDir.path.joinPath('launch_term.sh'));
        await scriptFile.create(exclusive: true);
        await scriptFile.writeAsString(_runEmulatorShell);

        if (Platform.isLinux || Platform.isMacOS) {
          await Process.run('chmod', ['+x', scriptFile.path]);
        }

        try {
          var terminal = Stores.setting.desktopTerminal.fetch();
          if (terminal.isEmpty) terminal = 'x-terminal-emulator';

          await Process.start(scriptFile.path, [terminal, ...sshCommand]);
        } catch (e, s) {
          context.showErrDialog(e, s, libL10n.emulator);
        } finally {
          if (await scriptDir.exists()) {
            await scriptDir.delete(recursive: true);
          }
        }
        break;
      default:
        context.showSnackBar(l10n.mismatchSystem(system));
    }
  } finally {
    final file = tempKeyFile;
    if (file != null && await file.exists()) {
      unawaited(
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e, s) {
            Loggers.app.warning(
              'Failed to delete temporary SSH key file',
              e,
              s,
            );
          }
        }),
      );
    }
  }
}

Future<void> _copyDesktopSshPasswordIfNeeded(
  Spi spi,
  BuildContext context,
) async {
  if (!isDesktop) return;
  if (!Stores.setting.desktopSshAutoCopyPassword.fetch()) return;

  final pwd = spi.pwd;
  if (pwd == null || pwd.isEmpty) return;

  if (Stores.setting.useBioAuth.fetch()) {
    late final AuthResult result;
    try {
      result = await LocalAuth.goWithResult();
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to authenticate before copying SSH password',
        e,
        s,
      );
      return;
    }
    if (result != AuthResult.success) {
      if (context.mounted) {
        context.showSnackBar(libL10n.fail);
      }
      return;
    }
  }

  try {
    await Clipboard.setData(ClipboardData(text: pwd));
  } catch (e, s) {
    Loggers.app.warning('Failed to copy SSH password to clipboard', e, s);
    return;
  }
  unawaited(
    Future.delayed(const Duration(seconds: 25), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text != pwd) return;
        await Clipboard.setData(const ClipboardData(text: ''));
      } catch (e, s) {
        Loggers.app.warning(
          'Failed to clear copied SSH password from clipboard',
          e,
          s,
        );
      }
    }),
  );
  if (context.mounted) {
    context.showSnackBar(libL10n.success);
  }
}

bool _checkClient(BuildContext context, String id, WidgetRef ref) {
  final serverState = ref.read(serverProvider(id));
  if (serverState.client == null) {
    context.showSnackBar(l10n.waitConnection);
    return false;
  }
  return true;
}

const _runEmulatorShell = '''
#!/bin/sh
TERMINAL="\$1"
shift

if [ -z "\$TERMINAL" ] || [ "\$TERMINAL" = "x-terminal-emulator" ]; then
    for term in kitty alacritty gnome-terminal gnome-console konsole xfce4-terminal terminator tilix wezterm foot xterm; do
        command -v "\$term" >/dev/null 2>&1 && { TERMINAL="\$term"; break; }
    done
    [ -z "\$TERMINAL" ] && TERMINAL="x-terminal-emulator"
fi

case "\$TERMINAL" in
    gnome-terminal|gnome-console) exec "\$TERMINAL" -- "\$@" ;;
    alacritty) 
        "\$TERMINAL" --version 2>&1 | grep -q "alacritty 0\\.1[3-9]" && 
        exec "\$TERMINAL" --command "\$@" || exec "\$TERMINAL" -e "\$@" ;;
    kitty|foot) exec "\$TERMINAL" "\$@" ;;
    wezterm) exec "\$TERMINAL" start -- "\$@" ;;
    xfce4-terminal) exec "\$TERMINAL" -e "\$*" ;;
    *) exec "\$TERMINAL" -e "\$@" ;;
esac
''';
