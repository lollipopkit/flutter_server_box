import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/llm/tools.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/agent/settings.dart';

/// The Agent on fl_pi_llm: what this app tells fl_pi_llm_ui about itself, and
/// starting the runtime.
abstract final class LlmHost {
  /// Configures the Agent and starts its runtime. After the stores are open.
  ///
  /// A runtime that does not start leaves the Agent unusable and says why
  /// there — every chat reports it — rather than the app not opening.
  ///
  /// [credentials] and [externalLibrary] are for tests, as in [Llm.init].
  static Future<void> init(
    ProviderContainer container, {
    @visibleForTesting LlmCredentials? credentials,
    @visibleForTesting ExternalLibrary? externalLibrary,
    @visibleForTesting Map<String, String> Function()? environment,
  }) async {
    AgentScope.container = container;
    _configure();
    try {
      await Llm.init(
        credentials: credentials,
        externalLibrary: externalLibrary,
        environment: environment,
      );
    } catch (e, s) {
      Loggers.app.severe('The Agent runtime did not start', e, s);
      return;
    }
    await LegacyAskAiMigration.run();
    try {
      await Skills.syncBuiltin(await builtinSkills());
    } catch (e, s) {
      Loggers.app.warning('Built-in skills', e, s);
    }
    // In the background: each server connects on its own, and one that wants
    // a sign-in says so on the tools page.
    if (LlmStores.tool.enabled.get()) unawaited(McpTools.connectStored());
    // The app-wide Agent's instructions list the servers: a server added,
    // renamed or connected is in the next open chat's prompt.
    container.listen(
      serversProvider.select((s) => (s.serverOrder, s.servers)),
      (_, _) => Chats.reconfigureSoon(),
    );
    Stores.setting.agentLocalExec.listenable().addListener(
      Chats.reconfigureSoon,
    );
  }

  /// Where the skills the app ships are, among its assets.
  static const _skillsAsset = '.claude/skills/';

  /// The skills this app ships — `serverbox-help`: how to use the app and run
  /// the Monitor agent. Read from the assets, which are the files Claude Code
  /// reads in the repository, so the two cannot drift apart.
  @visibleForTesting
  static Future<List<FoundSkill>> builtinSkills() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = <String, Uint8List>{
      for (final a in manifest.listAssets())
        if (a.startsWith(_skillsAsset))
          a.substring(_skillsAsset.length): (await rootBundle.load(a)).buffer.asUint8List(),
    };
    final skills = <FoundSkill>[];
    for (final dir in {for (final p in files.keys) p.split('/').first}) {
      skills.addAll(SkillDiscovery.find(files, path: dir).take(1));
    }
    return skills;
  }

  static void _configure() {
    LlmUi.appName = BuildData.name;
    LlmUi.appVersion = '${BuildData.build}';
    LlmUi.appUri = Uri.parse(Urls.site);
    LlmUi.openProviders = (context) => AgentProvidersPage.route.go(context);
    LlmUi.appTools = () => AgentTools.all;
    LlmUi.offers = offers;
    LlmUi.appPrompt = prompt;
  }

  /// A terminal's chats get that terminal and nothing else but the skills:
  /// they are about the shell on screen, and a tool reaching another machine
  /// or the web from there is not what anyone opened the panel for, where a
  /// skill only says how to do something. The app-wide Agent gets everything
  /// but a terminal, which it has none of.
  @visibleForTesting
  static bool offers(ChatMeta? meta, String group) =>
      AgentScope.terminalServerOf(meta) == null
      ? group != AgentTools.terminal
      : group == AgentTools.terminal ||
            group == TfSkill.groupName ||
            group == TfAskUser.groupName;

  @visibleForTesting
  static String? prompt(ChatMeta? meta) {
    final serverId = AgentScope.terminalServerOf(meta);
    if (serverId == null) {
      return AgentScope.container
          .read(globalAgentToolServiceProvider)
          .buildInstructions();
    }
    final name =
        TerminalHosts.of(serverId)?.serverName ??
        Stores.server.fetchOneRaw(serverId)?.name ??
        serverId;
    return terminalInstructions(name);
  }

  /// A terminal's chats: one server, the shell the user has open on it.
  @visibleForTesting
  static String terminalInstructions(String serverName) =>
      '''
You are the SSH operations Agent embedded in ServerBox, working only on the server named "$serverName", in the terminal the user has open on it.
Help the user diagnose issues and complete operational tasks. Use terminal_screen to read what the terminal shows, and terminal_run to run a command when remote inspection or a remote action is needed.
Propose one command at a time: the user reviews each before it runs, unless it is clearly read-only and they let such commands run by themselves. Never claim a command ran until its result is back.
When a command fails, read its output and try another way before asking the user. Many servers are BusyBox or another minimal userland, so a GNU-only option is worth retrying as its POSIX equivalent.
Prefer read-only inspection before changes. Avoid interactive commands and password prompts.
Set safe_to_run=true only for commands that are clearly read-only, idempotent and non-destructive. Set destructive=true when a command could lose data or take a service down; the app keeps its own list of dangerous commands, so use it for what a list cannot see.
Keep explanations concise and make risks explicit. Reply in the language the user writes in.''';
}

