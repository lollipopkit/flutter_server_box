import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/agent/agent.dart';
import 'package:server_box/view/page/benchmark/tab.dart';
import 'package:server_box/view/page/monitor/tab.dart';
import 'package:server_box/view/page/remote_desktop/tab.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/tab.dart';
import 'package:server_box/view/page/virt/tab.dart';
import 'package:server_box/view/page/workspace/tab.dart';

/// The page each tab opens. Apart from the rest of what a tab is
/// (`AppTabViewX`): a page listing tabs draws their marks and names, and
/// importing every tab's page with them made it depend on all of them.
extension AppTabPage on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const FileTabPage(),
      AppTab.snippet => const SnippetListPage(),
      AppTab.agent => const AgentPage(),
      AppTab.benchmark => const BenchmarkTabPage(),
      AppTab.remoteDesktop => const RemoteDesktopTabPage(),
      AppTab.virt => const VirtTabPage(),
      AppTab.workspace => const WorkspaceTabPage(),
      AppTab.monitor => const MonitorTabPage(),
    };
  }
}
