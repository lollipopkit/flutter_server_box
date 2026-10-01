part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  /// The section, in named groups: what the Agent may do by itself, and what
  /// it talks to — the providers and their models, its tools, and its skills.
  /// Those three are fl_pi_llm_ui's pages.
  List<SettingsGroup> _buildAskAiConfig() {
    final l10n = context.l10n;
    final local = LocalExec.forThisDevice();
    return [
      SettingsGroup(libL10n.general, [
        _buildAgentProviders(l10n),
        _buildAgentTools(l10n),
        _buildAgentSkills(l10n),
      ]),
      SettingsGroup(l10n.agentPermissions, [
        _buildAskAiAutoRun(l10n),
        // Absent where it could not be honoured: the sandboxed macOS build is
        // the App Store one, and an iOS build without the engine has no guest
        // to run in. Where the local target *is* a userland, a build that
        // cannot install one has nothing to offer either. A switch that turns
        // on nothing is worse than no switch.
        if (local != null && (!local.inRootfs || Rootfs.isAvailable))
          _buildAskAiLocalExec(l10n, local),
      ]),
    ];
  }

  SettingsRow _buildAgentProviders(AppLocalizations l10n) {
    final label = l10n.agentProviders;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.hub_outlined),
        title: Text(label),
        subtitle: Text(l10n.agentProvidersTip, style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => AgentProvidersPage.route.go(
          context,
          target: _SettingsWidth.pageTarget(context),
        ),
      ),
      keywords: '${l10n.agentProvidersTip} ${libL10n.apiKey} API model',
    );
  }

  SettingsRow _buildAgentTools(AppLocalizations l10n) {
    final label = l10n.agentTools;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.handyman_outlined),
        title: Text(label),
        subtitle: Text(l10n.agentToolsTip, style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => AgentToolsPage.route.go(
          context,
          target: _SettingsWidth.pageTarget(context),
        ),
      ),
      keywords: '${l10n.agentToolsTip} MCP',
    );
  }

  SettingsRow _buildAgentSkills(AppLocalizations l10n) {
    final label = l10n.agentSkills;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.auto_stories_outlined),
        title: Text(label),
        subtitle: Text(l10n.agentSkillsTip, style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => AgentSkillsPage.route.go(
          context,
          target: _SettingsWidth.pageTarget(context),
        ),
      ),
      keywords: '${l10n.agentSkillsTip} SKILL.md',
    );
  }

  SettingsRow _buildAskAiAutoRun(AppLocalizations l10n) {
    final label = l10n.askAiAutoRunSafeCommands;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: TipText(label, l10n.askAiAutoRunSafeCommandsTip),
        trailing: StoreSwitch(prop: _setting.agentAutoRunSafe),
      ),
      keywords: l10n.askAiAutoRunSafeCommandsTip,
    );
  }

  SettingsRow _buildAskAiLocalExec(AppLocalizations l10n, LocalExec local) {
    final label = l10n.agentLocalExec;
    // Two different machines: a container the app installed, or the computer
    // itself with the app's own data on it.
    final tip = local.inRootfs
        ? l10n.agentLocalExecRootfsTip
        : l10n.agentLocalExecTip;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.computer_outlined),
        title: TipText(label, tip),
        trailing: StoreSwitch(prop: _setting.agentLocalExec),
      ),
      keywords: tip,
    );
  }
}