/// The Agent's settings from before fl_pi_llm: one OpenAI-compatible
/// endpoint, its key and model, kept together as the `askAi` settings row.
///
/// They become a custom provider, its key moves to the keychain — out of the
/// database, and so out of backups and sync — and the row goes. Idempotent:
/// nothing is done without the row, and a restore of an older backup that
/// brings it back is taken over the same way at the next launch.
///
/// TODO: remove once no install or backup can still carry `askAi`.
abstract final class LegacyAskAiMigration {
  static const key = 'askAi';
  static const providerId = 'serverbox';
  static const _defaultBaseUrl = 'https://api.openai.com/v1';

  static Future<void> run() async {
    final raw = Stores.setting.get<Object>(key);
    if (raw is! Map) return;
    String str(String k, String fallback) => switch (raw[k]) {
      final String v when v.trim().isNotEmpty => v.trim(),
      _ => fallback,
    };
    final baseUrl = str('baseUrl', _defaultBaseUrl);
    final apiKey = str('apiKey', '');
    final model = str('model', '');
    try {
      // Never set up: an empty key on the default endpoint is the default
      // row, written by nothing the user did.
      if ((apiKey.isNotEmpty || baseUrl != _defaultBaseUrl) &&
          model.isNotEmpty) {
        final host = Uri.tryParse(baseUrl)?.host;
        final provider = LlmCustomProvider(
          id: providerId,
          name: host == null || host.isEmpty ? BuildData.name : host,
          api: raw['protocol'] == 'responses'
              ? LlmApi.openaiResponses
              : LlmApi.openaiCompletions,
          baseUrl: baseUrl,
          models: [model],
          allowInsecure: raw['allowInsecure'] == true,
        );
        await Llm.setCredential(providerId, LlmCredential.apiKey(apiKey));
        await LlmStores.llm.customProviders.set([
          for (final p in LlmStores.llm.customProviders.get() ?? const [])
            if (p.id != providerId) p,
          provider,
        ]);
        await Llm.applyCustomProviders();
        if (LlmStores.llm.defaultModel.get() == null) {
          await LlmStores.llm.defaultModel.set(LlmModelRef(providerId, model));
        }
      }
      if (raw['autoRunSafeCommands'] == true) {
        Stores.setting.agentAutoRunSafe.put(true);
      }
      Stores.setting.remove(key, updateLastUpdateTsOnRemove: false);
    } catch (e, s) {
      // Kept for the next launch: the key is still only in the row.
      Loggers.app.warning('Moving the Agent settings to a provider', e, s);
    }
  }
}
