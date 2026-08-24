import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/app/agent_shell_config.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/store/field_prop.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';

class SettingStore extends SqliteStore {
  SettingStore._() : super('setting');

  /// A distinct store name, so a test on `SqliteDb.openInMemory()` cannot
  /// collide with another test's rows.
  @visibleForTesting
  SettingStore.forTest() : super('setting_test');

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

  /// Which profile a terminal opens in, by `LinuxProfile.id`.
  ///
  /// Empty until something is chosen; the platform layer reads that as "the
  /// first one installed". A profile and not a distribution, because two of the
  /// same distribution can be installed side by side.
  late final linuxProfile = propertyDefault('linuxProfile', '');

  /// Which distribution a *new* profile would be of, by `LinuxDistro.id`.
  ///
  /// By name, never by index: an index silently changes meaning when a case is
  /// inserted, and this outlives the build that wrote it. Read through
  /// `linuxDistro()`, which falls back for a name no build knows.
  late final linuxDistro = propertyDefault(
    'linuxDistro',
    LinuxDistro.alpine.id,
  );

  /// Each distribution's mirror, keyed by `LinuxDistro.id`.
  ///
  /// A map rather than one string, because a mirror of one distribution is not
  /// a mirror of another — switching away and back would otherwise drop what
  /// was typed. Absent means "the distribution's own default", so nothing here
  /// pins a default against a release that moves it. Read and written through
  /// `linuxMirror()` / `setLinuxMirror()`.
  late final linuxMirrors = propertyDefault<Map<String, String>>(
    'linuxMirrors',
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

  /// The resolvers written into the guest's `/etc/resolv.conf`.
  ///
  /// Not per distribution: this is the network the device is on. Read through
  /// `linuxNameservers()`, which is also what decides what counts as an address
  /// in it.
  late final linuxDns = propertyDefault('linuxDns', Defaults.linuxDns);

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

  /// Width of the list column, wherever one shares the window with what it
  /// opens: the server list, the terminal and file rails, the agent's
  /// history. One width for all of them, so the columns line up between
  /// tabs.
  ///
  /// Remembered because it is a working preference, not a one-off: someone who
  /// widens it to read long server names wants it that way tomorrow too.
  ///
  /// The default is what dragging used to bottom out at. Only new installs see
  /// it — anyone who has dragged a divider has a number of their own stored,
  /// and moving that under them would undo the choice this exists to keep.
  late final paneListWidth = propertyDefault('paneListWidth', 220.0);

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

  /// List entries whose name starts with a dot.
  ///
  /// Off, because the common case is looking for something you put there. Not
  /// per-backend: someone who wants to see `.ssh` on a server wants to see
  /// `.config` on this device too.
  late final showHiddenFiles = propertyDefault('showHiddenFiles', false);

  /// Show tip of suspend
  late final showSuspendTip = propertyDefault('showSuspendTip', true);

  /// Whether collapse UI items by default
  late final collapseUIDefault = propertyDefault('collapseUIDefault', true);

  /// Terminal AI helper configuration, as one row.
  ///
  /// Six keys before this. See [AskAiConfig] for what moved and why; the
  /// per-field names below are [FieldProp]s onto it, so a caller reads and
  /// writes one field with one field's type and hears about one field's
  /// changes.
  ///
  /// One row is also one entry in `lastUpdateTs`, and sync resolves per entry.
  /// So two devices editing *different* fields between syncs no longer both
  /// win: the later write takes the whole object, and the other device's field
  /// goes back to what this one had. That was per field before, and it is the
  /// price of the grouping. It is the same trade [agentShell] makes, and the
  /// reason to accept it is that these are provider settings changed on one
  /// device at a time, not records edited in parallel.
  late final askAi = propertyDefault<AskAiConfig>(
    'askAi',
    const AskAiConfig(),
    fromObj: (raw) =>
        raw is Map ? AskAiConfig.fromJson(Map<String, dynamic>.from(raw)) : null,
    toObj: (val) => val?.toJson(),
  );

  late final askAiBaseUrl = FieldProp<AskAiConfig, String>(
    askAi,
    'baseUrl',
    read: (c) => c.baseUrl,
    write: (c, v) => c.copyWith(baseUrl: v),
  );
  late final askAiApiKey = FieldProp<AskAiConfig, String>(
    askAi,
    'apiKey',
    read: (c) => c.apiKey,
    write: (c, v) => c.copyWith(apiKey: v),
  );
  late final askAiModel = FieldProp<AskAiConfig, String>(
    askAi,
    'model',
    read: (c) => c.model,
    write: (c, v) => c.copyWith(model: v),
  );
  late final askAiProtocol = FieldProp<AskAiConfig, String>(
    askAi,
    'protocol',
    read: (c) => c.protocol,
    write: (c, v) => c.copyWith(protocol: v),
  );
  late final askAiAutoRunSafeCommands = FieldProp<AskAiConfig, bool>(
    askAi,
    'autoRunSafeCommands',
    read: (c) => c.autoRunSafeCommands,
    write: (c, v) => c.copyWith(autoRunSafeCommands: v),
  );

  /// Enter sends the prompt and Shift+Enter starts a line. Off swaps them: a
  /// line break is the plain key, and sending is the modifier or the button.
  late final askAiSendOnEnter = FieldProp<AskAiConfig, bool>(
    askAi,
    'sendOnEnter',
    read: (c) => c.sendOnEnter,
    write: (c, v) => c.copyWith(sendOnEnter: v),
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
  ///
  /// Its own key, and outside [askAi] on purpose: that group is which provider
  /// to talk to, and this is what the app will let the answer do to this
  /// machine. A restore that carried a provider's configuration across should
  /// not carry that with it.
  late final agentLocalExec = propertyDefault('agentLocalExec', false);

  /// The floating Agent's placement and size, as one row.
  ///
  /// Eight keys before this. See [AgentShellConfig] for the nesting; the
  /// per-field names below are [FieldProp]s onto it.
  late final agentShell = propertyDefault<AgentShellConfig>(
    'agentShell',
    const AgentShellConfig(),
    fromObj: (raw) => raw is Map
        ? AgentShellConfig.fromJson(Map<String, dynamic>.from(raw))
        : null,
    toObj: (val) => val?.toJson(),
  );

  late final agentShellMode = FieldProp<AgentShellConfig, String>(
    agentShell,
    'mode',
    read: (c) => c.mode,
    write: (c, v) => c.copyWith(mode: v),
  );

  late final agentShellLeft = FieldProp<AgentShellConfig, double>(
    agentShell,
    'window.left',
    read: (c) => c.window.left,
    write: (c, v) => c.copyWith(window: c.window.copyWith(left: v)),
  );
  late final agentShellTop = FieldProp<AgentShellConfig, double>(
    agentShell,
    'window.top',
    read: (c) => c.window.top,
    write: (c, v) => c.copyWith(window: c.window.copyWith(top: v)),
  );
  late final agentShellWidth = FieldProp<AgentShellConfig, double>(
    agentShell,
    'window.width',
    read: (c) => c.window.width,
    write: (c, v) => c.copyWith(window: c.window.copyWith(width: v)),
  );
  late final agentShellHeight = FieldProp<AgentShellConfig, double>(
    agentShell,
    'window.height',
    read: (c) => c.window.height,
    write: (c, v) => c.copyWith(window: c.window.copyWith(height: v)),
  );

  late final agentShellPillOnRight = FieldProp<AgentShellConfig, bool>(
    agentShell,
    'pill.onRight',
    read: (c) => c.pill.onRight,
    write: (c, v) => c.copyWith(pill: c.pill.copyWith(onRight: v)),
  );
  late final agentShellPillY = FieldProp<AgentShellConfig, double>(
    agentShell,
    'pill.y',
    read: (c) => c.pill.y,
    write: (c, v) => c.copyWith(pill: c.pill.copyWith(y: v)),
  );
  late final agentShellSheetHeight = FieldProp<AgentShellConfig, double>(
    agentShell,
    'pill.sheetHeight',
    read: (c) => c.pill.sheetHeight,
    write: (c, v) => c.copyWith(pill: c.pill.copyWith(sheetHeight: v)),
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
  ///
  /// An **internal** key, so `getAllMap` leaves it out of a backup and `clear`
  /// leaves it alone. Under a plain key it travelled: restoring a backup taken
  /// on a device still on the previous release wrote that device's version
  /// back, and the next launch found a version with no migration registered for
  /// it and threw `SchemaTooNewException`'s counterpart — a `StateError` that
  /// nothing catches.
  ///
  /// Being internal also means it never stamps `lastUpdateTs`, which it must
  /// not: it describes this device's storage, so counting a migration writing
  /// it as a user edit would make a device that has only just upgraded claim
  /// the newer copy of everything at the next sync.
  ///
  /// TODO: drop `schemaVersion` from `removeRetiredKeys` once no install can
  /// still carry the plain-key copy this replaced.
  late final schemaVersion = propertyDefault(
    '${StoreDefaults.prefixKey}schemaVersion',
    2,
    updateLastModified: false,
  );

  /// Hide title bar on desktop
  late final hideTitleBar = propertyDefault('hideTitleBar', isDesktop);

  /// Display CPU view as progress, also called as old CPU view
  late final cpuViewAsProgress = propertyDefault('cpuViewAsProgress', false);

  late final displayCpuIndex = propertyDefault('displayCpuIndex', true);

  late final editorSoftWrap = propertyDefault('editorSoftWrap', isIOS);

  late final sshTermHelpShown = propertyDefault('sshTermHelpShown', false);

  /// Whether the walkthrough over the virtual keys has run.
  ///
  /// Separate from [sshTermHelpShown], which gates a dialog about the terminal
  /// body and is the only guidance a desktop gets — there are no virtual keys
  /// there to walk through.
  late final virtKeyIntroShown = propertyDefault('virtKeyIntroShown', false);

  /// How many rows of virtual keys the terminal shows at once, 0 for all.
  ///
  /// Rows past that go on a page of their own, swiped sideways. It replaced a
  /// switch meaning "one row, scrolled sideways", which is this set to 1 —
  /// with the difference that a swipe now lands on whole rows rather than
  /// leaving the row halfway between two keys. See [VirtKeyRowsMigration].
  late final virtKeyRows = propertyDefault('virtKeyRows', 0);

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

  /// The build number the App Store build last mentioned the DMG one for.
  ///
  /// `-1` means never again. Only the sandboxed macOS build reads it — see
  /// `DmgNotice`, which is where the once-per-version rule lives.
  late final dmgTipBuild = propertyDefault('dmgTipBuild', 0);

  /// For desktop only.
  /// Record the position and size of the window.
  /// Stored as an object, not as a string holding one.
  ///
  /// `SqliteStore.set` encodes whatever `toObj` returns, so returning an
  /// already-encoded string got it encoded a second time and the `value`
  /// column held `"{\"size\":{\"width\":1324.0,...}}"`. Twice the bytes, and
  /// the raw settings editor could only show it as one escaped line instead of
  /// a value with fields.
  ///
  /// No migration: `WindowStateListener` writes on every move and resize, so
  /// the row rewrites itself the first time the window is touched. The string
  /// branch below is what reads it until then.
  late final windowState = property<WindowState>(
    'windowState',
    fromObj: (raw) => switch (raw) {
      // TODO: delete the string branch once no install can still hold one.
      final String s =>
        WindowState.fromJson(jsonDecode(s) as Map<String, dynamic>),
      final Map m => WindowState.fromJson(Map<String, dynamic>.from(m)),
      _ => null,
    },
    toObj: (state) => state?.toJson(),
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

  /// Whether to draw a distribution's mark beside each server.
  ///
  /// On by default: it is what makes a list of machines readable at a glance,
  /// and the marks are redrawn public-domain glyphs used to refer to the
  /// systems they identify — see `assets/distro/README.md`. Off draws nothing
  /// at all rather than the neutral outline, for anyone who would rather the
  /// rows carried no mark.
  late final showDistIcon = propertyDefault('showDistIcon', true);

  /// Hide port forward beta warning
  late final portForwardBetaWarned = propertyDefault(
    'portForwardBetaWarned',
    false,
  );

  /// Whether the one-off guide over the tab strip has been shown.
  ///
  /// The bulk actions there open on a long press or a right-click, and neither
  /// leaves a mark on screen — nothing about the strip says the menu exists.
  /// A version flag would show it again after every update; what is wanted is
  /// once per install, so this is set the first time it is dismissed and never
  /// read again.
  late final navTabMenuGuided = propertyDefault('navTabMenuGuided', false);

  /// The highest rootfs-manifest serial this device has accepted.
  ///
  /// A signature stays valid for as long as the key does, so verifying one
  /// does not make it current. Refusing a serial below this is what stops an
  /// old signed manifest being replayed to pin a device to a rootfs whose
  /// problems are known.
  ///
  /// Device-local bookkeeping, so it does not stamp the sync clock: which
  /// manifest a phone has seen is not an edit anyone made.
  late final rootfsManifestSerial = propertyDefault(
    'rootfsManifestSerial',
    0,
    updateLastModified: false,
  );

  /// The last manifest that verified, and its signature, base64.
  ///
  /// Both, because the cache is re-verified when it is read rather than
  /// trusted for having once been verified — it sits in app storage, and
  /// re-checking 64 bytes costs nothing next to believing whatever is there.
  late final rootfsManifestCache = propertyDefault(
    'rootfsManifestCache',
    '',
    updateLastModified: false,
  );
  late final rootfsManifestCacheSig = propertyDefault(
    'rootfsManifestCacheSig',
    '',
    updateLastModified: false,
  );

  /// Hide the Linux beta warning, which is asked before an install.
  ///
  /// Separate from [portForwardBetaWarned] rather than one flag for every beta
  /// feature: dismissing the warning on one says nothing about having read the
  /// other, and the two are not the same risk.
  late final linuxBetaWarned = propertyDefault('linuxBetaWarned', false);

  late final sshPageSortBy = propertyDefault('sshPageSortBy', 0);
  late final sshPageSortAsc = propertyDefault('sshPageSortAsc', true);

  /// Whether to automatically start/attach tmux on SSH connect.
  late final tmuxAuto = propertyDefault('tmuxAuto', false);

  /// Whether to show the tmux session selector dialog on connect.
  late final tmuxShowSelector = propertyDefault('tmuxShowSelector', true);

  /// Default tmux session name. Empty string means use 'server_box'.
  late final tmuxSessionName = propertyDefault('tmuxSessionName', '');

  /// Removes settings for UI choices that no longer exist. Idempotent so old
  /// installs are cleaned without another migration flag becoming permanent
  /// state of its own.
  Future<void> removeRetiredKeys() async {
    for (final key in const [
      'moveOutServerTabFuncBtns',
      'forceSinglePane',
      // The plain-key schema version. It moved to an internal key so that a
      // backup stops carrying it; this drops the copy a Hive import brought
      // across, which nothing reads and a backup would still export.
      'schemaVersion',
    ]) {
      remove(key, updateLastUpdateTsOnRemove: false);
    }

    // The flags `SettingsFixupsMigration` reads, dropped once it has had its
    // pass. The version is what says so: this runs from `Stores.init`, before
    // `SchemaVersion.migrate`, so removing them unconditionally would delete
    // them in the very launch that has to read them. Past that version they
    // have no reader, and a restore of an older backup writes them back long
    // after the step could run again — which is why this is here rather than
    // at the end of the step.
    //
    // TODO: delete with the flag reads in `SettingsFixupsMigration`.
    if (schemaVersion.fetch() > SettingsFixupsMigration.appliedAt) {
      remove(
        SettingsFixupsMigration.sshFlagKey,
        updateLastUpdateTsOnRemove: false,
      );
      remove(
        SettingsFixupsMigration.homeTabsFlagKey,
        updateLastUpdateTsOnRemove: false,
      );
    }

    // The switch `virtKeyRows` replaced, for the same reason and on the same
    // terms: the step that reads it runs after this does, and a restore of an
    // older backup writes it back long after that step can run again.
    //
    // TODO: delete with the read in `VirtKeyRowsMigration`.
    if (schemaVersion.fetch() > VirtKeyRowsMigration.appliedAt) {
      remove(VirtKeyRowsMigration.legacyKey, updateLastUpdateTsOnRemove: false);
    }
  }
}
