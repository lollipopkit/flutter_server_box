// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

/// One custom command as the editor holds it, before it becomes a file.
typedef _Cmd = ({String name, String cmd});

/// Editor for a server's custom status commands.
///
/// The commands are files in a directory on the server, and that directory is
/// the only copy: this page reads it on open and writes it back on save. So
/// the page needs the server to be reachable, and says so when it is not,
/// rather than collecting edits that would have nowhere to go.
///
/// Order is part of what is stored — it is the order the status page lists
/// them in — which is why this is a reorderable list and not the key/value
/// editor it replaced.
final class CustomCmdsPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const CustomCmdsPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: CustomCmdsPage.new,
    path: '/server/custom_cmds',
  );

  @override
  ConsumerState<CustomCmdsPage> createState() => _CustomCmdsPageState();
}

final class _CustomCmdsPageState extends ConsumerState<CustomCmdsPage> {
  /// Null until the server has answered.
  List<_Cmd>? _cmds;
  String? _err;
  bool _dirty = false;
  bool _saving = false;

  Spi get _spi => widget.args.spi;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: CustomAppBar(
          centerTitle: true,
          title: TwoLineText(up: l10n.customCmd, down: _spi.name),
          actions: [
            if (_cmds != null)
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Btn.icon(
                  text: libL10n.save,
                  icon: const Icon(Icons.save),
                  onTap: _save,
                ),
          ],
        ),
        floatingActionButton: _cmds == null
            ? null
            : FloatingActionButton(
                onPressed: _onAdd,
                child: const Icon(Icons.add),
              ),
        body: _buildBody(),
      ),
    );
  }
}

// --- Widget build ---

extension on _CustomCmdsPageState {
  Widget _buildBody() {
    final err = _err;
    if (err != null) return _buildErr(err);

    final cmds = _cmds;
    if (cmds == null) return UIs.centerLoading;
    if (cmds.isEmpty) return Center(child: Text(libL10n.empty, style: UIs.textGrey));

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 77),
      itemCount: cmds.length,
      itemBuilder: (_, idx) => _buildItem(cmds[idx], idx),
      onReorderItem: (o, n) {
        if (o == n) return;
        setState(() {
          _cmds!.insert(n, _cmds!.removeAt(o));
          _dirty = true;
        });
      },
    );
  }

  Widget _buildItem(_Cmd cmd, int idx) {
    return CardX(
      key: ValueKey('${idx}_${cmd.name}'),
      child: ListTile(
        title: Text(cmd.name),
        subtitle: Text(
          cmd.cmd,
          style: UIs.textGrey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _onEdit(idx),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, size: 19),
              onPressed: () => _onDelete(idx),
            ),
            ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErr(String err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(libL10n.error, style: UIs.text18),
          UIs.height13,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Text(err, style: UIs.textGrey, textAlign: TextAlign.center),
          ),
          UIs.height13,
          Btn.text(text: libL10n.retry, onTap: _load),
        ],
      ),
    );
  }
}

// --- Actions ---

extension on _CustomCmdsPageState {
  Future<void> _load() async {
    setState(() {
      _err = null;
      _cmds = null;
    });
    try {
      final system = ref.read(serverProvider(_spi.id)).status.system;
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      final res = await exec.run(
        ShellFuncManager.readCustomCmds(systemType: system),
        entry: ShellFuncManager.customCmdsEntry(system),
      );
      if (!res.succeeded) {
        throw '${res.exitCode}: ${res.combined}';
      }
      // A directory that does not exist yet reads as no commands: the first
      // save creates it. Telling the two apart matters to the migration, not
      // here.
      final parsed = ShellFuncManager.parseCustomCmds(res.stdout) ?? const [];
      if (!mounted) return;
      setState(() {
        _cmds = [for (final c in parsed) (name: c.name, cmd: c.cmd)];
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  Future<void> _save() async {
    final cmds = _cmds;
    if (cmds == null) return;
    setState(() => _saving = true);
    try {
      final system = ref.read(serverProvider(_spi.id)).status.system;
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      final res = await exec.run(
        ShellFuncManager.installCustomCmds(
          [for (final c in cmds) ffi.CustomCmd(name: c.name, cmd: c.cmd)],
          systemType: system,
        ),
        entry: ShellFuncManager.customCmdsEntry(system),
      );
      if (!res.succeeded) {
        throw '${res.exitCode}: ${res.combined}';
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      Toast.show(libL10n.saved);
    } catch (e) {
      if (!mounted) return;
      Toast.error(libL10n.saveFailed, body: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onAdd() async {
    final res = await _showEditDialog();
    if (res == null) return;
    setState(() {
      _cmds!.add(res);
      _dirty = true;
    });
  }

  Future<void> _onEdit(int idx) async {
    final res = await _showEditDialog(initial: _cmds![idx], editingIdx: idx);
    if (res == null) return;
    setState(() {
      _cmds![idx] = res;
      _dirty = true;
    });
  }

  Future<void> _onDelete(int idx) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.delFmt(libL10n.cmd, _cmds![idx].name)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    setState(() {
      _cmds!.removeAt(idx);
      _dirty = true;
    });
  }

  /// Closes the page when the user gives up the unsaved edits.
  ///
  /// The dialog's own buttons close the dialog; this is the caller, and it is
  /// on the page, so it is the one that may pop the page.
  Future<void> _confirmDiscard() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.goBackQ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    setState(() => _dirty = false);
    context.pop();
  }
}

// --- Utils ---

extension on _CustomCmdsPageState {
  /// [editingIdx] is the entry being edited, excluded from the duplicate-name
  /// check so that renaming nothing is not a conflict with itself.
  Future<_Cmd?> _showEditDialog({_Cmd? initial, int? editingIdx}) async {
    final nameCtrl = TextEditingController(text: initial?.name);
    final cmdCtrl = TextEditingController(text: initial?.cmd);
    try {
      while (true) {
        final ok = await context.showRoundDialog<bool>(
          title: initial == null ? libL10n.add : libL10n.edit,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: nameCtrl,
                label: libL10n.name,
                icon: Icons.label_outline,
                autoFocus: initial == null,
              ),
              Input(
                controller: cmdCtrl,
                label: libL10n.cmd,
                icon: Icons.terminal,
                maxLines: 5,
                minLines: 2,
              ),
            ],
          ),
          actions: Btnx.cancelOk,
        );
        if (ok != true || !mounted) return null;

        final name = nameCtrl.text.trim();
        final cmd = cmdCtrl.text.trim();
        final err = _validate(name, cmd, editingIdx);
        if (err != null) {
          Toast.error(err);
          continue;
        }
        return (name: name, cmd: cmd);
      }
    } finally {
      nameCtrl.dispose();
      cmdCtrl.dispose();
    }
  }

  String? _validate(String name, String cmd, int? editingIdx) {
    if (name.isEmpty) return '${libL10n.empty} ${libL10n.name}';
    if (cmd.isEmpty) return '${libL10n.empty} ${libL10n.cmd}';
    // The name is base64-encoded into the file name, so it may contain
    // anything — but a file name has a length limit, and encoding grows it by
    // a third. 64 characters leaves room on every filesystem worth naming.
    if (name.characters.length > 64) return '${libL10n.invalid}: ${libL10n.name}';
    for (var i = 0; i < _cmds!.length; i++) {
      // One file per name: two commands sharing one would be a single file,
      // and the second would silently replace the first on save.
      if (i != editingIdx && _cmds![i].name == name) {
        return '${libL10n.invalid}: ${libL10n.name}';
      }
    }
    return null;
  }
}
