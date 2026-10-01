// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get crashCollect => '诊断信息';

  @override
  String get crashCollectIntro =>
      'ServerBox 会记录运行过程中发生的情况，以便修复问题。你可以选择要发送多少信息。';

  @override
  String get crashCollectNone => '不发送';

  @override
  String get crashCollectNoneTip => '报告会保留在本机；发生崩溃后，你可手动发送。';

  @override
  String get crashCollectBasic => '基本信息';

  @override
  String get crashCollectBasicTip =>
      '只包含崩溃信息，不包含日志或性能数据。**这些信息可帮助我们改进 App 并修复问题。**';

  @override
  String get crashCollectFull => '完整信息';

  @override
  String get crashCollectFullTip =>
      '包含崩溃日志、性能数据和功能使用情况。**这些信息可帮助我们定位性能问题，并了解哪些功能真正有人使用。**';

  @override
  String get crashCollectFooter =>
      '无论选择哪个级别，记录时都会将已知服务器名称、地址和用户名替换为占位符。之后可在设置中更改收集级别。';

  @override
  String get privacy => '隐私';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get crashLastRunFailed => 'ServerBox 上次运行时异常退出。';

  @override
  String get crashReportTitle => '崩溃报告';

  @override
  String get crashReportHint =>
      '这是上次运行的日志。已知的服务器名称和地址已替换为占位符，但其中可能仍包含其他信息。提交前请仔细阅读。';

  @override
  String get crashReportSubmit => '复制并反馈';

  @override
  String get preReleaseUpdates => '接收预发布版本更新';

  @override
  String get addSystemPrivateKeyTip => '检测到暂无私钥，是否添加系统默认的私钥（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已添加至任务列表';

  @override
  String get askAi => '问 AI';

  @override
  String get askAiInsertTerminal => '插入终端';

  @override
  String get remoteDesktop => '远程桌面';

  @override
  String get askAiRiskReadOnly => '只读';

  @override
  String get askAiRiskCaution => '会更改系统';

  @override
  String get askAiRiskUnvetted => '未审核的主机';

  @override
  String get askAiRiskDestructive => '高风险';

  @override
  String get askAiAutoRunSafeCommands => '自动执行只读命令';

  @override
  String get askAiAutoRunSafeCommandsTip => '仅当模型与本地安全检查都判定命令为只读时自动执行';

  @override
  String get askAiHistory => '对话历史';

  @override
  String get askAiNewConversation => '新建对话';

  @override
  String get askAiUntitledConversation => '新对话';

  @override
  String get askAiRenameConversation => '重命名对话';

  @override
  String get askAiDeleteConversationTitle => '删除这个对话？';

  @override
  String get askAiDeleteConversationTip => '从本机删除该对话，无法撤销。';

  @override
  String get agentNoHistory => '暂无全局 Agent 对话';

  @override
  String get agentClearHistoryTitle => '清空全局 Agent 历史记录？';

  @override
  String get agentClearHistoryTip => '此设备上的全部全局 Agent 对话都将被删除。';

  @override
  String get agentToolShell => '终端命令';

  @override
  String get agentToolReadFile => '读取文件';

  @override
  String get agentToolWriteFile => '写入文件';

  @override
  String get floatOverTabs => '在其他标签页上悬浮';

  @override
  String get agentToolSshConnect => 'SSH 连接';

  @override
  String get agentToolSshDisconnect => '断开 SSH';

  @override
  String get agentSshConnectTitle => '连接到新主机';

  @override
  String get agentAuthMethod => '认证方式';

  @override
  String get agentSshConnectTip => 'Agent 想要建立 SSH 连接。请在此输入密码。';

  @override
  String get agentAdHocSessions => '临时连接';

  @override
  String get agentSaveServerTitle => '保存为服务器';

  @override
  String get agentSaveServerTip => '这台主机和你输入的密码将保存在本设备上';

  @override
  String get agentMonitorOptional => 'Monitor 代理（可选）';

  @override
  String get authFailTip => '认证失败，请检查信息是否正确';

  @override
  String get autoBackupConflict => '仅可启用一个自动备份任务';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoRun => '自动运行';

  @override
  String get autoUpdateHomeWidget => '自动更新桌面小部件';

  @override
  String get availableTabs => '可用标签';

  @override
  String get backupEncrypted => '备份已加密';

  @override
  String get backupNotEncrypted => '备份未加密';

  @override
  String get backupPassword => '备份密码';

  @override
  String get backupPasswordRemoved => '备份密码已移除';

  @override
  String get backupPasswordSet => '备份密码已设置';

  @override
  String get backupPasswordTip => '设置密码以加密备份文件。留空则禁用加密。';

  @override
  String get backupPasswordWrong => '备份密码错误';

  @override
  String get connectAll => '全部连接';

  @override
  String get disconnectAll => '全部断开';

  @override
  String get distIcon => '发行版标识';

  @override
  String get distIconIntroLegal =>
      '标识只根据本设备从远程系统读取的信息显示。这些信息可能不准确或已过期，也不代表某个衍生版本、重构版本或特定版本。无法识别时会显示通用图标。\n\n各标识均为其所有者的商标，此处仅用于说明对应的系统。';

  @override
  String get distIconTip => '在每台服务器旁显示一个小标识，表示它可能运行的系统';

  @override
  String get distNameMap => '名称映射';

  @override
  String get distNameMapTip =>
      '仅用于「托管处的文件名和本应用使用的名称对不上」的发行版。键是本应用使用的名称，值是实际要取的名称。没有缺图就不用填。';

  @override
  String get logoUrl => 'Logo 地址';

  @override
  String get logoUrlTip => '服务器详情页顶部的大图，按原色显示。';

  @override
  String get globe => '地球仪';

  @override
  String get locationTip =>
      '此服务器在地球仪上的显示位置。纬度在前、经度在后，单位为度，例如 39.9042, 116.4074。';

  @override
  String get markUrl => '标识地址';

  @override
  String get markUrlTip => '列表中服务器名字旁边的小标识。留空则不显示。\n\n和 Logo 不是同一张图';

  @override
  String get navTabMenuTip => '长按标签栏图标（鼠标右键点击）可一次性连接或断开其中的全部内容。';

  @override
  String nTags(int count) {
    return '$count 个标签';
  }

  @override
  String get remoteBackupPasswordRequired => '远程备份需要非空的备份密码';

  @override
  String get monitorHttpsRequired => '远程监控代理必须使用 HTTPS，除非该连接已允许 HTTP。';

  @override
  String get monitorAllowInsecureHttp => '允许 HTTP';

  @override
  String get plainHttpTitle => '这个 agent 走的是明文 HTTP';

  @override
  String get plainHttpTip => '密码和这个应用取的所有内容都会以明文传输。目前还没有发出任何东西。';

  @override
  String get allowForThisServer => '只对这台服务器允许';

  @override
  String get viewError => '查看错误';

  @override
  String get monitorAllowInsecureHttpTip =>
      '仅应在 HTTP 之外具备传输加密的可信私有网络中开启，例如 Tailscale';

  @override
  String monitorHttpTip(String url) {
    return '通过 **monitor** 的 HTTP 接口读取此服务器的状态，而不是经由 SSH 执行命令。\n\n需要先在服务器上安装 monitor；曲线、手表 App 和桌面小部件都依赖它。\n\n[如何部署 monitor]($url)';
  }

  @override
  String get backupTip => '导出数据可通过密码加密，请妥善保管。';

  @override
  String get icloudBackupStatusTitle => '备份状态';

  @override
  String get icloudBackupStatusLoading => '正在读取 iCloud 备份状态...';

  @override
  String get icloudBackupStatusError => '无法读取 iCloud 备份元数据';

  @override
  String get icloudBackupStatusEmpty => '尚未发现 iCloud 备份文件';

  @override
  String get icloudBackupStateUploading => '上传中';

  @override
  String get icloudBackupStateConflict => '检测到冲突';

  @override
  String get icloudBackupStateUploaded => '已上传';

  @override
  String get icloudBackupStateWaiting => '等待 iCloud 同步';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return '最后备份：$lastModified\n状态：$remoteState';
  }

  @override
  String get bgRun => '后台运行';

  @override
  String get bgRunTip =>
      '此开关只代表程序会尝试在后台运行，具体能否后台运行取决于是否开启了权限。原生 Android 请关闭本 App 的“电池优化”，MIUI / HyperOS 请将省电策略改为“无限制”。';

  @override
  String get trayReadings => '读数';

  @override
  String get trayChart => '图表';

  @override
  String get trayChartNone => '无';

  @override
  String get trayCompact => '紧凑行';

  @override
  String get trayCompactTip =>
      '每台服务器显示一行，不显示图表。Linux 的面板菜单通过 D-Bus 传递标签而非自定义布局，因此始终使用单行布局，但仍可将所选图表作为图片显示。';

  @override
  String get trayKeepRunning => '在托盘中继续运行';

  @override
  String get trayKeepRunningTip =>
      '关闭窗口后，App 会留在菜单栏或通知区域中，并继续监控服务器。关闭此选项后，关闭按钮会退出 App。';

  @override
  String get bgRunNeedsNotification => '后台运行需要显示常驻通知，但 App 尚未获得通知权限。点击授权。';

  @override
  String get clearAllStatsContent => '确定要清空所有服务器的连接统计数据吗？此操作无法撤销。';

  @override
  String get clearAllStatsTitle => '清空所有统计';

  @override
  String clearServerStatsContent(String serverName) {
    return '确定要清空服务器 \"$serverName\" 的连接统计数据吗？此操作无法撤销。';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return '清空 $serverName 统计';
  }

  @override
  String get clearThisServerStats => '清空此服务器统计';

  @override
  String get closeAfterSave => '保存后关闭';

  @override
  String get collapseUITip => '是否默认折叠 UI 中的长列表';

  @override
  String get connectionDetails => '连接详情';

  @override
  String get connectionStats => '连接统计';

  @override
  String get connectionStatsDesc => '查看服务器连接成功率和历史记录';

  @override
  String get containerTrySudoTip =>
      '例如：在应用内将用户设置为 aaa，但是 Docker 安装在root用户下，这时就需要启用此选项';

  @override
  String get containerSudoPasswordRequired => '需要 sudo 密码才能访问 Docker。请输入您的密码。';

  @override
  String get containerSudoPasswordIncorrect => 'sudo 密码错误或无权限。请重试。';

  @override
  String get copyPath => '复制路径';

  @override
  String get customCmd => '自定义命令';

  @override
  String get deleteServers => '批量删除服务器';

  @override
  String get deleteDirRecursive => '连同文件夹里的所有内容一起删除';

  @override
  String get dirEmpty => '请确保目录为空';

  @override
  String get discoverSshServers => '发现SSH服务器';

  @override
  String get discoveryFailed => '发现失败';

  @override
  String get discoverySettings => '发现设置';

  @override
  String get distro => '发行版';

  @override
  String get diskHealth => '磁盘健康';

  @override
  String dl2Local(String fileName) {
    return '下载 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '没有正在运行的容器。\n这可能是因为：\n- Docker 安装用户与 App 内配置的用户名不同\n- 环境变量 DOCKER_HOST 没有被正确读取。可以通过在终端内运行 `echo \$DOCKER_HOST` 来获取。';

  @override
  String get dockerProjectOther => '其他';

  @override
  String get dockerPruneTip => '清理未使用的数据以释放磁盘空间';

  @override
  String get dockerStatistics => 'Docker 统计';

  @override
  String get editVirtKeys => '虚拟按键';

  @override
  String get editorHighlightTip => '代码高亮功能可能影响性能，可选择关闭。';

  @override
  String get enableMdns => '启用mDNS';

  @override
  String get enableMdnsDesc => '使用mDNS/Bonjour发现SSH服务';

  @override
  String get envVars => '环境变量';

  @override
  String get extraArgs => '额外参数';

  @override
  String get fallbackSshDest => '备选 SSH 目标';

  @override
  String get fdroidReleaseTip => '如果你是从 F-Droid 下载的本应用，推荐关闭此选项';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return '文件 \'$file\' 过大 \'$size\'，超过了 $sizeMax';
  }

  @override
  String get fileDirGone => '此文件夹已不存在';

  @override
  String get fileDirGoneTip => '已被删除或重命名';

  @override
  String get fullScreen => '全屏';

  @override
  String get fullScreenJitter => '全屏模式抖动';

  @override
  String get fullScreenJitterHelp => '用于防止屏幕烧屏';

  @override
  String get fullScreenTip => '当设备旋转为横屏时，是否开启全屏模式。此选项仅作用于服务器 Tab 页。';

  @override
  String get githubGistIdOptional => 'Gist ID（可选）';

  @override
  String get githubGistToken => 'GitHub Gist Token';

  @override
  String get githubGistTokenEmpty => 'Token 为空';

  @override
  String get goto => '前往';

  @override
  String get homeTabs => '主页标签';

  @override
  String get homeTabsCustomizeDesc => '自定义主页上显示的标签及其顺序';

  @override
  String get ignoreCert => '忽略证书';

  @override
  String get image => '镜像';

  @override
  String get macDmgBody =>
      'App Store 要求本应用沙盒运行，而沙盒内无法开启终端。DMG 版可以开启。\n\nApp Store 版以后可能停止更新。';

  @override
  String get macDmgImportDenied => 'macOS 不允许读取此前安装版本的数据';

  @override
  String get macDmgImported => '已导入此前安装版本的数据';

  @override
  String get macDmgImportFailed => '读不到此前安装版本的数据';

  @override
  String get macDmgTip => '本机终端、在本机运行 snippet(DMG 版)';

  @override
  String get macDmgTitle => 'DMG 版';

  @override
  String get showHiddenFiles => '显示隐藏文件';

  @override
  String get sshKeyAlgorithm => '算法';

  @override
  String get sshKeyComment => '备注';

  @override
  String get sshKeyGenerate => '生成密钥对';

  @override
  String get sshKeyGenerating => '生成中…';

  @override
  String sshKeyLockedFmt(String name) {
    return '私钥 [$name] 未解锁。';
  }

  @override
  String get sshKeyPassphraseTip => '可选。设置口令后，私钥将加密存储，每次连接首次使用该密钥时会要求输入。';

  @override
  String get sshKeyPassphraseWrong => '口令错误。';

  @override
  String get sshKeyPublicKey => '公钥';

  @override
  String get sshKeyPublicKeyTip => '将此行追加到服务器的 ~/.ssh/authorized_keys。';

  @override
  String get sshKeyRecommended => '推荐';

  @override
  String sshKeyUnlockTip(String name) {
    return '请输入私钥 [$name] 的口令。';
  }

  @override
  String get ungrouped => '未分组';

  @override
  String get containerReclaimable => '可回收';

  @override
  String get unused => '未使用';

  @override
  String get dangling => '悬空';

  @override
  String get pruneUnusedImages => '清理未使用镜像';

  @override
  String get pruneDanglingImages => '清理悬空镜像';

  @override
  String get pruneImages => '清理镜像';

  @override
  String get unusedTaggedImages => '未使用标记';

  @override
  String get pruneDanglingImagesTip => '仅移除悬空镜像。';

  @override
  String get pruneUnusedImagesTip => '同时移除未被任何容器使用的已标记镜像。';

  @override
  String get includeUnusedVolumesTip => '同时移除未被任何容器使用的卷。';

  @override
  String get pruneCommandPreview => '命令预览';

  @override
  String get pruneForceSshTip => '远程执行始终启用 -f，以跳过无法交互的确认提示。';

  @override
  String get pruneVolumes => '清理卷';

  @override
  String get pruneUnusedData => '清理未使用数据';

  @override
  String get pull => '拉取';

  @override
  String get invalidHostFormat => '主机格式无效，仅支持 IPv4、IPv6 和域名字符。';

  @override
  String get jumpServer => '跳板服务器';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return '未找到 $serverName 配置的跳板服务器：$jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '「$name」已存在';
  }

  @override
  String get noJumpServerAvailable => '没有可用的跳板服务器。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '跳板服务器与 ProxyCommand 不能同时使用。';

  @override
  String get noConnectionMethod => '请配置 SSH、Monitor 或两者';

  @override
  String get keepForeground => '请将应用保持在前台运行';

  @override
  String get keepStatusWhenErr => '保留上次的服务器状态';

  @override
  String get keepStatusWhenErrTip => '仅限于执行脚本出错';

  @override
  String get keyAuth => '密钥认证';

  @override
  String get lastFailure => '最后失败';

  @override
  String get lastSuccess => '最后成功';

  @override
  String get letterCache => '普通键盘输入';

  @override
  String get letterCacheTip => '开启后，输入内容会经过普通输入法，这样可避免部分系统在终端弹出安全键盘';

  @override
  String get linuxShellTip => '终端用什么 shell 启动。留空恢复 /bin/sh。';

  @override
  String get linuxNetTip => 'DNS 服务器。留空恢复默认值';

  @override
  String madeWithLove(String myGithub) {
    return '用❤️制作 by $myGithub';
  }

  @override
  String get maxConcurrency => '最大并发数';

  @override
  String get maxRetryCount => '服务器尝试重连次数';

  @override
  String get mirror => '镜像';

  @override
  String get needRestart => '需要重启 App';

  @override
  String get newContainer => '新建容器';

  @override
  String get noConnectionStatsData => '暂无连接统计数据';

  @override
  String get noPrivateKeyTip => '私钥不存在，可能已被删除/配置错误';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get openLastPath => '打开上次的路径';

  @override
  String get openLastPathTip => '将为每台服务器记录其最后访问路径';

  @override
  String get parseContainerStatsTip => 'Docker 解析占用状态较为缓慢';

  @override
  String get privateKey => '私钥';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return '未找到私钥 [$keyId]。';
  }

  @override
  String get bmcPowerOnAction => '开机';

  @override
  String get bmcShutdown => '关机';

  @override
  String get bmcForceOff => '强制断电';

  @override
  String get restart => '重启';

  @override
  String get bmcPowerCycle => '冷重启';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '要对 $server 执行「$resetType」吗？';
  }

  @override
  String get bmcPowerDone => '电源状态已改变';

  @override
  String get bmcPowerAccepted => '操作已接受，但电源状态尚未改变。正常关机或重启是否成功取决于操作系统。';

  @override
  String get bmcPowerUnsupported => '该服务不允许这个操作的任何类型';

  @override
  String get bmcUnauthorized => 'BMC 拒绝了这个账号';

  @override
  String get bmcAccountMissing => '此 BMC 未设置账号';

  @override
  String get bmcPowerOn => '已开机';

  @override
  String get bmcPowerOff => '已关机';

  @override
  String get bmcCertRejected => '证书被拒绝——请在服务器设置里确认';

  @override
  String get bmcNotAService => '该地址上没有 Redfish 服务';

  @override
  String get bmcNoSystem => '该服务没有报告任何 system';

  @override
  String get bmcSensorsTruncated => '只显示了前面若干个传感器';

  @override
  String get bmcMultipleSystems => '仅显示第一个系统';

  @override
  String get bmcTip =>
      'BMC 是主板上的独立管理设备。即使主机已关机或操作系统无响应，它通常仍可访问。配置后，App 可以读取电源状态和硬件传感器。此功能需要 Redfish，大多数 2016 年以后的企业级硬件均支持。';

  @override
  String get bmcCert => '证书';

  @override
  String get bmcCertPinned => '已确认并钉住';

  @override
  String get bmcCertUnreviewed => '尚未确认——点击查看证书';

  @override
  String get bmcCertReview => '收到自签名证书。接受前请核对指纹；接受后将只信任这张证书。';

  @override
  String get bmcCertChanged => '证书不一致。请核对。';

  @override
  String get bmcCertExpired => '已过期。';

  @override
  String bmcCertWas(String fingerprint) {
    return '之前接受的：$fingerprint';
  }

  @override
  String get bmcAddrInvalid => 'BMC 地址必须是 URL，例如 https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      '此版本运行在沙盒中：命令使用的是空白家目录，因此依赖 ~/.ssh 的命令会失败。DMG 版不受此限制。';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return '无法读取私钥文件 $path:$reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return '此版本无法读取沙盒外的文件，因此无法访问 $path 中的密钥。请在设置中导入密钥，或改用 DMG 版。';
  }

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get liveActivity => '实时活动';

  @override
  String get liveActivityTip => '在锁屏和灵动岛上显示终端会话。无需解锁即可看到服务器名称和连接状态。';

  @override
  String get liveActivitySystemDisabled =>
      'iOS 未允许显示。开关位于「设置 › ServerBox › 实时活动」和「设置 › 面容 ID 与密码 › 实时活动」。';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand 在本机的 Linux 环境中运行，请先安装一个 Linux 系统。';

  @override
  String get proxyCommandMobileTip =>
      '在手机上，该命令会在所选的 Linux 系统中运行。请先在其中安装命令用到的工具（nc、socat 等）。';

  @override
  String get pveIgnoreCertTip => '不推荐开启，注意安全隐患！如果你使用的 PVE 默认证书，需要开启该选项';

  @override
  String get pvePasswordRequired => '需要提供 PVE 密码，请在服务器设置中填写。';

  @override
  String get pveOtpRequired => '此 PVE 服务器已启用双因素认证，请输入 OTP 验证码。';

  @override
  String get pveOtpCodeRequired => '请输入 OTP 验证码。';

  @override
  String get pveOtpVerificationFailed => 'OTP 验证失败，请使用最新验证码重试。';

  @override
  String get pveOtpTitle => 'OTP 验证';

  @override
  String get pveOtpLabel => 'OTP 验证码';

  @override
  String get pveInvalidResponseBody => 'PVE 登录返回了无效的响应内容。';

  @override
  String get pveInvalidResponseData => 'PVE 登录响应中缺少有效的 data 数据。';

  @override
  String get pveMissingAuthTicket => 'PVE 登录成功，但未返回认证票据。';

  @override
  String get pveLoadingConnect => '正在连接...';

  @override
  String get pvePassword => 'PVE 密码';

  @override
  String get pvePasswordHint => '使用密钥认证时需要填写';

  @override
  String get read => '读';

  @override
  String get recentConnections => '最近连接记录';

  @override
  String get rememberPwdInMem => '在内存中记住密码';

  @override
  String get rememberPwdInMemTip => '用于容器、挂起等';

  @override
  String get remotePath => '远端路径';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '已安装 $distro $installed，新版本为 $latest。更新会重新下载并替换整个容器，$pm 中的数据将丢失。';
  }

  @override
  String linuxSystemInUse(String name) {
    return '请先关闭 $name 上的终端，再删除';
  }

  @override
  String get rootfsSubtitle => '本机上的 Linux 用户空间';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return '下载 $distro $version(约 $size MB)并解压到本机。';
  }

  @override
  String get sameIdServerExist => '已存在相同 id 的服务器';

  @override
  String get second => '秒';

  @override
  String get serverFilesUnavailableTip =>
      '需要能通过 SSH 连接这台服务器，或者安装 Monitor agent 并开启文件 API。';

  @override
  String get back => '返回';

  @override
  String get history => '历史';

  @override
  String get homeDir => '主目录';

  @override
  String selected(int count) {
    return '已选 $count 项';
  }

  @override
  String get sendTo => '发送到…';

  @override
  String get serverFuncBtns => '服务器功能按钮';

  @override
  String get serverOrder => '服务器顺序';

  @override
  String get serverOverview => '服务器总览';

  @override
  String get serverOverviewTip => '在服务器列表顶部显示总览，并在打开的服务器上方显示服务器切换栏';

  @override
  String get serverTabEmpty => '还没有服务器';

  @override
  String get serverTabRequired => '服务器标签不能被移除';

  @override
  String get shareCodeHint => '请将这组数字另行告知接收方；验证码不包含在二维码中。';

  @override
  String get shareCodePrompt => '6 位验证码';

  @override
  String get shareCodeTitle => '一次性验证码';

  @override
  String get shareExpired => '此分享已过期，请让分享方重新生成。';

  @override
  String get shareImportFile => '从分享文件导入';

  @override
  String get shareImportTitle => '导入共享服务器';

  @override
  String get shareIncludesKey => '分享内容包含私钥。';

  @override
  String get shareOmittedBmc => 'BMC 凭据（仅包含地址，不包含账号和密码）。';

  @override
  String get shareOmittedJump => '跳板机（它在本机保存为另一台服务器）。';

  @override
  String get shareOmittedKeyPath => '密钥文件（该路径仅在本机有效）。';

  @override
  String get shareOmittedMissingKey => '私钥（本机密钥库中没有该密钥）。';

  @override
  String get shareOmittedTip => '以下内容未包含，接收方需自行配置：';

  @override
  String get sharePassphraseTip => '此密码用于加密文件。接收方导入服务器时需要输入，且无法找回。';

  @override
  String shareQrTip(int minutes) {
    return '二维码中的连接信息已加密，此分享将在 $minutes 分钟后过期。';
  }

  @override
  String get shareScanQr => '扫描二维码';

  @override
  String shareServerExists(String name) {
    return '本机服务器“$name”已使用此地址。仍要导入吗？';
  }

  @override
  String get shareTooBigForQr => '内容过大，无法生成二维码，请改用文件分享。';

  @override
  String get shareTooNew => '此分享由较新版本的 ServerBox 创建，请升级应用后再打开。';

  @override
  String get shareUnreadable => '这不是有效的 ServerBox 分享内容。';

  @override
  String get shareVia => '分享方式';

  @override
  String get sftpDlPrepare => '准备连接至服务器...';

  @override
  String get sftpEditorTip =>
      '如果为空，使用App内置的文件编辑器.  例如 `vim` (建议根据 `EDITOR` 自动获取).';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 来删除文件夹';

  @override
  String get sftpSSHConnected => 'SFTP 已连接';

  @override
  String get sftpShowFoldersFirst => '文件夹显示在前';

  @override
  String get sftpUnavailableUseScp =>
      '如果这台设备没有 SFTP 子系统（常见于嵌入式设备），请在服务器设置中将文件传输改为 SCP。';

  @override
  String get sshFileTransportTip =>
      '普通设备建议使用 SFTP。如果老旧或嵌入式设备的 SSH 服务没有 SFTP 子系统，请选择 SCP。SCP 需要 `scp` 命令，以及提供 `find`、`stat`、`mv`、`chmod` 等常用文件命令的 shell 环境。';

  @override
  String get specifyDev => '指定设备';

  @override
  String get specifyDevTip => '网络流量默认统计所有设备，可以在这里指定特定设备';

  @override
  String get tempIsCelsiusTip =>
      '开启后，温度值将被视为摄氏度而非毫摄氏度。仅在温度显示不正确时开启（例如显示0.1°C而非58°C）。';

  @override
  String spentTime(String time) {
    return '耗时：$time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return '所有服务器已存在（发现 $duplicateCount 个重复项）';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount 个重复项将被跳过';
  }

  @override
  String get sshConfigFound => '我们在您的系统中发现了 SSH 配置。';

  @override
  String sshConfigFoundServers(int totalCount) {
    return '发现 $totalCount 个服务器';
  }

  @override
  String get sshConfigImport => 'SSH 配置导入';

  @override
  String get sshConfigImportPermission => '是否允许读取 ~/.ssh/config 并自动导入服务器设置？';

  @override
  String get sshConfigImportTip => '首次创建服务器时提示读取 ~/.ssh/config';

  @override
  String sshConfigImported(int count) {
    return '从 SSH 配置导入了 $count 个服务器';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return '服务器 $serverName 的 SSH 主机密钥已更改，仅在信任该服务器时继续。';
  }

  @override
  String get sshHostKeyType => 'SSH 主机密钥类型';

  @override
  String get sshKnownHostKeys => '已信任的主机';

  @override
  String get sshKnownHostKeysTip => '本 app 已接受的主机密钥';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return '收到来自 $serverName 的新 SSH 主机密钥，在信任前请检查指纹。';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return '已存储的指纹：$fingerprint';
  }

  @override
  String get sshVerificationCode => '验证码';

  @override
  String get sshConfigManualSelect => '是否要手动选择 SSH 配置文件？';

  @override
  String get sshConfigNoServers => 'SSH 配置中未找到服务器';

  @override
  String get sshConfigPermissionDenied => '由于 macOS 权限限制，无法访问 SSH 配置文件。';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount 个服务器将被导入';
  }

  @override
  String get sshTermHelp =>
      '在终端可滚动时，横向拖动可以选中文字。点击键盘按钮可以开启/关闭键盘。文件图标会打开当前路径 SFTP。剪切板按钮会在有选中文字时复制内容，在未选中并且剪切板有内容时粘贴内容到终端。代码图标会粘贴代码片段到终端并执行。';

  @override
  String get sshVirtualKeyAutoOff => '虚拟按键自动切换';

  @override
  String get supportFmtArgs => '支持以下格式化参数：';

  @override
  String get suspendTip => 'suspend 功能需要 root 权限及 systemd 支持。';

  @override
  String switchTo(String val) {
    return '切换到 $val';
  }

  @override
  String get syncAppSettings => '同步应用设置';

  @override
  String get syncAppSettingsTip => '在自动同步中包含主题、布局、编辑器、终端等设备偏好设置。';

  @override
  String get termFontSizeTip => '此设置会影响终端大小（宽和高）。可以在终端页面缩放来调整当前会话的字体大小';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），仅作用于服务器页面部分字体，不建议修改。';

  @override
  String get times => '次';

  @override
  String get trySudo => '尝试使用 sudo';

  @override
  String get sudoPromptNotFound => '当前没有 sudo 密码提示。';

  @override
  String get updateServerStatusInterval => '服务器状态刷新间隔';

  @override
  String get useNoPwd => '将会使用无密码';

  @override
  String get usePodmanByDefault => '默认使用 Podman';

  @override
  String get used => '已用';

  @override
  String get viewDetails => '查看详情';

  @override
  String get virtKeyHelpIME => '打开/关闭键盘';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打开当前路径。';

  @override
  String get virtKeyHelpSnippet => '选择一个代码片段并在当前终端执行。';

  @override
  String get virtKeyHelpTmux => '在 tmux 的 session 和 window 之间切换。';

  @override
  String get virtKeyIntroActions => '快捷操作';

  @override
  String get virtKeyIntroActionsTip => '这些键不输入字符，而是打开对应功能。长按可查看说明。';

  @override
  String get virtKeyIntroCustomizeTip =>
      '在终端设置里可以调整顺序、开启更多键（文件、sudo、F1–F12 等），或隐藏用不到的键。';

  @override
  String get virtKeyIntroModifiers => '修饰键';

  @override
  String get virtKeyIntroModifiersTip => '点一下开启，再按键盘上的字母。开启状态只作用于下一个键。';

  @override
  String get virtKeyIntroNav => '光标移动';

  @override
  String get virtKeyIntroNavTip => '这些键移动光标。长按方向键可连续触发。';

  @override
  String get virtKeyIntroSelect => '终端有内容可滚动时，横向拖动即可选中文字。';

  @override
  String get virtKeyRows => '同时显示的行数';

  @override
  String get virtKeyRowsTip => '超出单页的可横向滑动切换';

  @override
  String get waitConnection => '请等待连接建立';

  @override
  String get wakeLock => '保持唤醒';

  @override
  String get watchNotPaired => '没有已配对的 Apple Watch';

  @override
  String get webdavSettingEmpty => 'WebDav 设置项为空';

  @override
  String get whenOpenApp => '当打开 App 时';

  @override
  String get wolTip => '配置 WOL 后，每次连接服务器时将自动发送唤醒请求';

  @override
  String get write => '写';

  @override
  String get writeScriptFailTip => '写入脚本失败，可能是没有权限/目录不存在等';

  @override
  String get writeScriptTip =>
      '在连接服务器后，会向 `~/.config/server_box` \n | `/tmp/server_box` 写入脚本来监测系统状态，你可以审查脚本内容。';

  @override
  String get menuGitHubRepository => 'GitHub 仓库';

  @override
  String get podmanDockerEmulationDetected =>
      '检测到 Podman Docker 仿真。请在设置中切换到 Podman。';

  @override
  String get betaTip => '此功能仍在测试阶段，不保证功能可用性。';

  @override
  String get portForward_startPrompt => '添加端口映射规则以开始使用';

  @override
  String get portForward_localHost => '本地主机';

  @override
  String get portForward_localPort => '本地端口';

  @override
  String get portForward_remoteHost => '远端主机';

  @override
  String get portForward_remotePort => '远端端口';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return '删除 $name？';
  }

  @override
  String get sponsor => '赞助';

  @override
  String get sortByJoinTime => '按加入时间';

  @override
  String get tmuxAutoAttach => 'tmux 自动附加';

  @override
  String get tmuxAuto => '自动使用 tmux';

  @override
  String get tmuxAutoTip => '通过 SSH 连接时自动启动或附加 tmux';

  @override
  String get tmuxSessionSelector => '会话选择器';

  @override
  String get tmuxSessionSelectorTip => '连接时显示会话选择器';

  @override
  String get tmuxDefaultSessionName => '默认会话名称';

  @override
  String get tmuxSessionName => '会话名称';

  @override
  String get tmuxNewSession => '新建会话';

  @override
  String get tmuxNewWindow => '新建窗口';

  @override
  String get tmuxNoWindowsFound => '未找到窗口';

  @override
  String tmuxWindowCount(int count) {
    return '$count 个窗口';
  }

  @override
  String get tmuxAttached => '已附加';

  @override
  String get tmuxSkip => '跳过';

  @override
  String get tmuxNotAvailable => 'tmux 不可用';

  @override
  String containerSegmentsMismatch(int count) {
    return '容器响应分段数量异常：$count';
  }

  @override
  String get containerOperationInProgress => '另一个容器操作正在进行中';

  @override
  String processCount(int count) {
    return '$count 个进程';
  }

  @override
  String get processParseUnsupportedOutput => '不支持此进程列表格式。';

  @override
  String get processParseInvalidRows => '部分进程条目无法读取。';

  @override
  String get processParseInvalidWindowsJson => '无法读取 Windows 进程响应。';

  @override
  String get processParseInvalidWindowsRows => '部分 Windows 进程条目无法读取。';

  @override
  String get processKillTargetChanged => '该进程已变化或退出，请刷新后重试。';

  @override
  String get processSearchHint => '名称、用户或 PID';

  @override
  String processShowKernelThreads(int count) {
    return '显示 $count 个内核线程';
  }

  @override
  String get processForceKill => '强制结束';

  @override
  String get processStarted => '启动';

  @override
  String get processThreads => '线程';

  @override
  String get watchServers => '手表上的服务器';

  @override
  String get watchServersTip => '手表独立向 monitor 取数据，所以只能选择已配置 monitor 的服务器。';

  @override
  String get watchNoMonitorServer => '没有服务器配置了 monitor';

  @override
  String get legacyStatusGoneTitle => '状态链接已失效';

  @override
  String get legacyStatusGoneBody =>
      '手表 App 和桌面小组件此前读取的是手动填写的 `/status` 地址。该接口已移除：它只能以文本形式返回当前值，这也是它们始终无法显示曲线的原因。\n\n现在它们读取 Monitor 的认证接口，可以绘制曲线，并自动与 App 保持同步。在 App 内配置一次服务器，所有手表和小组件都会自动获取。';

  @override
  String get services => '服务';

  @override
  String get status => '状态';

  @override
  String get enable => '启用';

  @override
  String get disable => '禁用';

  @override
  String get starting => '启动中';

  @override
  String get stopping => '停止中';

  @override
  String get serviceManagerUnsupported => '不支持的服务管理器';

  @override
  String get serviceManagerUnsupportedTip =>
      '此服务器使用的服务管理器暂未受 ServerBox 支持。目前支持 systemd、procd 和 OpenRC。';

  @override
  String serviceManagerFmt(String manager) {
    return '由 $manager 管理';
  }

  @override
  String get serviceListFailed => '无法列出服务';

  @override
  String get serviceDetailsUnavailable => '部分服务详情不可用';

  @override
  String get serviceDetailsUnavailableTip => '服务列表仍可使用，但服务管理器未返回完整的状态或开机启动信息。';

  @override
  String get systemdUserScopeMissing => '未列出用户 unit';

  @override
  String get systemdUserScopeMissingTip => '该账户在服务器上没有用户会话总线，因此只显示系统 unit。';

  @override
  String get serviceSearchHint => '单元名';

  @override
  String get serviceNeedsAttention => '需要处理';

  @override
  String serviceOtherUnits(int count) {
    return '其余 $count 个单元';
  }

  @override
  String get serviceUnit => '单元';

  @override
  String get serviceUnitType => '类型';

  @override
  String get serviceScope => '作用域';

  @override
  String get serviceStartup => '开机自启';

  @override
  String serviceUpFor(String duration) {
    return '运行 $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return '停止 $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return '下次 $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return '$duration前停止';
  }

  @override
  String serviceExitStatus(int code) {
    return '退出状态 $code';
  }

  @override
  String get serviceFullJournal => '完整日志';

  @override
  String get serviceUnitFile => '单元文件';

  @override
  String serviceJournalRecent(int count) {
    return '最近 $count 行';
  }

  @override
  String get serviceJournalUnreadable => '当前账户无法读取 journal';

  @override
  String get serverUnreachable => '无法在此服务器上执行命令';

  @override
  String get containerNoRuntime => '此处没有容器运行时';

  @override
  String get containerNoRuntimeTip =>
      '这台机器上 `docker` 和 `podman` 都没有响应。如果它装在另一个账户下，请在设置中开启「尝试使用 sudo」。';

  @override
  String get containerUnreadable => '容器运行时返回了无法解析的内容';

  @override
  String get power => '电源';

  @override
  String get fan => '风扇';

  @override
  String get clockSpeed => '频率';

  @override
  String get vendor => '厂商';

  @override
  String get continueInTerminal => '在终端中继续';

  @override
  String get askAiRiskUnknown => '未判定';

  @override
  String get agentLocalExec => '在本机执行命令';

  @override
  String get agentLocalExecTip => '允许 Agent 在运行 ServerBox 的这台机器上工作。只读的命令也需要审核';

  @override
  String get agentLocalExecRootfsTip =>
      '让 Agent 在本机运行，但只能操作 ServerBox 安装的 Linux 容器。';

  @override
  String macDmgImportedPartly(String path) {
    return '已导入此前安装版本的数据。下载的文件仍保留在 $path。';
  }

  @override
  String get bmcAccount => '账户';

  @override
  String get bmcAccountUnset => '未选择 — 点击选择或新建';

  @override
  String bmcAccountShared(int count) {
    return '$count 台服务器在用';
  }

  @override
  String get bmcAccounts => 'BMC 账户';

  @override
  String get bmcAccountSharedTip => '在这里修改会改变所有这些服务器使用的账户。';

  @override
  String bmcAccountInUse(int count) {
    return '$count 台服务器在用。它们会保留地址，但失去账户。';
  }

  @override
  String get bmcStaleWrite => 'BMC 上的内容在写入期间被改动过，请重试。';

  @override
  String get privacyBlur => '后台隐私保护';

  @override
  String get privacyBlurTip => '在多任务界面隐藏应用内容';

  @override
  String get floatReturnToTab => '放回标签页';

  @override
  String get termInFloatWindow => '此终端正在悬浮窗中';

  @override
  String get globeEnabledTip =>
      '根据服务器地址的地理位置，在地球仪上显示服务器。关闭后，服务器页面会隐藏该按钮，并停止所有地理位置查询。';

  @override
  String get geoShardsConsentAttribution =>
      'IP 地理位置数据由 [DB-IP](https://db-ip.com) 提供，采用 CC BY 4.0 许可。';

  @override
  String get geoMissPrivate => '非公网地址';

  @override
  String get geoMissNoData => '无可用位置数据';

  @override
  String get globeGuide => '点击这里，在地球仪上查看服务器及其地址对应的位置。';

  @override
  String get publicIp => '公网 IP';

  @override
  String get geoData => '城市级数据';

  @override
  String get geoDataTip => '下载后，所有地理位置查询都使用保存在本机的数据，不会向下载服务发送服务器地址或查询活动。';

  @override
  String get geoDataMissing => '未下载';

  @override
  String get geoDataUnreachable => '无法获取数据。';

  @override
  String get geoDataRemoveFailed => '无法删除数据。';

  @override
  String geoDataCurrent(String month) {
    return '已经是 $month 的数据。';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**下载大小：$download · 本机占用：$disk。** 完整数据集保存在本机，后续所有地理位置查询均在本地完成，不会向下载服务发送服务器地址或查询活动。\n\n数据每月更新。新版本会替换已安装的数据，不保留额外副本；你可以随时删除。';
  }

  @override
  String get benchmark => '性能测试';

  @override
  String get benchmarkIntro =>
      '在此服务器上运行 Yet Another Bench Script：磁盘、网络与 CPU。完整跑一次需要 10–20 分钟，离开本页或关闭 App 都不会中断。';

  @override
  String get benchmarkNoRuns => '还没有测试记录。';

  @override
  String get benchmarkRunning => '正在测试';

  @override
  String get benchmarkStartFailed => '无法启动测试';

  @override
  String get benchmarkCancelConfirm => '停止此次测试？已测得的部分会丢失。';

  @override
  String get benchmarkDeleteConfirm => '删除此条测试结果？';

  @override
  String get benchmarkNothingSelected => '所有项目均已关闭，本次只会采集系统信息，几秒即可完成。';

  @override
  String get benchmarkDiskTip =>
      'fio 四种 block size，约 3 分钟。会在工作目录写入 2 GB 测试文件，需要相应的空闲空间。';

  @override
  String get benchmarkNetworkTip => 'iperf3 对测公共服务器，约 4 分钟。';

  @override
  String get benchmarkReducedNetwork => '减少测试节点';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return '3 个节点而非 7 个，流量从约 $full 降到约 $reduced。';
  }

  @override
  String get benchmarkCpuTip =>
      '下载 Geekbench（专有软件）运行，并**将结果公开发布到 geekbench.com 的公共页面**，包含 CPU 型号、核心数与内存。';

  @override
  String get benchmarkSensitiveOptions =>
      '以下选项会在此服务器下载并运行第三方软件，或向第三方发送服务器信息，默认关闭。';

  @override
  String get benchmarkIpInfoTip => '通过明文 HTTP 将此服务器的公网地址发送至 ip-api.com。';

  @override
  String get benchmarkIpInfo => '查询 IP 归属';

  @override
  String get benchmarkPreferBin => '下载 fio 与 iperf3';

  @override
  String get benchmarkPreferBinTip =>
      '从 GitHub 下载，而不使用主机自带的软件包。仅在主机两者都没有安装时开启。';

  @override
  String get benchmarkWorkDir => '工作目录';

  @override
  String get benchmarkWorkDirTip => '决定磁盘测试测的是哪个文件系统。留空表示登录账户的家目录。';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return '约 $minutes 分钟';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return '约 $size 流量';
  }

  @override
  String get benchmarkPhaseSystem => '读取系统信息';

  @override
  String get benchmarkPhaseDisk => '测试磁盘';

  @override
  String get benchmarkPhaseNetwork => '测试网络';

  @override
  String get benchmarkPhaseCpu => '测试 CPU';

  @override
  String get benchmarkPhaseDone => '收尾';

  @override
  String get benchmarkResultUnreadable => '此结果无法按 JSON 解析，原始文本见下方。';

  @override
  String get benchmarkViewOnGeekbench => '在 Geekbench 查看';

  @override
  String get benchmarkGeekbenchPublic => '此结果已公开发布在上述链接。';

  @override
  String get benchmarkSingleCore => '单核';

  @override
  String get benchmarkMultiCore => '多核';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => '上行';

  @override
  String get benchmarkRecv => '下行';

  @override
  String get benchmarkLatency => '延迟';

  @override
  String get benchmarkVirt => '虚拟化';

  @override
  String get benchmarkRawLog => '运行日志';

  @override
  String benchmarkUpstream(String version) {
    return '由 Yet Another Bench Script ($version) 提供';
  }

  @override
  String get benchmarkPhaseStarting => '正在启动';

  @override
  String get benchmarkNoOutputYet =>
      '暂时没有输出。YABS 在输出第一行前会先检查能否访问 google.com 和 icanhazip.com；如果网络屏蔽其中任一站点，可能需要等待数分钟。';

  @override
  String get tagsEmptyTip => '还没有标签。编辑服务器时添加标签，它就会显示在这里。';

  @override
  String get benchmarkNoServers => '请先添加服务器，再回来进行性能测试。';

  @override
  String get schemaTooNewTitle => '这些数据比当前应用新';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return '这些数据由更新版本的 ServerBox 写入（存储版本 v$stored）。当前版本最高支持 v$supported，数据未被改动。';
  }

  @override
  String get schemaTooNewReinstall => '请重新安装更新的版本，即可再次打开全部数据。';

  @override
  String get schemaTooNewExportPlain => '导出无密码副本';

  @override
  String get schemaTooNewPlainWarn =>
      '文件将以明文包含所有 SSH 私钥、服务器密码和 API key。任何拿到文件的人都能访问这些内容。';

  @override
  String get schemaTooNewWipe => '删除所有数据';

  @override
  String get schemaTooNewWipeConfirm =>
      '本设备上的所有服务器、密钥、代码片段和设置都将被删除，且无法撤销。此前导出的备份将成为仅存的副本。';

  @override
  String get schemaTooNewWipeDone => '数据已删除。请重新打开应用，从头开始。';

  @override
  String get schemaTooNewWipeFailed =>
      '部分数据未能删除，当前版本仍然无法打开剩下的内容。请重新安装更新的版本来读取它。';

  @override
  String get systemUsers => '用户';

  @override
  String get userManagerLinuxOnly => '系统用户管理目前仅支持 Linux 服务器。';

  @override
  String get userRegularAccount => '普通用户';

  @override
  String get userCurrentAccount => '当前账户';

  @override
  String get userSystemAccount => '系统账户';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => '状态';

  @override
  String get userLoginEnabled => '可登录';

  @override
  String get userDetailAccount => '账户';

  @override
  String get userDetailSecurity => '安全';

  @override
  String get userSshKeys => 'SSH 密钥';

  @override
  String get userExpires => '过期';

  @override
  String get userNever => '永不';

  @override
  String get userPasswordSet => '已设置';

  @override
  String get userPasswordLocked => '已锁定';

  @override
  String get userPasswordNone => '无';

  @override
  String get userSuperuser => '超级用户';

  @override
  String get userOpenShell => '打开 Shell';

  @override
  String get userRootChangesWarning => 'root 的改动会立即作用于所有会话。';

  @override
  String get userComment => '备注';

  @override
  String get userPrimaryGroup => '主用户组';

  @override
  String get userSupplementaryGroups => '附加用户组';

  @override
  String get userLoginShell => '登录 Shell';

  @override
  String get userCreateHome => '创建主目录';

  @override
  String get userMoveHome => '路径变化时移动现有主目录';

  @override
  String get userRemoveHome => '删除主目录';

  @override
  String get userPasswordCreateTip => '密码留空将创建一个无法使用密码登录的账户。';

  @override
  String get userPasswordEditTip => '密码留空将保留现有密码。';

  @override
  String funcUnavailableFmt(String func) {
    return '此服务器的连接方式不提供$func。';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return '$func需要在 Monitor agent 中开启 $setting。';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return '$func需要更新 Monitor agent。';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      '通过 Monitor agent 进行远程转发需要更新版本的 agent，请在服务器上更新。';

  @override
  String get rangeLive => '实时';

  @override
  String get diskIo => '磁盘读写';

  @override
  String get peak => '峰值';

  @override
  String get hardware => '硬件';

  @override
  String get cores => '核心';

  @override
  String get historyNoStored => '只有 monitor agent 会存储历史。此连接只保留本应用连接后看到的部分。';

  @override
  String get noHistoryYet => '还没有采样';

  @override
  String get noData => '无数据';

  @override
  String get from => '起';

  @override
  String get to => '止';

  @override
  String get beyondRetention => '超出这个 agent 保留的范围';

  @override
  String agentRetentionFmt(String kept) {
    return 'agent 保留 $kept';
  }

  @override
  String get agentServerTools => '服务器工具';

  @override
  String get agentServerToolsTip =>
      '在服务器上执行命令、读写文件，通过 SSH 连接其他主机，并使用 ServerBox 自身的操作。';

  @override
  String get agentTerminalTools => '终端';

  @override
  String get agentTerminalToolsTip => '在终端自己的对话中：读取终端显示的内容，并在其服务器上执行命令。';

  @override
  String get agentToolTerminalScreen => '读取屏幕';

  @override
  String get agentProviders => '提供商';

  @override
  String get agentProvidersTip => 'API Key、模型，以及新对话使用的模型';

  @override
  String get agentTools => '工具';

  @override
  String get agentToolsTip => 'Agent 可以使用的工具，以及 MCP 服务器';

  @override
  String get agentSnippetToolsTip => '列出、新增、修改和删除 snippet；修改前会询问。';

  @override
  String get agentVirtToolsTip => '读取虚拟化标签页已加载的虚拟机和容器。';

  @override
  String get agentBenchmarkToolsTip => '读取性能测试结果；经你批准后运行或停止测试。';

  @override
  String get agentRemoteDesktopToolsTip => '列出远程桌面配置；经你批准后连接或断开。';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip => '特定任务的操作说明，可从 GitHub 或链接安装';

  @override
  String get agentPermissions => '权限';

  @override
  String get agentEmptyHint => '询问你的服务器，或让 Agent 在服务器上完成某项操作。';

  @override
  String get agentTerminalEmptyHint => '询问这台服务器。Agent 可以读取当前终端，并在这里执行命令。';

  @override
  String oldestSampleFmt(String time) {
    return '最早的采样在 $time';
  }

  @override
  String get rangeEndsBeforeItStarts => '区间的结束必须晚于开始。';

  @override
  String get samples => '采样';

  @override
  String get unavailable => '不可用';

  @override
  String get metricUnavailableTip => '页面其余部分不受影响。到主机上检查这项读数所用的命令。';

  @override
  String get waitingFirstSample => '等待第一次采样';

  @override
  String atTimeFmt(String time) {
    return '$time 时';
  }

  @override
  String get stored => '已存储';

  @override
  String lastSampleFmt(String ago) {
    return '最近采样于$ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return '以下全部是 $time 的数据，$ago。';
  }

  @override
  String noDataBeforeFmt(String time) {
    return '$time 之前没有数据';
  }

  @override
  String loadingRangeFmt(String range) {
    return '正在加载 $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return '没有 $metric 的存储历史';
  }

  @override
  String devicesFmt(int count) {
    return '$count 个设备';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count 个设备 · 最忙 $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$total 个设备中的 $plotted 个';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count 个传感器 · 最热 $name';
  }

  @override
  String get oneDeviceAtLeast => '图表至少保留一个设备。';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$total 个$what中的 $shown 个';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count 个$what';
  }

  @override
  String get unitDevices => '设备';

  @override
  String get unitSensors => '传感器';

  @override
  String get unitBatteries => '电池';

  @override
  String get unitCommands => '命令';

  @override
  String get unitReadings => '读数';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => '最热';

  @override
  String get oldest => '最久';

  @override
  String get notApplicable => '不适用';

  @override
  String get attributes => '属性';

  @override
  String get powerOnHours => '通电时间';

  @override
  String get powerCycles => '通电次数';

  @override
  String get lifeLeft => '剩余寿命';

  @override
  String get lifetimeWrite => '累计写入';

  @override
  String get lifetimeRead => '累计读取';

  @override
  String get averageErase => '平均擦除次数';

  @override
  String get unsafeShutdowns => '异常断电次数';

  @override
  String get diskAllPassed => '全部 PASSED';

  @override
  String diskWarningFmt(int count) {
    return '$count 个警告';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$total 个设备中的 $wrong 个';
  }

  @override
  String get diskSmartSortedTip => '最差的排在最前';

  @override
  String readAgoFmt(String ago) {
    return '$ago读取';
  }

  @override
  String processesFmt(int count) {
    return '$count 个进程';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count 个异常';
  }

  @override
  String get diskSmartOpenTip => '点按查看该盘的属性';

  @override
  String get cycle => '循环次数';

  @override
  String get window => '窗口';

  @override
  String ofFmt(String total) {
    return '共 $total';
  }

  @override
  String get serverDetailCards => '详情页卡片';

  @override
  String get connection => '连接方式';

  @override
  String get connectionTip => '两个可以同时开启。顺序就是拨号的顺序。';

  @override
  String get transportNoneOn => '两个都关闭了 —— 这台服务器无法连接。';

  @override
  String get thisDevice => '本机';

  @override
  String get localServerTip =>
      '直接在本机运行状态脚本读取本机信息，不使用 SSH 和 Monitor HTTP，二者的设置会保留。';

  @override
  String get localServerUnsupported =>
      '当前平台无法将本机作为服务器读取。Linux、Windows 和 macOS DMG 版本支持。';

  @override
  String get remoteDesktopIntro =>
      '在应用内打开服务器的 RDP 或 VNC 桌面。连接经由服务器的 SSH 连接或其 Monitor agent 转发，桌面端口无需对网络开放。';

  @override
  String get remoteDesktopIntroProfiles =>
      '在服务器的「远程桌面」按钮或「远程桌面」标签页中，为每个桌面保存一个配置。';

  @override
  String get localServerIntro =>
      '将运行 ServerBox 的设备添加为服务器。状态、进程、服务、容器、终端和文件都无需 SSH 或 Monitor agent。';

  @override
  String get localServerAdd => '添加本机';

  @override
  String get localServerIntroFooter => '之后也可以在服务器编辑页的「连接方式」中开启。';

  @override
  String get transportSectionOff => '已关闭。下面的字段会保留，供你再次开启时使用。';

  @override
  String get monitorAgent => 'Monitor 代理';

  @override
  String get plainHttpEditTip =>
      '凭据和指标会以明文穿过网络。请限制在局域网或 Tailscale 地址内，或者把代理放到 TLS 后面。';

  @override
  String get behaviour => '行为';

  @override
  String get optional => '可选';

  @override
  String get sshAdvanced => 'SSH 高级';

  @override
  String get sshAdvancedTip => '备用地址、ProxyCommand、跳板机、文件传输、远端路径';

  @override
  String get sshLegacyAlgorithms => '兼容旧版算法';

  @override
  String get sshLegacyAlgorithmsTip =>
      '用于只提供 SHA-1 `ssh-rsa` 主机密钥或 SHA-1 密钥交换的旧 SSH 服务端（路由器、交换机）。安全性较低，仅在设备确实需要时开启。';

  @override
  String get appearanceAndPlace => '外观与位置';

  @override
  String get appearanceAndPlaceTip => 'Logo、坐标';

  @override
  String get statusCollection => '状态采集';

  @override
  String get statusCollectionTip => '运行哪些命令、自定义命令、读取哪个设备';

  @override
  String get tagAllTags => '全部标签';

  @override
  String get tagMatching => '匹配';

  @override
  String get tagNewHint => '新标签';

  @override
  String tagCreateFmt(String tag) {
    return '新建 #$tag';
  }

  @override
  String get tagOnThisServer => '在这台上';

  @override
  String tagServersFmt(int count) {
    return '$count 台服务器';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '这台上有 $count 个';
  }

  @override
  String get tagMatchesTyped => '与输入匹配';

  @override
  String get tagEditorTip =>
      '输入会过滤列表；按钮新建标签并直接加到这台服务器上。铅笔是重命名，会改掉所有用到它的服务器。没有服务器再用的标签会在保存时消失。';

  @override
  String get tagRenamesOnSave => '重命名在保存时生效';

  @override
  String get scheduledTasks => '计划任务';

  @override
  String get scheduledTaskLinuxOnly => '计划任务管理目前仅支持 Linux 服务器。';

  @override
  String get scheduledTaskUnavailable => '此服务器上没有可用的 crontab。';

  @override
  String get scheduledTaskPreserveTip => '保存时会保留此 crontab 中的注释、环境变量和无法识别的行。';

  @override
  String get scheduledTaskSchedule => '执行周期';

  @override
  String get scheduledTaskAdd => '添加任务';

  @override
  String get scheduledTaskNextRun => '下次运行';

  @override
  String scheduledTaskNextInFmt(String time) {
    return '$time后';
  }

  @override
  String get scheduledTaskEnabled => '已启用';

  @override
  String get scheduledTaskCommentedOut => '已注释';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    return '$total 个任务 · $enabled 个已启用';
  }

  @override
  String get scheduledTaskFilterHint => '筛选任务';

  @override
  String get scheduledTaskPreserved => '保留的行';

  @override
  String get scheduledTaskRaw => '原始 crontab';

  @override
  String get scheduledTaskEnableNow => '立即启用';

  @override
  String get scheduledTaskEnableNowTip => '关闭时该行以注释写入。';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return '$user 没有计划任务。在此添加的内容会写入该账户的 crontab。';
  }

  @override
  String get scheduledTaskFieldMinute => '分钟';

  @override
  String get scheduledTaskFieldHour => '小时';

  @override
  String get scheduledTaskFieldDayOfMonth => '日';

  @override
  String get scheduledTaskFieldMonth => '月';

  @override
  String get scheduledTaskFieldDayOfWeek => '星期';

  @override
  String get cronErrScheduleEmpty => '需要填写执行周期。';

  @override
  String get cronErrCommandEmpty => '需要填写命令。';

  @override
  String get cronErrLineBreak => 'crontab 中的一行不能包含换行。';

  @override
  String get cronErrMacro => '宏是一个单词，例如 @reboot。';

  @override
  String get cronErrFieldCount => 'cron 执行周期需要 5 个字段，或 @reboot 这样的宏。';

  @override
  String get cronAtBoot => '开机时';

  @override
  String get cronEveryMin => '每分钟';

  @override
  String cronEveryMinsFmt(int minutes) {
    return '每 $minutes 分钟';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return '每小时的 :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return '每 $hours 小时';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return '每 $hours 小时的 :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return '每天 $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return '工作日 $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return '每$day $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return '每月 $day 日 $time';
  }

  @override
  String get monitorSettings => 'Monitor 设置';

  @override
  String get monitorAgentDefault => 'agent 默认值';

  @override
  String get monitorNeedsRestart => 'agent 重启后生效';

  @override
  String get monitorCollection => '采集';

  @override
  String get extendedInterval => '扩展采集周期';

  @override
  String get idlePause => '无人查看时暂停';

  @override
  String get idlePauseTip =>
      '扩展采集会调用 smartctl、sensors 和 amd-smi。没有客户端轮询时暂停，可以避免为无人查看的数据唤醒硬盘。';

  @override
  String get idlePauseThreshold => '闲置判定时长';

  @override
  String get monitorAlerts => '告警';

  @override
  String get monitoringRules => '告警规则';

  @override
  String get ruleMonitorType => '指标';

  @override
  String get ruleThreshold => '阈值';

  @override
  String get ruleMatcher => '匹配对象';

  @override
  String get ruleTip =>
      '指标：cpu / memory / swap / disk / network / temperature。匹配对象：cpu0 指定单核，memory 用 used / free / avail，network 用 rx / tx；disk 和 temperature 忽略此项。阈值：比较符加数值，例如 >=80%、>=70c 或 >10m/s。';

  @override
  String get pushChannels => '通知渠道';

  @override
  String get pushType => '类型';

  @override
  String get pushRate => '发送频率限制';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => '已在 agent 上设置，不显示';

  @override
  String get pushSecretKeep => '留空则保持不变';

  @override
  String get pushTestTip => '按当前页面上的配置发送一条通知，无论是否已保存。';

  @override
  String get pushTestSent => '渠道已接受';

  @override
  String get pushTestFailed => '渠道拒绝了这条通知';

  @override
  String get pushTestMessage => '来自 ServerBox Monitor 的测试通知';

  @override
  String get pushUnknownType =>
      '此 agent 没有该类型的发送实现，因此不显示其配置。可以在这里删除，或在 agent 的 config.toml 中编辑。';

  @override
  String get pushJsonInvalid => '不是合法的 JSON';

  @override
  String get dataRetention => '数据保留';

  @override
  String get dataRetentionTip => '关闭表示 agent 不会删除任何数据，其数据库会无限增长。';

  @override
  String get retentionMetrics => '指标保留';

  @override
  String get retentionAlerts => '告警保留';

  @override
  String get retentionCleanup => '清理执行间隔';

  @override
  String get retentionMaxDbSize => '数据库体积上限';

  @override
  String get corsOrigins => 'CORS 允许来源';

  @override
  String get corsOriginsTip => '允许浏览器面板从哪些来源调用此 agent。留空表示仅同源。';

  @override
  String get monitorNoRemoteAccess =>
      '此 agent 目前只能查看监控数据，不能打开终端、执行命令或浏览文件。要开启这些功能，请修改 agent 的 config.toml，在 [remote_access] 下打开对应选项。';

  @override
  String get alerts => '告警';

  @override
  String get online => '在线';

  @override
  String get densityCards => '卡片';

  @override
  String get densityRows => '列表';

  @override
  String get densityGrid => '方块';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get searchServerTip => '搜索名称和地址，也就是编辑页最先问的两项。';

  @override
  String get addServerTip => '手动填写、扫描二维码，或导入别人分享的文件。';

  @override
  String get move => '移动';

  @override
  String get moveToTop => '移到最前';

  @override
  String get moveToBottom => '移到最后';

  @override
  String get groupByTag => '按标签分组';

  @override
  String get groupByTagTip => '标签是在服务器自己的编辑页里加的。';

  @override
  String get connecting => '连接中…';

  @override
  String get authShort => '认证';

  @override
  String get remoteDesktopFitToWindow => '适合窗口';

  @override
  String get remoteDesktopActualSize => '实际大小';

  @override
  String get remoteDesktopZoom => '缩放';

  @override
  String get remoteDesktopViewOnly => '仅查看';

  @override
  String get remoteDesktopDisableViewOnly => '关闭仅查看';

  @override
  String get remoteDesktopSendClipboardText => '发送剪贴板文本';

  @override
  String get remoteDesktopShowKeyboard => '显示键盘';

  @override
  String get remoteDesktopMoreControls => '更多控制';

  @override
  String get remoteDesktopUseDirectPointer => '使用直接指针';

  @override
  String get remoteDesktopUseTouchpadPointer => '使用触控板指针';

  @override
  String get remoteDesktopSendCtrlAltDelete => '发送 Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => '重新连接';

  @override
  String get remoteDesktopFullScreen => '全屏';

  @override
  String get remoteDesktopExitFullScreen => '退出全屏';

  @override
  String get remoteDesktopCloseSession => '关闭会话';

  @override
  String get remoteDesktopConnected => '已连接';

  @override
  String get remoteDesktopConnecting => '正在连接';

  @override
  String get remoteDesktopReconnecting => '正在重新连接';

  @override
  String get remoteDesktopDisconnected => '已断开连接';

  @override
  String get remoteDesktopGuideTouch => '触控板';

  @override
  String get remoteDesktopGuideTouchTip =>
      '单指像触控板一样移动指针，轻点即单击。双指轻点为右键，双指拖动为滚动，双指捏合为缩放。轻点两下且第二下不松手，即可拖动。';

  @override
  String get remoteDesktopGuideKeyboardTip => '打开屏幕键盘，输入的内容会发送到远程桌面。';

  @override
  String get remoteDesktopGuideViewOnlyTip => '停止发送指针和按键，只查看画面，不会误点。';

  @override
  String get remoteDesktopGuideMoreTip => 'Ctrl+Alt+Delete、重新连接和全屏都在这里。';

  @override
  String get remoteDesktopGuidePointerTip => '这里也可以切换为直接指针：手指点到哪里就点击哪里。';

  @override
  String get remoteDesktopVncClipboardLatin1Only => 'VNC 剪贴板仅支持 Latin-1 文本。';

  @override
  String get remoteDesktopAddProfile => '添加配置';

  @override
  String get remoteDesktopNoProfiles => '暂无远程桌面配置';

  @override
  String get remoteDesktopAdd => '添加远程桌面';

  @override
  String get remoteDesktopEdit => '编辑远程桌面';

  @override
  String get remoteDesktopTargetTip =>
      '目标地址由 SSH 服务器或 Monitor Agent 解析，localhost 指向该服务器。';

  @override
  String get remoteDesktopDomain => '域（可选）';

  @override
  String get remoteDesktopPassword => '密码（可选）';

  @override
  String get remoteDesktopSavePassword => '保存密码';

  @override
  String get remoteDesktopSavePasswordTip =>
      '保存在加密数据库中。备份会包含已保存的密码，只有设置备份密码时才会加密。';

  @override
  String get remoteDesktopShareSession => '共享会话';

  @override
  String get remoteDesktopProtocol => '协议';

  @override
  String get remoteDesktopUniqueName => '此服务器的配置名称不能重复。';

  @override
  String get remoteDesktopVncPasswordLength => '传统 VNC 密码最多为 8 个 ASCII 字节。';

  @override
  String get remoteDesktopNameRequired => '请输入配置名称。';

  @override
  String get remoteDesktopHostRequired => '请输入目标主机。';

  @override
  String get remoteDesktopPortRequired => '请输入有效的端口。';

  @override
  String get remoteDesktopUsernameRequired => '请输入 RDP 用户名。';

  @override
  String get remoteDesktopVncPasswordAscii => '传统 VNC 密码只能包含 ASCII 字符。';

  @override
  String get remoteDesktopCertificateRequired => '需要确认证书';

  @override
  String get remoteDesktopWaiting => '正在等待桌面…';

  @override
  String get remoteDesktopCertificateChanged => '远程桌面证书已更改';

  @override
  String get remoteDesktopTrustCertificate => '是否信任此证书？';

  @override
  String get remoteDesktopCertificateChangedTip =>
      '证书指纹与保存的值不一致。替换信任前，请核实新的指纹。';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      '系统无法验证此证书。继续前，请核实其 SHA-256 指纹。';

  @override
  String get remoteDesktopReplaceTrust => '替换信任';

  @override
  String get remoteDesktopTrustReconnect => '信任并重新连接';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return '是否删除远程桌面配置“$name”？';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return '正在重新连接（$attempt/3）…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return '此前信任的指纹\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return '主题：$subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return '颁发者：$issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return '有效期：$start – $end';
  }

  @override
  String get pveAuthToken => 'API token';

  @override
  String get pveVersionLow => '当前该功能处于测试阶段，仅在 PVE 8+ 上测试过，请谨慎使用';

  @override
  String get pveTokenId => 'Token ID';

  @override
  String get pveTokenSecret => 'Token secret';

  @override
  String get pveTokenTip =>
      '在 PVE 的 数据中心 → 权限 → API Tokens 中创建。需要在要显示的路径上具有 VM.Audit、VM.PowerMgmt、VM.Console、VM.Snapshot、VM.Snapshot.Rollback、Datastore.Audit 和 Sys.Audit 权限；如果启用了权限分离，需要把这些权限授予 token 本身。';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'token $account 在这台主机上没有任何可见的资源。开启了权限分离的 token 不继承其用户的权限，需要单独授权。在 PVE 主机上执行：\n$command\n或者取消该 token 的“权限分离”。';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account 在这台主机上没有任何可见的资源。在 PVE 主机上为它授权：\n$command';
  }

  @override
  String get pveTokenIdInvalid => 'Token ID 的格式应为 user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      '以 SSH 用户身份在 PAM realm 登录，使用 SSH 密码；SSH 使用 key 时使用下方的 PVE 密码。需要时会要求输入两步验证码。';

  @override
  String get pveCertUnpinned => '尚未确认。除非证书由受信任的 CA 签发，下次连接时会显示证书以供确认。';

  @override
  String get pveCertForget => '忘记证书';

  @override
  String get pveCertForgetTip => '下次连接时会再次显示 PVE 证书以供确认。';

  @override
  String get virtualization => '虚拟化';

  @override
  String get virtIntro =>
      '管理 Proxmox VE 和 libvirt/KVM 主机上的虚拟机和容器：查看状态、执行电源操作、打开控制台。';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE 已从服务器页面移到此标签页。服务器的 PVE 卡片会在这里打开它。';

  @override
  String get virtIntroLibvirt =>
      '安装了 libvirt 的 virsh 的服务器会显示为主机，并列出其 QEMU/KVM 虚拟机。';

  @override
  String get virtIntroTransports => '两者都可以通过 SSH、Monitor agent 或在本设备上使用。';

  @override
  String get virtIntroTokens =>
      'PVE 可以使用 API token 登录，无需密码。在服务器编辑页面的 PVE 部分设置。';

  @override
  String get virtIntroInBar => '已添加到标签栏。';

  @override
  String get virtIntroInMore => '位于“更多”中。可在设置的“主页标签”中将其移到标签栏。';

  @override
  String get virtGuests => '虚拟机';

  @override
  String get virtHosts => '宿主机';

  @override
  String get virtCheckServer => '检查此服务器';

  @override
  String get virtCheckAll => '检查所有服务器';

  @override
  String get virtProbeNotChecked => '尚未检查';

  @override
  String get virtProbeAbsent => '不是宿主机';

  @override
  String virtProbeContainer(String kind) {
    return '$kind 容器';
  }

  @override
  String get virtProbeContainerTip => '这台服务器运行在容器里，本身不是宿主机。请在运行它的宿主机上管理。';

  @override
  String get virtProbePve => 'PVE，未配置';

  @override
  String virtPveSetupTip(String version) {
    return '这台服务器运行着 $version。在服务器设置里填写 API 访问信息（推荐使用 API token）后，即可在这里管理其中的虚拟机和容器。';
  }

  @override
  String get virtNoHosts => '没有虚拟化宿主机';

  @override
  String get virtNoHostsTip =>
      '运行 Proxmox VE 且填写了 API 访问信息的服务器是宿主机，能运行 virsh 的服务器也是。其他服务器可以在宿主机切换器中检查。';

  @override
  String get virtNoGuests => '没有虚拟机或容器';

  @override
  String get virtPaused => '已暂停';

  @override
  String get virtStarting => '正在启动…';

  @override
  String get virtStopping => '正在关机…';

  @override
  String get virtRebooting => '正在重启…';

  @override
  String get virtMigrating => '正在迁移…';

  @override
  String get virtBackingUp => '正在备份…';

  @override
  String get virtResume => '恢复';

  @override
  String get virtOverview => '概览';

  @override
  String get virtConsole => '控制台';

  @override
  String get virtConsoleNone => '此虚拟机没有可用的控制台';

  @override
  String get virtConsoleGraphical => '图形';

  @override
  String get virtVncPasswordNeeded => '这个显示需要密码';

  @override
  String get virtConsoleSerialTip =>
      '在宿主机上用 virsh 打开虚拟机的串口控制台。断开连接或按 Ctrl+] 可返回宿主机的 shell。';

  @override
  String virtConsoleVia(String transport) {
    return '经 $transport';
  }

  @override
  String get virtConsoleEnterTip => '没有输出？按 Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return '$seconds 秒后自动按 Enter 唤出提示符';
  }

  @override
  String get virtConsoleEnterNow => '立即';

  @override
  String get virtOffTip => '启动后在这里显示实时 CPU、内存、磁盘和网络。';

  @override
  String get virtAllocated => '已分配';

  @override
  String virtRunningCount(int running, int total) {
    return '$running 运行 · 共 $total 台';
  }

  @override
  String get virtTemplate => '模板';

  @override
  String get virtAutostart => '随宿主机启动';

  @override
  String get virtErrUnreachable => '无法连接到此宿主机';

  @override
  String get virtErrNotConfigured => '此服务器的 PVE 设置不完整';

  @override
  String get virtErrNotConfiguredTip => '请在服务器设置中检查地址，以及密码或 API token。';

  @override
  String get virtErrAuthFailed => '宿主机拒绝了登录';

  @override
  String get virtErrCertUnconfirmed => '请确认宿主机的证书';

  @override
  String get virtErrCertChanged => '宿主机的证书已更改';

  @override
  String get virtErrRelayNotGranted => 'Monitor agent 不转发连接';

  @override
  String get virtErrExecNotGranted => 'Monitor agent 不执行命令';

  @override
  String get virtErrNotInstalled => '此服务器上未安装 virsh';

  @override
  String get virtErrServerRemoved => '该服务器已被删除';

  @override
  String get virtErrSudoRequired => 'sudo 需要密码才能访问 libvirt';

  @override
  String get virtErrSudoRejected => 'sudo 拒绝了该密码';

  @override
  String get virtErrInvalidResponse => '宿主机返回了无法识别的内容';

  @override
  String get virtErrActionFailed => '宿主机拒绝了该操作';

  @override
  String get remoteSessionIdleTimeout => '离开后自动关闭';

  @override
  String get remoteSessionIdleTimeoutTip =>
      '离开远程桌面或虚拟机控制台后,连接保持多久。关闭前会显示提示,10 秒内可选择保持连接。';

  @override
  String get remoteSessionKeepAlive => '保持连接';

  @override
  String get remoteSessionClosedAway => '已因空闲关闭';

  @override
  String remoteSessionClosingIn(int seconds) {
    return '$seconds 秒后关闭';
  }

  @override
  String get virtSnapshots => '快照';

  @override
  String get virtSnapshotCreate => '创建快照';

  @override
  String get virtSnapshotNone => '还没有快照';

  @override
  String get virtSnapshotWithMemory => '磁盘和内存';

  @override
  String get virtSnapshotDiskOnly => '仅磁盘';

  @override
  String get virtSnapshotParent => '父快照';

  @override
  String get virtSnapshotRevert => '恢复到此快照';

  @override
  String get virtSnapshotMemory => '包含内存状态';

  @override
  String get virtSnapshotMemoryTip => '恢复后回到这一刻的运行状态。';

  @override
  String get virtSnapshotMemoryAlways => '在此宿主机上，运行中的虚拟机快照总是包含内存。';

  @override
  String get virtSnapshotMemoryOff => '虚拟机未运行，只能保存磁盘。';

  @override
  String get virtSnapshotNameInvalid => '以字母开头，之后只能是字母、数字、- 或 _，长度 2 到 40。';

  @override
  String get virtSnapshotNameTaken => '已有同名快照。';

  @override
  String get virtSnapshotRevertTip => '恢复会丢弃快照之后的所有改动。';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return '将 $guest 恢复到 $snapshot？此后的所有改动都会丢失。';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return '此快照不含内存：$guest 将被停止。';
  }

  @override
  String get virtSnapshotStartAfter => '恢复后启动';

  @override
  String get virtVolumes => '卷';

  @override
  String get virtNoPools => '没有存储池';

  @override
  String get virtNoNetworks => '没有网络';

  @override
  String get virtPoolInactive => '存储池未激活，无法列出其中的卷。';

  @override
  String get virtShared => '节点间共享';

  @override
  String get virtBackingFile => '后备文件';

  @override
  String get virtNetIsolated => '隔离';

  @override
  String get virtNetBridged => '桥接';

  @override
  String get virtNetRouted => '路由';

  @override
  String get virtBridge => '网桥';

  @override
  String get virtPorts => '端口';

  @override
  String get virtAttachedGuests => '已连接的虚拟机';

  @override
  String get virtNoAttachedGuests => '没有虚拟机连接到此网络';

  @override
  String get virtCreateVm => '新建虚拟机';

  @override
  String get virtCreateLxc => '新建容器';

  @override
  String get virtCreateGuest => '新建虚拟机或容器';

  @override
  String get virtKindVm => '虚拟机';

  @override
  String get virtKindLxc => '容器';

  @override
  String get virtHostname => '主机名';

  @override
  String get virtInstallMedia => '安装介质';

  @override
  String get virtNoIsos => '这台主机上没有 ISO 镜像';

  @override
  String get virtNoTemplates => '这台主机上没有容器模板。可以在 PVE 中存储的 CT 模板里下载。';

  @override
  String get virtNoDiskStorage => '这台主机上没有可以创建新磁盘的存储';

  @override
  String get virtStartAfterCreate => '创建后启动';

  @override
  String get virtUnprivileged => '非特权容器';

  @override
  String get virtUnprivilegedTip => '容器内的 root 对应宿主机上的普通用户。';

  @override
  String get virtSshKeys => 'SSH 公钥';

  @override
  String get virtCredentialsTip => 'root 密码、SSH 公钥，或两者都设置。';

  @override
  String virtCreated(String name) {
    return '已创建 $name';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '已创建 $name，但未能启动';
  }

  @override
  String get virtErrExists => '同名的虚拟机或磁盘已存在';

  @override
  String get virtCreateNameInvalidLibvirt =>
      '字母、数字、.、_ 和 -，以字母或数字开头，最多 63 个字符。';

  @override
  String get virtCreateNameInvalidPve => '字母、数字和 -，各段之间用点分隔，最多 63 个字符。';

  @override
  String get virtCreateNameTaken => '已有同名虚拟机。';

  @override
  String get virtCreateVmidTaken => '这个 VMID 已被占用。';

  @override
  String get virtCreateCoresInvalid => '超出了这台主机允许的核心数。';

  @override
  String get virtCreateMemoryInvalid => '内存不足。';

  @override
  String get virtCreateStorageMissing => '选择磁盘的存放位置。';

  @override
  String get virtCreateDiskInvalid => '范围为 1 GiB 到 64 TiB。';

  @override
  String get virtCreateTemplateMissing => '选择一个模板。';

  @override
  String get virtCreateCredentialsMissing => '设置 root 密码或 SSH 公钥。';

  @override
  String virtCreatePasswordShort(int min) {
    return '至少 $min 个字符。';
  }

  @override
  String get virtCreateSshKeysInvalid => '每行一个 OpenSSH 公钥。';

  @override
  String get virtDeleteDisks => '同时删除磁盘卷';

  @override
  String get virtDeleteDisksPve => '磁盘会随它一起删除，安装介质会保留。';

  @override
  String virtDeleted(String name) {
    return '已删除 $name';
  }

  @override
  String get pveTokenTipCreate =>
      '创建和删除虚拟机还需要 VM.Allocate、VM.Config.*、Datastore.AllocateSpace 和 SDN.Use。';

  @override
  String get pveTokenTipHardware =>
      '编辑硬件需要 VM.Config.CPU、VM.Config.Memory、VM.Config.Disk、VM.Config.CDROM、VM.Config.Network 和 VM.Config.Options；添加磁盘和网卡还需要 Datastore.AllocateSpace 和 SDN.Use。修改显卡以及 USB、PCI 设备还需要 VM.Config.HWType；通过资源映射直通设备需要该映射的 Mapping.Use，列出映射需要 Mapping.Audit。';

  @override
  String get pveTokenTipBackup =>
      '克隆需要 VM.Clone，备份与还原需要 VM.Backup，转为模板需要 VM.Allocate；备份任务还需要 Sys.Audit 才能读取，以及在 / 上的 Sys.Modify 才能新建、编辑和删除；副本或备份存放的存储上还需要 Datastore.AllocateSpace。';

  @override
  String get virtErrConflict => '已在别处修改';

  @override
  String get virtErrConflictTip => '此配置在读取后被他人修改，因此未做任何更改。已重新读取，如仍需要请再次修改。';

  @override
  String get virtHardware => '硬件';

  @override
  String get virtHwAddDisk => '添加磁盘';

  @override
  String get virtHwAddMount => '添加挂载点';

  @override
  String get virtHwAddNic => '添加网卡';

  @override
  String get virtHwAppliesOnRestart => '已保存，将在下次启动时生效。';

  @override
  String get virtHwAutostart => '随宿主机开机自启';

  @override
  String get virtHwAutostartPve => 'onboot · 按 VMID 顺序启动';

  @override
  String get virtHwBalloonLibvirt => '当前内存';

  @override
  String get virtHwBalloonNote => '允许宿主机在内存紧张时回收虚拟机的空闲内存';

  @override
  String get virtHwBoot => '引导';

  @override
  String get virtHwBootOrder => '启动顺序';

  @override
  String get virtHwBootTip => '用箭头调整顺序；点按设备可切换是否从它启动。';

  @override
  String get virtHwCdrom => '光驱';

  @override
  String get virtHwConfigFile => '配置文件';

  @override
  String get virtHwCores => '核心';

  @override
  String get virtHwCpuTypeDefault => '默认';

  @override
  String get virtHwDeleteVolume => '同时删除卷';

  @override
  String get virtHwDetach => '分离';

  @override
  String get virtHwDiskHotplug => '支持热插拔，运行中也能添加';

  @override
  String get virtHwDisksLxc => '根磁盘与挂载点';

  @override
  String get virtHwEject => '弹出';

  @override
  String get virtHwEmpty => '无介质';

  @override
  String get virtHwFirewall => '防火墙';

  @override
  String virtHwFree(String size) {
    return '可用 $size';
  }

  @override
  String get virtHwGrow => '扩容';

  @override
  String get virtHwGrowNote => '只能在原容量上扩容。';

  @override
  String get virtHwGrowNoteRunning => '只能在原容量上扩容。运行中扩容后需在系统内扩展分区。';

  @override
  String get virtHwGuestUsed => '系统内已用';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return '宿主机 $threads 线程 · 已分配 $allocated';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return '宿主机 $total · 已分配 $allocated';
  }

  @override
  String get virtHwHotplugNow => '支持热插拔，运行中立即生效。';

  @override
  String get virtHwIssueBootEmpty => '至少勾选一个设备';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'vCPU 总数须在 1 到 $max 之间';
  }

  @override
  String get virtHwIssueCpuOnline => '在线 vCPU 须在 1 到总数之间';

  @override
  String get virtHwIssueDiskShrink => '须大于当前大小：磁盘只能扩大';

  @override
  String get virtHwIssueDiskSize => '须在 1 到 65536 GiB 之间';

  @override
  String virtHwIssueMemory(int min, int max) {
    return '须在 $min 到 $max MiB 之间';
  }

  @override
  String get virtHwIssueMemoryMin => '不能超过内存';

  @override
  String get virtHwIssueMountPoint => '须为绝对路径，如 /data';

  @override
  String get virtHwIssueStorageSpace => '超出了存储的可用空间';

  @override
  String get virtHwIssueSwap => '不能为负数';

  @override
  String get virtHwLater => '重启后生效';

  @override
  String get virtHwLess => '减少';

  @override
  String get virtHwLinkDown => '已断开';

  @override
  String get virtHwLinkNote => '断开后系统内会显示网线已拔出，无需重启';

  @override
  String get virtHwLinkUp => '已连接';

  @override
  String get virtHwMac => 'MAC 地址';

  @override
  String get virtHwModel => '型号';

  @override
  String get virtHwMore => '增加';

  @override
  String get virtHwMountFromPool => '挂载点直接从存储池分配';

  @override
  String get virtHwMountPoint => '挂载点';

  @override
  String get virtHwMoveDown => '下移';

  @override
  String get virtHwMoveUp => '上移';

  @override
  String get virtHwNewDisk => '新磁盘';

  @override
  String get virtHwNewMount => '新挂载点';

  @override
  String get virtHwNewNic => '新网卡';

  @override
  String get virtHwNicHotplug => 'virtio 网卡支持热插拔';

  @override
  String get virtHwNics => '网卡';

  @override
  String get virtHwNoMedia => '无介质';

  @override
  String get virtHwNoNetworks => '没有可用的网络或网桥';

  @override
  String get virtHwNoStorage => '没有可存放磁盘的存储';

  @override
  String get virtHwOnline => '在线 vCPU';

  @override
  String get virtHwPendingBanner => '部分硬件更改在重启后生效';

  @override
  String get virtHwPickNet => '选择网络';

  @override
  String get virtHwPickPool => '选择存储池和容量';

  @override
  String get virtHwProcessor => '处理器';

  @override
  String get virtHwRemove => '移除';

  @override
  String get virtHwRemoveCdrom => '移除光驱';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return '从 $guest 移除 $disk？';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return '从 $guest 移除 $nic？';
  }

  @override
  String get virtHwResources => '资源';

  @override
  String get virtHwRestartNow => '立即重启';

  @override
  String get virtHwRevert => '撤销';

  @override
  String get virtHwRevertAll => '全部撤销';

  @override
  String get virtSetRenameStopped => '关机后才能改名：libvirt 只能重命名未运行的虚拟机。';

  @override
  String virtSetIssueDescription(int max) {
    return '最多 $max 字节（UTF-8），且不能包含控制字符。';
  }

  @override
  String get virtSetManualStart => '手动启动';

  @override
  String get virtSetProtection => '保护';

  @override
  String get virtSetProtectionNote => '禁止删除虚拟机和修改磁盘';

  @override
  String get virtSetIrreversible => '不可撤销';

  @override
  String get virtSetDeleteStopFirst => '先关机再删除。';

  @override
  String get virtSetDeleteProtected => '已开启保护，先在常规里关闭。';

  @override
  String get virtSetDeleteAgain => '再点一次确认';

  @override
  String virtSetDeleteConfirm(String name) {
    return '确认删除 $name';
  }

  @override
  String get virtSetDeleteVm => '删除虚拟机';

  @override
  String get virtSetDeleteLxc => '删除容器';

  @override
  String get virtHwSockets => '插槽';

  @override
  String get virtHwSource => '源';

  @override
  String get virtHwSwap => '交换空间';

  @override
  String get virtHwTopology => '插槽 × 核心';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets 插槽 × $cores 核 × $threads 线程';
  }

  @override
  String virtHwTotal(String size) {
    return '$size 总计';
  }

  @override
  String get virtHwVolumeKept => '已移除，但运行中的虚拟机仍在使用该磁盘，因此保留了卷。它会在下次启动时分离。';

  @override
  String get virtHwBus => '总线';

  @override
  String get virtHwCache => '缓存';

  @override
  String get virtHwBusStopped => '关机后才能更换总线。';

  @override
  String get virtHwMacGenerate => '生成';

  @override
  String get virtHwIssueMac => '须为单播 MAC 地址，如 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => '先关机';

  @override
  String get virtHwIssueStorageMissing => '先选择存放的存储';

  @override
  String get virtHwIssueDevice => '先选择一个设备';

  @override
  String get virtHwDevices => '光驱与直通';

  @override
  String get virtHwDevicesEmpty => 'USB 与 PCI 直通、光驱、TPM';

  @override
  String get virtHwAddDevice => '添加设备';

  @override
  String get virtHwNewDevice => '新设备';

  @override
  String get virtHwUsbHotplug => 'USB 直通支持热插拔。';

  @override
  String get virtHwPci => 'PCI 直通';

  @override
  String get virtHwIommuOffTitle => '宿主机没有开启 IOMMU';

  @override
  String get virtHwIommuOffBody =>
      '先在宿主机 BIOS 中开启 VT-d 或 AMD-Vi，并在内核中启用 IOMMU。在此之前，添加了 PCI 设备的虚拟机无法启动。';

  @override
  String get virtHwPciTitle => '需要宿主机开启 IOMMU';

  @override
  String get virtHwPciBody => '直通后该设备不能再给宿主机使用，虚拟机也不能在线迁移。';

  @override
  String virtHwIommuGroup(int group) {
    return 'IOMMU 组 $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '同一 IOMMU 组共 $count 个设备，会一起直通';
  }

  @override
  String get virtHwNoHostDevices => '宿主机上没有可直通的设备';

  @override
  String get virtHwMappingsOnly =>
      '这里只能使用资源映射：PVE 只允许以密码登录的 root@pam 直通原始设备。可在 数据中心 → 资源映射 中创建映射。';

  @override
  String get virtHwTpmNote => 'Windows 11 需要 TPM 2.0。';

  @override
  String get virtHwDisplay => '显示';

  @override
  String get virtHwProtocol => '协议';

  @override
  String get virtHwListen => '监听';

  @override
  String get virtHwGpu => '显卡';

  @override
  String get virtHwListenAllTitle => '控制台暴露在网络上';

  @override
  String get virtHwListenAllBody =>
      '监听所有地址后任何能访问宿主机的人都能连上控制台。保持 127.0.0.1，经 SSH 隧道连接即可。';

  @override
  String get virtHwFirmware => '固件';

  @override
  String get virtHwUefiSub => 'OVMF · 支持 Secure Boot，Windows 11 需要';

  @override
  String get virtHwBiosSub => 'SeaBIOS · 旧系统和 MBR 分区';

  @override
  String get virtHwSecureBootNote => '只引导已签名的内核和引导程序';

  @override
  String get virtHwFirmwareWarnTitle => '已安装系统不要切换固件';

  @override
  String get virtHwFirmwareWarnBody => '在 UEFI 和 BIOS 之间切换会导致现有系统无法引导。';

  @override
  String get virtHwFirmwareStopped => '关机后才能切换固件。';

  @override
  String get virtHwSecureBootVars => '开关 Secure Boot 会重新生成 EFI 变量，其中保存的启动项会丢失。';

  @override
  String get virtHwEfiStorage => 'EFI 变量存放在';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return '将 $guest 切换到 $firmware？';
  }

  @override
  String get virtCloneName => '新名称';

  @override
  String get virtCloneFull => '完整克隆';

  @override
  String get virtCloneCopyDisks => '复制磁盘内容';

  @override
  String get virtCloneLinkedNote => '关闭则为链接克隆，依赖原磁盘';

  @override
  String get virtCloneFullOnly => '只有模板可以链接克隆';

  @override
  String get virtCloneEmptyNote => '关闭则新建同样大小的空磁盘';

  @override
  String get virtCloneStopFirst => '克隆前需要先关机。';

  @override
  String get virtCloneFullShort => '完整';

  @override
  String get virtCloneLinkedShort => '链接';

  @override
  String get virtCloneEmptyShort => '空磁盘';

  @override
  String get virtCloning => '正在克隆…';

  @override
  String virtCloned(String name) {
    return '已克隆为 $name';
  }

  @override
  String get virtBackupPlan => '计划';

  @override
  String get virtBackupPlanWhere => '数据中心 → 备份';

  @override
  String get virtBackupNoPlanShort => '无计划';

  @override
  String get virtBackupNoPlan => '没有包含它的定时备份任务。';

  @override
  String get virtBackupKeep => '保留';

  @override
  String get virtBackupJobDisabled => '这个任务已停用。';

  @override
  String virtBackupCount(int count) {
    return '$count 份';
  }

  @override
  String virtSnapshotCount(int count) {
    return '$count 个';
  }

  @override
  String get virtBackupNoStorage => '这个节点上没有能存放备份的存储。';

  @override
  String get virtBackupLiveTip => '运行中用 snapshot 模式，不停机';

  @override
  String get virtBackupStoppedTip => '已关机：按当前状态备份';

  @override
  String get virtBackupNow => '立即备份';

  @override
  String get virtBackupNotes => '备注';

  @override
  String get virtBackupProtected => '受保护：在 PVE 中取消保护之前不能删除。';

  @override
  String virtBackupVerified(String state) {
    return '校验：$state';
  }

  @override
  String get virtBackupRestoreOverwrites => '还原会覆盖当前磁盘';

  @override
  String get virtBackupStopFirst => '先关机再还原。';

  @override
  String get virtBackupRestoreAgain => '虚拟机的磁盘和配置会被备份里的替换。';

  @override
  String get virtBackupDeleteConfirm => '确认删除备份';

  @override
  String get virtBackupRestoreNew => '还原为新的';

  @override
  String get virtBackupRestoreConfirm => '确认覆盖还原';

  @override
  String get virtBackupDone => '备份完成';

  @override
  String get virtBackupDeleted => '已删除备份';

  @override
  String virtBackupRestored(String time) {
    return '已从 $time 还原';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account 在 $path 上没有 $privilege 权限。请在 PVE 主机上授予：\n$command';
  }

  @override
  String get virtCanDelete => '可以删除';

  @override
  String get virtInUse => '使用中';

  @override
  String get virtOps => '操作';

  @override
  String get virtPool => '存储池';

  @override
  String get virtPoolNew => '新建存储池';

  @override
  String get virtStorageAdd => '添加存储';

  @override
  String virtPoolUsedPct(String pct) {
    return '已用 $pct%';
  }

  @override
  String get virtPoolInUse => '有卷正被虚拟机使用，不能停用或删除。';

  @override
  String get virtPoolDelete => '删除存储池';

  @override
  String get virtStorageRemove => '移除存储';

  @override
  String virtPoolDeleteAsk(String name) {
    return '删除存储池 $name？会删除它的定义，卷保留在原处。';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return '从 PVE 配置中移除存储 $name？其中的数据保留。';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '其中的 $count 个卷会保留在磁盘上。';
  }

  @override
  String get virtPoolDeleteStorage => '同时删除其目录（仅当为空时）';

  @override
  String virtPoolStopAsk(String name) {
    return '停用存储池 $name？在重新启用前无法列出或创建其中的卷。';
  }

  @override
  String get virtStorageClusterWide => '这会作用于集群中所有配置了该存储的节点。';

  @override
  String get virtStorageDisable => '停用';

  @override
  String get virtStorageEnable => '启用';

  @override
  String virtStorageDisableAsk(String name) {
    return '停用存储 $name？在重新启用前，磁盘在其上的虚拟机无法启动。';
  }

  @override
  String get virtPoolLogicalNote => '使用已有的卷组，不会格式化任何设备。';

  @override
  String get virtPoolMountPoint => '挂载点';

  @override
  String get virtPoolSourceNfs => '源 (host:/path)';

  @override
  String get virtPoolSourceVg => '卷组';

  @override
  String get virtPoolSourceThin => '卷组 / thin pool';

  @override
  String get virtPoolSourceZfs => 'ZFS 池';

  @override
  String get virtPoolTypeVg => 'LVM 卷组';

  @override
  String get virtResNameEmpty => '请输入名称';

  @override
  String get virtResNameInvalid => '主机不接受此名称（字母、数字、. _ -）';

  @override
  String get virtResSourceInvalid => '不是有效的路径或来源';

  @override
  String get virtResTargetInvalid => '需要绝对路径';

  @override
  String get virtResCidrInvalid => '需要带前缀的地址，例如 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid => '需要网段内、按顺序、且不含宿主机地址的两个地址';

  @override
  String get virtResSubnetTaken => '已有网络使用此网段';

  @override
  String get virtResBridgeInvalid => '不是有效的网络接口名';

  @override
  String get virtResFormat => '这个存储池不支持此格式';

  @override
  String get virtVolNew => '新建卷';

  @override
  String virtVolCount(int count) {
    return '$count 个卷';
  }

  @override
  String get virtVolNone => '这个存储池还没有卷。';

  @override
  String get virtVolEmptyAttach => '新卷可以之后挂载到任意虚拟机';

  @override
  String get virtVolEmptyUpload => '也可以直接上传 ISO';

  @override
  String get virtVolPveName => 'PVE 按所属虚拟机命名卷：vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => '使用者';

  @override
  String get virtVolAllocated => '已分配';

  @override
  String get virtVolGrowFromGuest => '有虚拟机在使用：请在该虚拟机的硬件页扩容';

  @override
  String get virtVolInUse => '有虚拟机正在使用此卷';

  @override
  String virtVolBackingOf(String names) {
    return '$names 的后备文件';
  }

  @override
  String get virtVolIsBase => '有其他卷以此卷为后备文件，删除它会损坏那些卷';

  @override
  String get virtVolAttach => '挂载到虚拟机';

  @override
  String get virtVolAttachNote => '作为新磁盘挂载到其第一块磁盘所在的总线';

  @override
  String virtVolAttached(String name) {
    return '已挂载到 $name';
  }

  @override
  String get virtVolInsert => '插入光驱';

  @override
  String virtVolInserted(String name) {
    return '已插入 $name 的光驱';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name 没有光驱';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return '从 $pool 删除卷 $name？其中的数据将永久丢失。';
  }

  @override
  String get virtUploadIso => '上传 ISO';

  @override
  String virtUploadTo(String pool) {
    return '上传到 $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name 上传完成';
  }

  @override
  String get virtNetConfig => '配置';

  @override
  String get virtNetConfigFile => '配置文件';

  @override
  String get virtNetInternal => '内部';

  @override
  String get virtNetBridgePorts => '桥接端口';

  @override
  String get virtNetHostBridge => '宿主机网桥';

  @override
  String get virtNetPortsHint => 'eno2，留空为内部网桥';

  @override
  String get virtNetDhcpRange => 'DHCP 范围';

  @override
  String get virtNetDhcpTip => 'dnsmasq 为虚拟机分配地址';

  @override
  String get virtNetVlanTip => '允许虚拟机网卡带 VLAN tag';

  @override
  String get virtNetNatTip => '经宿主机转发，虚拟机能上网但外部不可达';

  @override
  String get virtNetRoutedTip => '经宿主机路由，不做 NAT：局域网需要回程路由';

  @override
  String get virtNetIsolatedTip => '只有虚拟机之间和宿主机能通信';

  @override
  String get virtNetBridgedTip => '直接接入宿主机网桥，与物理网络同网段';

  @override
  String get virtNetNew => '新建网络';

  @override
  String get virtNetNewBridge => '新建 Linux bridge';

  @override
  String get virtNetVirtual => '虚拟网络';

  @override
  String get virtNetDelete => '删除网络';

  @override
  String virtNetDeleteAsk(String name) {
    return '删除网络 $name？它会被停止并删除定义。';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return '从 $node 移除网桥 $name？它会先从待生效配置中移除，应用配置后才从宿主机上删除。';
  }

  @override
  String virtNetInUse(int count) {
    return '$count 台在使用，不能删除。';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return '停用 $name？其上的 $count 台虚拟机会断网，直到重新启用。';
  }

  @override
  String get virtNetInactivePve => '未激活：新网桥在应用配置前处于待生效状态。';

  @override
  String get virtNetPveApplyNote => '保存为待生效的变更，应用配置（ifreload -a）后生效。';

  @override
  String get virtNetPendingSaved => '已保存为待生效，应用配置后生效';

  @override
  String virtNetPendingTitle(String node) {
    return '$node 上有待生效的网络变更';
  }

  @override
  String get virtNetPendingTip => 'PVE 会把网络变更保存在 interfaces.new 中，应用后才生效。';

  @override
  String get virtNetPendingShow => '查看变更';

  @override
  String get virtNetApply => '应用配置';

  @override
  String virtNetApplyAsk(String node) {
    return '应用 $node 上待生效的网络配置？PVE 会重新加载宿主机网络（ifreload -a），配置有误可能导致宿主机断网。';
  }

  @override
  String virtNetRevertAsk(String node) {
    return '丢弃 $node 上待生效的网络配置？';
  }

  @override
  String get pveTokenTipStorage =>
      '管理存储需要 /storage 上的 Datastore.Allocate（添加、停用、移除）、Datastore.AllocateSpace（卷）和 Datastore.AllocateTemplate（上传）；Linux bridge 和应用网络配置需要节点上的 Sys.Modify。';

  @override
  String get virtCreateUnnamed => '未命名';

  @override
  String get virtCreateNotChosen => '未选择';

  @override
  String get virtCreateKindVmSub => 'qm · 完整的 KVM 虚拟机';

  @override
  String get virtCreateKindLxcSub => 'pct · 共享宿主机内核，开销更小';

  @override
  String get virtCloudImage => '云镜像';

  @override
  String get virtCloudImageTip =>
      '已装好系统的磁盘：复制一份，扩到「存储」里的容量，首次启动时由 cloud-init 配置。镜像本身保持不变。';

  @override
  String get virtNoCloudImagesLibvirt =>
      '这里没有云镜像：把 qcow2 或 raw 镜像放进一个存储池（可在「存储」里上传），且没有虚拟机在用它。';

  @override
  String get virtNoCloudImagesPve =>
      '这里没有云镜像：把 qcow2、raw 或 vmdk 镜像上传到内容类型含「导入」(Import) 的存储（PVE 8.2+）。';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 需要 UEFI + TPM 2.0';

  @override
  String get virtCreateWindowsBody => '在上面选 UEFI 并打开 TPM。';

  @override
  String get virtCreateWindowsNoTpm => '这台宿主机没有软件 TPM (swtpm)：安装后才能给虚拟机添加。';

  @override
  String virtCreateImageSize(String size) {
    return '镜像有 $size：磁盘至少要这么大。';
  }

  @override
  String get virtCreateImageMissing => '选择一个云镜像。';

  @override
  String get virtCreateIncomplete => '先补全标橙色的部分。';

  @override
  String virtCreateOn(String host) {
    return '将在 $host 上创建';
  }

  @override
  String get virtCiTip => '一个带 sudo 的账户，可用密码、SSH 密钥或两者登录。';

  @override
  String get virtCiUserInvalid => '小写字母、数字、_ 和 -，以字母或 _ 开头';

  @override
  String get virtCiCredentialsMissing => '设置密码或 SSH 密钥。';

  @override
  String get virtCiHostnamePve => '主机名就是虚拟机的名称。';

  @override
  String get virtCiStatic => '静态';

  @override
  String get virtCiAddressInvalid => '带前缀的 IPv4 地址，如 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'IPv4 地址，如 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => '留空：由 DHCP 提供';

  @override
  String get virtCiDnsInvalid => 'IP 地址，用空格或逗号分隔';

  @override
  String get virtCiSearch => '搜索域';

  @override
  String get virtCiSeedNote => '写入磁盘旁的一个小 ISO，作为光驱挂载，随虚拟机一起删除。只保存密码的哈希。';

  @override
  String get virtCiNoToolTitle => '宿主机上没有制作 cloud-init 数据的工具';

  @override
  String virtCiNoToolBody(String tools) {
    return '在宿主机上安装 $tools 之一。没有 cloud-init，镜像启动后没有可登录的账户。';
  }

  @override
  String get virtHwCloudInitNote => 'cloud-init 在首次启动时读取的数据，不是安装介质，这里不能换盘。';

  @override
  String get virtHwCdromLater => '运行中添加的光驱在下次启动时生效（SATA 和 IDE 不支持热插拔）。';

  @override
  String virtCreateDiskKept(String size) {
    return '磁盘保持为镜像本身的 $size，大于所选容量：磁盘不会被裁得比其中的系统还小。';
  }

  @override
  String get virtCiEditTip => 'cloud-init 在这台虚拟机里配置的内容：带 sudo 的账户、登录方式、主机名和地址。';

  @override
  String get virtCiForeignTitle => '这份 seed 包含本应用不写入的设置';

  @override
  String get virtCiForeignBody =>
      '在别处写入的设置（软件包、命令、其他账户）不在这里显示。保存后，seed 会被替换为这里显示的内容。';

  @override
  String get virtCiPasswordKept => '已设置，留空则保持不变';

  @override
  String get virtCiRemovePassword => '移除密码';

  @override
  String get virtCiRemovePasswordNote => '只能用 SSH 密钥登录';

  @override
  String get virtCiKeysAdded =>
      '密钥会添加到账户。在这里删掉的密钥仍留在系统内，需要在系统内删除；改用户名会新建一个账户，旧账户保留。';

  @override
  String get virtCiEffectTitle => '下次启动时生效';

  @override
  String get virtCiEffectLibvirt => '保存会写入一份新的 seed，并使用新的实例 ID。';

  @override
  String get virtCiEffectPve =>
      'PVE 会立即重写它的 cloud-init 驱动器，实例 ID 由这些设置计算得出，因此这里的任何改动都会产生新的实例 ID。';

  @override
  String get virtCiNewInstance =>
      '下次启动时，cloud-init 会把系统当作新实例：重新设置主机名，账户不存在时创建它，设置密码、添加密钥，并重新写入网络配置。它还会生成新的 SSH 主机密钥，因此 SSH 客户端会提示主机密钥已变更。在那次启动之前不会有任何变化。';

  @override
  String get virtCiSaved => '已保存，下次启动时生效。';

  @override
  String get virtSnapshotExternal => '不停机，仅磁盘';

  @override
  String get virtSnapshotExternalTip =>
      '虚拟机继续运行。每块磁盘在所选存储池中得到一个 qcow2 覆盖层，虚拟机停留在链上。';

  @override
  String get virtSnapshotFormInternal => '内部（镜像内）';

  @override
  String get virtSnapshotOverlayPool => '覆盖层存储池';

  @override
  String get virtSnapshotOverlayBeside => '各磁盘所在目录';

  @override
  String get virtSnapshotExternalNoMemory => '外部快照不含内存：虚拟机不会停机。';

  @override
  String get virtSnapshotChain => '磁盘链';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count 层';
  }

  @override
  String get virtSnapshotChainFile => '文件';

  @override
  String get virtSnapshotChainActive => '当前使用';

  @override
  String get virtSnapshotChainBase => '基础镜像';

  @override
  String get virtSnapshotNoSupport => '虚拟机的存储不支持快照，无法创建。';

  @override
  String get virtSnapshotRevertChain =>
      '在链上恢复会把运行中的覆盖层合并进镜像，并让之后的所有快照无法使用。只能恢复到最新的快照。';

  @override
  String get virtSnapshotRevertHasChildren => '后面还有快照时不可恢复。';

  @override
  String get virtSnapshotDiff => '与当前的不同';

  @override
  String get virtSnapshotDiffNone => '自该快照以来配置没有变化。';

  @override
  String get virtSnapshotDiffShow => '与当前比较';

  @override
  String get virtSnapshotDiffGroupCpu => '处理器';

  @override
  String get virtSnapshotDiffGroupMemory => '内存';

  @override
  String get virtSnapshotDiffGroupDisks => '磁盘';

  @override
  String get virtSnapshotDiffGroupNic => '网卡';

  @override
  String get virtSnapshotDiffGroupFirmware => '固件';

  @override
  String get virtSnapshotDiffGroupBoot => '启动';

  @override
  String get virtSnapshotDiffGroupOther => '其他';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => '已移除';

  @override
  String get virtSnapshotDiffAdded => '已添加';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return '恢复到 $snapshot 会改变：';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return '主机无法说明差异：$error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return '虚拟机已在 $count 层链上，该快照会再增加一层。';
  }

  @override
  String get virtToTemplate => '转为模板';

  @override
  String get virtToTemplateNote => '模板无法启动，也无法还原为虚拟机。其磁盘变为基础镜像，链接克隆正是共享它。';

  @override
  String virtToTemplateConfirm(String name) {
    return '将 $name 转为模板？';
  }

  @override
  String get virtToTemplateIrreversible => '此操作无法撤销：模板无法还原为虚拟机。';

  @override
  String get virtToTemplateStopped => '请先关机。';

  @override
  String get virtToTemplateSnapshots => '含快照的虚拟机无法转为模板。';

  @override
  String virtTemplateCreated(String name) {
    return '$name 现在是模板';
  }

  @override
  String get virtTemplateTip => '模板只有在克隆后才能运行。';

  @override
  String get virtCloneStorageSame => '与源相同';

  @override
  String get virtCloneNodeSame => '与源相同';

  @override
  String get virtCloneStorageContent => '该存储不存放虚拟机磁盘。';

  @override
  String get virtCloneStorageShared => '复制到其他节点需要共享存储。';

  @override
  String get virtCloneNodeUnknown => '该宿主机没有此节点。';

  @override
  String get virtCloneLinkedTarget => '链接克隆共享模板的磁盘，因此不能指定存储或节点。';

  @override
  String get virtBackupJobs => '备份任务';

  @override
  String get virtBackupJobsNone => '没有计划备份任务。添加一个即可按计划备份虚拟机。';

  @override
  String get virtBackupJobNew => '新建任务';

  @override
  String get virtBackupJobRun => '立即运行';

  @override
  String get virtBackupJobRunAsk => '立即启动该备份任务？';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return '删除备份任务 $id？已生成的备份会保留。';
  }

  @override
  String get virtBackupJobSaved => '任务已保存';

  @override
  String get virtBackupJobDeleted => '任务已删除';

  @override
  String get virtBackupJobStarted => '备份任务已启动';

  @override
  String get virtBackupSchedule => '时间表';

  @override
  String get virtBackupScheduleHelp =>
      'systemd 日历事件的子集：02:30、mon..fri 02:30、sat 03:00、daily、hourly、*/15。';

  @override
  String get virtBackupScheduleInvalid => '宿主机不接受该时间表。';

  @override
  String virtBackupScheduleNext(String times) {
    return '接下来运行：$times';
  }

  @override
  String get virtBackupSelection => '虚拟机';

  @override
  String get virtBackupSelectionAll => '所有虚拟机';

  @override
  String get virtBackupSelectionList => '选定的虚拟机';

  @override
  String get virtBackupSelectionNone => '请至少选择一台虚拟机。';

  @override
  String get virtBackupMail => '通知';

  @override
  String get virtBackupNotesTemplate => '备份备注';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return '备注会加到该任务生成的每个备份上。其中的 $vars 会被替换为实际值。';
  }

  @override
  String get virtBackupPrune => '保留';

  @override
  String get virtBackupPruneTip =>
      'PVE 的保留选项，例如 keep-last=7,keep-daily=4。留空则用存储或节点自身的设置。';

  @override
  String get virtBackupJobNode => '节点';

  @override
  String get virtBackupJobNodeAny => '所有节点';

  @override
  String get virtBackupEnabled => '启用';

  @override
  String get virtBackupOptions => '选项';

  @override
  String get virtBackupProtect => '保护';

  @override
  String get virtBackupProtectTip => '受保护的备份不会被保留策略清理，在取消保护前也无法删除。';

  @override
  String get virtBackupEditNotes => '备注';

  @override
  String get virtBackupSaveNotes => '保存';

  @override
  String get virtBackupEdited => '备份已更新';

  @override
  String get virtBackupRestoreStorage => '还原到存储';

  @override
  String get virtBackupRestoreStorageSame => '与备份一致';

  @override
  String get virtCloneStorageMissing => '该节点上没有存放虚拟机磁盘的存储。';

  @override
  String get virtBackupCompress => '压缩';

  @override
  String get virtBackupUnprotect => '取消保护';

  @override
  String get virtBackupModeStops => 'suspend 和 stop 会在复制期间中断运行中的虚拟机。';

  @override
  String get virtBackupScheduleValidate => '向宿主机校验';

  @override
  String virtBackupSelected(int count) {
    return '已选 $count 台';
  }

  @override
  String get virtBackupExcludeTip => '该节点上的所有虚拟机都会备份。关闭某个即可排除它。';

  @override
  String virtNetEditAsk(int count) {
    return '运行中的网络在重启前保持原样。重启会中断其上的 $count 台虚拟机。';
  }

  @override
  String get virtNetEditAskNoGuest => '运行中的网络在重启前保持原样。';

  @override
  String get virtNetEditRestart => '立即重启以生效';

  @override
  String get virtNetEditRestartNote => '重启期间其上的虚拟机将断网。';

  @override
  String get virtNetEditPending => '配置中已有改动，运行中的网络尚未生效。';

  @override
  String get virtNetRestart => '重启';

  @override
  String virtNetRestartAsk(String name, int count) {
    return '重启 $name？其上的 $count 台虚拟机将断网，直到它重新启动。';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return '重启 $name？其上没有虚拟机。';
  }

  @override
  String get virtNetHosts => '静态地址';

  @override
  String get virtNetHostAdd => '添加地址';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => '地址';

  @override
  String get virtNetHostName => '名称（可选）';

  @override
  String get virtNetHostEmpty => '未给任何 MAC 分配固定地址：所有虚拟机都从 DHCP 范围中获取。';

  @override
  String get virtNetHostOthers => '其余虚拟机都从 DHCP 范围中获取地址。';

  @override
  String get virtNetHostInvalid => '宿主机会拒绝的 MAC、地址或名称，或同一个 MAC 出现两次。';

  @override
  String get virtNetManagementIface => '此接口承载宿主机自身的地址。编辑或应用它会中断宿主机的连接。';

  @override
  String get virtNetManagementTip => '它承载宿主机的管理流量，或位于承载管理流量的接口之下：应用不会编辑它。';

  @override
  String get virtNetPhysicalTip => '物理接口属于宿主机本身：应用只编辑网桥。';

  @override
  String get virtNetVlanAware => 'VLAN 感知';

  @override
  String get virtCiExpire => '密码过期';

  @override
  String get virtCiExpireNote =>
      '首次用该密码登录时必须设置新密码。仅 libvirt 支持：PVE 固定写入 \"expire: false\"，没有对应选项。';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip => '可填多个，用空格分隔；resolv.conf 只保留前几个。';

  @override
  String virtCiNicsTip(int count) {
    return 'seed 的 network-config 中有 $count 块网卡；表单编辑第一块。';
  }

  @override
  String get virtUsbByVendor => '按厂商和产品';

  @override
  String get virtUsbByAddress => '按地址';

  @override
  String get virtUsbAddressTip =>
      '设备跟随此地址：插在该处的设备会交给虚拟机。libvirt 用总线号和设备号标识 USB hostdev。';

  @override
  String virtUsbPortNote(int bus, String port) {
    return '总线 $bus · 端口 $port';
  }

  @override
  String get virtSbUnsupported =>
      '宿主机的固件描述文件中没有带已注册密钥的 Secure Boot 固件，开启后虚拟机无法启动。';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote => '只引导已签名的内核和引导程序。';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return '总线 $bus · 设备号 $device';
  }

  @override
  String get virtHwRevertPendingTitle => '丢弃待生效的修改';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name 将回到正在运行的状态：用运行中的定义重新写入配置，下次启动得到的与这次完全相同。其 NVRAM 文件与固件保持不变。';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return '丢弃 $name 所有等待下次启动的修改？';
  }

  @override
  String get virtBackupPlanNew => '新建计划';

  @override
  String get virtBackupPlanNewTip => '只备份这台虚拟机的定时计划。';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还备份另外 $count 台虚拟机',
      zero: '没有其他虚拟机',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => '减少动态效果';

  @override
  String get copyLink => '复制链接';

  @override
  String funcNeedsAgentPermission(String func) {
    return '你在此 Monitor agent 上的账号没有 $func 的权限，请联系该 agent 的管理员。';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func 需要通过 HTTPS 连接此 Monitor agent，或在 agent 和本 App 中同时允许 HTTP。';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '此 Monitor agent 尚未配置 $func，需要由其运维人员配置。';
  }

  @override
  String get monitorFilesReadOnly => '只读：此账号可以浏览 agent 上的文件，但不能修改。';

  @override
  String get monitorAccess => '访问';

  @override
  String get monitorAccounts => '账号';

  @override
  String get monitorRoles => '角色';

  @override
  String get monitorRole => '角色';

  @override
  String get monitorChangePassword => '修改密码';

  @override
  String get monitorNewPassword => '新密码';

  @override
  String get monitorCurrentPassword => '你当前的密码';

  @override
  String get monitorReauthTip => '修改访问权限需要再次输入你的密码。';

  @override
  String get monitorPasswordTooShort => '至少 8 个字符';

  @override
  String get monitorPasswordMismatch => '两次输入的密码不一致';

  @override
  String get monitorErrReauth => '密码错误。';

  @override
  String get monitorErrLastAdmin => 'agent 至少需要一个管理员账号。';

  @override
  String get monitorErrConflict => '已存在，或仍在使用中。';

  @override
  String get monitorErrForbidden => '只有管理员可以执行此操作。';

  @override
  String get monitorRoleNameRule => '小写字母、数字、- 和 _，最多 32 个字符';

  @override
  String get monitorGrantShell => 'Shell 和命令';

  @override
  String get monitorGrantShellTip => '终端、进程、服务、容器、代码片段、电源 —— 以 agent 的系统账号运行';

  @override
  String get monitorGrantSshTerminal => '面板 SSH 终端';

  @override
  String get monitorGrantFiles => '文件';

  @override
  String get monitorGrantConnect => '出站连接';

  @override
  String get monitorGrantConnectTip => '本地和动态端口转发、远程桌面';

  @override
  String get monitorGrantConnectAllow =>
      '允许的目标（IP 或 CIDR，可带 :端口 或 :起-止；每行一个，留空表示任意）';

  @override
  String get monitorGrantListen => '在服务器上监听';

  @override
  String get monitorGrantListenTip => '远程端口转发';

  @override
  String get monitorGrantListenPublic => '非 loopback 地址';

  @override
  String get monitorGrantPorts => '端口范围（留空表示任意）';

  @override
  String get monitorGrantOff => '关闭';

  @override
  String get monitorBuiltin => '内置';

  @override
  String get monitorAdminRoleTip => '管理账号、角色和 agent 的设置';

  @override
  String get monitorYou => '你';

  @override
  String get monitorNoAccessToSettings => '只有管理员可以修改此 agent 的设置。';

  @override
  String get monitorPasswordNotSaved =>
      'agent 上的密码已修改，但 App 未能保存新密码。请在这台服务器的设置中更新 Monitor 密码。';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get crashCollect => '診斷資料';

  @override
  String get crashCollectIntro => 'ServerBox 會記錄執行期間發生的情況，以便修正問題。你可以選擇要傳送多少資料。';

  @override
  String get crashCollectNone => '不傳送';

  @override
  String get crashCollectNoneTip => '報告仍會保留在本機；當機後你仍可手動傳送。';

  @override
  String get crashCollectBasic => '基本資料';

  @override
  String get crashCollectBasicTip =>
      '只包含當機資訊，不包含日誌或效能資料。**這有助於我們改善 App 和修正錯誤。**';

  @override
  String get crashCollectFull => '完整資料';

  @override
  String get crashCollectFullTip =>
      '除了當機日誌外，也會包含效能資料和功能使用情況：用於定位變慢的問題，以及了解哪些功能真的有人用。';

  @override
  String get crashCollectFooter =>
      '無論選擇哪個等級，記錄時都會將已知伺服器名稱、位址和使用者名稱替換為預留位置。之後可在設定中更改收集等級。';

  @override
  String get privacy => '隱私';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get crashLastRunFailed => 'ServerBox 上次執行時異常結束。';

  @override
  String get crashReportTitle => '當機報告';

  @override
  String get crashReportHint =>
      '這是上次執行的日誌。已知的伺服器名稱和位址已替換為預留位置，但其中可能仍包含其他資訊。提交前請仔細閱讀。';

  @override
  String get crashReportSubmit => '複製並回報';

  @override
  String get preReleaseUpdates => '接收預發布版本更新';

  @override
  String get addSystemPrivateKeyTip => '偵測到尚無私鑰，是否要加入系統預設的私鑰（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已新增至任務清單';

  @override
  String get askAi => '詢問 AI';

  @override
  String get askAiInsertTerminal => '插入終端機';

  @override
  String get remoteDesktop => '遠端桌面';

  @override
  String get askAiRiskReadOnly => '唯讀';

  @override
  String get askAiRiskCaution => '會變更系統';

  @override
  String get askAiRiskUnvetted => '未審核的主機';

  @override
  String get askAiRiskDestructive => '高風險';

  @override
  String get askAiAutoRunSafeCommands => '自動執行唯讀指令';

  @override
  String get askAiAutoRunSafeCommandsTip => '僅當模型與本機安全檢查都判定命令為唯讀時自動執行';

  @override
  String get askAiHistory => '對話歷史';

  @override
  String get askAiNewConversation => '新增對話';

  @override
  String get askAiUntitledConversation => '新對話';

  @override
  String get askAiRenameConversation => '重新命名對話';

  @override
  String get askAiDeleteConversationTitle => '刪除這個對話？';

  @override
  String get askAiDeleteConversationTip => '從本機刪除該對話，無法復原。';

  @override
  String get agentNoHistory => '暫無全域 Agent 對話';

  @override
  String get agentClearHistoryTitle => '清除全域 Agent 歷史記錄？';

  @override
  String get agentClearHistoryTip => '此裝置上的全部全域 Agent 對話都將被刪除。';

  @override
  String get agentToolShell => '終端指令';

  @override
  String get agentToolReadFile => '讀取檔案';

  @override
  String get agentToolWriteFile => '寫入檔案';

  @override
  String get floatOverTabs => '在其他分頁上懸浮';

  @override
  String get agentToolSshConnect => 'SSH 連線';

  @override
  String get agentToolSshDisconnect => '中斷 SSH';

  @override
  String get agentSshConnectTitle => '連線到新主機';

  @override
  String get agentAuthMethod => '認證方式';

  @override
  String get agentSshConnectTip => 'Agent 想要建立 SSH 連線。請在此輸入密碼。';

  @override
  String get agentAdHocSessions => '暫時連線';

  @override
  String get agentSaveServerTitle => '儲存為伺服器';

  @override
  String get agentSaveServerTip => '這台主機和你輸入的密碼將儲存在本裝置上';

  @override
  String get agentMonitorOptional => 'Monitor 代理（選填）';

  @override
  String get authFailTip => '認證失敗，請檢查資訊是否正確';

  @override
  String get autoBackupConflict => '僅能啟用一項自動備份任務';

  @override
  String get autoConnect => '自動連線';

  @override
  String get autoRun => '自動執行';

  @override
  String get autoUpdateHomeWidget => '自動更新桌面小工具';

  @override
  String get availableTabs => '可用標籤';

  @override
  String get backupEncrypted => '備份已加密';

  @override
  String get backupNotEncrypted => '備份未加密';

  @override
  String get backupPassword => '備份密碼';

  @override
  String get backupPasswordRemoved => '備份密碼已移除';

  @override
  String get backupPasswordSet => '備份密碼已設定';

  @override
  String get backupPasswordTip => '設定密碼來加密備份檔案。留空則停用加密。';

  @override
  String get backupPasswordWrong => '備份密碼錯誤';

  @override
  String get connectAll => '全部連線';

  @override
  String get disconnectAll => '全部斷開';

  @override
  String get distIcon => '發行版標識';

  @override
  String get distIconIntroLegal =>
      '標識只根據本裝置從遠端系統讀取的資訊顯示。這些資訊可能不準確或已過期，也不代表某個衍生版本、重建版本或特定版本。無法識別時會顯示通用圖示。\n\n各標識均為其所有者的商標，此處僅用於說明對應的系統。';

  @override
  String get distIconTip => '在每台伺服器旁顯示一個小標識，表示它可能執行的系統';

  @override
  String get distNameMap => '名稱對應';

  @override
  String get distNameMapTip =>
      '僅用於「託管處的檔名和本應用使用的名稱對不上」的發行版。鍵是本應用使用的名稱，值是實際要取的名稱。沒有缺圖就不用填。';

  @override
  String get logoUrl => 'Logo 位址';

  @override
  String get logoUrlTip => '伺服器詳情頁頂部的大圖，按原色顯示。';

  @override
  String get globe => '地球儀';

  @override
  String get locationTip =>
      '此伺服器在地球儀上的顯示位置。緯度在前、經度在後，單位為度，例如 39.9042, 116.4074。';

  @override
  String get markUrl => '標識位址';

  @override
  String get markUrlTip => '清單中伺服器名稱旁邊的小標識。留空則不顯示。\n\n和 Logo 不是同一張圖';

  @override
  String get navTabMenuTip => '長按標籤列圖示（滑鼠右鍵點選）可一次連線或斷開其中的全部項目。';

  @override
  String nTags(int count) {
    return '$count 個標籤';
  }

  @override
  String get remoteBackupPasswordRequired => '遠端備份需要非空的備份密碼';

  @override
  String get monitorHttpsRequired => '遠端監控代理必須使用 HTTPS，除非該連線已允許 HTTP。';

  @override
  String get monitorAllowInsecureHttp => '允許 HTTP';

  @override
  String get plainHttpTitle => '這個 agent 走的是明文 HTTP';

  @override
  String get plainHttpTip => '密碼和這個應用取的所有內容都會以明文傳輸。目前還沒有送出任何東西。';

  @override
  String get allowForThisServer => '只對這台伺服器允許';

  @override
  String get viewError => '檢視錯誤';

  @override
  String get monitorAllowInsecureHttpTip =>
      '僅應在 HTTP 之外具備傳輸加密的可信私有網路中開啟，例如 Tailscale';

  @override
  String monitorHttpTip(String url) {
    return '透過 **monitor** 的 HTTP 介面讀取此伺服器的狀態，而不是經由 SSH 執行指令。\n\n需要先在伺服器上安裝 monitor；曲線、手錶 App 與桌面小工具都依賴它。\n\n[如何部署 monitor]($url)';
  }

  @override
  String get backupTip => '匯出的資料可透過密碼加密，請妥善保管。';

  @override
  String get icloudBackupStatusTitle => '備份狀態';

  @override
  String get icloudBackupStatusLoading => '正在讀取 iCloud 備份狀態...';

  @override
  String get icloudBackupStatusError => '無法讀取 iCloud 備份中繼資料';

  @override
  String get icloudBackupStatusEmpty => '尚未找到 iCloud 備份檔案';

  @override
  String get icloudBackupStateUploading => '上傳中';

  @override
  String get icloudBackupStateConflict => '偵測到衝突';

  @override
  String get icloudBackupStateUploaded => '已上傳';

  @override
  String get icloudBackupStateWaiting => '等待 iCloud 同步';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return '最後備份：$lastModified\n狀態：$remoteState';
  }

  @override
  String get bgRun => '背景執行';

  @override
  String get bgRunTip =>
      '此開關僅代表程式會嘗試於背景執行，能否成功取決於系統權限。在原生 Android 上，請關閉本應用的「電池最佳化」；在 MIUI / HyperOS 上，請將省電策略調整為「無限制」。';

  @override
  String get trayReadings => '讀數';

  @override
  String get trayChart => '圖表';

  @override
  String get trayChartNone => '無';

  @override
  String get trayCompact => '精簡列';

  @override
  String get trayCompactTip =>
      '每部伺服器顯示一行，不顯示圖表。Linux 的面板選單透過 D-Bus 傳送標籤而非自訂版面配置，因此一律使用單行版面配置，但仍可將所選圖表顯示為圖片。';

  @override
  String get trayKeepRunning => '在系統匣中繼續執行';

  @override
  String get trayKeepRunningTip =>
      '關閉視窗後，App 會留在選單列或通知區域中，並繼續監控伺服器。關閉此選項後，關閉按鈕會結束 App。';

  @override
  String get bgRunNeedsNotification => '背景執行需要顯示常駐通知，但 App 尚未取得通知權限。點一下即可授權。';

  @override
  String get clearAllStatsContent => '確定要清空所有伺服器的連線統計資料嗎？此操作無法撤銷。';

  @override
  String get clearAllStatsTitle => '清空所有統計';

  @override
  String clearServerStatsContent(String serverName) {
    return '確定要清空伺服器 \"$serverName\" 的連線統計資料嗎？此操作無法撤銷。';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return '清空 $serverName 統計';
  }

  @override
  String get clearThisServerStats => '清空此伺服器統計';

  @override
  String get closeAfterSave => '儲存後關閉';

  @override
  String get collapseUITip => '是否預設折疊 UI 中存在的長列表';

  @override
  String get connectionDetails => '連線詳情';

  @override
  String get connectionStats => '連線統計';

  @override
  String get connectionStatsDesc => '檢視伺服器連線成功率和歷史記錄';

  @override
  String get containerTrySudoTip =>
      '例如：App 內設定使用者為 aaa，但是 Docker 安裝在 root 使用者，這時就需要開啟此選項';

  @override
  String get containerSudoPasswordRequired => '需要 sudo 密碼才能存取 Docker。請輸入您的密碼。';

  @override
  String get containerSudoPasswordIncorrect => 'sudo 密碼錯誤或無權限。請重試。';

  @override
  String get copyPath => '複製路徑';

  @override
  String get customCmd => '自訂指令';

  @override
  String get deleteServers => '大量刪除伺服器';

  @override
  String get deleteDirRecursive => '連同資料夾裡的所有內容一起刪除';

  @override
  String get dirEmpty => '請確保目錄為空';

  @override
  String get discoverSshServers => '發現SSH服務器';

  @override
  String get discoveryFailed => '發現失敗';

  @override
  String get discoverySettings => '發現設定';

  @override
  String get distro => '發行版';

  @override
  String get diskHealth => '磁碟健康';

  @override
  String dl2Local(String fileName) {
    return '下載 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '沒有正在執行的容器。\n這可能是因為：\n- Docker 安裝使用者與 App 內配置的使用者名稱不同\n- 環境變數 DOCKER_HOST 沒有被正確讀取。你可以通過在終端機內執行 `echo \$DOCKER_HOST` 來獲取。';

  @override
  String get dockerProjectOther => '其他';

  @override
  String get dockerPruneTip => '清理未使用的資料以釋放磁碟空間';

  @override
  String get dockerStatistics => 'Docker 統計';

  @override
  String get editVirtKeys => '虛擬按鍵';

  @override
  String get editorHighlightTip => '程式碼高亮功能可能影響效能，可選擇性關閉。';

  @override
  String get enableMdns => '啟用mDNS';

  @override
  String get enableMdnsDesc => '使用mDNS/Bonjour發現SSH服務';

  @override
  String get envVars => '環境變數';

  @override
  String get extraArgs => '額外參數';

  @override
  String get fallbackSshDest => '備選 SSH 目標';

  @override
  String get fdroidReleaseTip => '如果你是從 F-Droid 下載的本App，推薦關閉此選項';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return '檔案 \'$file\' 過大 \'$size\'，超過了 $sizeMax';
  }

  @override
  String get fileDirGone => '此資料夾已不存在';

  @override
  String get fileDirGoneTip => '已被刪除或重新命名';

  @override
  String get fullScreen => '全螢幕';

  @override
  String get fullScreenJitter => '全螢幕模式抖動';

  @override
  String get fullScreenJitterHelp => '防止螢幕烙印';

  @override
  String get fullScreenTip => '當設備旋轉為橫向時，是否開啟全螢幕模式？此選項僅適用於伺服器分頁。';

  @override
  String get githubGistIdOptional => 'Gist ID（選填）';

  @override
  String get githubGistToken => 'GitHub Gist Token';

  @override
  String get githubGistTokenEmpty => 'Token 為空';

  @override
  String get goto => '前往';

  @override
  String get homeTabs => '主頁標籤';

  @override
  String get homeTabsCustomizeDesc => '自訂主頁上顯示的標籤及其順序';

  @override
  String get ignoreCert => '忽略憑證';

  @override
  String get image => '映像檔';

  @override
  String get macDmgBody =>
      'App Store 要求本應用沙盒執行，而沙盒內無法開啟終端。DMG 版可以開啟。\n\nApp Store 版以後可能停止更新。';

  @override
  String get macDmgImportDenied => 'macOS 不允許讀取此前安裝版本的資料';

  @override
  String get macDmgImported => '已匯入此前安裝版本的資料';

  @override
  String get macDmgImportFailed => '讀不到此前安裝版本的資料';

  @override
  String get macDmgTip => '本機終端、在本機執行 snippet（DMG 版）';

  @override
  String get macDmgTitle => 'DMG 版';

  @override
  String get showHiddenFiles => '顯示隱藏檔案';

  @override
  String get sshKeyAlgorithm => '演算法';

  @override
  String get sshKeyComment => '備註';

  @override
  String get sshKeyGenerate => '產生金鑰對';

  @override
  String get sshKeyGenerating => '產生中…';

  @override
  String sshKeyLockedFmt(String name) {
    return '私密金鑰 [$name] 未解鎖。';
  }

  @override
  String get sshKeyPassphraseTip => '選填。設定通行密碼後，私密金鑰將加密儲存，每次連線首次使用該金鑰時會要求輸入。';

  @override
  String get sshKeyPassphraseWrong => '通行密碼錯誤。';

  @override
  String get sshKeyPublicKey => '公開金鑰';

  @override
  String get sshKeyPublicKeyTip => '將此行附加到伺服器的 ~/.ssh/authorized_keys。';

  @override
  String get sshKeyRecommended => '推薦';

  @override
  String sshKeyUnlockTip(String name) {
    return '請輸入私密金鑰 [$name] 的通行密碼。';
  }

  @override
  String get ungrouped => '未分組';

  @override
  String get containerReclaimable => '可回收';

  @override
  String get unused => '未使用';

  @override
  String get dangling => '懸空';

  @override
  String get pruneUnusedImages => '清理未使用映像檔';

  @override
  String get pruneDanglingImages => '清理懸空映像檔';

  @override
  String get pruneImages => '清理映像檔';

  @override
  String get unusedTaggedImages => '未使用標記';

  @override
  String get pruneDanglingImagesTip => '僅移除懸空映像。';

  @override
  String get pruneUnusedImagesTip => '同時移除未被任何容器使用的已標記映像檔。';

  @override
  String get includeUnusedVolumesTip => '同時移除未被任何容器使用的卷。';

  @override
  String get pruneCommandPreview => '命令預覽';

  @override
  String get pruneForceSshTip => '遠端執行始終啟用 -f，以略過無法互動的確認提示。';

  @override
  String get pruneVolumes => '清理卷';

  @override
  String get pruneUnusedData => '清理未使用資料';

  @override
  String get pull => '拉取';

  @override
  String get invalidHostFormat => '主機格式無效，僅支援 IPv4、IPv6 和網域字元。';

  @override
  String get jumpServer => '跳板伺服器';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return '未找到 $serverName 配置的跳板伺服器：$jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '「$name」已存在';
  }

  @override
  String get noJumpServerAvailable => '沒有可用的跳板伺服器。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '跳板伺服器與 ProxyCommand 不能同時使用。';

  @override
  String get noConnectionMethod => '請設定 SSH、Monitor 或兩者';

  @override
  String get keepForeground => '請讓 App 保持在前景執行';

  @override
  String get keepStatusWhenErr => '保留上次的伺服器狀態';

  @override
  String get keepStatusWhenErrTip => '僅在執行腳本出錯時';

  @override
  String get keyAuth => '金鑰認證';

  @override
  String get lastFailure => '最後失敗';

  @override
  String get lastSuccess => '最後成功';

  @override
  String get letterCache => '一般鍵盤輸入';

  @override
  String get letterCacheTip => '開啟後，輸入內容會經過一般輸入法，這樣可避免部分系統在終端彈出安全鍵盤。';

  @override
  String get linuxShellTip => '終端用什麼 shell 啟動。留空恢復 /bin/sh。';

  @override
  String get linuxNetTip => 'DNS 伺服器。留空恢復預設值';

  @override
  String madeWithLove(String myGithub) {
    return '用❤️製作 by $myGithub';
  }

  @override
  String get maxConcurrency => '最大並發數';

  @override
  String get maxRetryCount => '伺服器嘗試重連次數';

  @override
  String get mirror => '鏡像';

  @override
  String get needRestart => '需要重開 App';

  @override
  String get newContainer => '新建容器';

  @override
  String get noConnectionStatsData => '暫無連線統計資料';

  @override
  String get noPrivateKeyTip => '私鑰不存在，可能已被刪除/配置錯誤。';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get openLastPath => '打開上次的路徑';

  @override
  String get openLastPathTip => '將為每台伺服器紀錄其最後存取路徑';

  @override
  String get parseContainerStatsTip => 'Docker 解析消耗狀態較為緩慢';

  @override
  String get privateKey => '私鑰';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return '未找到私鑰 [$keyId]。';
  }

  @override
  String get bmcPowerOnAction => '開機';

  @override
  String get bmcShutdown => '關機';

  @override
  String get bmcForceOff => '強制斷電';

  @override
  String get restart => '重新啟動';

  @override
  String get bmcPowerCycle => '冷重新啟動';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '要對 $server 執行「$resetType」嗎？';
  }

  @override
  String get bmcPowerDone => '電源狀態已改變';

  @override
  String get bmcPowerAccepted => '操作已接受，但電源狀態尚未改變。正常關機或重新啟動是否成功取決於作業系統。';

  @override
  String get bmcPowerUnsupported => '該服務不允許這個操作的任何類型';

  @override
  String get bmcUnauthorized => 'BMC 拒絕了這個帳號';

  @override
  String get bmcAccountMissing => '此 BMC 未設定帳號';

  @override
  String get bmcPowerOn => '已開機';

  @override
  String get bmcPowerOff => '已關機';

  @override
  String get bmcCertRejected => '憑證被拒絕——請在伺服器設定裡確認';

  @override
  String get bmcNotAService => '該位址上沒有 Redfish 服務';

  @override
  String get bmcNoSystem => '該服務沒有回報任何 system';

  @override
  String get bmcSensorsTruncated => '只顯示了前面若干個感測器';

  @override
  String get bmcMultipleSystems => '僅顯示第一個系統';

  @override
  String get bmcTip =>
      'BMC 是主機板上的獨立管理裝置。即使主機已關機或作業系統無回應，它通常仍可存取。設定後，App 可讀取電源狀態與硬體感測器。此功能需要 Redfish，大多數 2016 年以後的企業級硬體都支援。';

  @override
  String get bmcCert => '憑證';

  @override
  String get bmcCertPinned => '已確認並釘住';

  @override
  String get bmcCertUnreviewed => '尚未確認——點擊查看憑證';

  @override
  String get bmcCertReview => '收到自簽憑證。接受前請核對指紋；接受後將只信任這張憑證。';

  @override
  String get bmcCertChanged => '憑證不一致。請核對。';

  @override
  String get bmcCertExpired => '已過期。';

  @override
  String bmcCertWas(String fingerprint) {
    return '之前接受的：$fingerprint';
  }

  @override
  String get bmcAddrInvalid => 'BMC 位址必須是 URL，例如 https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      '此版本執行在沙盒中：命令使用的是空白家目錄，因此依賴 ~/.ssh 的命令會失敗。DMG 版不受此限制。';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return '無法讀取私鑰檔案 $path:$reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return '此版本無法讀取沙盒外的檔案，因此無法存取 $path 中的金鑰。請在設定中匯入金鑰，或改用 DMG 版。';
  }

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get liveActivity => '即時動態';

  @override
  String get liveActivityTip => '在鎖定畫面和動態島上顯示終端機工作階段。無需解鎖即可查看伺服器名稱與連線狀態。';

  @override
  String get liveActivitySystemDisabled =>
      'iOS 未允許顯示。開關位於「設定 › ServerBox › 即時動態」和「設定 › 面容 ID 與密碼 › 即時動態」。';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand 在本機的 Linux 環境中執行，請先安裝一個 Linux 系統。';

  @override
  String get proxyCommandMobileTip =>
      '在手機上，該指令會在所選的 Linux 系統中執行。請先在其中安裝指令用到的工具（nc、socat 等）。';

  @override
  String get pveIgnoreCertTip => '不建議啟用，請注意安全風險！如果您使用的是 PVE 的預設憑證，則需要啟用此選項。';

  @override
  String get pvePasswordRequired => '需要提供 PVE 密碼，請在伺服器設定中填寫。';

  @override
  String get pveOtpRequired => '此 PVE 伺服器已啟用雙因素認證，請輸入 OTP 驗證碼。';

  @override
  String get pveOtpCodeRequired => '請輸入 OTP 驗證碼。';

  @override
  String get pveOtpVerificationFailed => 'OTP 驗證失敗，請使用最新驗證碼重試。';

  @override
  String get pveOtpTitle => 'OTP 驗證';

  @override
  String get pveOtpLabel => 'OTP 驗證碼';

  @override
  String get pveInvalidResponseBody => 'PVE 登入返回了無效的回應內容。';

  @override
  String get pveInvalidResponseData => 'PVE 登入回應中缺少有效的 data 資料。';

  @override
  String get pveMissingAuthTicket => 'PVE 登入成功，但未返回認證票據。';

  @override
  String get pveLoadingConnect => '正在連接...';

  @override
  String get pvePassword => 'PVE 密碼';

  @override
  String get pvePasswordHint => '使用密鑰認證時需要填寫';

  @override
  String get read => '讀取';

  @override
  String get recentConnections => '最近連線記錄';

  @override
  String get rememberPwdInMem => '在記憶體中記住密碼';

  @override
  String get rememberPwdInMemTip => '用於容器、暫停等';

  @override
  String get remotePath => '遠端路徑';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '已安裝 $distro $installed，現有 $latest。更新會重新下載並替換整個容器：$pm 資料會遺失';
  }

  @override
  String linuxSystemInUse(String name) {
    return '請先關閉 $name 上的終端，再刪除';
  }

  @override
  String get rootfsSubtitle => '本機上的 Linux 使用者空間';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return '下載 $distro $version（約 $size MB）並解壓到本機。';
  }

  @override
  String get sameIdServerExist => '已存在相同 ID 的伺服器';

  @override
  String get second => '秒';

  @override
  String get serverFilesUnavailableTip =>
      '需要能連上這台伺服器的 SSH，或者安裝 server_box_monitor 並開啟檔案 API。';

  @override
  String get back => '返回';

  @override
  String get history => '歷史';

  @override
  String get homeDir => '主目錄';

  @override
  String selected(int count) {
    return '已選 $count 項';
  }

  @override
  String get sendTo => '傳送到…';

  @override
  String get serverFuncBtns => '伺服器功能按鈕';

  @override
  String get serverOrder => '伺服器順序';

  @override
  String get serverOverview => '伺服器總覽';

  @override
  String get serverOverviewTip => '在伺服器列表頂部顯示總覽，並在開啟的伺服器上方顯示伺服器切換列';

  @override
  String get serverTabEmpty => '還沒有伺服器';

  @override
  String get serverTabRequired => '服務器標籤不能被移除';

  @override
  String get shareCodeHint => '請將這組數字另行告知接收方；驗證碼不包含在 QR Code 中。';

  @override
  String get shareCodePrompt => '6 位驗證碼';

  @override
  String get shareCodeTitle => '一次性驗證碼';

  @override
  String get shareExpired => '此分享已過期，請讓分享方重新產生。';

  @override
  String get shareImportFile => '從分享檔案匯入';

  @override
  String get shareImportTitle => '匯入共享伺服器';

  @override
  String get shareIncludesKey => '分享內容包含私鑰。';

  @override
  String get shareOmittedBmc => 'BMC 憑證（僅包含位址，不包含帳號和密碼）。';

  @override
  String get shareOmittedJump => '跳板伺服器（它在本機儲存為另一台伺服器）。';

  @override
  String get shareOmittedKeyPath => '金鑰檔案（該路徑僅在本機有效）。';

  @override
  String get shareOmittedMissingKey => '私鑰（本機金鑰庫中沒有該金鑰）。';

  @override
  String get shareOmittedTip => '以下內容未包含，接收方需自行設定：';

  @override
  String get sharePassphraseTip => '此密碼用於加密檔案。接收方匯入伺服器時需要輸入，且無法找回。';

  @override
  String shareQrTip(int minutes) {
    return 'QR Code 中的連線資訊已加密，此分享將在 $minutes 分鐘後過期。';
  }

  @override
  String get shareScanQr => '掃描 QR Code';

  @override
  String shareServerExists(String name) {
    return '本機伺服器「$name」已使用此位址。仍要匯入嗎？';
  }

  @override
  String get shareTooBigForQr => '內容過大，無法產生 QR Code，請改用檔案分享。';

  @override
  String get shareTooNew => '此分享由較新版本的 ServerBox 建立，請更新 App 後再開啟。';

  @override
  String get shareUnreadable => '這不是有效的 ServerBox 分享內容。';

  @override
  String get shareVia => '分享方式';

  @override
  String get sftpDlPrepare => '準備連線至伺服器...';

  @override
  String get sftpEditorTip =>
      '如果為空，使用 App 內建的檔案編輯器。 例如 `vim`（建議根據 `EDITOR` 自動取得）。';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 來刪除檔案夾';

  @override
  String get sftpSSHConnected => 'SFTP 已連線';

  @override
  String get sftpShowFoldersFirst => '資料夾顯示在前';

  @override
  String get sftpUnavailableUseScp =>
      '如果這台裝置沒有 SFTP 子系統（不少嵌入式裝置如此），請在伺服器設定裡把檔案傳輸改為 SCP。';

  @override
  String get sshFileTransportTip =>
      '一般裝置用 SFTP。老舊或嵌入式裝置的 SSH 服務沒有 SFTP 子系統，請選 SCP：它只需要 scp 指令，以及帶有 find、stat、mv、chmod 等常用檔案指令的 shell 環境。';

  @override
  String get specifyDev => '指定裝置';

  @override
  String get specifyDevTip => '網路流量預設統計所有裝置，可以在這裡指定特定裝置';

  @override
  String get tempIsCelsiusTip =>
      '啟用後，溫度值會以攝氏度而非毫攝氏度處理。僅在溫度顯示錯誤時開啟（例如顯示 0.1°C 而非 58°C）。';

  @override
  String spentTime(String time) {
    return '耗時：$time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return '所有伺服器均已存在（發現$duplicateCount個重複項）';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '將跳過$duplicateCount個重複項';
  }

  @override
  String get sshConfigFound => '我們在您的系統中發現了SSH設定';

  @override
  String sshConfigFoundServers(int totalCount) {
    return '發現$totalCount個伺服器';
  }

  @override
  String get sshConfigImport => '匯入SSH設定';

  @override
  String get sshConfigImportPermission => '您是否希望允許讀取 ~/.ssh/config 並自動匯入伺服器設定？';

  @override
  String get sshConfigImportTip => '在建立第一個伺服器時提示讀取 ~/.ssh/config';

  @override
  String sshConfigImported(int count) {
    return '已從SSH設定匯入$count個伺服器';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return '伺服器 $serverName 的 SSH 主機金鑰已變更，僅在信任該伺服器時繼續。';
  }

  @override
  String get sshHostKeyType => 'SSH 主機金鑰類型';

  @override
  String get sshKnownHostKeys => '已信任的主機';

  @override
  String get sshKnownHostKeysTip => '本 app 已接受的主機金鑰';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return '收到來自 $serverName 的新 SSH 主機金鑰，信任前請先檢查指紋。';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return '已儲存的指紋：$fingerprint';
  }

  @override
  String get sshVerificationCode => '驗證碼';

  @override
  String get sshConfigManualSelect => '是否要手動選擇 SSH 設定檔案？';

  @override
  String get sshConfigNoServers => 'SSH設定中未找到伺服器';

  @override
  String get sshConfigPermissionDenied => '由於 macOS 權限限制，無法存取 SSH 設定檔案。';

  @override
  String sshConfigServersToImport(int importCount) {
    return '將匯入$importCount個伺服器';
  }

  @override
  String get sshTermHelp =>
      '在終端機可捲動時，橫向拖動可以選中文字。點擊鍵盤按鈕可以開啟/關閉鍵盤。檔案圖示會打開目前路徑 SFTP。剪貼簿按鈕會在有選中文字時複製內容，在未選中並且剪貼簿有內容時貼上內容到終端機。程式碼圖示會貼上程式碼片段到終端機並執行。';

  @override
  String get sshVirtualKeyAutoOff => '虛擬按鍵自動切換';

  @override
  String get supportFmtArgs => '支援以下格式化參數：';

  @override
  String get suspendTip => 'suspend 功能需要 root 權限及 systemd 支援。';

  @override
  String switchTo(String val) {
    return '切換到 $val';
  }

  @override
  String get syncAppSettings => '同步 App 設定';

  @override
  String get syncAppSettingsTip => '將主題、版面配置、編輯器、終端等裝置偏好一併納入自動同步。';

  @override
  String get termFontSizeTip => '此設定將影響終端機大小（寬度和高度）。您可以在終端機頁面縮放，來調整目前會話的字型大小。';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），僅作用於伺服器頁面部分字型，不建議修改。';

  @override
  String get times => '次';

  @override
  String get trySudo => '嘗試使用 sudo';

  @override
  String get sudoPromptNotFound => '目前沒有 sudo 密碼提示。';

  @override
  String get updateServerStatusInterval => '伺服器狀態更新間隔';

  @override
  String get useNoPwd => '將使用無密碼';

  @override
  String get usePodmanByDefault => '預設使用 Podman';

  @override
  String get used => '已使用';

  @override
  String get viewDetails => '檢視詳情';

  @override
  String get virtKeyHelpIME => '打開/關閉鍵盤';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打開目前路徑。';

  @override
  String get virtKeyHelpSnippet => '選擇一個程式碼片段並在目前終端機執行。';

  @override
  String get virtKeyHelpTmux => '在 tmux 的 session 和 window 之間切換。';

  @override
  String get virtKeyIntroActions => '快捷操作';

  @override
  String get virtKeyIntroActionsTip => '這些鍵不輸入字元，而是開啟對應功能。長按可檢視說明。';

  @override
  String get virtKeyIntroCustomizeTip =>
      '在終端機設定裡可以調整順序、開啟更多鍵（檔案、sudo、F1–F12 等），或隱藏用不到的鍵。';

  @override
  String get virtKeyIntroModifiers => '修飾鍵';

  @override
  String get virtKeyIntroModifiersTip => '點一下開啟，再按鍵盤上的字母。開啟狀態只作用於下一個鍵。';

  @override
  String get virtKeyIntroNav => '游標移動';

  @override
  String get virtKeyIntroNavTip => '這些鍵移動游標。長按方向鍵可連續觸發。';

  @override
  String get virtKeyIntroSelect => '終端機有內容可捲動時，橫向拖曳即可選取文字。';

  @override
  String get virtKeyRows => '同時顯示的列數';

  @override
  String get virtKeyRowsTip => '其餘的放在單獨一頁，橫向滑動切換。';

  @override
  String get waitConnection => '請等待連線建立';

  @override
  String get wakeLock => '保持喚醒';

  @override
  String get watchNotPaired => '沒有已配對的 Apple Watch';

  @override
  String get webdavSettingEmpty => 'WebDav 設定項爲空';

  @override
  String get whenOpenApp => '當打開 App 時';

  @override
  String get wolTip => '設定 WOL 後，每次連線伺服器時將自動發送喚醒請求';

  @override
  String get write => '寫入';

  @override
  String get writeScriptFailTip => '寫入腳本失敗，可能是沒有權限/目錄不存在等。';

  @override
  String get writeScriptTip =>
      '連線到伺服器後，將會在 `~/.config/server_box` \n | `/tmp/server_box` 中寫入一個腳本來監測系統狀態。你可以審查腳本內容。';

  @override
  String get menuGitHubRepository => 'GitHub 儲存庫';

  @override
  String get podmanDockerEmulationDetected =>
      '檢測到 Podman Docker 仿真。請在設定中切換到 Podman。';

  @override
  String get betaTip => '此功能仍在 Beta 測試階段，不保證可正常運作。';

  @override
  String get portForward_startPrompt => '新增一條連接埠轉發規則以開始';

  @override
  String get portForward_localHost => '本機主機';

  @override
  String get portForward_localPort => '本機連接埠';

  @override
  String get portForward_remoteHost => '遠端主機';

  @override
  String get portForward_remotePort => '遠端連接埠';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return '刪除 $name？';
  }

  @override
  String get sponsor => '贊助';

  @override
  String get sortByJoinTime => '依加入時間';

  @override
  String get tmuxAutoAttach => 'tmux 自動附加';

  @override
  String get tmuxAuto => '自動使用 tmux';

  @override
  String get tmuxAutoTip => '透過 SSH 連線時自動啟動或附加 tmux';

  @override
  String get tmuxSessionSelector => '工作階段選擇器';

  @override
  String get tmuxSessionSelectorTip => '連線時顯示工作階段選擇器';

  @override
  String get tmuxDefaultSessionName => '預設工作階段名稱';

  @override
  String get tmuxSessionName => '工作階段名稱';

  @override
  String get tmuxNewSession => '新增工作階段';

  @override
  String get tmuxNewWindow => '新增視窗';

  @override
  String get tmuxNoWindowsFound => '找不到視窗';

  @override
  String tmuxWindowCount(int count) {
    return '$count 個視窗';
  }

  @override
  String get tmuxAttached => '已附加';

  @override
  String get tmuxSkip => '略過';

  @override
  String get tmuxNotAvailable => 'tmux 無法使用';

  @override
  String containerSegmentsMismatch(int count) {
    return '容器回應分段數量異常：$count';
  }

  @override
  String get containerOperationInProgress => '另一個容器操作正在進行中';

  @override
  String processCount(int count) {
    return '$count 個處理程序';
  }

  @override
  String get processParseUnsupportedOutput => '不支援此處理程序清單格式。';

  @override
  String get processParseInvalidRows => '部分處理程序項目無法讀取。';

  @override
  String get processParseInvalidWindowsJson => '無法讀取 Windows 處理程序回應。';

  @override
  String get processParseInvalidWindowsRows => '部分 Windows 處理程序項目無法讀取。';

  @override
  String get processKillTargetChanged => '該處理程序已變更或結束，請重新整理後再試。';

  @override
  String get processSearchHint => '名稱、使用者或 PID';

  @override
  String processShowKernelThreads(int count) {
    return '顯示 $count 個核心執行緒';
  }

  @override
  String get processForceKill => '強制終止';

  @override
  String get processStarted => '啟動時間';

  @override
  String get processThreads => '執行緒';

  @override
  String get watchServers => '手錶上的伺服器';

  @override
  String get watchServersTip => '手錶獨立向 monitor 取資料，所以只能選擇已設定 monitor 的伺服器。';

  @override
  String get watchNoMonitorServer => '沒有伺服器設定了 monitor';

  @override
  String get legacyStatusGoneTitle => '狀態連結已失效';

  @override
  String get legacyStatusGoneBody =>
      '手錶 App 與桌面小工具先前讀取的是手動填寫的 `/status` 位址。該端點已移除：它只能以文字回傳目前數值，這也是它們始終無法顯示曲線的原因。\n\n現在它們讀取 Monitor 的驗證 API，可以繪製曲線，並自動與 App 保持同步。在 App 內設定一次伺服器，所有手錶與小工具都會自動取得。';

  @override
  String get services => '服務';

  @override
  String get status => '狀態';

  @override
  String get enable => '啟用';

  @override
  String get disable => '停用';

  @override
  String get starting => '啟動中';

  @override
  String get stopping => '停止中';

  @override
  String get serviceManagerUnsupported => '不支援的服務管理器';

  @override
  String get serviceManagerUnsupportedTip =>
      '此伺服器使用的服務管理器尚未受 ServerBox 支援。目前支援 systemd、procd 和 OpenRC。';

  @override
  String serviceManagerFmt(String manager) {
    return '由 $manager 管理';
  }

  @override
  String get serviceListFailed => '無法列出服務';

  @override
  String get serviceDetailsUnavailable => '部分服務詳細資料無法使用';

  @override
  String get serviceDetailsUnavailableTip => '服務列表仍可使用，但服務管理器未傳回完整的狀態或開機啟動資訊。';

  @override
  String get systemdUserScopeMissing => '未列出使用者 unit';

  @override
  String get systemdUserScopeMissingTip => '該帳號在伺服器上沒有使用者工作階段匯流排，因此只顯示系統 unit。';

  @override
  String get serviceSearchHint => 'Unit 名稱';

  @override
  String get serviceNeedsAttention => '需要注意';

  @override
  String serviceOtherUnits(int count) {
    return '其他 $count 個 unit';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => '類型';

  @override
  String get serviceScope => '範圍';

  @override
  String get serviceStartup => '啟動方式';

  @override
  String serviceUpFor(String duration) {
    return '已執行 $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return '已停止 $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return '$duration 後執行';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return '已於 $duration 前停止';
  }

  @override
  String serviceExitStatus(int code) {
    return '結束狀態 $code';
  }

  @override
  String get serviceFullJournal => '完整 journal';

  @override
  String get serviceUnitFile => 'Unit 檔案';

  @override
  String serviceJournalRecent(int count) {
    return '最近 $count 行';
  }

  @override
  String get serviceJournalUnreadable => '此帳號無法讀取 journal';

  @override
  String get serverUnreachable => '無法在此伺服器上執行命令';

  @override
  String get containerNoRuntime => '此處沒有容器執行環境';

  @override
  String get containerNoRuntimeTip =>
      '這台機器上 `docker` 和 `podman` 都沒有回應。如果它裝在另一個帳號下，請在設定中開啟「嘗試使用 sudo」。';

  @override
  String get containerUnreadable => '容器執行環境回傳了無法解析的內容';

  @override
  String get power => '電源';

  @override
  String get fan => '風扇';

  @override
  String get clockSpeed => '頻率';

  @override
  String get vendor => '廠商';

  @override
  String get continueInTerminal => '在終端機中繼續';

  @override
  String get askAiRiskUnknown => '未判定';

  @override
  String get agentLocalExec => '在本機執行命令';

  @override
  String get agentLocalExecTip => '允許 Agent 在執行 ServerBox 的這台機器上工作。唯讀的命令也需要審核';

  @override
  String get agentLocalExecRootfsTip =>
      '讓 Agent 在本機執行，但只能操作 ServerBox 安裝的 Linux 容器。';

  @override
  String macDmgImportedPartly(String path) {
    return '已匯入先前安裝版本的資料。下載的檔案仍保留在 $path。';
  }

  @override
  String get bmcAccount => '帳戶';

  @override
  String get bmcAccountUnset => '未選擇 — 點擊選擇或新增';

  @override
  String bmcAccountShared(int count) {
    return '$count 台伺服器在用';
  }

  @override
  String get bmcAccounts => 'BMC 帳戶';

  @override
  String get bmcAccountSharedTip => '在這裡修改會改變所有這些伺服器使用的帳戶。';

  @override
  String bmcAccountInUse(int count) {
    return '$count 台伺服器在用。它們會保留位址，但失去帳戶。';
  }

  @override
  String get bmcStaleWrite => 'BMC 上的內容在寫入期間被改動過，請重試。';

  @override
  String get privacyBlur => '背景隱私保護';

  @override
  String get privacyBlurTip => '在多工介面隱藏應用內容';

  @override
  String get floatReturnToTab => '放回分頁';

  @override
  String get termInFloatWindow => '此終端正在懸浮視窗中';

  @override
  String get globeEnabledTip =>
      '根據伺服器位址的地理位置，在地球儀上顯示伺服器。關閉後，伺服器頁面會隱藏該按鈕，並停止所有地理位置查詢。';

  @override
  String get geoShardsConsentAttribution =>
      'IP 地理位置資料由 [DB-IP](https://db-ip.com) 提供，採用 CC BY 4.0 授權。';

  @override
  String get geoMissPrivate => '非公網位址';

  @override
  String get geoMissNoData => '無可用位置資料';

  @override
  String get globeGuide => '點這裡，在地球儀上檢視伺服器及其位址對應的位置。';

  @override
  String get publicIp => '公網 IP';

  @override
  String get geoData => '城市級資料';

  @override
  String get geoDataTip => '下載後，所有地理位置查詢都使用儲存在本機的資料，不會向下載服務傳送伺服器位址或查詢活動。';

  @override
  String get geoDataMissing => '未下載';

  @override
  String get geoDataUnreachable => '無法取得資料。';

  @override
  String get geoDataRemoveFailed => '無法刪除資料。';

  @override
  String geoDataCurrent(String month) {
    return '已經是 $month 的資料。';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**下載大小：$download · 本機空間：$disk。** 完整資料集儲存在本機，後續所有地理位置查詢都在本機完成，不會向下載服務傳送伺服器位址或查詢活動。\n\n資料每月更新。新版本會取代已安裝的資料，不保留額外副本；你可以隨時刪除。';
  }

  @override
  String get benchmark => '效能測試';

  @override
  String get benchmarkIntro =>
      '在此伺服器上執行 Yet Another Bench Script，測試磁碟、網路與 CPU。完整執行一次需要 10–20 分鐘，離開此頁面或關閉 App 都不會中斷。';

  @override
  String get benchmarkNoRuns => '尚無效能測試記錄。';

  @override
  String get benchmarkRunning => '正在進行效能測試';

  @override
  String get benchmarkStartFailed => '無法啟動效能測試';

  @override
  String get benchmarkCancelConfirm => '要停止這次測試嗎？目前已測得的結果將會遺失。';

  @override
  String get benchmarkDeleteConfirm => '要刪除這筆測試結果嗎？';

  @override
  String get benchmarkNothingSelected => '所有測試項目都已關閉，本次只會收集系統資訊，幾秒內即可完成。';

  @override
  String get benchmarkDiskTip =>
      '以四種區塊大小執行 fio，約需 3 分鐘。會在工作目錄寫入 2 GB 測試檔案，因此需要同等的可用空間。';

  @override
  String get benchmarkNetworkTip => '透過 iperf3 對公用伺服器進行測試，約需 4 分鐘。';

  @override
  String get benchmarkReducedNetwork => '減少測試節點';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return '使用 3 個節點而非 7 個，預估流量會從 $full 降至 $reduced。';
  }

  @override
  String get benchmarkCpuTip =>
      '下載並執行專有軟體 Geekbench，且**會將結果公開發佈至 geekbench.com 的公開頁面**，其中包含 CPU 型號、核心數與記憶體資訊。';

  @override
  String get benchmarkSensitiveOptions =>
      '以下選項會在此伺服器下載並執行第三方軟體，或將伺服器資訊傳送給第三方，預設關閉。';

  @override
  String get benchmarkIpInfoTip => '透過未加密的 HTTP，將此伺服器的公用 IP 位址傳送至 ip-api.com。';

  @override
  String get benchmarkIpInfo => '查詢 IP 所有者';

  @override
  String get benchmarkPreferBin => '下載 fio 與 iperf3';

  @override
  String get benchmarkPreferBinTip => '從 GitHub 下載，而不使用主機的套件。僅在主機未安裝這兩個程式時啟用。';

  @override
  String get benchmarkWorkDir => '工作目錄';

  @override
  String get benchmarkWorkDirTip => '決定磁碟測試要測量哪個檔案系統。留空表示使用登入帳號的家目錄。';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return '約 $minutes 分鐘';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return '約 $size 流量';
  }

  @override
  String get benchmarkPhaseSystem => '正在讀取系統資訊';

  @override
  String get benchmarkPhaseDisk => '正在測試磁碟';

  @override
  String get benchmarkPhaseNetwork => '正在測試網路';

  @override
  String get benchmarkPhaseCpu => '正在測試 CPU';

  @override
  String get benchmarkPhaseDone => '正在完成';

  @override
  String get benchmarkResultUnreadable => '無法將此結果解析為 JSON，原始文字如下。';

  @override
  String get benchmarkViewOnGeekbench => '在 Geekbench 上檢視';

  @override
  String get benchmarkGeekbenchPublic => '此結果已透過上述連結公開發佈。';

  @override
  String get benchmarkSingleCore => '單核心';

  @override
  String get benchmarkMultiCore => '多核心';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => '上傳';

  @override
  String get benchmarkRecv => '下載';

  @override
  String get benchmarkLatency => '延遲';

  @override
  String get benchmarkVirt => '虛擬化';

  @override
  String get benchmarkRawLog => '執行記錄';

  @override
  String benchmarkUpstream(String version) {
    return '由 Yet Another Bench Script ($version) 提供';
  }

  @override
  String get benchmarkPhaseStarting => '正在啟動';

  @override
  String get benchmarkNoOutputYet =>
      '暫時沒有輸出。YABS 在輸出第一行前會先檢查能否連線至 google.com 和 icanhazip.com；如果網路封鎖其中任一網站，可能需要等待數分鐘。';

  @override
  String get tagsEmptyTip => '尚無標籤。編輯伺服器時新增標籤，就會顯示在這裡。';

  @override
  String get benchmarkNoServers => '請先新增伺服器，再返回執行效能測試。';

  @override
  String get schemaTooNewTitle => '這些資料比目前 App 新';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return '這些資料由較新版本的 ServerBox 寫入（儲存版本 v$stored）。目前版本最高支援 v$supported，資料未被更動。';
  }

  @override
  String get schemaTooNewReinstall => '請重新安裝較新版本，即可再次開啟所有資料。';

  @override
  String get schemaTooNewExportPlain => '匯出無密碼副本';

  @override
  String get schemaTooNewPlainWarn =>
      '檔案將以明文包含所有 SSH 私鑰、伺服器密碼與 API key。任何取得檔案的人都能存取這些內容。';

  @override
  String get schemaTooNewWipe => '刪除所有資料';

  @override
  String get schemaTooNewWipeConfirm =>
      '本裝置上的所有伺服器、金鑰、程式碼片段與設定都將被刪除，且無法復原。先前匯出的備份將成為僅存的副本。';

  @override
  String get schemaTooNewWipeDone => '資料已刪除。請重新開啟 App，從頭開始。';

  @override
  String get schemaTooNewWipeFailed =>
      '部分資料未能刪除，目前版本仍然無法開啟剩下的內容。請重新安裝更新的版本來讀取它。';

  @override
  String get systemUsers => '使用者';

  @override
  String get userManagerLinuxOnly => '系統使用者管理目前僅支援 Linux 伺服器。';

  @override
  String get userRegularAccount => '一般使用者';

  @override
  String get userCurrentAccount => '目前帳戶';

  @override
  String get userSystemAccount => '系統帳戶';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => '登入狀態';

  @override
  String get userLoginEnabled => '已允許登入';

  @override
  String get userDetailAccount => '帳號';

  @override
  String get userDetailSecurity => '安全性';

  @override
  String get userSshKeys => 'SSH 金鑰';

  @override
  String get userExpires => '到期日';

  @override
  String get userNever => '永不';

  @override
  String get userPasswordSet => '已設定';

  @override
  String get userPasswordLocked => '已鎖定';

  @override
  String get userPasswordNone => '無';

  @override
  String get userSuperuser => '超級使用者';

  @override
  String get userOpenShell => '開啟 shell';

  @override
  String get userRootChangesWarning => '對 root 的修改會立即套用到所有工作階段。';

  @override
  String get userComment => '備註';

  @override
  String get userPrimaryGroup => '主要群組';

  @override
  String get userSupplementaryGroups => '附加群組';

  @override
  String get userLoginShell => '登入 Shell';

  @override
  String get userCreateHome => '建立家目錄';

  @override
  String get userMoveHome => '路徑變更時移動現有家目錄';

  @override
  String get userRemoveHome => '刪除家目錄';

  @override
  String get userPasswordCreateTip => '密碼留空將建立一個無法使用密碼登入的帳戶。';

  @override
  String get userPasswordEditTip => '密碼留空將保留現有密碼。';

  @override
  String funcUnavailableFmt(String func) {
    return '此伺服器的連線方式不提供$func。';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return '$func需要在 Monitor agent 中開啟 $setting。';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return '$func需要更新 Monitor agent。';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      '透過 Monitor agent 進行遠端轉發需要較新版本的 agent，請在伺服器上更新。';

  @override
  String get rangeLive => '即時';

  @override
  String get diskIo => '磁碟讀寫';

  @override
  String get peak => '峰值';

  @override
  String get hardware => '硬體';

  @override
  String get cores => '核心';

  @override
  String get historyNoStored => '只有 monitor agent 會儲存歷史。此連線只保留本應用連線後看到的部分。';

  @override
  String get noHistoryYet => '還沒有取樣';

  @override
  String get noData => '無資料';

  @override
  String get from => '起';

  @override
  String get to => '迄';

  @override
  String get beyondRetention => '超出這個 agent 保留的範圍';

  @override
  String agentRetentionFmt(String kept) {
    return 'agent 保留 $kept';
  }

  @override
  String get agentServerTools => '伺服器工具';

  @override
  String get agentServerToolsTip =>
      '在伺服器上執行指令、讀寫檔案，透過 SSH 連線其他主機，並使用 ServerBox 本身的操作。';

  @override
  String get agentTerminalTools => '終端';

  @override
  String get agentTerminalToolsTip => '在終端自己的對話中：讀取終端顯示的內容，並在其伺服器上執行指令。';

  @override
  String get agentToolTerminalScreen => '讀取螢幕';

  @override
  String get agentProviders => '提供者';

  @override
  String get agentProvidersTip => 'API Key、模型，以及新對話使用的模型';

  @override
  String get agentTools => '工具';

  @override
  String get agentToolsTip => 'Agent 可以使用的工具，以及 MCP 伺服器';

  @override
  String get agentSnippetToolsTip => '列出、新增、修改和刪除 snippet；修改前會詢問。';

  @override
  String get agentVirtToolsTip => '讀取虛擬化分頁已載入的虛擬機和容器。';

  @override
  String get agentBenchmarkToolsTip => '讀取效能測試結果；經你核准後執行或停止測試。';

  @override
  String get agentRemoteDesktopToolsTip => '列出遠端桌面設定；經你核准後連線或中斷。';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip => '特定任務的操作說明，可從 GitHub 或連結安裝';

  @override
  String get agentPermissions => '權限';

  @override
  String get agentEmptyHint => '詢問你的伺服器，或讓 Agent 在伺服器上完成某項操作。';

  @override
  String get agentTerminalEmptyHint => '詢問這台伺服器。Agent 可以讀取目前的終端，並在這裡執行指令。';

  @override
  String oldestSampleFmt(String time) {
    return '最早的取樣在 $time';
  }

  @override
  String get rangeEndsBeforeItStarts => '區間的結束必須晚於開始。';

  @override
  String get samples => '取樣';

  @override
  String get unavailable => '無法取得';

  @override
  String get metricUnavailableTip => '頁面其餘部分不受影響。到主機上檢查這項讀數所用的命令。';

  @override
  String get waitingFirstSample => '等待第一次取樣';

  @override
  String atTimeFmt(String time) {
    return '$time 時';
  }

  @override
  String get stored => '已儲存';

  @override
  String lastSampleFmt(String ago) {
    return '最近取樣於$ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return '以下全部是 $time 的資料，$ago。';
  }

  @override
  String noDataBeforeFmt(String time) {
    return '$time 之前沒有資料';
  }

  @override
  String loadingRangeFmt(String range) {
    return '正在載入 $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return '沒有 $metric 的儲存歷史';
  }

  @override
  String devicesFmt(int count) {
    return '$count 個裝置';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count 個裝置 · 最忙 $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$total 個裝置中的 $plotted 個';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count 個感測器 · 最熱 $name';
  }

  @override
  String get oneDeviceAtLeast => '圖表至少保留一個裝置。';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$total 個$what中的 $shown 個';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count 個$what';
  }

  @override
  String get unitDevices => '裝置';

  @override
  String get unitSensors => '感測器';

  @override
  String get unitBatteries => '電池';

  @override
  String get unitCommands => '命令';

  @override
  String get unitReadings => '讀數';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => '最熱';

  @override
  String get oldest => '最久';

  @override
  String get notApplicable => '不適用';

  @override
  String get attributes => '屬性';

  @override
  String get powerOnHours => '通電時間';

  @override
  String get powerCycles => '通電次數';

  @override
  String get lifeLeft => '剩餘壽命';

  @override
  String get lifetimeWrite => '累計寫入';

  @override
  String get lifetimeRead => '累計讀取';

  @override
  String get averageErase => '平均抹除次數';

  @override
  String get unsafeShutdowns => '異常斷電次數';

  @override
  String get diskAllPassed => '全部 PASSED';

  @override
  String diskWarningFmt(int count) {
    return '$count 個警告';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$total 個裝置中的 $wrong 個';
  }

  @override
  String get diskSmartSortedTip => '最差的排在最前';

  @override
  String readAgoFmt(String ago) {
    return '$ago讀取';
  }

  @override
  String processesFmt(int count) {
    return '$count 個處理程序';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count 個異常';
  }

  @override
  String get diskSmartOpenTip => '點按查看該磁碟的屬性';

  @override
  String get cycle => '循環次數';

  @override
  String get window => '視窗';

  @override
  String ofFmt(String total) {
    return '共 $total';
  }

  @override
  String get serverDetailCards => '詳情頁卡片';

  @override
  String get connection => '連線方式';

  @override
  String get connectionTip => '兩個可以同時開啟。順序就是撥接的順序。';

  @override
  String get transportNoneOn => '兩個都關閉了 —— 這台伺服器無法連線。';

  @override
  String get thisDevice => '本機';

  @override
  String get localServerTip =>
      '直接在本機執行狀態腳本讀取本機資訊，不使用 SSH 和 Monitor HTTP，兩者的設定會保留。';

  @override
  String get localServerUnsupported =>
      '目前平台無法將本機作為伺服器讀取。Linux、Windows 和 macOS DMG 版本支援。';

  @override
  String get remoteDesktopIntro =>
      '在應用程式內開啟伺服器的 RDP 或 VNC 桌面。連線經由伺服器的 SSH 連線或其 Monitor agent 轉送，桌面連接埠無需對網路開放。';

  @override
  String get remoteDesktopIntroProfiles =>
      '在伺服器的「遠端桌面」按鈕或「遠端桌面」分頁中，為每個桌面儲存一個設定檔。';

  @override
  String get localServerIntro =>
      '將執行 ServerBox 的裝置新增為伺服器。狀態、程序、服務、容器、終端機和檔案都無需 SSH 或 Monitor agent。';

  @override
  String get localServerAdd => '新增本機';

  @override
  String get localServerIntroFooter => '之後也可以在伺服器編輯頁的「連線方式」中開啟。';

  @override
  String get transportSectionOff => '已關閉。下面的欄位會保留，供你再次開啟時使用。';

  @override
  String get monitorAgent => 'Monitor 代理';

  @override
  String get plainHttpEditTip =>
      '憑證和指標會以明文穿過網路。請限制在區域網路或 Tailscale 位址內，或者把代理放到 TLS 後面。';

  @override
  String get behaviour => '行為';

  @override
  String get optional => '選用';

  @override
  String get sshAdvanced => 'SSH 進階';

  @override
  String get sshAdvancedTip => '備用位址、ProxyCommand、跳板機、檔案傳輸、遠端路徑';

  @override
  String get sshLegacyAlgorithms => '舊版演算法相容模式';

  @override
  String get sshLegacyAlgorithmsTip =>
      '適用於只提供 SHA-1 `ssh-rsa` 主機金鑰或 SHA-1 金鑰交換的舊式 SSH 伺服器，例如路由器或交換器。此模式安全性較低，只在裝置確實需要時開啟。';

  @override
  String get appearanceAndPlace => '外觀與位置';

  @override
  String get appearanceAndPlaceTip => 'Logo、座標';

  @override
  String get statusCollection => '狀態收集';

  @override
  String get statusCollectionTip => '執行哪些命令、自訂命令、讀取哪個裝置';

  @override
  String get tagAllTags => '全部標籤';

  @override
  String get tagMatching => '符合';

  @override
  String get tagNewHint => '新標籤';

  @override
  String tagCreateFmt(String tag) {
    return '新增 #$tag';
  }

  @override
  String get tagOnThisServer => '在這台上';

  @override
  String tagServersFmt(int count) {
    return '$count 台伺服器';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '這台上有 $count 個';
  }

  @override
  String get tagMatchesTyped => '與輸入相符';

  @override
  String get tagEditorTip =>
      '輸入會過濾清單；按鈕會新增標籤並直接加到這台伺服器上。鉛筆是重新命名，會改掉所有用到它的伺服器。沒有伺服器再使用的標籤會在儲存時消失。';

  @override
  String get tagRenamesOnSave => '重新命名在儲存時生效';

  @override
  String get scheduledTasks => '排程工作';

  @override
  String get scheduledTaskLinuxOnly => '排程工作管理目前僅支援 Linux 伺服器。';

  @override
  String get scheduledTaskUnavailable => '此伺服器上沒有可用的 crontab。';

  @override
  String get scheduledTaskPreserveTip => '儲存時會保留此 crontab 中的註解、環境變數及無法識別的行。';

  @override
  String get scheduledTaskSchedule => '執行週期';

  @override
  String get scheduledTaskAdd => '新增工作';

  @override
  String get scheduledTaskNextRun => '下次執行';

  @override
  String scheduledTaskNextInFmt(String time) {
    return '$time 後';
  }

  @override
  String get scheduledTaskEnabled => '已啟用';

  @override
  String get scheduledTaskCommentedOut => '已註解';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    return '$total 個工作 · 已啟用 $enabled 個';
  }

  @override
  String get scheduledTaskFilterHint => '篩選工作';

  @override
  String get scheduledTaskPreserved => '保留的行';

  @override
  String get scheduledTaskRaw => '原始 crontab';

  @override
  String get scheduledTaskEnableNow => '立即啟用';

  @override
  String get scheduledTaskEnableNowTip => '關閉後，這一行會以註解寫入。';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return '$user 沒有排程工作。在此新增的內容會寫入該帳號的 crontab。';
  }

  @override
  String get scheduledTaskFieldMinute => '分鐘';

  @override
  String get scheduledTaskFieldHour => '小時';

  @override
  String get scheduledTaskFieldDayOfMonth => '每月的日期';

  @override
  String get scheduledTaskFieldMonth => '月份';

  @override
  String get scheduledTaskFieldDayOfWeek => '星期';

  @override
  String get cronErrScheduleEmpty => '請設定執行週期。';

  @override
  String get cronErrCommandEmpty => '請輸入指令。';

  @override
  String get cronErrLineBreak => 'crontab 的一行不能包含換行字元。';

  @override
  String get cronErrMacro => 'macro 必須是單一字詞，例如 @reboot。';

  @override
  String get cronErrFieldCount => 'cron 排程必須包含五個欄位，或使用 @reboot 之類的 macro。';

  @override
  String get cronAtBoot => '開機時';

  @override
  String get cronEveryMin => '每分鐘';

  @override
  String cronEveryMinsFmt(int minutes) {
    return '每 $minutes 分鐘';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return '每小時的 :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return '每 $hours 小時';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return '每 $hours 小時的 :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return '每天 $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return '週一至週五 $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return '每週$day $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return '每月 $day 日的 $time';
  }

  @override
  String get monitorSettings => 'Monitor 設定';

  @override
  String get monitorAgentDefault => 'agent 預設值';

  @override
  String get monitorNeedsRestart => 'agent 重啟後生效';

  @override
  String get monitorCollection => '採集';

  @override
  String get extendedInterval => '延伸採集週期';

  @override
  String get idlePause => '無人檢視時暫停';

  @override
  String get idlePauseTip =>
      '延伸採集會呼叫 smartctl、sensors 與 amd-smi。沒有用戶端輪詢時暫停，可以避免為無人檢視的資料喚醒硬碟。';

  @override
  String get idlePauseThreshold => '閒置判定時長';

  @override
  String get monitorAlerts => '告警';

  @override
  String get monitoringRules => '告警規則';

  @override
  String get ruleMonitorType => '指標';

  @override
  String get ruleThreshold => '閾值';

  @override
  String get ruleMatcher => '比對對象';

  @override
  String get ruleTip =>
      '指標：cpu / memory / swap / disk / network / temperature。比對對象：cpu0 指定單核，memory 用 used / free / avail，network 用 rx / tx；disk 與 temperature 會忽略此項。閾值：比較符加數值，例如 >=80%、>=70c 或 >10m/s。';

  @override
  String get pushChannels => '通知管道';

  @override
  String get pushType => '類型';

  @override
  String get pushRate => '發送頻率限制';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => '已在 agent 上設定，不顯示';

  @override
  String get pushSecretKeep => '留空則保持不變';

  @override
  String get pushTestTip => '依目前頁面上的設定發送一則通知，無論是否已儲存。';

  @override
  String get pushTestSent => '管道已接受';

  @override
  String get pushTestFailed => '管道拒絕了這則通知';

  @override
  String get pushTestMessage => '來自 ServerBox Monitor 的測試通知';

  @override
  String get pushUnknownType =>
      '此 agent 沒有該類型的發送實作，因此不顯示其設定。可以在這裡刪除，或在 agent 的 config.toml 中編輯。';

  @override
  String get pushJsonInvalid => '不是合法的 JSON';

  @override
  String get dataRetention => '資料保留';

  @override
  String get dataRetentionTip => '關閉表示 agent 不會刪除任何資料，其資料庫會無限成長。';

  @override
  String get retentionMetrics => '指標保留';

  @override
  String get retentionAlerts => '告警保留';

  @override
  String get retentionCleanup => '清理執行間隔';

  @override
  String get retentionMaxDbSize => '資料庫容量上限';

  @override
  String get corsOrigins => 'CORS 允許來源';

  @override
  String get corsOriginsTip => '允許瀏覽器面板從哪些來源呼叫此 agent。留空表示僅同源。';

  @override
  String get monitorNoRemoteAccess =>
      '此 agent 目前只能查看監控資料，不能開啟終端、執行命令或瀏覽檔案。若要開啟這些功能，請修改 agent 的 config.toml，在 [remote_access] 下開啟對應選項。';

  @override
  String get alerts => '警示';

  @override
  String get online => '線上';

  @override
  String get densityCards => '卡片';

  @override
  String get densityRows => '列';

  @override
  String get densityGrid => '網格';

  @override
  String get connect => '連線';

  @override
  String get disconnect => '中斷連線';

  @override
  String get searchServerTip => '搜尋名稱和位址——編輯頁最先詢問的兩項資料。';

  @override
  String get addServerTip => '填寫其中一項、掃描 QR code，或匯入他人分享的檔案。';

  @override
  String get move => '移動';

  @override
  String get moveToTop => '移到最前';

  @override
  String get moveToBottom => '移到最後';

  @override
  String get groupByTag => '依標籤分組';

  @override
  String get groupByTagTip => '標籤是在伺服器自己的編輯頁裡加的。';

  @override
  String get connecting => '連線中…';

  @override
  String get authShort => '認證';

  @override
  String get remoteDesktopFitToWindow => '符合視窗';

  @override
  String get remoteDesktopActualSize => '實際大小';

  @override
  String get remoteDesktopZoom => '縮放';

  @override
  String get remoteDesktopViewOnly => '僅供檢視';

  @override
  String get remoteDesktopDisableViewOnly => '停用僅供檢視';

  @override
  String get remoteDesktopSendClipboardText => '傳送剪貼簿文字';

  @override
  String get remoteDesktopShowKeyboard => '顯示鍵盤';

  @override
  String get remoteDesktopMoreControls => '更多控制項';

  @override
  String get remoteDesktopUseDirectPointer => '使用直接指標';

  @override
  String get remoteDesktopUseTouchpadPointer => '使用觸控板指標';

  @override
  String get remoteDesktopSendCtrlAltDelete => '傳送 Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => '重新連線';

  @override
  String get remoteDesktopFullScreen => '全螢幕';

  @override
  String get remoteDesktopExitFullScreen => '結束全螢幕';

  @override
  String get remoteDesktopCloseSession => '關閉工作階段';

  @override
  String get remoteDesktopConnected => '已連線';

  @override
  String get remoteDesktopConnecting => '正在連線';

  @override
  String get remoteDesktopReconnecting => '正在重新連線';

  @override
  String get remoteDesktopDisconnected => '已中斷連線';

  @override
  String get remoteDesktopGuideTouch => '觸控板';

  @override
  String get remoteDesktopGuideTouchTip =>
      '單指像觸控板一樣移動指標，輕點即單擊。雙指輕點為右鍵，雙指拖曳為捲動，雙指捏合為縮放。輕點兩下且第二下不放開，即可拖曳。';

  @override
  String get remoteDesktopGuideKeyboardTip => '開啟螢幕鍵盤，輸入的內容會傳送到遠端桌面。';

  @override
  String get remoteDesktopGuideViewOnlyTip => '停止傳送指標和按鍵，只檢視畫面，不會誤點。';

  @override
  String get remoteDesktopGuideMoreTip => 'Ctrl+Alt+Delete、重新連線和全螢幕都在這裡。';

  @override
  String get remoteDesktopGuidePointerTip => '這裡也可以切換為直接指標：手指點到哪裡就點擊哪裡。';

  @override
  String get remoteDesktopVncClipboardLatin1Only => 'VNC 剪貼簿僅支援 Latin-1 文字。';

  @override
  String get remoteDesktopAddProfile => '新增設定檔';

  @override
  String get remoteDesktopNoProfiles => '尚無遠端桌面設定檔';

  @override
  String get remoteDesktopAdd => '新增遠端桌面';

  @override
  String get remoteDesktopEdit => '編輯遠端桌面';

  @override
  String get remoteDesktopTargetTip =>
      '目標由 SSH 伺服器或 Monitor Agent 解析，localhost 指向該伺服器。';

  @override
  String get remoteDesktopDomain => '網域（選填）';

  @override
  String get remoteDesktopPassword => '密碼（選填）';

  @override
  String get remoteDesktopSavePassword => '儲存密碼';

  @override
  String get remoteDesktopSavePasswordTip =>
      '儲存於加密資料庫。備份會包含已儲存的密碼，只有在設定備份密碼時才會加密。';

  @override
  String get remoteDesktopShareSession => '共用工作階段';

  @override
  String get remoteDesktopProtocol => '通訊協定';

  @override
  String get remoteDesktopUniqueName => '此伺服器的設定檔名稱不可重複。';

  @override
  String get remoteDesktopVncPasswordLength => '傳統 VNC 密碼最多為 8 個 ASCII 位元組。';

  @override
  String get remoteDesktopNameRequired => '請輸入設定檔名稱。';

  @override
  String get remoteDesktopHostRequired => '請輸入目標主機。';

  @override
  String get remoteDesktopPortRequired => '請輸入有效的連接埠。';

  @override
  String get remoteDesktopUsernameRequired => '請輸入 RDP 使用者名稱。';

  @override
  String get remoteDesktopVncPasswordAscii => '傳統 VNC 密碼只能包含 ASCII 字元。';

  @override
  String get remoteDesktopCertificateRequired => '需要確認憑證';

  @override
  String get remoteDesktopWaiting => '正在等待桌面…';

  @override
  String get remoteDesktopCertificateChanged => '遠端桌面憑證已變更';

  @override
  String get remoteDesktopTrustCertificate => '是否信任此憑證？';

  @override
  String get remoteDesktopCertificateChangedTip =>
      '憑證指紋與儲存的值不一致。替換信任前，請先核實新的指紋。';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      '系統無法驗證此憑證。繼續前，請先核實其 SHA-256 指紋。';

  @override
  String get remoteDesktopReplaceTrust => '替換信任';

  @override
  String get remoteDesktopTrustReconnect => '信任並重新連線';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return '是否刪除遠端桌面設定檔「$name」？';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return '正在重新連線（$attempt/3）…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return '先前信任的指紋\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return '主體：$subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return '簽發者：$issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return '有效期：$start – $end';
  }

  @override
  String get pveAuthToken => 'API token';

  @override
  String get pveVersionLow => '此功能目前處於測試階段，僅在 PVE 8+ 上進行過測試。請謹慎使用。';

  @override
  String get pveTokenId => 'Token ID';

  @override
  String get pveTokenSecret => 'Token secret';

  @override
  String get pveTokenTip =>
      '在 PVE 的 資料中心 → 權限 → API Tokens 中建立。需要在要顯示的路徑上具有 VM.Audit、VM.PowerMgmt、VM.Console、VM.Snapshot、VM.Snapshot.Rollback、Datastore.Audit 和 Sys.Audit 權限；若啟用了權限分離，需要將這些權限授予 token 本身。';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'token $account 在這台主機上沒有任何可見的資源。啟用了權限分離的 token 不繼承其使用者的權限，需要單獨授權。在 PVE 主機上執行：\n$command\n或取消該 token 的「權限分離」。';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account 在這台主機上沒有任何可見的資源。在 PVE 主機上為它授權：\n$command';
  }

  @override
  String get pveTokenIdInvalid => 'Token ID 的格式應為 user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      '以 SSH 使用者身分在 PAM realm 登入，使用 SSH 密碼；SSH 使用 key 時使用下方的 PVE 密碼。需要時會要求輸入兩步驟驗證碼。';

  @override
  String get pveCertUnpinned => '尚未確認。除非憑證由受信任的 CA 簽發，下次連線時會顯示憑證以供確認。';

  @override
  String get pveCertForget => '忘記憑證';

  @override
  String get pveCertForgetTip => '下次連線時會再次顯示 PVE 憑證以供確認。';

  @override
  String get virtualization => '虛擬化';

  @override
  String get virtIntro =>
      '管理 Proxmox VE 與 libvirt/KVM 主機上的虛擬機器和容器：查看狀態、執行電源操作、開啟主控台。';

  @override
  String get virtIntroPveMoved => 'Proxmox VE 已從伺服器頁面移到此分頁。伺服器的 PVE 卡片會在這裡開啟它。';

  @override
  String get virtIntroLibvirt =>
      '安裝了 libvirt 的 virsh 的伺服器會顯示為主機，並列出其 QEMU/KVM 虛擬機器。';

  @override
  String get virtIntroTransports => '兩者都可以透過 SSH、Monitor agent 或在本裝置上使用。';

  @override
  String get virtIntroTokens =>
      'PVE 可以使用 API token 登入，無需密碼。請在伺服器編輯頁面的 PVE 部分設定。';

  @override
  String get virtIntroInBar => '已新增到分頁列。';

  @override
  String get virtIntroInMore => '位於「更多」中。可在設定的「主頁標籤」中將其移到分頁列。';

  @override
  String get virtGuests => '虛擬機';

  @override
  String get virtHosts => '主機';

  @override
  String get virtCheckServer => '檢查此伺服器';

  @override
  String get virtCheckAll => '檢查所有伺服器';

  @override
  String get virtProbeNotChecked => '尚未檢查';

  @override
  String get virtProbeAbsent => '不是主機';

  @override
  String virtProbeContainer(String kind) {
    return '$kind 容器';
  }

  @override
  String get virtProbeContainerTip => '這台伺服器執行在容器中，本身不是主機。請在執行它的主機上管理。';

  @override
  String get virtProbePve => 'PVE，未設定';

  @override
  String virtPveSetupTip(String version) {
    return '這台伺服器執行著 $version。在伺服器設定中填寫 API 存取資訊（建議使用 API token）後，即可在這裡管理其中的虛擬機和容器。';
  }

  @override
  String get virtNoHosts => '沒有虛擬化主機';

  @override
  String get virtNoHostsTip =>
      '執行 Proxmox VE 且填寫了 API 存取資訊的伺服器是主機，能執行 virsh 的伺服器也是。其他伺服器可以在主機切換器中檢查。';

  @override
  String get virtNoGuests => '沒有虛擬機或容器';

  @override
  String get virtPaused => '已暫停';

  @override
  String get virtStarting => '正在啟動…';

  @override
  String get virtStopping => '正在關機…';

  @override
  String get virtRebooting => '正在重新啟動…';

  @override
  String get virtMigrating => '正在遷移…';

  @override
  String get virtBackingUp => '正在備份…';

  @override
  String get virtResume => '繼續';

  @override
  String get virtOverview => '概覽';

  @override
  String get virtConsole => '主控台';

  @override
  String get virtConsoleNone => '此虛擬機器沒有可用的主控台';

  @override
  String get virtConsoleGraphical => '圖形';

  @override
  String get virtVncPasswordNeeded => '這個顯示需要密碼';

  @override
  String get virtConsoleSerialTip =>
      '在主機上以 virsh 開啟虛擬機器的序列主控台。中斷連線或按 Ctrl+] 可返回主機的 shell。';

  @override
  String virtConsoleVia(String transport) {
    return '經 $transport';
  }

  @override
  String get virtConsoleEnterTip => '沒有輸出？按 Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return '$seconds 秒後自動按 Enter 喚出提示字元';
  }

  @override
  String get virtConsoleEnterNow => '立即';

  @override
  String get virtOffTip => '啟動後在這裡顯示即時 CPU、記憶體、磁碟和網路。';

  @override
  String get virtAllocated => '已分配';

  @override
  String virtRunningCount(int running, int total) {
    return '$running 執行中 · 共 $total 台';
  }

  @override
  String get virtTemplate => '範本';

  @override
  String get virtAutostart => '隨主機啟動';

  @override
  String get virtErrUnreachable => '無法連線到此主機';

  @override
  String get virtErrNotConfigured => '此伺服器的 PVE 設定不完整';

  @override
  String get virtErrNotConfiguredTip => '請在伺服器設定中檢查位址，以及密碼或 API token。';

  @override
  String get virtErrAuthFailed => '主機拒絕了登入';

  @override
  String get virtErrCertUnconfirmed => '請確認主機的憑證';

  @override
  String get virtErrCertChanged => '主機的憑證已變更';

  @override
  String get virtErrRelayNotGranted => 'Monitor agent 不轉送連線';

  @override
  String get virtErrExecNotGranted => 'Monitor agent 不執行命令';

  @override
  String get virtErrNotInstalled => '此伺服器上未安裝 virsh';

  @override
  String get virtErrServerRemoved => '該伺服器已被刪除';

  @override
  String get virtErrSudoRequired => 'sudo 需要密碼才能存取 libvirt';

  @override
  String get virtErrSudoRejected => 'sudo 拒絕了該密碼';

  @override
  String get virtErrInvalidResponse => '主機回傳了無法辨識的內容';

  @override
  String get virtErrActionFailed => '主機拒絕了該操作';

  @override
  String get remoteSessionIdleTimeout => '離開後自動關閉';

  @override
  String get remoteSessionIdleTimeoutTip =>
      '離開遠端桌面或虛擬機主控台後,連線保持多久。關閉前會顯示提示,10 秒內可選擇保持連線。';

  @override
  String get remoteSessionKeepAlive => '保持連線';

  @override
  String get remoteSessionClosedAway => '已因閒置關閉';

  @override
  String remoteSessionClosingIn(int seconds) {
    return '$seconds 秒後關閉';
  }

  @override
  String get virtSnapshots => '快照';

  @override
  String get virtSnapshotCreate => '建立快照';

  @override
  String get virtSnapshotNone => '還沒有快照';

  @override
  String get virtSnapshotWithMemory => '磁碟和記憶體';

  @override
  String get virtSnapshotDiskOnly => '僅磁碟';

  @override
  String get virtSnapshotParent => '父快照';

  @override
  String get virtSnapshotRevert => '還原到此快照';

  @override
  String get virtSnapshotMemory => '包含記憶體狀態';

  @override
  String get virtSnapshotMemoryTip => '還原後回到這一刻的執行狀態。';

  @override
  String get virtSnapshotMemoryAlways => '在此主機上，執行中的虛擬機快照總是包含記憶體。';

  @override
  String get virtSnapshotMemoryOff => '虛擬機未執行，只能儲存磁碟。';

  @override
  String get virtSnapshotNameInvalid => '以字母開頭，之後只能是字母、數字、- 或 _，長度 2 到 40。';

  @override
  String get virtSnapshotNameTaken => '已有同名快照。';

  @override
  String get virtSnapshotRevertTip => '還原會捨棄快照之後的所有變更。';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return '將 $guest 還原到 $snapshot？此後的所有變更都會遺失。';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return '此快照不含記憶體：$guest 將被停止。';
  }

  @override
  String get virtSnapshotStartAfter => '還原後啟動';

  @override
  String get virtVolumes => '磁碟區';

  @override
  String get virtNoPools => '沒有儲存池';

  @override
  String get virtNoNetworks => '沒有網路';

  @override
  String get virtPoolInactive => '儲存池未啟用，無法列出其中的磁碟區。';

  @override
  String get virtShared => '節點間共用';

  @override
  String get virtBackingFile => '後備檔案';

  @override
  String get virtNetIsolated => '隔離';

  @override
  String get virtNetBridged => '橋接';

  @override
  String get virtNetRouted => '路由';

  @override
  String get virtBridge => '網橋';

  @override
  String get virtPorts => '連接埠';

  @override
  String get virtAttachedGuests => '已連線的虛擬機';

  @override
  String get virtNoAttachedGuests => '沒有虛擬機連線到此網路';

  @override
  String get virtCreateVm => '新增虛擬機';

  @override
  String get virtCreateLxc => '新增容器';

  @override
  String get virtCreateGuest => '新增虛擬機或容器';

  @override
  String get virtKindVm => '虛擬機';

  @override
  String get virtKindLxc => '容器';

  @override
  String get virtHostname => '主機名稱';

  @override
  String get virtInstallMedia => '安裝媒體';

  @override
  String get virtNoIsos => '這台主機上沒有 ISO 映像';

  @override
  String get virtNoTemplates => '這台主機上沒有容器範本。可以在 PVE 中儲存的 CT 範本裡下載。';

  @override
  String get virtNoDiskStorage => '這台主機上沒有可以建立新磁碟的儲存';

  @override
  String get virtStartAfterCreate => '建立後啟動';

  @override
  String get virtUnprivileged => '非特權容器';

  @override
  String get virtUnprivilegedTip => '容器內的 root 對應主機上的一般使用者。';

  @override
  String get virtSshKeys => 'SSH 公鑰';

  @override
  String get virtCredentialsTip => 'root 密碼、SSH 公鑰，或兩者都設定。';

  @override
  String virtCreated(String name) {
    return '已建立 $name';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '已建立 $name，但未能啟動';
  }

  @override
  String get virtErrExists => '同名的虛擬機器或磁碟已存在';

  @override
  String get virtCreateNameInvalidLibvirt =>
      '字母、數字、.、_ 和 -，以字母或數字開頭，最多 63 個字元。';

  @override
  String get virtCreateNameInvalidPve => '字母、數字和 -，各段之間以點分隔，最多 63 個字元。';

  @override
  String get virtCreateNameTaken => '已有同名虛擬機器。';

  @override
  String get virtCreateVmidTaken => '這個 VMID 已被使用。';

  @override
  String get virtCreateCoresInvalid => '超出了這台主機允許的核心數。';

  @override
  String get virtCreateMemoryInvalid => '記憶體不足。';

  @override
  String get virtCreateStorageMissing => '選擇磁碟的存放位置。';

  @override
  String get virtCreateDiskInvalid => '範圍為 1 GiB 到 64 TiB。';

  @override
  String get virtCreateTemplateMissing => '選擇一個範本。';

  @override
  String get virtCreateCredentialsMissing => '設定 root 密碼或 SSH 公鑰。';

  @override
  String virtCreatePasswordShort(int min) {
    return '至少 $min 個字元。';
  }

  @override
  String get virtCreateSshKeysInvalid => '每行一個 OpenSSH 公鑰。';

  @override
  String get virtDeleteDisks => '同時刪除磁碟區';

  @override
  String get virtDeleteDisksPve => '磁碟會隨它一起刪除，安裝媒體會保留。';

  @override
  String virtDeleted(String name) {
    return '已刪除 $name';
  }

  @override
  String get pveTokenTipCreate =>
      '建立和刪除虛擬機器還需要 VM.Allocate、VM.Config.*、Datastore.AllocateSpace 和 SDN.Use。';

  @override
  String get pveTokenTipHardware =>
      '編輯硬體需要 VM.Config.CPU、VM.Config.Memory、VM.Config.Disk、VM.Config.CDROM、VM.Config.Network 和 VM.Config.Options；新增磁碟和網路卡還需要 Datastore.AllocateSpace 和 SDN.Use。修改顯示卡以及 USB、PCI 裝置還需要 VM.Config.HWType；透過資源對應直通裝置需要該對應的 Mapping.Use，列出對應需要 Mapping.Audit。';

  @override
  String get pveTokenTipBackup =>
      '複製需要 VM.Clone，備份與還原需要 VM.Backup，轉為範本需要 VM.Allocate；備份工作還需要 Sys.Audit 才能讀取，以及在 / 上的 Sys.Modify 才能新增、編輯和刪除；副本或備份存放的儲存上還需要 Datastore.AllocateSpace。';

  @override
  String get virtErrConflict => '已在別處修改';

  @override
  String get virtErrConflictTip => '此設定在讀取後被他人修改，因此未做任何變更。已重新讀取，如仍需要請再次修改。';

  @override
  String get virtHardware => '硬體';

  @override
  String get virtHwAddDisk => '新增磁碟';

  @override
  String get virtHwAddMount => '新增掛載點';

  @override
  String get virtHwAddNic => '新增網路卡';

  @override
  String get virtHwAppliesOnRestart => '已儲存，將在下次啟動時生效。';

  @override
  String get virtHwAutostart => '隨主機開機自動啟動';

  @override
  String get virtHwAutostartPve => 'onboot · 依 VMID 順序啟動';

  @override
  String get virtHwBalloonLibvirt => '目前記憶體';

  @override
  String get virtHwBalloonNote => '允許主機在記憶體緊張時回收虛擬機器的閒置記憶體';

  @override
  String get virtHwBoot => '開機';

  @override
  String get virtHwBootOrder => '啟動順序';

  @override
  String get virtHwBootTip => '用箭頭調整順序；點按裝置可切換是否從它開機。';

  @override
  String get virtHwCdrom => '光碟機';

  @override
  String get virtHwConfigFile => '設定檔';

  @override
  String get virtHwCores => '核心';

  @override
  String get virtHwCpuTypeDefault => '預設';

  @override
  String get virtHwDeleteVolume => '同時刪除磁碟區';

  @override
  String get virtHwDetach => '分離';

  @override
  String get virtHwDiskHotplug => '支援熱插拔，執行中也能新增';

  @override
  String get virtHwDisksLxc => '根磁碟與掛載點';

  @override
  String get virtHwEject => '退出';

  @override
  String get virtHwEmpty => '無媒體';

  @override
  String get virtHwFirewall => '防火牆';

  @override
  String virtHwFree(String size) {
    return '可用 $size';
  }

  @override
  String get virtHwGrow => '擴充';

  @override
  String get virtHwGrowNote => '只能在原容量上擴充。';

  @override
  String get virtHwGrowNoteRunning => '只能在原容量上擴充。執行中擴充後需在系統內擴充分割區。';

  @override
  String get virtHwGuestUsed => '系統內已用';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return '主機 $threads 執行緒 · 已分配 $allocated';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return '主機 $total · 已分配 $allocated';
  }

  @override
  String get virtHwHotplugNow => '支援熱插拔，執行中立即生效。';

  @override
  String get virtHwIssueBootEmpty => '至少勾選一個裝置';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'vCPU 總數須在 1 到 $max 之間';
  }

  @override
  String get virtHwIssueCpuOnline => '線上 vCPU 須在 1 到總數之間';

  @override
  String get virtHwIssueDiskShrink => '須大於目前大小：磁碟只能擴大';

  @override
  String get virtHwIssueDiskSize => '須在 1 到 65536 GiB 之間';

  @override
  String virtHwIssueMemory(int min, int max) {
    return '須在 $min 到 $max MiB 之間';
  }

  @override
  String get virtHwIssueMemoryMin => '不能超過記憶體';

  @override
  String get virtHwIssueMountPoint => '須為絕對路徑，如 /data';

  @override
  String get virtHwIssueStorageSpace => '超出了儲存的可用空間';

  @override
  String get virtHwIssueSwap => '不能為負數';

  @override
  String get virtHwLater => '重新啟動後生效';

  @override
  String get virtHwLess => '減少';

  @override
  String get virtHwLinkDown => '已中斷';

  @override
  String get virtHwLinkNote => '中斷後系統內會顯示網路線已拔出，不需要重新啟動';

  @override
  String get virtHwLinkUp => '已連線';

  @override
  String get virtHwMac => 'MAC 位址';

  @override
  String get virtHwModel => '型號';

  @override
  String get virtHwMore => '增加';

  @override
  String get virtHwMountFromPool => '掛載點直接從儲存池分配';

  @override
  String get virtHwMountPoint => '掛載點';

  @override
  String get virtHwMoveDown => '下移';

  @override
  String get virtHwMoveUp => '上移';

  @override
  String get virtHwNewDisk => '新磁碟';

  @override
  String get virtHwNewMount => '新掛載點';

  @override
  String get virtHwNewNic => '新網路卡';

  @override
  String get virtHwNicHotplug => 'virtio 網路卡支援熱插拔';

  @override
  String get virtHwNics => '網路卡';

  @override
  String get virtHwNoMedia => '無媒體';

  @override
  String get virtHwNoNetworks => '沒有可用的網路或橋接';

  @override
  String get virtHwNoStorage => '沒有可存放磁碟的儲存';

  @override
  String get virtHwOnline => '線上 vCPU';

  @override
  String get virtHwPendingBanner => '部分硬體變更在重新啟動後生效';

  @override
  String get virtHwPickNet => '選擇網路';

  @override
  String get virtHwPickPool => '選擇儲存池和容量';

  @override
  String get virtHwProcessor => '處理器';

  @override
  String get virtHwRemove => '移除';

  @override
  String get virtHwRemoveCdrom => '移除光碟機';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return '從 $guest 移除 $disk？';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return '從 $guest 移除 $nic？';
  }

  @override
  String get virtHwResources => '資源';

  @override
  String get virtHwRestartNow => '立即重新啟動';

  @override
  String get virtHwRevert => '復原';

  @override
  String get virtHwRevertAll => '全部復原';

  @override
  String get virtSetRenameStopped => '關機後才能改名：libvirt 只能重新命名未執行的虛擬機。';

  @override
  String virtSetIssueDescription(int max) {
    return '最多 $max 位元組（UTF-8），且不能包含控制字元。';
  }

  @override
  String get virtSetManualStart => '手動啟動';

  @override
  String get virtSetProtection => '保護';

  @override
  String get virtSetProtectionNote => '禁止刪除虛擬機和修改磁碟';

  @override
  String get virtSetIrreversible => '無法復原';

  @override
  String get virtSetDeleteStopFirst => '先關機再刪除。';

  @override
  String get virtSetDeleteProtected => '已開啟保護，請先在一般設定中關閉。';

  @override
  String get virtSetDeleteAgain => '再按一次確認';

  @override
  String virtSetDeleteConfirm(String name) {
    return '確認刪除 $name';
  }

  @override
  String get virtSetDeleteVm => '刪除虛擬機';

  @override
  String get virtSetDeleteLxc => '刪除容器';

  @override
  String get virtHwSockets => '插槽';

  @override
  String get virtHwSource => '來源';

  @override
  String get virtHwSwap => '交換空間';

  @override
  String get virtHwTopology => '插槽 × 核心';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets 插槽 × $cores 核 × $threads 執行緒';
  }

  @override
  String virtHwTotal(String size) {
    return '$size 總計';
  }

  @override
  String get virtHwVolumeKept => '已移除，但執行中的虛擬機器仍在使用該磁碟，因此保留了磁碟區。它會在下次啟動時分離。';

  @override
  String get virtHwBus => '匯流排';

  @override
  String get virtHwCache => '快取';

  @override
  String get virtHwBusStopped => '關機後才能更換匯流排。';

  @override
  String get virtHwMacGenerate => '產生';

  @override
  String get virtHwIssueMac => '須為單播 MAC 位址，如 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => '先關機';

  @override
  String get virtHwIssueStorageMissing => '先選擇存放的儲存';

  @override
  String get virtHwIssueDevice => '先選擇一個裝置';

  @override
  String get virtHwDevices => '光碟機與直通';

  @override
  String get virtHwDevicesEmpty => 'USB 與 PCI 直通、光碟機、TPM';

  @override
  String get virtHwAddDevice => '新增裝置';

  @override
  String get virtHwNewDevice => '新裝置';

  @override
  String get virtHwUsbHotplug => 'USB 直通支援熱插拔。';

  @override
  String get virtHwPci => 'PCI 直通';

  @override
  String get virtHwIommuOffTitle => '主機沒有啟用 IOMMU';

  @override
  String get virtHwIommuOffBody =>
      '先在主機 BIOS 中啟用 VT-d 或 AMD-Vi，並在核心中啟用 IOMMU。在此之前，加入了 PCI 裝置的虛擬機無法啟動。';

  @override
  String get virtHwPciTitle => '需要主機啟用 IOMMU';

  @override
  String get virtHwPciBody => '直通後該裝置不能再給主機使用，虛擬機也不能線上遷移。';

  @override
  String virtHwIommuGroup(int group) {
    return 'IOMMU 群組 $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '同一 IOMMU 群組共 $count 個裝置，會一起直通';
  }

  @override
  String get virtHwNoHostDevices => '主機上沒有可直通的裝置';

  @override
  String get virtHwMappingsOnly =>
      '這裡只能使用資源對應：PVE 只允許以密碼登入的 root@pam 直通原始裝置。可在 資料中心 → 資源對應 中建立對應。';

  @override
  String get virtHwTpmNote => 'Windows 11 需要 TPM 2.0。';

  @override
  String get virtHwDisplay => '顯示';

  @override
  String get virtHwProtocol => '協定';

  @override
  String get virtHwListen => '監聽';

  @override
  String get virtHwGpu => '顯示卡';

  @override
  String get virtHwListenAllTitle => '主控台暴露在網路上';

  @override
  String get virtHwListenAllBody =>
      '監聽所有位址後，任何能存取主機的人都能連上主控台。保持 127.0.0.1，經 SSH 通道連線即可。';

  @override
  String get virtHwFirmware => '韌體';

  @override
  String get virtHwUefiSub => 'OVMF · 支援 Secure Boot，Windows 11 需要';

  @override
  String get virtHwBiosSub => 'SeaBIOS · 舊系統與 MBR 分割';

  @override
  String get virtHwSecureBootNote => '只開機已簽署的核心與開機程式';

  @override
  String get virtHwFirmwareWarnTitle => '已安裝系統不要切換韌體';

  @override
  String get virtHwFirmwareWarnBody => '在 UEFI 與 BIOS 之間切換會導致現有系統無法開機。';

  @override
  String get virtHwFirmwareStopped => '關機後才能切換韌體。';

  @override
  String get virtHwSecureBootVars =>
      '開關 Secure Boot 會重新產生 EFI 變數，其中儲存的開機項目會遺失。';

  @override
  String get virtHwEfiStorage => 'EFI 變數存放於';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return '將 $guest 切換到 $firmware？';
  }

  @override
  String get virtCloneName => '新名稱';

  @override
  String get virtCloneFull => '完整複製';

  @override
  String get virtCloneCopyDisks => '複製磁碟內容';

  @override
  String get virtCloneLinkedNote => '關閉則為連結複製，依賴原磁碟';

  @override
  String get virtCloneFullOnly => '只有範本可以連結複製';

  @override
  String get virtCloneEmptyNote => '關閉則新建同樣大小的空磁碟';

  @override
  String get virtCloneStopFirst => '複製前需要先關機。';

  @override
  String get virtCloneFullShort => '完整';

  @override
  String get virtCloneLinkedShort => '連結';

  @override
  String get virtCloneEmptyShort => '空磁碟';

  @override
  String get virtCloning => '正在複製…';

  @override
  String virtCloned(String name) {
    return '已複製為 $name';
  }

  @override
  String get virtBackupPlan => '排程';

  @override
  String get virtBackupPlanWhere => '資料中心 → 備份';

  @override
  String get virtBackupNoPlanShort => '無排程';

  @override
  String get virtBackupNoPlan => '沒有包含它的定時備份工作。';

  @override
  String get virtBackupKeep => '保留';

  @override
  String get virtBackupJobDisabled => '這個工作已停用。';

  @override
  String virtBackupCount(int count) {
    return '$count 份';
  }

  @override
  String virtSnapshotCount(int count) {
    return '$count 個';
  }

  @override
  String get virtBackupNoStorage => '這個節點上沒有能存放備份的儲存。';

  @override
  String get virtBackupLiveTip => '執行中用 snapshot 模式，不停機';

  @override
  String get virtBackupStoppedTip => '已關機：按目前狀態備份';

  @override
  String get virtBackupNow => '立即備份';

  @override
  String get virtBackupNotes => '備註';

  @override
  String get virtBackupProtected => '受保護：在 PVE 中取消保護之前不能刪除。';

  @override
  String virtBackupVerified(String state) {
    return '驗證：$state';
  }

  @override
  String get virtBackupRestoreOverwrites => '還原會覆蓋目前的磁碟';

  @override
  String get virtBackupStopFirst => '先關機再還原。';

  @override
  String get virtBackupRestoreAgain => '虛擬機器的磁碟和設定會被備份中的取代。';

  @override
  String get virtBackupDeleteConfirm => '確認刪除備份';

  @override
  String get virtBackupRestoreNew => '還原為新的';

  @override
  String get virtBackupRestoreConfirm => '確認覆蓋還原';

  @override
  String get virtBackupDone => '備份完成';

  @override
  String get virtBackupDeleted => '已刪除備份';

  @override
  String virtBackupRestored(String time) {
    return '已從 $time 還原';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account 在 $path 上沒有 $privilege 權限。請在 PVE 主機上授予：\n$command';
  }

  @override
  String get virtCanDelete => '可以刪除';

  @override
  String get virtInUse => '使用中';

  @override
  String get virtOps => '操作';

  @override
  String get virtPool => '儲存池';

  @override
  String get virtPoolNew => '新增儲存池';

  @override
  String get virtStorageAdd => '新增儲存';

  @override
  String virtPoolUsedPct(String pct) {
    return '已用 $pct%';
  }

  @override
  String get virtPoolInUse => '有磁碟區正被虛擬機器使用，無法停用或刪除。';

  @override
  String get virtPoolDelete => '刪除儲存池';

  @override
  String get virtStorageRemove => '移除儲存';

  @override
  String virtPoolDeleteAsk(String name) {
    return '刪除儲存池 $name？會刪除其定義，磁碟區保留在原處。';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return '從 PVE 設定中移除儲存 $name？其中的資料保留。';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '其中的 $count 個磁碟區會保留在磁碟上。';
  }

  @override
  String get virtPoolDeleteStorage => '同時刪除其目錄（僅當為空時）';

  @override
  String virtPoolStopAsk(String name) {
    return '停用儲存池 $name？重新啟用前無法列出或建立其中的磁碟區。';
  }

  @override
  String get virtStorageClusterWide => '這會作用於叢集中所有設定了該儲存的節點。';

  @override
  String get virtStorageDisable => '停用';

  @override
  String get virtStorageEnable => '啟用';

  @override
  String virtStorageDisableAsk(String name) {
    return '停用儲存 $name？重新啟用前，磁碟在其上的虛擬機器無法啟動。';
  }

  @override
  String get virtPoolLogicalNote => '使用現有的磁碟區群組，不會格式化任何裝置。';

  @override
  String get virtPoolMountPoint => '掛載點';

  @override
  String get virtPoolSourceNfs => '來源 (host:/path)';

  @override
  String get virtPoolSourceVg => '磁碟區群組';

  @override
  String get virtPoolSourceThin => '磁碟區群組 / thin pool';

  @override
  String get virtPoolSourceZfs => 'ZFS 池';

  @override
  String get virtPoolTypeVg => 'LVM 磁碟區群組';

  @override
  String get virtResNameEmpty => '請輸入名稱';

  @override
  String get virtResNameInvalid => '主機不接受此名稱（字母、數字、. _ -）';

  @override
  String get virtResSourceInvalid => '不是有效的路徑或來源';

  @override
  String get virtResTargetInvalid => '需要絕對路徑';

  @override
  String get virtResCidrInvalid => '需要帶前綴的位址，例如 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid => '需要網段內、依序、且不含主機位址的兩個位址';

  @override
  String get virtResSubnetTaken => '已有網路使用此網段';

  @override
  String get virtResBridgeInvalid => '不是有效的網路介面名稱';

  @override
  String get virtResFormat => '這個儲存池不支援此格式';

  @override
  String get virtVolNew => '新增磁碟區';

  @override
  String virtVolCount(int count) {
    return '$count 個磁碟區';
  }

  @override
  String get virtVolNone => '這個儲存池還沒有磁碟區。';

  @override
  String get virtVolEmptyAttach => '新磁碟區之後可以掛載到任一虛擬機器';

  @override
  String get virtVolEmptyUpload => '也可以直接上傳 ISO';

  @override
  String get virtVolPveName => 'PVE 依所屬虛擬機器命名磁碟區：vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => '使用者';

  @override
  String get virtVolAllocated => '已配置';

  @override
  String get virtVolGrowFromGuest => '有虛擬機器在使用：請在該虛擬機器的硬體頁擴充';

  @override
  String get virtVolInUse => '有虛擬機器正在使用此磁碟區';

  @override
  String virtVolBackingOf(String names) {
    return '$names 的後備檔案';
  }

  @override
  String get virtVolIsBase => '有其他磁碟區以此為後備檔案，刪除它會損壞那些磁碟區';

  @override
  String get virtVolAttach => '掛載到虛擬機器';

  @override
  String get virtVolAttachNote => '作為新磁碟掛載到其第一顆磁碟所在的匯流排';

  @override
  String virtVolAttached(String name) {
    return '已掛載到 $name';
  }

  @override
  String get virtVolInsert => '插入光碟機';

  @override
  String virtVolInserted(String name) {
    return '已插入 $name 的光碟機';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name 沒有光碟機';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return '從 $pool 刪除磁碟區 $name？其中的資料將永久遺失。';
  }

  @override
  String get virtUploadIso => '上傳 ISO';

  @override
  String virtUploadTo(String pool) {
    return '上傳到 $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name 上傳完成';
  }

  @override
  String get virtNetConfig => '設定';

  @override
  String get virtNetConfigFile => '設定檔';

  @override
  String get virtNetInternal => '內部';

  @override
  String get virtNetBridgePorts => '橋接埠';

  @override
  String get virtNetHostBridge => '主機網橋';

  @override
  String get virtNetPortsHint => 'eno2，留空為內部網橋';

  @override
  String get virtNetDhcpRange => 'DHCP 範圍';

  @override
  String get virtNetDhcpTip => 'dnsmasq 為虛擬機器分配位址';

  @override
  String get virtNetVlanTip => '允許虛擬機器網卡帶 VLAN tag';

  @override
  String get virtNetNatTip => '經主機轉送，虛擬機器可上網但外部無法連入';

  @override
  String get virtNetRoutedTip => '經主機路由，不做 NAT：區域網路需要回程路由';

  @override
  String get virtNetIsolatedTip => '只有虛擬機器之間和主機能通訊';

  @override
  String get virtNetBridgedTip => '直接接入主機網橋，與實體網路同網段';

  @override
  String get virtNetNew => '新增網路';

  @override
  String get virtNetNewBridge => '新增 Linux bridge';

  @override
  String get virtNetVirtual => '虛擬網路';

  @override
  String get virtNetDelete => '刪除網路';

  @override
  String virtNetDeleteAsk(String name) {
    return '刪除網路 $name？它會被停止並刪除定義。';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return '從 $node 移除網橋 $name？它會先從待生效設定中移除，套用設定後才從主機上刪除。';
  }

  @override
  String virtNetInUse(int count) {
    return '$count 台在使用，無法刪除。';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return '停用 $name？其上的 $count 台虛擬機器會斷網，直到重新啟用。';
  }

  @override
  String get virtNetInactivePve => '未啟用：新網橋在套用設定前處於待生效狀態。';

  @override
  String get virtNetPveApplyNote => '儲存為待生效的變更，套用設定（ifreload -a）後生效。';

  @override
  String get virtNetPendingSaved => '已儲存為待生效，套用設定後生效';

  @override
  String virtNetPendingTitle(String node) {
    return '$node 上有待生效的網路變更';
  }

  @override
  String get virtNetPendingTip => 'PVE 會把網路變更保存在 interfaces.new 中，套用後才生效。';

  @override
  String get virtNetPendingShow => '查看變更';

  @override
  String get virtNetApply => '套用設定';

  @override
  String virtNetApplyAsk(String node) {
    return '套用 $node 上待生效的網路設定？PVE 會重新載入主機網路（ifreload -a），設定有誤可能導致主機斷線。';
  }

  @override
  String virtNetRevertAsk(String node) {
    return '捨棄 $node 上待生效的網路設定？';
  }

  @override
  String get pveTokenTipStorage =>
      '管理儲存需要 /storage 上的 Datastore.Allocate（新增、停用、移除）、Datastore.AllocateSpace（磁碟區）和 Datastore.AllocateTemplate（上傳）；Linux bridge 和套用網路設定需要節點上的 Sys.Modify。';

  @override
  String get virtCreateUnnamed => '未命名';

  @override
  String get virtCreateNotChosen => '未選擇';

  @override
  String get virtCreateKindVmSub => 'qm · 完整的 KVM 虛擬機器';

  @override
  String get virtCreateKindLxcSub => 'pct · 共用主機核心，開銷更小';

  @override
  String get virtCloudImage => '雲端映像';

  @override
  String get virtCloudImageTip =>
      '已裝好系統的磁碟：複製一份，擴充到「儲存」中的容量，首次啟動時由 cloud-init 設定。映像本身保持不變。';

  @override
  String get virtNoCloudImagesLibvirt =>
      '這裡沒有雲端映像：把 qcow2 或 raw 映像放進一個儲存池（可在「儲存」中上傳），且沒有虛擬機器在使用它。';

  @override
  String get virtNoCloudImagesPve =>
      '這裡沒有雲端映像：把 qcow2、raw 或 vmdk 映像上傳到內容類型含「匯入」(Import) 的儲存（PVE 8.2+）。';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 需要 UEFI + TPM 2.0';

  @override
  String get virtCreateWindowsBody => '在上方選 UEFI 並開啟 TPM。';

  @override
  String get virtCreateWindowsNoTpm => '這台主機沒有軟體 TPM (swtpm)：安裝後才能為虛擬機器新增。';

  @override
  String virtCreateImageSize(String size) {
    return '映像有 $size：磁碟至少要這麼大。';
  }

  @override
  String get virtCreateImageMissing => '選擇一個雲端映像。';

  @override
  String get virtCreateIncomplete => '先補齊標為橘色的部分。';

  @override
  String virtCreateOn(String host) {
    return '將在 $host 上建立';
  }

  @override
  String get virtCiTip => '一個帶 sudo 的帳戶，可用密碼、SSH 金鑰或兩者登入。';

  @override
  String get virtCiUserInvalid => '小寫字母、數字、_ 和 -，以字母或 _ 開頭';

  @override
  String get virtCiCredentialsMissing => '設定密碼或 SSH 金鑰。';

  @override
  String get virtCiHostnamePve => '主機名稱就是虛擬機器的名稱。';

  @override
  String get virtCiStatic => '靜態';

  @override
  String get virtCiAddressInvalid => '帶前綴的 IPv4 位址，如 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'IPv4 位址，如 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => '留空：由 DHCP 提供';

  @override
  String get virtCiDnsInvalid => 'IP 位址，以空格或逗號分隔';

  @override
  String get virtCiSearch => '搜尋網域';

  @override
  String get virtCiSeedNote => '寫入磁碟旁的一個小 ISO，作為光碟機掛載，隨虛擬機器一起刪除。只儲存密碼的雜湊。';

  @override
  String get virtCiNoToolTitle => '主機上沒有製作 cloud-init 資料的工具';

  @override
  String virtCiNoToolBody(String tools) {
    return '在主機上安裝 $tools 之一。沒有 cloud-init，映像啟動後沒有可登入的帳戶。';
  }

  @override
  String get virtHwCloudInitNote => 'cloud-init 在首次啟動時讀取的資料，不是安裝媒體，這裡不能換片。';

  @override
  String get virtHwCdromLater => '執行中新增的光碟機在下次啟動時生效（SATA 和 IDE 不支援熱插拔）。';

  @override
  String virtCreateDiskKept(String size) {
    return '磁碟保持為映像本身的 $size，大於所選容量：磁碟不會被裁得比其中的系統還小。';
  }

  @override
  String get virtCiEditTip =>
      'cloud-init 在這台虛擬機器裡設定的內容：帶 sudo 的帳戶、登入方式、主機名稱和位址。';

  @override
  String get virtCiForeignTitle => '這份 seed 包含本應用程式不寫入的設定';

  @override
  String get virtCiForeignBody =>
      '在別處寫入的設定（套件、命令、其他帳戶）不在這裡顯示。儲存後，seed 會被替換為這裡顯示的內容。';

  @override
  String get virtCiPasswordKept => '已設定，留空則保持不變';

  @override
  String get virtCiRemovePassword => '移除密碼';

  @override
  String get virtCiRemovePasswordNote => '只能用 SSH 金鑰登入';

  @override
  String get virtCiKeysAdded =>
      '金鑰會新增到帳戶。在這裡刪掉的金鑰仍留在系統內，需要在系統內刪除；改使用者名稱會新建一個帳戶，舊帳戶保留。';

  @override
  String get virtCiEffectTitle => '下次啟動時生效';

  @override
  String get virtCiEffectLibvirt => '儲存會寫入一份新的 seed，並使用新的執行個體 ID。';

  @override
  String get virtCiEffectPve =>
      'PVE 會立即重寫它的 cloud-init 磁碟機，執行個體 ID 由這些設定計算得出，因此這裡的任何變更都會產生新的執行個體 ID。';

  @override
  String get virtCiNewInstance =>
      '下次啟動時，cloud-init 會把系統當作新的執行個體：重新設定主機名稱，帳戶不存在時建立它，設定密碼、新增金鑰，並重新寫入網路設定。它還會產生新的 SSH 主機金鑰，因此 SSH 用戶端會提示主機金鑰已變更。在那次啟動之前不會有任何變化。';

  @override
  String get virtCiSaved => '已儲存，下次啟動時生效。';

  @override
  String get virtSnapshotExternal => '不停機，僅磁碟';

  @override
  String get virtSnapshotExternalTip =>
      '虛擬機器繼續運行。每顆磁碟在所選儲存池中得到一個 qcow2 覆蓋層，虛擬機器停留在鏈上。';

  @override
  String get virtSnapshotFormInternal => '內部（映像內）';

  @override
  String get virtSnapshotOverlayPool => '覆蓋層儲存池';

  @override
  String get virtSnapshotOverlayBeside => '各磁碟所在目錄';

  @override
  String get virtSnapshotExternalNoMemory => '外部快照不含記憶體：虛擬機器不會停機。';

  @override
  String get virtSnapshotChain => '磁碟鏈';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count 層';
  }

  @override
  String get virtSnapshotChainFile => '檔案';

  @override
  String get virtSnapshotChainActive => '目前使用';

  @override
  String get virtSnapshotChainBase => '基礎映像';

  @override
  String get virtSnapshotNoSupport => '虛擬機器的儲存不支援快照，無法建立。';

  @override
  String get virtSnapshotRevertChain =>
      '在鏈上恢復會把運行中的覆蓋層合併進映像，並讓之後的所有快照無法使用。只能恢復到最新的快照。';

  @override
  String get virtSnapshotRevertHasChildren => '後面還有快照時不可恢復。';

  @override
  String get virtSnapshotDiff => '與現在的不同';

  @override
  String get virtSnapshotDiffNone => '自該快照以來設定沒有變化。';

  @override
  String get virtSnapshotDiffShow => '與現在比較';

  @override
  String get virtSnapshotDiffGroupCpu => '處理器';

  @override
  String get virtSnapshotDiffGroupMemory => '記憶體';

  @override
  String get virtSnapshotDiffGroupDisks => '磁碟';

  @override
  String get virtSnapshotDiffGroupNic => '網卡';

  @override
  String get virtSnapshotDiffGroupFirmware => '韌體';

  @override
  String get virtSnapshotDiffGroupBoot => '啟動';

  @override
  String get virtSnapshotDiffGroupOther => '其他';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => '已移除';

  @override
  String get virtSnapshotDiffAdded => '已新增';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return '恢復到 $snapshot 會改變：';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return '主機無法說明差異：$error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return '虛擬機器已在 $count 層鏈上，該快照會再增加一層。';
  }

  @override
  String get virtToTemplate => '轉為範本';

  @override
  String get virtToTemplateNote => '範本無法啟動，也無法還原為虛擬機器。其磁碟成為基礎映像，連結複製正是共享它。';

  @override
  String virtToTemplateConfirm(String name) {
    return '將 $name 轉為範本？';
  }

  @override
  String get virtToTemplateIrreversible => '此操作無法復原：範本無法還原為虛擬機器。';

  @override
  String get virtToTemplateStopped => '請先關機。';

  @override
  String get virtToTemplateSnapshots => '含快照的虛擬機器無法轉為範本。';

  @override
  String virtTemplateCreated(String name) {
    return '$name 現在是範本';
  }

  @override
  String get virtTemplateTip => '範本只有在複製後才能執行。';

  @override
  String get virtCloneStorageSame => '與來源相同';

  @override
  String get virtCloneNodeSame => '與來源相同';

  @override
  String get virtCloneStorageContent => '該儲存不存放虛擬機器磁碟。';

  @override
  String get virtCloneStorageShared => '複製到其他節點需要共享儲存。';

  @override
  String get virtCloneNodeUnknown => '該主機沒有此節點。';

  @override
  String get virtCloneLinkedTarget => '連結複製共享範本的磁碟，因此不能指定儲存或節點。';

  @override
  String get virtBackupJobs => '備份工作';

  @override
  String get virtBackupJobsNone => '沒有排程備份工作。新增一個即可依排程備份虛擬機器。';

  @override
  String get virtBackupJobNew => '新增工作';

  @override
  String get virtBackupJobRun => '立即執行';

  @override
  String get virtBackupJobRunAsk => '立即啟動該備份工作？';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return '刪除備份工作 $id？已產生的備份會保留。';
  }

  @override
  String get virtBackupJobSaved => '工作已儲存';

  @override
  String get virtBackupJobDeleted => '工作已刪除';

  @override
  String get virtBackupJobStarted => '備份工作已啟動';

  @override
  String get virtBackupSchedule => '時間表';

  @override
  String get virtBackupScheduleHelp =>
      'systemd 日曆事件的子集：02:30、mon..fri 02:30、sat 03:00、daily、hourly、*/15。';

  @override
  String get virtBackupScheduleInvalid => '主機不接受該時間表。';

  @override
  String virtBackupScheduleNext(String times) {
    return '接下來執行：$times';
  }

  @override
  String get virtBackupSelection => '虛擬機器';

  @override
  String get virtBackupSelectionAll => '所有虛擬機器';

  @override
  String get virtBackupSelectionList => '選定的虛擬機器';

  @override
  String get virtBackupSelectionNone => '請至少選擇一台虛擬機器。';

  @override
  String get virtBackupMail => '通知';

  @override
  String get virtBackupNotesTemplate => '備份備註';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return '備註會加到該工作產生的每個備份上。其中的 $vars 會被替換為實際值。';
  }

  @override
  String get virtBackupPrune => '保留';

  @override
  String get virtBackupPruneTip =>
      'PVE 的保留選項，例如 keep-last=7,keep-daily=4。留空則用儲存或節點自身的設定。';

  @override
  String get virtBackupJobNode => '節點';

  @override
  String get virtBackupJobNodeAny => '所有節點';

  @override
  String get virtBackupEnabled => '啟用';

  @override
  String get virtBackupOptions => '選項';

  @override
  String get virtBackupProtect => '保護';

  @override
  String get virtBackupProtectTip => '受保護的備份不會被保留策略清理，在取消保護前也無法刪除。';

  @override
  String get virtBackupEditNotes => '備註';

  @override
  String get virtBackupSaveNotes => '儲存';

  @override
  String get virtBackupEdited => '備份已更新';

  @override
  String get virtBackupRestoreStorage => '還原到儲存';

  @override
  String get virtBackupRestoreStorageSame => '與備份一致';

  @override
  String get virtCloneStorageMissing => '該節點上沒有存放虛擬機器磁碟的儲存。';

  @override
  String get virtBackupCompress => '壓縮';

  @override
  String get virtBackupUnprotect => '取消保護';

  @override
  String get virtBackupModeStops => 'suspend 和 stop 會在複製期間中斷執行中的虛擬機器。';

  @override
  String get virtBackupScheduleValidate => '向主機校驗';

  @override
  String virtBackupSelected(int count) {
    return '已選 $count 台';
  }

  @override
  String get virtBackupExcludeTip => '該節點上的所有虛擬機器都會備份。關閉某個即可排除它。';

  @override
  String virtNetEditAsk(int count) {
    return '執行中的網路在重新啟動前維持原樣。重新啟動會中斷其上的 $count 台虛擬機器。';
  }

  @override
  String get virtNetEditAskNoGuest => '執行中的網路在重新啟動前維持原樣。';

  @override
  String get virtNetEditRestart => '立即重新啟動以生效';

  @override
  String get virtNetEditRestartNote => '重新啟動期間其上的虛擬機器將斷網。';

  @override
  String get virtNetEditPending => '設定中已有變更，執行中的網路尚未生效。';

  @override
  String get virtNetRestart => '重新啟動';

  @override
  String virtNetRestartAsk(String name, int count) {
    return '重新啟動 $name？其上的 $count 台虛擬機器將斷網，直到它重新啟動。';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return '重新啟動 $name？其上沒有虛擬機器。';
  }

  @override
  String get virtNetHosts => '靜態位址';

  @override
  String get virtNetHostAdd => '新增位址';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => '位址';

  @override
  String get virtNetHostName => '名稱（選填）';

  @override
  String get virtNetHostEmpty => '未給任何 MAC 分配固定位址：所有虛擬機器都從 DHCP 範圍中取得。';

  @override
  String get virtNetHostOthers => '其餘虛擬機器都從 DHCP 範圍中取得位址。';

  @override
  String get virtNetHostInvalid => '主機系統會拒絕的 MAC、位址或名稱，或同一個 MAC 出現兩次。';

  @override
  String get virtNetManagementIface => '此介面承載主機系統本身的位址。編輯或套用它會中斷主機系統的連線。';

  @override
  String get virtNetManagementTip => '它承載主機的管理流量，或位於承載管理流量的介面之下：應用程式不會編輯它。';

  @override
  String get virtNetPhysicalTip => '實體介面屬於主機本身：應用程式只編輯網橋。';

  @override
  String get virtNetVlanAware => 'VLAN 感知';

  @override
  String get virtCiExpire => '密碼過期';

  @override
  String get virtCiExpireNote =>
      '首次以該密碼登入時必須設定新密碼。僅 libvirt 支援：PVE 固定寫入 \"expire: false\"，沒有對應選項。';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip => '可填多個，以空格分隔；resolv.conf 只保留前幾個。';

  @override
  String virtCiNicsTip(int count) {
    return 'seed 的 network-config 中有 $count 張網路卡；表單編輯第一張。';
  }

  @override
  String get virtUsbByVendor => '依廠商與產品';

  @override
  String get virtUsbByAddress => '依位址';

  @override
  String get virtUsbAddressTip =>
      '裝置跟隨此位址：插在該處的裝置會交給虛擬機器。libvirt 以匯流排與裝置編號標識 USB hostdev。';

  @override
  String virtUsbPortNote(int bus, String port) {
    return '匯流排 $bus · 連接埠 $port';
  }

  @override
  String get virtSbUnsupported =>
      '主機系統的韌體描述檔中沒有帶已註冊金鑰的 Secure Boot 韌體，開啟後虛擬機器無法啟動。';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote => '只引導已簽署的核心與引導程式。';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return '匯流排 $bus · 裝置編號 $device';
  }

  @override
  String get virtHwRevertPendingTitle => '丟棄待生效的變更';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name 將回到正在執行的狀態：以執行中的定義重新寫入設定，下次啟動得到的與這次完全相同。其 NVRAM 檔案與韌體保持不變。';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return '丟棄 $name 所有等待下次啟動的變更？';
  }

  @override
  String get virtBackupPlanNew => '新增計畫';

  @override
  String get virtBackupPlanNewTip => '只備份這台虛擬機器的定時計畫。';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '還備份另外 $count 台虛擬機器',
      zero: '沒有其他虛擬機器',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => '減少動態效果';

  @override
  String get copyLink => '複製連結';

  @override
  String funcNeedsAgentPermission(String func) {
    return '你在此 Monitor agent 上的帳號沒有 $func 的權限，請聯絡該 agent 的管理員。';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func 需要透過 HTTPS 連線此 Monitor agent，或在 agent 和本 App 中同時允許 HTTP。';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '此 Monitor agent 尚未設定 $func，需要由其維運人員設定。';
  }

  @override
  String get monitorFilesReadOnly => '唯讀：此帳號可以瀏覽 agent 上的檔案，但不能修改。';

  @override
  String get monitorAccess => '存取';

  @override
  String get monitorAccounts => '帳號';

  @override
  String get monitorRoles => '角色';

  @override
  String get monitorRole => '角色';

  @override
  String get monitorChangePassword => '變更密碼';

  @override
  String get monitorNewPassword => '新密碼';

  @override
  String get monitorCurrentPassword => '你目前的密碼';

  @override
  String get monitorReauthTip => '變更存取權限需要再次輸入你的密碼。';

  @override
  String get monitorPasswordTooShort => '至少 8 個字元';

  @override
  String get monitorPasswordMismatch => '兩次輸入的密碼不一致';

  @override
  String get monitorErrReauth => '密碼錯誤。';

  @override
  String get monitorErrLastAdmin => 'agent 至少需要一個管理員帳號。';

  @override
  String get monitorErrConflict => '已存在，或仍在使用中。';

  @override
  String get monitorErrForbidden => '只有管理員可以執行此操作。';

  @override
  String get monitorRoleNameRule => '小寫字母、數字、- 和 _，最多 32 個字元';

  @override
  String get monitorGrantShell => 'Shell 和指令';

  @override
  String get monitorGrantShellTip => '終端機、程序、服務、容器、程式碼片段、電源 —— 以 agent 的系統帳號執行';

  @override
  String get monitorGrantSshTerminal => '面板 SSH 終端機';

  @override
  String get monitorGrantFiles => '檔案';

  @override
  String get monitorGrantConnect => '對外連線';

  @override
  String get monitorGrantConnectTip => '本機和動態連接埠轉發、遠端桌面';

  @override
  String get monitorGrantConnectAllow =>
      '允許的目標（IP 或 CIDR，可帶 :連接埠 或 :起-迄；每行一個，留空表示任意）';

  @override
  String get monitorGrantListen => '在伺服器上監聽';

  @override
  String get monitorGrantListenTip => '遠端連接埠轉發';

  @override
  String get monitorGrantListenPublic => '非 loopback 位址';

  @override
  String get monitorGrantPorts => '連接埠範圍（留空表示任意）';

  @override
  String get monitorGrantOff => '關閉';

  @override
  String get monitorBuiltin => '內建';

  @override
  String get monitorAdminRoleTip => '管理帳號、角色和 agent 的設定';

  @override
  String get monitorYou => '你';

  @override
  String get monitorNoAccessToSettings => '只有管理員可以變更此 agent 的設定。';

  @override
  String get monitorPasswordNotSaved =>
      'agent 上的密碼已修改，但 App 未能儲存新密碼。請在這台伺服器的設定中更新 Monitor 密碼。';
}
