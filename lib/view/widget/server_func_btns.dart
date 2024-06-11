import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/pkg/manager.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/data/res/store.dart';

import '../../core/route.dart';
import '../../core/utils/server.dart';
import '../../data/model/pkg/upgrade_info.dart';
import '../../data/model/server/server_private_info.dart';

class ServerFuncBtnsTopRight extends StatelessWidget {
  final ServerPrivateInfo spi;

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

  final ServerPrivateInfo spi;

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
            (e) => Stores.setting.moveOutServerTabFuncBtns.fetch()
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
  ServerPrivateInfo spi,
  BuildContext context,
) async {
  switch (value) {
    case ServerFuncBtn.pkg:
      _onPkg(context, spi);
      break;
    case ServerFuncBtn.sftp:
      AppRoutes.sftp(spi: spi).checkGo(
        context: context,
        check: () => _checkClient(context, spi.id),
      );
      break;
    case ServerFuncBtn.snippet:
      if (Pros.snippet.snippets.isEmpty) {
        context.showSnackBar(l10n.noSavedSnippet);
        return;
      }
      final snippets = await context.showPickWithTagDialog<Snippet>(
        title: l10n.snippet,
        tags: Pros.snippet.tags,
        itemsBuilder: (e) {
          if (e == null) return Pros.snippet.snippets;
          return Pros.snippet.snippets
              .where((element) => element.tags?.contains(e) ?? false)
              .toList();
        },
        name: (e) => e.name,
      );
      if (snippets == null || snippets.isEmpty) return;
      final snippet = snippets.firstOrNull;
      if (snippet == null) return;
      final fmted = snippet.fmtWithSpi(spi);
      final sure = await context.showRoundDialog<bool>(
        title: l10n.attention,
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
  }
}

void _gotoSSH(ServerPrivateInfo spi, BuildContext context) async {
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
    extraArgs.addAll(["-i", path]);
  }

  final sshCommand = ["ssh", "${spi.user}@${spi.ip}"] + extraArgs;
  final system = Pfs.type;
  switch (system) {
    case Pfs.windows:
      await Process.start("cmd", ["/c", "start"] + sshCommand);
      break;
    case Pfs.linux:
      await Process.start("x-terminal-emulator", ["-e"] + sshCommand);
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
  final server = Pros.server.pick(id: id);
  if (server == null || server.client == null) {
    context.showSnackBar(l10n.waitConnection);
    return false;
  }
  return true;
}

Future<void> _onPkg(BuildContext context, ServerPrivateInfo spi) async {
  final server = spi.server;
  final client = server?.client;
  if (server == null || client == null) {
    context.showSnackBar(l10n.noClient);
    return;
  }
  final sys = server.status.more[StatusCmdType.sys];
  if (sys == null) {
    context.showSnackBar(l10n.noResult);
    return;
  }

  final pkg = PkgManager.fromDist(sys.dist);
  if (pkg == null) {
    context.showSnackBar('Unsupported dist: $sys');
    return;
  }

  // Update pkg list
  await context.showLoadingDialog(
    fn: () async {
      final updateCmd = pkg.update;
      if (updateCmd != null) {
        await client.execWithPwd(
          updateCmd,
          context: context,
          id: spi.id,
        );
      }
    },
    barrierDismiss: true,
  );

  final listCmd = pkg.listUpdate;
  if (listCmd == null) {
    context.showSnackBar('Unsupported dist: $sys');
    return;
  }

  // Get upgrade list
  final result = await context.showLoadingDialog(fn: () async {
    return await client.run(listCmd).string;
  });
  final list = pkg.updateListRemoveUnused(result.split('\n'));
  final upgradeable = list.map((e) => UpgradePkgInfo(e, pkg)).toList();
  if (upgradeable.isEmpty) {
    context.showSnackBar(l10n.noUpdateAvailable);
    return;
  }
  final args = upgradeable.map((e) => e.package).join(' ');
  final isSU = server.spi.user == 'root';
  final upgradeCmd = isSU ? pkg.upgrade(args) : 'sudo ${pkg.upgrade(args)}';

  // Confirm upgrade
  final gotoUpgrade = await context.showRoundDialog<bool>(
    title: l10n.attention,
    child: SingleChildScrollView(
      child: Text(
          '${l10n.pkgUpgradeTip}\n${l10n.foundNUpdate(upgradeable.length)}\n\n$upgradeCmd'),
    ),
    actions: [
      CountDownBtn(
        onTap: () => context.pop(true),
        text: l10n.update,
        afterColor: Colors.red,
      ),
    ],
  );

  if (gotoUpgrade != true) return;

  AppRoutes.ssh(spi: spi, initCmd: upgradeCmd).checkGo(
    context: context,
    check: () => _checkClient(context, spi.id),
  );
}
