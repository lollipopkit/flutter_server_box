import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/default.dart';

class SettingStore extends HiveStore {
  SettingStore._() : super('setting');

  @visibleForTesting
  SettingStore.forBox(Box<dynamic> testBox) : super('setting_test') {
    box = testBox;
  }

  static final instance = SettingStore._();

  /// Time out for server connect and more...
  late final timeout = propertyDefault('timeOut', 5);

  /// Record history of SFTP path and etc.
  late final recordHistory = propertyDefault('recordHistory', true);

  /// Disk view: amount / IO
  late final serverTabPreferDiskAmount = propertyDefault(
    'serverTabPreferDiskAmount',
    false,
  );

  /// Bigger for bigger font size
  /// 1.0 means 100%
  /// Warning: This may cause some UI issues
  late final textFactor = propertyDefault('textFactor', 1.0);

  /// The seed of color scheme
  late final colorSeed = propertyDefault('primaryColor', 4287106639);

  late final serverStatusUpdateInterval = propertyDefault(
    'serverStatusUpdateInterval',
    Defaults.updateInterval,
  );

  // Max retry count when connect to server
  late final maxRetryCount = propertyDefault('maxRetryCount', 2);

  // Night mode: 0 -> auto, 1 -> light, 2 -> dark, 3 -> AMOLED, 4 -> AUTO-AMOLED
  late final themeMode = propertyDefault('themeMode', 0);

  // Font file path
  late final fontPath = propertyDefault('fontPath', '');

  // Backgroud running (Android)
  late final bgRun = propertyDefault('bgRun', isAndroid);

  // Server order
  late final serverOrder = listProperty<String>('serverOrder');

  late final snippetOrder = listProperty<String>('snippetOrder');

  // Server details page cards order
  late final detailCardOrder = listProperty(
    'detailCardOrder',
    defaultValue: ServerDetailCards.values.map((e) => e.name).toList(),
  );

  // Disabled detail cards (for persistence when toggling visibility)
  late final detailCardDisabled = listProperty<String>('detailCardDisabled');

  // Disabled SSH virtual keys (for persistence when toggling visibility)
  late final sshVirtKeysDisabled = listProperty<int>('sshVirtKeysDisabled');

  // SSH term font size
  late final termFontSize = propertyDefault('termFontSize', 13.0);

  // Locale
  late final locale = propertyDefault('locale', '');

  // SSH virtual key (ctrl | alt) auto turn off
  late final sshVirtualKeyAutoOff = propertyDefault(
    'sshVirtualKeyAutoOff',
    true,
  );

  late final editorFontSize = propertyDefault('editorFontSize', 12.5);

  late final editorFontFamily = propertyDefault('editorFontFamily', '');

  /// Trusted SSH host key fingerprints keyed by `serverId::keyType`.
  late final sshKnownHostFingerprints = propertyDefault<Map<String, String>>(
    'sshKnownHostFingerprints',
    const {},
    fromObj: (raw) {
      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      return <String, String>{};
    },
  );

  // Editor theme
  late final editorTheme = propertyDefault('editorTheme', Defaults.editorTheme);

  late final editorDarkTheme = propertyDefault(
    'editorDarkTheme',
    Defaults.editorDarkTheme,
  );

  late final fullScreen = propertyDefault('fullScreen', false);

  late final fullScreenJitter = propertyDefault('fullScreenJitter', true);

  late final sshVirtKeys = listProperty<int>(
    'sshVirtKeys',
    defaultValue: VirtKeyX.defaultOrder.map((e) => e.index).toList(),
    fromObj: (val) => List<int>.from(val as List),
  );

  late final netViewType = propertyDefault(
    'netViewType',
    NetViewType.speed,
    fromObj: (val) => NetViewType.values.firstWhereOrNull((e) => e.name == val),
    toObj: (type) => type?.name,
  );

  // Only valid on iOS
  late final autoUpdateHomeWidget = propertyDefault(
    'autoUpdateHomeWidget',
    isIOS,
  );

  /// Servers the watch app may show, by [Spi.id], in display order.
  ///
  /// The watch used to be configured by a list of URLs living only inside the
  /// WCSession application context — invisible to backup and sync, lost on
  /// reinstall, and unrelated to the server list the user actually maintains.
  /// Keeping the selection here makes the app the source of truth and the
  /// context merely the transport. iOS only.
  late final watchServerIds = listProperty<String>('watchServerIds');

