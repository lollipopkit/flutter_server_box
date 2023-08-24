import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/data/provider/server.dart';

import '../../core/route.dart';
import '../../core/utils/misc.dart' hide pathJoin;
import '../../core/utils/platform.dart';
import '../../core/utils/server.dart';
import '../../core/utils/ui.dart';
import '../../data/model/app/menu.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/model/server/snippet.dart';
import '../../data/provider/snippet.dart';
import '../../locator.dart';
import 'tag.dart';

class ServerFuncBtns extends StatelessWidget {
  const ServerFuncBtns({
    super.key,
    required this.spi,
    required this.s,
    this.iconSize,
  });

  final ServerPrivateInfo spi;
  final S s;
  final double? iconSize;

  void _onTapMoreBtns(
    ServerTabMenuType value,
    ServerPrivateInfo spi,
    BuildContext context,
  ) async {
    switch (value) {
      case ServerTabMenuType.pkg:
        AppRoute.pkg(spi: spi).checkGo(
          context: context,
          check: () => _checkClient(context, spi.id),
        );
        break;
      case ServerTabMenuType.sftp:
        AppRoute.sftp(spi: spi).checkGo(
          context: context,
          check: () => _checkClient(context, spi.id),
        );
        break;
      case ServerTabMenuType.snippet:
        final provider = locator<SnippetProvider>();
        final snippets = await showDialog<List<Snippet>>(
          context: context,
          builder: (_) => TagPicker<Snippet>(
            items: provider.snippets,
            tags: provider.tags.toSet(),
          ),
        );
        if (snippets == null) {
          return;
        }
        final result =
            await locator<ServerProvider>().runSnippets(spi.id, snippets);
        if (result != null && result.isNotEmpty) {
          showRoundDialog(
            context: context,
            title: Text(s.result),
            child: Text(result),
            actions: [
              TextButton(
                onPressed: () => copy2Clipboard(result),
                child: Text(s.copy),
              )
            ],
          );
        }
        break;
      case ServerTabMenuType.docker:
        AppRoute.docker(spi: spi).checkGo(
          context: context,
          check: () => _checkClient(context, spi.id),
        );
        break;
      case ServerTabMenuType.process:
        AppRoute.process(spi: spi).checkGo(
          context: context,
          check: () => _checkClient(context, spi.id),
        );
        break;
      case ServerTabMenuType.terminal:
        _gotoSSH(spi, context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ServerTabMenuType.values
          .map((e) => IconButton(
                onPressed: () => _onTapMoreBtns(e, spi, context),
                padding: EdgeInsets.zero,
                tooltip: e.name,
                icon: Icon(e.icon, size: iconSize ?? 15),
              ))
          .toList(),
    );
  }

  Future<void> _gotoSSH(
    ServerPrivateInfo spi,
    BuildContext context,
  ) async {
    // as a `Mobile first` app -> handle mobile first
    //
    // run built-in ssh on macOS due to incompatibility
    if (!isDesktop || isMacOS) {
      AppRoute.ssh(spi: spi).go(context);
      return;
    }
    final extraArgs = <String>[];
    if (spi.port != 22) {
      extraArgs.addAll(['-p', '${spi.port}']);
    }

    final path = () {
      final tempKeyFileName = 'srvbox_pk_${spi.pubKeyId}';
      return pathJoin(Directory.systemTemp.path, tempKeyFileName);
    }();
    final file = File(path);
    final shouldGenKey = spi.pubKeyId != null;
    if (shouldGenKey) {
      if (await file.exists()) {
        await file.delete();
      }
      await file.writeAsString(getPrivateKey(spi.pubKeyId!));
      extraArgs.addAll(["-i", path]);
    }

    List<String> sshCommand = ["ssh", "${spi.user}@${spi.ip}"] + extraArgs;
    final system = Platform.operatingSystem;
    switch (system) {
      case "windows":
        await Process.start("cmd", ["/c", "start"] + sshCommand);
        break;
      case "linux":
        await Process.start("x-terminal-emulator", ["-e"] + sshCommand);
        break;
      default:
        showSnackBar(context, Text('Mismatch system: $system'));
    }
    // For security reason, delete the private key file after use
    if (shouldGenKey) {
      if (!await file.exists()) return;
      await Future.delayed(const Duration(seconds: 2), file.delete);
    }
  }

  bool _checkClient(BuildContext context, String id) {
    final server = locator<ServerProvider>().servers[id];
    if (server == null || server.client == null) {
      showSnackBar(context, Text(s.waitConnection));
      return false;
    }
    return true;
  }
}
