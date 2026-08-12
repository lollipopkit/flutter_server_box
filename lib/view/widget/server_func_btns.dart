import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
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
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/systemd.dart';

class ServerFuncBtns extends StatelessWidget {
  const ServerFuncBtns({super.key, required this.spi});

  final Spi spi;

  @override
  Widget build(BuildContext context) {
    final btns = this.btns;
    if (btns.isEmpty) return UIs.placeholder;

    final items = [
      for (final value in btns)
        Consumer(builder: (_, ref, _) => _buildItem(context, value, ref)),
    ];

    // It has to say how wide it is. A shrink-wrapping viewport
    // takes the width of what is in it and no more — and, once whatever holds
    // it runs out of room to give, scrolls instead of overflowing. One line
    // either way.
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(_kPad, _kVPadTop, _kPad, _kVPadBottom),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
      separatorBuilder: (_, _) => const SizedBox(width: _kGap),
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
  Widget _buildItem(BuildContext context, ServerFuncBtn e, WidgetRef ref) {
    // The label is part of the button, not a caption under one. An
    // `IconButton` with a `Text` beneath it left the word inert, so half of
    // what looks like a target did nothing when tapped.
    return InkWell(
      onTap: () => _onTapMoreBtns(e, context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.icon, size: 17),
            const SizedBox(height: 4),
            Text(e.toStr, style: UIs.text11Grey),
          ],
        ),
      ),
    );
  }
}

extension ServerFuncBtnsUtils on ServerFuncBtns {
  List<ServerFuncBtn> get btns {
    final ordered = () {
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

    // A server reached only through its agent's passwordless PTY has one
    // stream and no way to run a second command, so every other entry here
    // would open a page that can never load. Filtered rather than disabled:
    // there is nothing the user could do to make them work short of
    // configuring SSH.
    final caps = ServerCapabilities.of(ServerConnectCredential.fromSpi(spi));
    if (caps.shell) return ordered;
    return ordered
        .where((e) => e == ServerFuncBtn.terminal && caps.terminal)
        .toList();
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
        if (!await _checkClient(context, spi.id, ref)) return;
        // Into the file tab rather than over whatever is on screen, so two
        // servers can be open at once and neither is lost by opening the other.
        ref.read(sftpRequestsProvider.notifier).add(spi);
        ref.read(homeTabRequestProvider.notifier).go(AppTab.file);
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
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SshPageArgs(spi: spi, initSnippet: snippet);
        SSHPage.route.go(context, args);
        break;
      case ServerFuncBtn.container:
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        ContainerPage.route.go(context, args);
        break;
      case ServerFuncBtn.process:
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        ProcessPage.route.go(context, args);
        break;
      case ServerFuncBtn.terminal:
        _gotoSSH(spi, context, ref);
        break;
      case ServerFuncBtn.iperf:
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        IPerfPage.route.go(context, args);
        break;
      case ServerFuncBtn.systemd:
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        SystemdPage.route.go(context, args);
        break;
      case ServerFuncBtn.portForward:
        if (!await _checkClient(context, spi.id, ref)) return;
        if (!context.mounted) return;
        final args = SpiRequiredArgs(spi);
        PortForwardPage.route.go(context, args);
        break;
    }
  }
}

