import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/workspace/workspace.dart';

/// What a view looks like and whether a server can show it.
///
/// Through the server's own function row where there is an entry for the
/// view: the icon, the name and — the part that matters — the answer to
/// "can this connection do it", which a monitor-only server answers per entry.
extension WorkspaceViewX on WorkspaceView {
  ServerFuncBtn? get func => switch (this) {
    WorkspaceView.term => ServerFuncBtn.terminal,
    WorkspaceView.files => ServerFuncBtn.files,
    WorkspaceView.docker => ServerFuncBtn.container,
    WorkspaceView.proc => ServerFuncBtn.process,
    WorkspaceView.systemd => ServerFuncBtn.systemd,
    WorkspaceView.snippet => ServerFuncBtn.snippet,
    WorkspaceView.status || WorkspaceView.agent => null,
  };

  IconData get icon => switch (this) {
    WorkspaceView.status => Icons.monitor_heart_outlined,
    WorkspaceView.agent => Icons.auto_awesome,
    // Not the function row's: that one is a brand mark, and a strip of tabs
    // reads better in one family of glyphs.
    WorkspaceView.docker => Icons.view_in_ar_outlined,
    WorkspaceView.systemd => Icons.settings_applications_outlined,
    _ => func!.icon,
  };

  String get label => switch (this) {
    WorkspaceView.status => l10n.status,
    WorkspaceView.agent => 'Agent',
    _ => func!.toStr,
  };

  /// Null when [spi] can show this; otherwise why not.
  String? unavailableOn(Spi spi, MonitorRemoteAccess? granted) {
    final f = func;
    if (f == null) return null;
    if (f.availableOn(spi, granted)) return null;
    return f.unavailableReason(spi, granted);
  }
}

/// `Terminal · web-02`: what a pane's bar calls its tab.
String wsTabTitle(WsTab tab, Spi? spi) =>
    '${tab.view.label} · ${spi?.name ?? libL10n.unknown}';