  /// Raw Go-compat `/status` URLs typed by hand in builds before the watch
  /// could read a server record.
  ///
  /// Still pushed to the watch so an existing setup keeps working, and still
  /// editable so it can be emptied.
  ///
  /// TODO: drop this together with the watch app's `legacy` server kind and
  /// monitor's `/status` compat route, once no install can still be carrying
  /// one of these.
  late final watchLegacyUrls = listProperty<String>('watchLegacyUrls');

  /// Whether [watchLegacyUrls] has been seeded from the pre-existing
  /// application context. Runs at most once; the user may legitimately empty
  /// the list afterwards, and re-importing would resurrect it.
  ///
  /// TODO: drop with [watchLegacyUrls].
  late final watchLegacyUrlsImported = propertyDefault(
    'watchLegacyUrlsImported',
    false,
  );

  /// Server whose status feeds the iOS lock-screen accessory widget, by
  /// [Spi.id]. Empty means none is chosen, which is what every install had
  /// until now — the widget read an App Group key nothing ever wrote.
  late final accessoryWidgetServerId = propertyDefault(
    'accessoryWidgetServerId',
    '',
  );

  late final autoCheckAppUpdate = propertyDefault('autoCheckAppUpdate', true);

  /// Whether the server card carried the function buttons instead of the
  /// detail page.
  ///
  /// TODO: delete this and its stored key. Nothing reads it — the buttons are
  /// a bar floating over the detail page, which is where they are within reach
  /// on either layout, so there is no longer a choice to store.
  @Deprecated('The buttons float over the detail page on every layout')
  late final moveServerFuncs = propertyDefault(
    'moveOutServerTabFuncBtns',
    false,
  );

  // TODO: remove once shipped builds have stopped carrying it — the retired
  // `forceSinglePane` key stays in the settings box until something clears it.
  // Nothing reads it, so it costs one unused entry.

  /// Width of the list column, wherever one shares the window with what it
  /// opens: the server list, the terminal and file rails, the agent's
  /// history. One width for all of them, so the columns line up between
  /// tabs.
  ///
  /// Remembered because it is a working preference, not a one-off: someone who
  /// widens it to read long server names wants it that way tomorrow too.
  late final paneListWidth = propertyDefault('paneListWidth', 320.0);

  /// Whether use `rm -r` to delete directory on SFTP
  late final sftpRmrDir = propertyDefault('sftpRmrDir', false);

  /// Whether use system's primary color as the app's primary color
  late final useSystemPrimaryColor = propertyDefault(
    'useSystemPrimaryColor',
    false,
  );

  /// Only valid on iOS / Android / Windows
  late final useBioAuth = propertyDefault('useBioAuth', false);

  /// Delay to lock the App with BioAuth, in seconds.
  /// Set to `0` to disable this feature.
  late final delayBioAuthLock = propertyDefault('delayBioAuthLock', 0);

  /// The performance of highlight is bad
  late final editorHighlight = propertyDefault('editorHighlight', true);

  /// Open SFTP with last viewed path
  late final sftpOpenLastPath = propertyDefault('sftpOpenLastPath', true);

  /// Show folders first in SFTP file browser
  late final sftpShowFoldersFirst = propertyDefault(
    'sftpShowFoldersFirst',
    true,
  );

  /// Show tip of suspend
  late final showSuspendTip = propertyDefault('showSuspendTip', true);

  /// Whether collapse UI items by default
  late final collapseUIDefault = propertyDefault('collapseUIDefault', true);

  /// Terminal AI helper configuration
  late final askAiBaseUrl = propertyDefault(
    'askAiBaseUrl',
    'https://api.openai.com',
  );
  late final askAiApiKey = propertyDefault('askAiApiKey', '');
  late final askAiModel = propertyDefault('askAiModel', 'gpt-5.4-mini');
  late final askAiProtocol = propertyDefault('askAiProtocol', 'auto');
  late final askAiAutoRunSafeCommands = propertyDefault(
    'askAiAutoRunSafeCommands',
    false,
  );

  /// Whether the Agent may run commands on this device.
  ///
  /// Off until asked for, unlike a configured server. A server was added
  /// deliberately and is somewhere else; this machine is where the app's own
  /// stores, private keys and keychain live, and nobody opted into a model
  /// touching those by adding a server.
  ///
  /// Auto-running stays off here whatever [askAiAutoRunSafeCommands] says —
  /// that setting is about servers. See `AskAiCommand.canAutoRun`.
  late final agentLocalExec = propertyDefault('agentLocalExec', false);