void _gotoSSH(Spi spi, BuildContext context, WidgetRef ref) async {
  // Determine whether to use built-in SSH or system SSH
  final useSystemSsh = Stores.setting.sshConnectionMode.fetch();
  // Neither a tunneled server nor one reached through its agent's own PTY has
  // an address the system `ssh` could dial: their bytes travel over the
  // agent's WebSocket, which only this app speaks. The built-in terminal is
  // the only option for them regardless of the setting.
  final ssh = spi.ssh;
  final useBuiltin =
      isMobile || !useSystemSsh || ssh == null || ssh.viaMonitor;

  // One way in. A terminal opened from here used to be a page pushed over
  // whatever was on screen, unknown to the SSH tab and its sessions, so the
  // same server opened twice gave two shells that could not see each other and
  // only one of which survived a relaunch.
  if (useBuiltin) {
    ref.read(terminalRequestsProvider.notifier).add(spi);
    ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
    return;
  }

  final extraArgs = <String>[];
  if (ssh.port != 22) {
    extraArgs.addAll(['-p', '${ssh.port}']);
  }

  await _copyDesktopSshPasswordIfNeeded(spi, context);

  File? tempKeyFile;
  final shouldGenKey = ssh.keyId != null;
  var sshLaunched = false;

  try {
    if (shouldGenKey) {
      final tempDir = await Directory.systemTemp.createTemp(
        'srvbox_pk_${ssh.keyId}_',
      );
      final path = tempDir.path.joinPath('id_key');
      final file = File(path);
      tempKeyFile = file;
      final keyContent = getPrivateKey(ssh.keyId!);
      final keyContentWithNewline = keyContent.endsWith('\n')
          ? keyContent
          : '$keyContent\n';
      await file.writeAsString(keyContentWithNewline);
      try {
        await _restrictPrivateKeyFile(path);
      } on ProcessException catch (e, s) {
        Loggers.app.warning(
          'Failed to restrict temporary SSH key file permissions',
          e,
          s,
        );
        if (context.mounted) {
          context.showErrDialog(e, s, libL10n.error);
        }
        return;
      } on Exception catch (e, s) {
        Loggers.app.warning('Failed to prepare temporary SSH key file', e, s);
        if (context.mounted) {
          context.showErrDialog(e, s, libL10n.error);
        }
        return;
      }
      extraArgs.addAll(['-i', path]);
    }

    final sshCommand = ['ssh'] + extraArgs + ['${ssh.user}@${ssh.ip}'];
    final system = Pfs.type;
    switch (system) {
      case Pfs.windows:
        await Process.start('cmd', ['/c', 'start'] + sshCommand);
        sshLaunched = true;
        break;
      case Pfs.macos:
        try {
          final command = _shellJoin(sshCommand);
          await Process.start('osascript', [
            '-e',
            'tell application "Terminal" to activate',
            '-e',
            'tell application "Terminal" to do script ${_appleScriptString(command)}',
          ]);
          sshLaunched = true;
        } catch (e, s) {
          context.showErrDialog(e, s, libL10n.emulator);
        }
        break;
      case Pfs.linux:
        final scriptDir = await Directory.systemTemp.createTemp(
          'srvbox_launch_term_',
        );
        final scriptFile = File(scriptDir.path.joinPath('launch_term.sh'));
        await scriptFile.create(exclusive: true);
        await scriptFile.writeAsString(_runEmulatorShell);

        await Process.run('chmod', ['+x', scriptFile.path]);

        try {
          var terminal = Stores.setting.desktopTerminal.fetch();
          if (terminal.isEmpty) terminal = 'x-terminal-emulator';

          await Process.start(scriptFile.path, [terminal, ...sshCommand]);
          sshLaunched = true;
        } catch (e, s) {
          if (context.mounted) {
            context.showErrDialog(e, s, libL10n.emulator);
          }
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
    if (file != null) {
      if (sshLaunched) {
        // Keep the key file alive while SSH is establishing the connection.
        unawaited(
          Future.delayed(const Duration(seconds: 30), () async {
            try {
              final parent = file.parent;
              if (await parent.exists()) {
                await parent.delete(recursive: true);
              }
            } catch (e, s) {
              Loggers.app.warning(
                'Failed to delete temporary SSH key directory',
                e,
                s,
              );
            }
          }),
        );
      } else {
        // SSH never launched — clean up immediately.
        try {
          final parent = file.parent;
          if (await parent.exists()) {
            await parent.delete(recursive: true);
          }
        } catch (e, s) {
          Loggers.app.warning(
            'Failed to delete temporary SSH key directory',
            e,
            s,
          );
        }
      }
    }
  }
}

Future<void> _restrictPrivateKeyFile(String path) async {
  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chmod',
        ['600', path],
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
    return;
  }

  final whoami = await Process.run('whoami', []);
  if (whoami.exitCode != 0) {
    throw ProcessException(
      'whoami',
      const [],
      '${whoami.stdout}${whoami.stderr}',
      whoami.exitCode,
    );
  }

  final user = whoami.stdout.toString().trim();
  final icacls = await Process.run('icacls', [
    path,
    '/inheritance:r',
    '/grant:r',
    '$user:F',
  ]);
  if (icacls.exitCode != 0) {
    throw ProcessException(
      'icacls',
      [path, '/inheritance:r', '/grant:r', '$user:F'],
      '${icacls.stdout}${icacls.stderr}',
      icacls.exitCode,
    );
  }
}

Future<void> _copyDesktopSshPasswordIfNeeded(
  Spi spi,
  BuildContext context,
) async {
  if (!isDesktop) return;
  if (!Stores.setting.desktopSshAutoCopyPassword.fetch()) return;

  final pwd = spi.ssh?.pwd;
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
        // Only clear if the clipboard still holds the password.
        // If the user copied something else in the meantime, preserve it.
        if (current?.text == pwd) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
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

/// Makes sure a shell is available before opening a page that needs one.
///
/// Connects on demand rather than only reporting a missing client: a server
/// reached through its monitor agent has no SSH connection until something
/// asks for one, so "wait for the connection" would be advice that never
/// comes true. Servers connected over SSH already hold a client and take the
/// fast path out of [ServerNotifier.ensureShellClient].
///
/// Returns false — after telling the user why — when there is no shell to be
/// had. Callers must re-check `context.mounted` before navigating, since this
/// can await a real connection attempt.
Future<bool> _checkClient(BuildContext context, String id, WidgetRef ref) async {
  final notifier = ref.read(serverProvider(id).notifier);
  final existing = ref.read(serverProvider(id)).client;
  if (existing != null && !existing.isClosed) return true;

  if (context.mounted) context.showSnackBar(l10n.waitConnection);
  try {
    await notifier.ensureShellClient();
    return true;
  } catch (e, s) {
    Loggers.app.warning('Ensure shell client for $id', e, s);
    if (context.mounted) {
      context.showSnackBar(
        e is SSHErr ? (e.message ?? e.type.name) : e.toString(),
      );
    }
    return false;
  }
}

String _shellJoin(List<String> args) {
  return args.map(shellSingleQuote).join(' ');
}

String _appleScriptString(String value) {
  final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '"$escaped"';
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
