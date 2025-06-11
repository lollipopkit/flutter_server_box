import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/iperf.dart';
import 'package:server_box/view/page/process.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/systemd.dart';

class ServerFuncBtnsTopRight extends StatelessWidget {
  final Spi spi;

  const ServerFuncBtnsTopRight({super.key, required this.spi});

  @override
  Widget build(BuildContext context) {
    return PopupMenu<ServerFuncBtn>(
      items: ServerFuncBtn.values.map((e) => PopMenu.build(e, e.icon, e.toStr)).toList(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onSelected: (val) => _onTapMoreBtns(val, spi, context),
    );
  }
}

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
          final item = _buildItem(context, value);
          return item.paddingSymmetric(horizontal: 7);
        },
      ),
    );
  }

  Widget _buildItem(BuildContext context, ServerFuncBtn e) {
    final move = Stores.setting.moveServerFuncs.fetch();
    if (move) {
      return IconButton(
        onPressed: () => _onTapMoreBtns(e, spi, context),
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
            onPressed: () => _onTapMoreBtns(e, spi, context),
            padding: EdgeInsets.zero,
            icon: Icon(e.icon, size: 17),
          ),
          Text(e.toStr, style: UIs.text11Grey),
        ],
      ),
    );
  }

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

void _onTapMoreBtns(ServerFuncBtn value, Spi spi, BuildContext context) async {
  // final isMobile = ResponsiveBreakpoints.of(context).isMobile;
  switch (value) {
    // case ServerFuncBtn.pkg:
    //   _onPkg(context, spi);
    //   break;
    case ServerFuncBtn.sftp:
      if (!_checkClient(context, spi.id)) return;
      final args = SftpPageArgs(spi: spi);
      // if (isMobile) {
      SftpPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(context)?.replace(
      //     SftpPage.route.toWidget(args: args),
      //   );
      // }

      break;
    case ServerFuncBtn.snippet:
      if (SnippetProvider.snippets.value.isEmpty) {
        context.showSnackBar(libL10n.empty);
        return;
      }
      final snippets = await context.showPickWithTagDialog<Snippet>(
        title: l10n.snippet,
        tags: SnippetProvider.tags,
        itemsBuilder: (e) {
          if (e == TagSwitcher.kDefaultTag) {
            return SnippetProvider.snippets.value;
          }
          return SnippetProvider.snippets.value
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
        child: SingleChildScrollView(child: SimpleMarkdown(data: '```shell\n$fmted\n```')),
        actions: [CountDownBtn(onTap: () => context.pop(true), text: l10n.run, afterColor: Colors.red)],
      );
      if (sure != true) return;
      if (!_checkClient(context, spi.id)) return;
      final args = SshPageArgs(spi: spi, initSnippet: snippet);
      // if (isMobile) {
      SSHPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(context)?.replace(
      //     SSHPage.route.toWidget(args: args),
      //   );
      // }
      break;
    case ServerFuncBtn.container:
      if (!_checkClient(context, spi.id)) return;
      final args = SpiRequiredArgs(spi);
      // if (isMobile) {
      ContainerPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(
      //     context,
      //   )?.replace(ContainerPage.route.toWidget(args: args));
      // }
      break;
    case ServerFuncBtn.process:
      if (!_checkClient(context, spi.id)) return;
      final args = SpiRequiredArgs(spi);
      // if (isMobile) {
      ProcessPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(context)?.replace(
      //     ProcessPage.route.toWidget(args: args),
      //   );
      // }
      break;
    case ServerFuncBtn.terminal:
      _gotoSSH(spi, context);
      break;
    case ServerFuncBtn.iperf:
      if (!_checkClient(context, spi.id)) return;
      final args = SpiRequiredArgs(spi);
      // if (isMobile) {
      IPerfPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(context)?.replace(
      //     IPerfPage.route.toWidget(args: args),
      //   );
      // }
      break;
    case ServerFuncBtn.systemd:
      if (!_checkClient(context, spi.id)) return;
      final args = SpiRequiredArgs(spi);
      // if (isMobile) {
      SystemdPage.route.go(context, args);
      // } else {
      //   SplitViewNavigator.of(context)?.replace(
      //     SystemdPage.route.toWidget(args: args),
      //   );
      // }
      break;
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

  final path = await () async {
    final tempKeyFileName = 'srvbox_pk_${spi.keyId}';

    /// For security reason, save the private key file to app doc path
    return Paths.doc.joinPath(tempKeyFileName);
  }();
  final file = File(path);
  final shouldGenKey = spi.keyId != null;
  if (shouldGenKey) {
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsString(getPrivateKey(spi.keyId!));
    extraArgs.addAll(['-i', path]);
  }

  final sshCommand = ['ssh', '${spi.user}@${spi.ip}'] + extraArgs;
  final system = Pfs.type;
  switch (system) {
    case Pfs.windows:
      await Process.start('cmd', ['/c', 'start'] + sshCommand);
      break;
    case Pfs.linux:
      final scriptFile = File('${Directory.systemTemp.path}/srvbox_launch_term.sh');
      await scriptFile.writeAsString(_runEmulatorShell);

      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['+x', scriptFile.path]);
      }

      try {
        var terminal = Stores.setting.desktopTerminal.fetch();
        if (terminal.isEmpty) terminal = 'x-terminal-emulator';

        await Process.start(scriptFile.path, [terminal, ...sshCommand]);
      } catch (e, s) {
        context.showErrDialog(e, s, l10n.emulator);
      } finally {
        await scriptFile.delete();
      }
      break;
    default:
      context.showSnackBar('Mismatch system: $system');
  }

  if (shouldGenKey) {
    if (!await file.exists()) return;
    await Future.delayed(const Duration(seconds: 2), file.delete);
  }
}

bool _checkClient(BuildContext context, String id) {
  final server = ServerProvider.pick(id: id)?.value;
  if (server == null || server.client == null) {
    context.showSnackBar(l10n.waitConnection);
    return false;
  }
  return true;
}

const _runEmulatorShell = '''
#!/bin/sh
# launch_terminal.sh

TERMINAL="\$1"
shift  # Remove the first argument (terminal name)

# Auto detect terminal if not provided
if [ -z "\$TERMINAL" ] || [ "\$TERMINAL" = "x-terminal-emulator" ]; then
    # Follow the order of preference
    for term in kitty alacritty gnome-terminal konsole xfce4-terminal terminator tilix wezterm foot; do
        if command -v "\$term" >/dev/null 2>&1; then
            TERMINAL="\$term"
            break
        fi
    done

    [ -z "\$TERMINAL" ] && TERMINAL="x-terminal-emulator"
fi

case "\$TERMINAL" in
    gnome-terminal)
        exec "\$TERMINAL" -- "\$@"
        ;;
    konsole|terminator|tilix)
        exec "\$TERMINAL" -e "\$@"
        ;;
    xfce4-terminal)
        exec "\$TERMINAL" -e "\$*"
        ;;
    alacritty)
        # Check alacritty version
        if "\$TERMINAL" --version 2>&1 | grep -q "alacritty 0\\.1[3-9]"; then
            # 0.13.0+
            exec "\$TERMINAL" --command "\$@"
        else
            # Old versions
            exec "\$TERMINAL" -e "\$@"
        fi
        ;;
    kitty)
        exec "\$TERMINAL" "\$@"
        ;;
    wezterm)
        exec "\$TERMINAL" start -- "\$@"
        ;;
    foot)
        exec "\$TERMINAL" "\$@"
        ;;
    urxvt|rxvt-unicode)
        exec "\$TERMINAL" -e "\$@"
        ;;
    x-terminal-emulator|*)
        # Default
        exec "\$TERMINAL" -e "\$@"
        ;;
esac
''';