  /// Enter sends the prompt and Shift+Enter starts a line. Off swaps them: a
  /// line break is the plain key, and sending is the modifier or the button.
  late final askAiSendOnEnter = propertyDefault('askAiSendOnEnter', true);

  /// Whether the Agent follows you onto the other tabs, and how much of it
  /// comes along. One of `AgentShellMode`'s names.
  late final agentShellMode = propertyDefault('agentShellMode', 'hidden');

  /// Where the floating Agent sits on a desktop window, and how big it is.
  ///
  /// A negative offset means "never placed", which the shell reads as its
  /// default corner — a first run has no position to restore, and 0,0 is a
  /// real position somebody may have dragged it to.
  late final agentShellLeft = propertyDefault('agentShellLeft', -1.0);
  late final agentShellTop = propertyDefault('agentShellTop', -1.0);
  late final agentShellWidth = propertyDefault('agentShellWidth', 400.0);
  late final agentShellHeight = propertyDefault('agentShellHeight', 560.0);

  /// Which edge the collapsed pill clings to on a phone, and how far down it.
  late final agentShellPillOnRight = propertyDefault(
    'agentShellPillOnRight',
    true,
  );
  late final agentShellPillY = propertyDefault('agentShellPillY', 0.62);

  /// How much of a phone screen the expanded Agent takes, as a fraction.
  late final agentShellSheetHeight = propertyDefault(
    'agentShellSheetHeight',
    0.62,
  );

  late final serverFuncBtns = listProperty(
    'serverBtns',
    defaultValue: ServerFuncBtn.defaultIdxs,
  );

  /// Docker is more popular than podman, set to `false` to use docker
  late final usePodman = propertyDefault('usePodman', false);

  /// Try to use `sudo` to run docker command
  late final containerTrySudo = propertyDefault('containerTrySudo', true);

  /// Keep previous server status when err occurs
  late final keepStatusWhenErr = propertyDefault('keepStatusWhenErr', false);

  /// Parse container stat
  late final containerParseStat = propertyDefault('containerParseStat', true);

  /// Auto refresh container status
  late final containerAutoRefresh = propertyDefault(
    'containerAutoRefresh',
    true,
  );

  /// Use double column servers page on Desktop
  late final doubleColumnServersPage = propertyDefault(
    'doubleColumnServersPage',
    true,
  );

  /// Remerber pwd in memory
  /// Used for [DialogX.showPwdDialog]
  late final rememberPwdInMem = propertyDefault('rememberPwdInMem', true);

  /// SSH Term Theme
  /// 0: follow app theme, 1: light, 2: dark
  late final termTheme = propertyDefault('termTheme', 0);

  late final lastVer = propertyDefault('lastVer', 0);

  /// Layout version of this device's local storage — see [SchemaVersion].
  ///
  /// Defaults to 2, not 0: storage that predates versioning is, by definition,
  /// whatever the last unversioned release wrote, and that is v2 (Spi with a
  /// flat SSH layout plus `monitorHttp`). A fresh install overwrites this with
  /// [SchemaVersion.current] before any migration runs.
  late final schemaVersion = propertyDefault('schemaVersion', 2);

  /// Hide title bar on desktop
  late final hideTitleBar = propertyDefault('hideTitleBar', isDesktop);

  /// Display CPU view as progress, also called as old CPU view
  late final cpuViewAsProgress = propertyDefault('cpuViewAsProgress', false);

  late final displayCpuIndex = propertyDefault('displayCpuIndex', true);

  late final editorSoftWrap = propertyDefault('editorSoftWrap', isIOS);

  late final sshTermHelpShown = propertyDefault('sshTermHelpShown', false);

  late final horizonVirtKey = propertyDefault('horizonVirtKey', false);

  /// general wake lock
  late final generalWakeLock = propertyDefault('generalWakeLock', false);

  /// ssh page
  late final sshWakeLock = propertyDefault('sshWakeLock', true);
  late final sshBgImage = propertyDefault('sshBgImage', '');
  late final sshBgOpacity = propertyDefault('sshBgOpacity', 0.3);
  late final sshBlurRadius = propertyDefault('sshBlurRadius', 0.0);

