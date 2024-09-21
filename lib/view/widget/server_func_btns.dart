import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/systemd.dart';

import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

class ServerFuncBtnsTopRight extends StatelessWidget {
  final Spi spi;

  const ServerFuncBtnsTopRight({
    super.key,
    required this.spi,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenu<ServerFuncBtn>(
      items: ServerFuncBtn.values
          .map((e) => PopMenu.build(e, e.icon, e.toStr))
          .toList(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onSelected: (val) => _onTapMoreBtns(val, spi, context),
    );
  }
}

class ServerFuncBtns extends StatelessWidget {
  const ServerFuncBtns({
    super.key,
    required this.spi,
  });

  final Spi spi;

  @override
  Widget build(BuildContext context) {
    final btns = () {
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
    }();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: btns
          .map(
            (e) => Stores.setting.moveServerFuncs.fetch()
                ? IconButton(
                    onPressed: () => _onTapMoreBtns(e, spi, context),
                    padding: EdgeInsets.zero,
                    tooltip: e.toStr,
                    icon: Icon(e.icon, size: 15),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _onTapMoreBtns(e, spi, context),
                          padding: EdgeInsets.zero,
                          icon: Icon(e.icon, size: 17),
                        ),
                        Text(e.toStr, style: UIs.text11Grey)
                      ],
                    ),
                  ),
          )
          .toList(),
    );
  }
}

void _onTapMoreBtns(
  ServerFuncBtn value,
  Spi spi,
  BuildContext context,
) async {
  switch (value) {
    // case ServerFuncBtn.pkg:
    //   _onPkg(context, spi);
    //   break;
    case ServerFuncBtn.sftp:
      AppRoutes.sftp(spi: spi).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
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
        child: SingleChildScrollView(
          child: SimpleMarkdown(data: '```shell\n$fmted\n```'),
        ),
        actions: [
          CountDownBtn(
            onTap: () => context.pop(true),
            text: l10n.run,
            afterColor: Colors.red,
          ),
        ],
      );
      if (sure != true) return;
      AppRoutes.ssh(spi: spi, initSnippet: snippet).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
      break;
    case ServerFuncBtn.container:
      AppRoutes.docker(spi: spi).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
      break;
    case ServerFuncBtn.process:
      AppRoutes.process(spi: spi).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
      break;
    case ServerFuncBtn.terminal:
      _gotoSSH(spi, context);
      break;
    case ServerFuncBtn.iperf:
      AppRoutes.iperf(spi: spi).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
      break;
    case ServerFuncBtn.systemd:
      SystemdPage.route.go(context, SystemdPageArgs(spi: spi));
      break;
  }
}

void _gotoSSH(Spi spi, BuildContext context) async {
  // run built-in ssh on macOS due to incompatibility
  if (isMobile || isMacOS) {
    AppRoutes.ssh(spi: spi).go(context);
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
      await Process.start('x-terminal-emulator', ['-e'] + sshCommand);
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
