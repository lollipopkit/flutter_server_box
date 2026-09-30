import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' as llm;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// The Agent's providers — their keys, models and the default one — as a page
/// of its own: fl_pi_llm_ui draws the body, which it leaves to the app to put
/// under a bar.
class AgentProvidersPage extends StatelessWidget {
  const AgentProvidersPage({super.key});

  static const route = AppRouteNoArg(
    page: AgentProvidersPage.new,
    path: '/settings/agent/providers',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(context.l10n.agentProviders)),
      body: const llm.ProvidersPage(),
    );
  }
}

/// Which tools the Agent may use, and the MCP servers it reaches — see
/// [AgentProvidersPage].
class AgentToolsPage extends StatelessWidget {
  const AgentToolsPage({super.key});

  static const route = AppRouteNoArg(
    page: AgentToolsPage.new,
    path: '/settings/agent/tools',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(context.l10n.agentTools)),
      body: const llm.ToolsPage(),
    );
  }
}

/// The skills the Agent can load, and installing them — see
/// [AgentProvidersPage].
class AgentSkillsPage extends StatelessWidget {
  const AgentSkillsPage({super.key});

  static const route = AppRouteNoArg(
    page: AgentSkillsPage.new,
    path: '/settings/agent/skills',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(context.l10n.agentSkills)),
      body: const llm.SkillsPage(),
    );
  }
}