  /// fmt: https://example.com/{DIST}-{BRIGHT}.png
  late final serverLogoUrl = propertyDefault('serverLogoUrl', '');

  late final betaTest = propertyDefault('betaTest', false);

  /// For desktop only.
  /// Record the position and size of the window.
  late final windowState = property<WindowState>(
    'windowState',
    fromObj: (raw) =>
        WindowState.fromJson(jsonDecode(raw as String) as Map<String, dynamic>),
    toObj: (state) => state == null ? null : jsonEncode(state.toJson()),
  );

  late final introVer = propertyDefault('introVer', 0);

  late final letterCache = propertyDefault('letterCache', false);

  /// Set it to `$EDITOR`, `vim` and etc. to use remote system editor in SSH terminal.
  /// Set it empty to use local editor GUI.
  late final sftpEditor = propertyDefault('sftpEditor', '');

  /// Preferred terminal emulator command on desktop
  late final desktopTerminal = propertyDefault(
    'desktopTerminal',
    'x-terminal-emulator',
  );

  /// Copy the login password to clipboard before launching desktop SSH terminal
  late final desktopSshAutoCopyPassword = propertyDefault(
    'desktopSshAutoCopyPassword',
    false,
  );

  /// SSH connection mode on desktop.
  /// false = built-in (dartssh2 + xterm)
  /// true = system SSH (launch ssh command in external terminal)
  late final sshConnectionMode = propertyDefault('sshConnectionMode', false);

  /// Run foreground service on Android, if the SSH terminal is running
  late final fgService = propertyDefault('fgService', false);

  /// Close the editor after saving
  late final closeAfterSave = propertyDefault('closeAfterSave', false);

  /// Have notified user for notificaiton permission or not
  late final noNotiPerm = propertyDefault('noNotiPerm', false);

  /// The backup password
  late final backupPassword = SecureProp('bakPasswd');

  /// Whether to read SSH config from ~/.ssh/config on first time
  late final firstTimeReadSSHCfg = propertyDefault('firstTimeReadSSHCfg', true);

  /// Tabs at home page
  late final homeTabs = listProperty(
    'homeTabs',
    defaultValue: AppTab.values,
    fromObj: AppTab.parseAppTabsFromObj,
    toObj: (val) {
      return val?.map((e) => e.name).toList() ?? [];
    },
  );

  /// Add Agent to the legacy default home tabs once.
  Future<void> migrateHomeTabsAgent() async {
    const key = 'homeTabs';
    const flagKey = 'homeTabsAgentMigrated';
    if (box.get(flagKey) == true) return;

    final tabs = AppTab.parseAppTabsFromObj(box.get(key));
    const legacyDefaultTabs = {
      AppTab.server,
      AppTab.ssh,
      AppTab.file,
      AppTab.snippet,
    };
    if (tabs.length == legacyDefaultTabs.length &&
        tabs.toSet().containsAll(legacyDefaultTabs)) {
      await box.put(
        key,
        [...tabs, AppTab.agent].map((tab) => tab.name).toList(),
      );
    }
    await box.put(flagKey, true);
  }

  /// Hide port forward beta warning
  late final portForwardBetaWarned = propertyDefault(
    'portForwardBetaWarned',
    false,
  );

  late final sshPageSortBy = propertyDefault('sshPageSortBy', 0);
  late final sshPageSortAsc = propertyDefault('sshPageSortAsc', true);

  /// Whether to automatically start/attach tmux on SSH connect.
  late final tmuxAuto = propertyDefault('tmuxAuto', false);

  /// Whether to show the tmux session selector dialog on connect.
  late final tmuxShowSelector = propertyDefault('tmuxShowSelector', true);

  /// Default tmux session name. Empty string means use 'server_box'.
  late final tmuxSessionName = propertyDefault('tmuxSessionName', '');

  /// Migrate sshConnectionMode from old int values (-1/0/1) to bool.
  /// Call once after store initialization.
  void migrateSshConnectionMode() {
    const key = 'sshConnectionMode';
    const flagKey = 'sshConnectionModeMigrated';
    if (box.get(flagKey) == true) return;
    final raw = box.get(key);
    if (raw is int) {
      // -1 = auto, 0 = built-in, 1 = system SSH
      final bool value;
      if (raw == -1) {
        value = !isMacOS; // macOS default built-in, others default system SSH
      } else {
        value = raw != 0;
      }
      box.put(key, value);
    }
    box.put(flagKey, true);
  }
}
