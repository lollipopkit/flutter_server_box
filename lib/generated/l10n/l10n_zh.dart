// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get acceptBeta => '接受测试版更新推送';

  @override
  String get addSystemPrivateKeyTip => '检测到暂无私钥，是否添加系统默认的私钥（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已添加至任务列表';

  @override
  String get addr => '地址';

  @override
  String get askAi => '问 AI';

  @override
  String get ai => 'AI';

  @override
  String get askAiApiKey => 'API 密钥';

  @override
  String get askAiAwaitingResponse => '等待 AI 响应...';

  @override
  String get askAiBaseUrl => 'API 接口地址';

  @override
  String get askAiEndpointTip =>
      '填写服务根地址，或完整的 Chat Completions/Responses 地址。ServerBox 会根据所选协议自动补全路径。';

  @override
  String get askAiProtocol => 'API 协议';

  @override
  String get askAiProtocolTip =>
      '自动模式对 OpenAI 官方接口使用 Responses，对兼容服务使用 Chat Completions。';

  @override
  String get askAiProtocolAuto => '自动';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => '命令已插入终端';

  @override
  String askAiConfigMissing(Object fields) {
    return '请前往设置配置 $fields';
  }

  @override
  String get askAiConfirmExecute => '执行前确认';

  @override
  String get askAiConversation => 'AI 对话';

  @override
  String get askAiDisclaimer => 'AI 可能会犯错，请谨慎使用。';

  @override
  String get askAiFollowUpHint => '继续提问...';

  @override
  String get askAiInsertTerminal => '插入终端';

  @override
  String get askAiNoResponse => '无回复内容';

  @override
  String get askAiRecommendedCommand => 'AI 推荐命令';

  @override
  String get askAiSelectedContent => '选中的内容';

  @override
  String get askAiUsageHint => '通过逐步审核的操作诊断并管理当前 SSH 服务器';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => '想在这台服务器上做什么？';

  @override
  String get askAiAgentWelcomeTip =>
      '可以让 Agent 诊断问题或完成任务。Agent 每次只提出一条命令，并在更改系统前等待审核。';

  @override
  String get askAiAgentPromptHint => '让 Agent 检查或修复问题……';

  @override
  String get askAiAgentSend => '发送给 Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      '分析选中的终端内容，解释发生了什么；如果需要操作，请提出最安全的下一步。';

  @override
  String get askAiTerminalContext => '终端上下文';

  @override
  String get askAiReady => '就绪';

  @override
  String get askAiThinking => '思考中';

  @override
  String get askAiRunningCommand => '执行中';

  @override
  String get askAiReviewNeeded => '待审核';

  @override
  String get askAiReviewAction => '审核建议命令';

  @override
  String get askAiReviewBeforeContinuing => '请先审核或拒绝当前建议命令';

  @override
  String get askAiApproveRun => '批准并执行';

  @override
  String get askAiDecline => '拒绝';

  @override
  String get askAiActionDeclined => '已拒绝建议命令。';

  @override
  String get askAiInterrupted => '已中断 Agent 回复。';

  @override
  String get askAiRiskReadOnly => '只读';

  @override
  String get askAiRiskCaution => '会更改系统';

  @override
  String get askAiRiskDestructive => '高风险';

  @override
  String get askAiHighRiskConfirmTitle => '执行高风险命令？';

  @override
  String get askAiHighRiskConfirmBody => '此命令可能删除数据、停止服务或造成难以撤销的更改，请在执行前仔细检查。';

  @override
  String get askAiCommandCancelled => '已取消';

  @override
  String get askAiCommandTimedOut => '执行超时';

  @override
  String get askAiNoCommandOutput => '命令已完成，没有输出。';

  @override
  String get askAiOutputTruncated => '输出过长，回传给 Agent 前已被截断。';

  @override
  String get askAiAutoApproved => '已自动批准';

  @override
  String get askAiAutoRunSafeCommands => '自动执行只读命令';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      '仅当模型与本地安全检查都判定命令为只读时自动执行；会更改系统的命令仍需人工审核。';

  @override
  String get askAiSendOnEnter => 'Enter 发送';

  @override
  String get askAiSendOnEnterTip =>
      'Enter 发送消息，Shift+Enter 换行。关闭后互换：Enter 换行，Cmd/Ctrl+Enter 发送。';

  @override
  String get askAiApiKeyOptional => '本地或无需认证的接口可留空';

  @override
  String get askAiHistory => '对话历史';

  @override
  String get askAiNewConversation => '新建对话';

  @override
  String get askAiNoHistory => '这台服务器还没有已保存的对话';

  @override
  String get askAiNoHistoryMessages => '暂无消息';

  @override
  String get askAiUntitledConversation => '新对话';

  @override
  String get askAiRenameConversation => '重命名对话';

  @override
  String get askAiDeleteConversationTitle => '删除这个对话？';

  @override
  String get askAiDeleteConversationTip => '此操作会从本机删除该对话，且无法撤销。';

  @override
  String get askAiClearHistory => '清空历史';

  @override
  String get askAiClearHistoryTitle => '清空这台服务器的 Agent 历史？';

  @override
  String get askAiClearHistoryTip => '本机为这台服务器保存的所有 Agent 对话都会被删除。';

  @override
  String get askAiRestoredReview => '此命令来自历史记录，请重新审核；恢复后绝不会自动执行。';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => '想对你的服务器做些什么？';

  @override
  String get agentWelcomeTip =>
      '可以让 Agent 诊断问题或执行运维任务。它会读取 ServerBox 的实时状态，并一次提出一个需要审核的操作。';

  @override
  String get agentPromptHint => '让 Agent 检查或操作你的服务器……';

  @override
  String get agentNoServers => '尚未配置服务器';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => '工具执行失败。';

  @override
  String get atLeastOneTab => '至少需要选择一个标签';

  @override
  String get authFailTip => '认证失败，请检查连接信息是否正确';

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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return '最后备份：$lastModified\n状态：$remoteState';
  }

  @override
  String get bgRun => '后台运行';

  @override
  String get bgRunTip =>
      '此开关只代表程序会尝试在后台运行，具体能否后台运行取决于是否开启了权限。原生 Android 请关闭本 App 的“电池优化”，MIUI / HyperOS 请将省电策略改为“无限制”。';

  @override
  String get clearAllStatsContent => '确定要清空所有服务器的连接统计数据吗？此操作无法撤销。';

  @override
  String get clearAllStatsTitle => '清空所有统计';

  @override
  String clearServerStatsContent(Object serverName) {
    return '确定要清空服务器 \"$serverName\" 的连接统计数据吗？此操作无法撤销。';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '清空 $serverName 统计';
  }

  @override
  String get clearThisServerStats => '清空此服务器统计';

  @override
  String get compactDatabase => '压缩数据库';

  @override
  String compactDatabaseContent(Object size) {
    return '数据库大小：$size\n\n此操作将重新组织数据库以减少体积，数据不会丢失。';
  }

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
  String get cpuViewAsProgressTip => '以进度条样式显示每个 CPU 的使用率（旧版样式）';

  @override
  String get configured => '已配置';

  @override
  String get customCmd => '自定义命令';

  @override
  String get deleteServers => '批量删除服务器';

  @override
  String get desktopTerminalTip => '启动 SSH 连接所用的终端模拟器命令';

  @override
  String get dirEmpty => '请确保目录为空';

  @override
  String get discoverSshServers => '发现SSH服务器';

  @override
  String get discoveryFailed => '发现失败';

  @override
  String get discoverySettings => '发现设置';

  @override
  String get discoverySummary => '发现摘要';

  @override
  String get diskHealth => '磁盘健康';

  @override
  String get displayCpuIndex => '显示 CPU 索引';

  @override
  String dl2Local(Object fileName) {
    return '下载 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '没有正在运行的容器。\n这可能是因为：\n- Docker 安装用户与 App 内配置的用户名不同\n- 环境变量 DOCKER_HOST 没有被正确读取。可以通过在终端内运行 `echo \$DOCKER_HOST` 来获取。';

  @override
  String dockerImagesFmt(Object count) {
    return '$count 个镜像';
  }

  @override
  String get dockerProjectOther => '其他';

  @override
  String get dockerPruneTip => '清理未使用的数据以释放磁盘空间';

  @override
  String get dockerStatistics => 'Docker 统计';

  @override
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount 个正在运行, $stoppedCount 个已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count 个容器正在运行';
  }

  @override
  String get doubleColumnMode => '双列模式';

  @override
  String get doubleColumnTip => '此选项仅用于启用该功能，是否生效取决于设备宽度';

  @override
  String get editVirtKeys => '编辑虚拟按键';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '文件 \'$file\' 过大 \'$size\'，超过了 $sizeMax';
  }

  @override
  String get finishedAt => '完成于';

  @override
  String get followSystem => '跟随系统';

  @override
  String get fontSize => '字体大小';

  @override
  String get fullScreen => '全屏模式';

  @override
  String get fullScreenJitter => '全屏模式抖动';

  @override
  String get fullScreenJitterHelp => '用于防止屏幕烧屏';

  @override
  String get fullScreenTip => '当设备旋转为横屏时，是否开启全屏模式。此选项仅作用于服务器 Tab 页。';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'Gist ID（可选）';

  @override
  String get githubGistToken => 'GitHub Gist Token';

  @override
  String get githubGistTokenEmpty => 'Token 为空';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

  @override
  String get hideTitleBar => '隐藏标题栏';

  @override
  String get highlight => '代码高亮';

  @override
  String get homeTabs => '主页标签';

  @override
  String get homeTabsCustomizeDesc => '自定义主页上显示的标签及其顺序';

  @override
  String get homeWidgetUrlConfig => '桌面部件链接配置';

  @override
  String get ignoreCert => '忽略证书';

  @override
  String get image => '镜像';

  @override
  String get imagesList => '镜像列表';

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
  String get pruneDanglingImagesTip => '仅移除悬空镜像（未标记的镜像层）。';

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
  String get volume => '卷';

  @override
  String get pull => '拉取';

  @override
  String get invalid => '无效';

  @override
  String get invalidUrl => '无效的 URL';

  @override
  String get invalidHostFormat => '主机格式无效，仅支持 IPv4、IPv6 和域名字符。';

  @override
  String get jumpServer => '跳板服务器';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '未找到 $serverName 配置的跳板服务器：$jumpIds';
  }

  @override
  String get noJumpServerAvailable => '没有可用的跳板服务器。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '跳板服务器与 ProxyCommand 不能同时使用。';

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
  String madeWithLove(Object myGithub) {
    return '用❤️制作 by $myGithub';
  }

  @override
  String get maxConcurrency => '最大并发数';

  @override
  String get maxRetryCount => '服务器尝试重连次数';

  @override
  String mismatchSystem(Object system) {
    return '系统不匹配：$system';
  }

  @override
  String get more => '更多';

  @override
  String get needRestart => '需要重启 App';

  @override
  String get netViewType => '网络视图类型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noConnectionStatsData => '暂无连接统计数据';

  @override
  String get noLineChart => '不使用折线图';

  @override
  String get noPrivateKeyTip => '私钥不存在，可能已被删除/配置错误';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get onlyOneLine => '仅显示为一行（可滚动）';

  @override
  String get openLastPath => '打开上次的路径';

  @override
  String get openLastPathTip => '将为每台服务器记录其最后访问路径';

  @override
  String get parseContainerStatsTip => 'Docker 解析占用状态较为缓慢';

  @override
  String get fullAccessRefused => '该 agent 未开放免 SSH 访问。';

  @override
  String get fullAccessInsecure =>
      '该 agent 仅在 TLS 或本地回环上开放免 SSH 访问，而当前连接是明文 HTTP。';

  @override
  String get permission => '权限';

  @override
  String get plugInType => '插入类型';

  @override
  String get preferDiskAmount => '优先显示硬盘容量';

  @override
  String get privateKey => '私钥';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return '未找到私钥 [$keyId]。';
  }

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get proxyCommandOnlySupportedOnDesktop => 'ProxyCommand 仅支持桌面平台。';

  @override
  String get pveIgnoreCertTip => '不推荐开启，注意安全隐患！如果你使用的 PVE 默认证书，需要开启该选项';

  @override
  String get pveServerClientMissing => '当前服务器的 SSH 客户端不可用。';

  @override
  String get pveAddressMissing => '未配置 PVE 地址，请在服务器设置中填写。';

  @override
  String get pvePasswordRequired => '需要提供 PVE 密码，请在服务器设置中填写。';

  @override
  String get pveOtpRequired => '此 PVE 服务器已启用双因素认证，请输入 OTP 验证码。';

  @override
  String get pveOtpChallengeExpired => 'OTP 验证挑战已过期，请刷新后重试。';

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
  String get pveVersionLow => '当前该功能处于测试阶段，仅在 PVE 8+ 上测试过，请谨慎使用';

  @override
  String get pveLoadingForwarding => '正在建立 SSH 隧道...';

  @override
  String get pveLoadingLogin => '正在认证 PVE...';

  @override
  String get pveLoadingData => '正在获取集群数据...';

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
  String get reconnecting => '重连中...';

  @override
  String get rememberPwdInMem => '在内存中记住密码';

  @override
  String get rememberPwdInMemTip => '用于容器、挂起等';

  @override
  String get remotePath => '远端路径';

  @override
  String get sameIdServerExist => '已存在相同 id 的服务器';

  @override
  String get save => '保存';

  @override
  String get second => '秒';

  @override
  String get serverDetailOrder => '详情页部件顺序';

  @override
  String get serverFuncBtns => '服务器功能按钮';

  @override
  String get serverOrder => '服务器顺序';

  @override
  String get serverTabRequired => '服务器标签不能被移除';

  @override
  String get shareServerRiskTip =>
      '此二维码以明文包含服务器的连接设置，其中有密码。任何扫描或拍下它的人都能连接到这台服务器。';

  @override
  String get sftpDlPrepare => '准备连接至服务器...';

  @override
  String get sftpEditorTip =>
      '如果为空, 使用App内置的文件编辑器. 如果有值, 这是用远程服务器的编辑器, 例如 `vim` (建议根据 `EDITOR` 自动获取).';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 来删除文件夹';

  @override
  String get sftpSSHConnected => 'SFTP 已连接';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => '文件夹显示在前';

  @override
  String get size => '大小';

  @override
  String get softWrap => '自动换行';

  @override
  String get specifyDev => '指定设备';

  @override
  String get specifyDevTip => '例如网络流量统计默认是所有设备，你可以在这里指定特定的设备';

  @override
  String get tempIsCelsiusTip =>
      '开启后，温度值将被视为摄氏度而非毫摄氏度。仅在温度显示不正确时开启（例如显示0.1°C而非58°C）。';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗时：$time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return '所有服务器已存在（发现 $duplicateCount 个重复项）';
  }

  @override
  String get ssh => 'SSH';

  @override
  String get sshConnectionModeTip => '内置终端：使用应用自带的终端。系统 SSH：在外部终端中调用系统 ssh 命令。';

  @override
  String get sshConnectionModeUseBuiltin => '使用内置终端';

  @override
  String get sshConnectionModeUseSystem => '使用系统 SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount 个重复项将被跳过';
  }

  @override
  String get sshConfigFound => '我们在您的系统中发现了 SSH 配置。';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '发现 $totalCount 个服务器';
  }

  @override
  String get sshConfigImport => 'SSH 配置导入';

  @override
  String get sshConfigImportPermission => '是否允许读取 ~/.ssh/config 并自动导入服务器设置？';

  @override
  String get sshConfigImportTip => '首次创建服务器时提示读取 ~/.ssh/config';

  @override
  String sshConfigImported(Object count) {
    return '从 SSH 配置导入了 $count 个服务器';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '服务器 $serverName 的 SSH 主机密钥已更改，仅在信任该服务器时继续。';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return '指纹（MD5 Base64）：$fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return '指纹（MD5 十六进制）：$fingerprint';
  }

  @override
  String get sshHostKeyType => 'SSH 主机密钥类型';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '收到来自 $serverName 的新 SSH 主机密钥，在信任前请检查指纹。';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
    return '$importCount 个服务器将被导入';
  }

  @override
  String get sshTermHelp =>
      '在终端可滚动时，横向拖动可以选中文字。点击键盘按钮可以开启/关闭键盘。文件图标会打开当前路径 SFTP。剪切板按钮会在有选中文字时复制内容，在未选中并且剪切板有内容时粘贴内容到终端。代码图标会粘贴代码片段到终端并执行。';

  @override
  String get sshVirtualKeyAutoOff => '虚拟按键自动切换';

  @override
  String get stat => '统计';

  @override
  String get supportFmtArgs => '支持以下格式化参数：';

  @override
  String get suspendTip => 'suspend 功能需要 root 权限及 systemd 支持。';

  @override
  String switchTo(Object val) {
    return '切换到 $val';
  }

  @override
  String get syncAppSettings => '同步应用设置';

  @override
  String get syncAppSettingsTip => '在自动同步中包含主题、布局、编辑器、终端等设备偏好设置。';

  @override
  String get system => '系统';

  @override
  String get termFontSizeTip => '此设置会影响终端大小（宽和高）。可以在终端页面缩放来调整当前会话的字体大小';

  @override
  String get textScaler => '字体缩放';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），仅作用于服务器页面部分字体，不建议修改。';

  @override
  String get time => '时间';

  @override
  String get times => '次';

  @override
  String get trySudo => '尝试使用 sudo';

  @override
  String get sudoPromptNotFound => '当前没有 sudo 密码提示。';

  @override
  String get unknown => '未知';

  @override
  String get updateServerStatusInterval => '服务器状态刷新间隔';

  @override
  String get useNoPwd => '将会使用无密码';

  @override
  String get usePodmanByDefault => '默认使用 Podman';

  @override
  String get used => '已用';

  @override
  String get view => '视图';

  @override
  String get viewDetails => '查看详情';

  @override
  String get viewErr => '查看错误';

  @override
  String get virtKeyHelpClipboard => '如果终端有选中字符，则复制选中字符至剪切板，否则粘贴剪切板内容至终端。';

  @override
  String get virtKeyHelpIME => '打开/关闭键盘';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打开当前路径。';

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
  String get wiki => 'Wiki';

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
  String get portForwardBeta => '此功能仍在测试阶段，不保证功能可用性。';

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
  String get portForward_type_local => '本地';

  @override
  String get portForward_type_remote => '远程';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '删除 $name？';
  }

  @override
  String get sponsor => '赞助';

  @override
  String get sort => '排序';

  @override
  String get sortByName => '按名称';

  @override
  String get sortByJoinTime => '按加入时间';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get serverHistory => '服务器历史';

  @override
  String get clearHistory => '清空历史';

  @override
  String get portForwardBetaTitle => '端口映射 (Beta)';

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
  String get tmuxExistingSessions => '现有会话';

  @override
  String get tmuxNewSession => '新建会话';

  @override
  String get tmuxWindows => '窗口';

  @override
  String get tmuxNewWindow => '新建窗口';

  @override
  String get tmuxNoWindowsFound => '未找到窗口';

  @override
  String tmuxWindowCount(int count) {
    return '$count 个窗口';
  }

  @override
  String tmuxPaneCount(int count) {
    return '$count 个窗格';
  }

  @override
  String get tmuxAttached => '已附加';

  @override
  String get tmuxActive => '活动中';

  @override
  String tmuxActiveAt(String time) {
    return '活动：$time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return '附加：$time';
  }

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
  String get systemd => 'Systemd';

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
  String get watchServers => '手表上的服务器';

  @override
  String get watchServersTip =>
      '手表自己向 monitor agent 取数据，所以只能选择已配置 monitor 的服务器。';

  @override
  String get watchNoMonitorServer => '没有服务器配置了 monitor';

  @override
  String get watchLegacyUrls => '旧版 status 链接';

  @override
  String get accessoryWidgetServer => '锁屏小组件服务器';

  @override
  String get systemdMissing => '此服务器没有 systemd';

  @override
  String get systemdMissingTip => '机器上没有安装 `systemctl`，因此没有 unit 可列。';

  @override
  String initSystemFmt(String init) {
    return '这台机器似乎使用 $init。';
  }

  @override
  String get systemdListFailed => '无法列出 unit';

  @override
  String get systemdUserScopeMissing => '未列出用户 unit';

  @override
  String get systemdUserScopeMissingTip => '该账户在服务器上没有用户会话总线，因此只显示系统 unit。';

  @override
  String get serverUnreachable => '无法在此服务器上执行命令';

  @override
  String get containerNoRuntime => '此处没有容器运行时';

  @override
  String get containerNoRuntimeTip =>
      '这台机器上 `docker` 和 `podman` 都没有响应。如果它装在另一个账户下，请在设置中开启「尝试使用 sudo」。';

  @override
  String get containerUnreadable => '容器运行时返回了无法解析的内容';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get acceptBeta => '接受測試版更新推送';

  @override
  String get addSystemPrivateKeyTip => '偵測到尚無私鑰，是否要加入系統預設的私鑰（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已新增至任務清單';

  @override
  String get addr => '位址';

  @override
  String get askAi => '詢問 AI';

  @override
  String get ai => 'AI';

  @override
  String get askAiApiKey => 'API 金鑰';

  @override
  String get askAiAwaitingResponse => '等待 AI 回應...';

  @override
  String get askAiBaseUrl => 'API 介面位址';

  @override
  String get askAiEndpointTip =>
      '填寫服務根位址，或完整的 Chat Completions/Responses 位址。ServerBox 會依所選協議自動補全路徑。';

  @override
  String get askAiProtocol => 'API 協議';

  @override
  String get askAiProtocolTip =>
      '自動模式對 OpenAI 官方介面使用 Responses，對相容服務使用 Chat Completions。';

  @override
  String get askAiProtocolAuto => '自動';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => '指令已插入終端機';

  @override
  String askAiConfigMissing(Object fields) {
    return '請前往設定配置 $fields';
  }

  @override
  String get askAiConfirmExecute => '執行前確認';

  @override
  String get askAiConversation => 'AI 對話';

  @override
  String get askAiDisclaimer => 'AI 可能會犯錯，請謹慎使用。';

  @override
  String get askAiFollowUpHint => '繼續提問...';

  @override
  String get askAiInsertTerminal => '插入終端機';

  @override
  String get askAiNoResponse => '無回覆內容';

  @override
  String get askAiRecommendedCommand => 'AI 推薦指令';

  @override
  String get askAiSelectedContent => '選取的內容';

  @override
  String get askAiUsageHint => '透過逐步審核的操作診斷並管理目前 SSH 伺服器';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => '想在這台伺服器上做什麼？';

  @override
  String get askAiAgentWelcomeTip =>
      '可以讓 Agent 診斷問題或完成工作。Agent 每次只提出一條指令，並在變更系統前等待審核。';

  @override
  String get askAiAgentPromptHint => '讓 Agent 檢查或修復問題……';

  @override
  String get askAiAgentSend => '傳送給 Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      '分析選取的終端機內容，解釋發生了什麼；如果需要操作，請提出最安全的下一步。';

  @override
  String get askAiTerminalContext => '終端機內容';

  @override
  String get askAiReady => '就緒';

  @override
  String get askAiThinking => '思考中';

  @override
  String get askAiRunningCommand => '執行中';

  @override
  String get askAiReviewNeeded => '待審核';

  @override
  String get askAiReviewAction => '審核建議指令';

  @override
  String get askAiReviewBeforeContinuing => '請先審核或拒絕目前的建議指令';

  @override
  String get askAiApproveRun => '核准並執行';

  @override
  String get askAiDecline => '拒絕';

  @override
  String get askAiActionDeclined => '已拒絕建議指令。';

  @override
  String get askAiInterrupted => '已中斷 Agent 回覆。';

  @override
  String get askAiRiskReadOnly => '唯讀';

  @override
  String get askAiRiskCaution => '會變更系統';

  @override
  String get askAiRiskDestructive => '高風險';

  @override
  String get askAiHighRiskConfirmTitle => '執行高風險指令？';

  @override
  String get askAiHighRiskConfirmBody => '此指令可能刪除資料、停止服務或造成難以復原的變更，請在執行前仔細檢查。';

  @override
  String get askAiCommandCancelled => '已取消';

  @override
  String get askAiCommandTimedOut => '執行逾時';

  @override
  String get askAiNoCommandOutput => '指令已完成，沒有輸出。';

  @override
  String get askAiOutputTruncated => '輸出過長，傳回 Agent 前已被截斷。';

  @override
  String get askAiAutoApproved => '已自動核准';

  @override
  String get askAiAutoRunSafeCommands => '自動執行唯讀指令';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      '僅當模型與本機安全檢查都判定指令為唯讀時自動執行；會變更系統的指令仍需人工審核。';

  @override
  String get askAiSendOnEnter => 'Enter 傳送';

  @override
  String get askAiSendOnEnterTip =>
      'Enter 傳送訊息，Shift+Enter 換行。關閉後互換：Enter 換行，Cmd/Ctrl+Enter 傳送。';

  @override
  String get askAiApiKeyOptional => '本機或不需驗證的介面可留空';

  @override
  String get askAiHistory => '對話歷史';

  @override
  String get askAiNewConversation => '新增對話';

  @override
  String get askAiNoHistory => '這台伺服器尚無已儲存的對話';

  @override
  String get askAiNoHistoryMessages => '暫無訊息';

  @override
  String get askAiUntitledConversation => '新對話';

  @override
  String get askAiRenameConversation => '重新命名對話';

  @override
  String get askAiDeleteConversationTitle => '刪除這個對話？';

  @override
  String get askAiDeleteConversationTip => '此操作會從本機刪除該對話，且無法復原。';

  @override
  String get askAiClearHistory => '清除歷史';

  @override
  String get askAiClearHistoryTitle => '清除這台伺服器的 Agent 歷史？';

  @override
  String get askAiClearHistoryTip => '本機為這台伺服器儲存的所有 Agent 對話都會被刪除。';

  @override
  String get askAiRestoredReview => '此指令來自歷史記錄，請重新審核；恢復後絕不會自動執行。';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => '想對你的伺服器做些什麼？';

  @override
  String get agentWelcomeTip =>
      '可以讓 Agent 診斷問題或執行維運工作。它會讀取 ServerBox 的即時狀態，並一次提出一個需要審核的操作。';

  @override
  String get agentPromptHint => '讓 Agent 檢查或操作你的伺服器……';

  @override
  String get agentNoServers => '尚未設定伺服器';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => '工具執行失敗。';

  @override
  String get atLeastOneTab => '至少需要選擇一個標籤';

  @override
  String get authFailTip => '認證失敗，請檢查連線資訊是否正確';

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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return '最後備份：$lastModified\n狀態：$remoteState';
  }

  @override
  String get bgRun => '背景執行';

  @override
  String get bgRunTip =>
      '此開關僅代表程式會嘗試於背景執行，能否成功取決於系統權限。在原生 Android 上，請關閉本應用的「電池最佳化」；在 MIUI / HyperOS 上，請將省電策略調整為「無限制」。';

  @override
  String get clearAllStatsContent => '確定要清空所有伺服器的連線統計資料嗎？此操作無法撤銷。';

  @override
  String get clearAllStatsTitle => '清空所有統計';

  @override
  String clearServerStatsContent(Object serverName) {
    return '確定要清空伺服器 \"$serverName\" 的連線統計資料嗎？此操作無法撤銷。';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '清空 $serverName 統計';
  }

  @override
  String get clearThisServerStats => '清空此伺服器統計';

  @override
  String get compactDatabase => '壓縮資料庫';

  @override
  String compactDatabaseContent(Object size) {
    return '資料庫大小：$size\n\n此操作將重新組織資料庫以減少體積，資料不會遺失。';
  }

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
  String get cpuViewAsProgressTip => '以進度條樣式顯示每個CPU的使用率（舊版樣式）';

  @override
  String get configured => '已設定';

  @override
  String get customCmd => '自訂指令';

  @override
  String get deleteServers => '大量刪除伺服器';

  @override
  String get desktopTerminalTip => '啟動 SSH 連線時用於打開終端機模擬器的指令。';

  @override
  String get dirEmpty => '請確保目錄為空';

  @override
  String get discoverSshServers => '發現SSH服務器';

  @override
  String get discoveryFailed => '發現失敗';

  @override
  String get discoverySettings => '發現設定';

  @override
  String get discoverySummary => '發現摘要';

  @override
  String get diskHealth => '磁碟健康';

  @override
  String get displayCpuIndex => '顯示 CPU 索引';

  @override
  String dl2Local(Object fileName) {
    return '下載 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '沒有正在執行的容器。\n這可能是因為：\n- Docker 安裝使用者與 App 內配置的使用者名稱不同\n- 環境變數 DOCKER_HOST 沒有被正確讀取。你可以通過在終端機內執行 `echo \$DOCKER_HOST` 來獲取。';

  @override
  String dockerImagesFmt(Object count) {
    return '$count 個映像檔';
  }

  @override
  String get dockerProjectOther => '其他';

  @override
  String get dockerPruneTip => '清理未使用的資料以釋放磁碟空間';

  @override
  String get dockerStatistics => 'Docker 統計';

  @override
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount 個正在執行, $stoppedCount 個已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count 個容器正在執行';
  }

  @override
  String get doubleColumnMode => '雙列模式';

  @override
  String get doubleColumnTip => '此選項僅用於啟用此功能，是否生效取決於裝置寬度';

  @override
  String get editVirtKeys => '編輯虛擬按鍵';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '檔案 \'$file\' 過大 \'$size\'，超過了 $sizeMax';
  }

  @override
  String get finishedAt => '完成於';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get fontSize => '字型大小';

  @override
  String get fullScreen => '全螢幕模式';

  @override
  String get fullScreenJitter => '全螢幕模式抖動';

  @override
  String get fullScreenJitterHelp => '防止螢幕烙印';

  @override
  String get fullScreenTip => '當設備旋轉為橫向時，是否開啟全螢幕模式？此選項僅適用於伺服器分頁。';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'Gist ID（選填）';

  @override
  String get githubGistToken => 'GitHub Gist Token';

  @override
  String get githubGistTokenEmpty => 'Token 為空';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

  @override
  String get hideTitleBar => '隱藏標題欄';

  @override
  String get highlight => '程式碼標記';

  @override
  String get homeTabs => '主頁標籤';

  @override
  String get homeTabsCustomizeDesc => '自訂主頁上顯示的標籤及其順序';

  @override
  String get homeWidgetUrlConfig => '桌面小工具連結配置';

  @override
  String get ignoreCert => '忽略憑證';

  @override
  String get image => '映像檔';

  @override
  String get imagesList => '映像檔列表';

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
  String get pruneDanglingImagesTip => '僅移除懸空映像檔（未標記的映像層）。';

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
  String get volume => '卷';

  @override
  String get pull => '拉取';

  @override
  String get invalid => '無效';

  @override
  String get invalidUrl => '無效的網址';

  @override
  String get invalidHostFormat => '主機格式無效，僅支援 IPv4、IPv6 和網域字元。';

  @override
  String get jumpServer => '跳板伺服器';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '未找到 $serverName 配置的跳板伺服器：$jumpIds';
  }

  @override
  String get noJumpServerAvailable => '沒有可用的跳板伺服器。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '跳板伺服器與 ProxyCommand 不能同時使用。';

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
  String madeWithLove(Object myGithub) {
    return '用❤️製作 by $myGithub';
  }

  @override
  String get maxConcurrency => '最大並發數';

  @override
  String get maxRetryCount => '伺服器嘗試重連次數';

  @override
  String mismatchSystem(Object system) {
    return '系統不匹配：$system';
  }

  @override
  String get more => '更多';

  @override
  String get needRestart => '需要重開 App';

  @override
  String get netViewType => '網路檢視類型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noConnectionStatsData => '暫無連線統計資料';

  @override
  String get noLineChart => '不使用折線圖';

  @override
  String get noPrivateKeyTip => '私鑰不存在，可能已被刪除/配置錯誤。';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get onlyOneLine => '僅顯示為一行（可捲動）';

  @override
  String get openLastPath => '打開上次的路徑';

  @override
  String get openLastPathTip => '將為每台伺服器紀錄其最後存取路徑';

  @override
  String get parseContainerStatsTip => 'Docker 解析消耗狀態較為緩慢';

  @override
  String get fullAccessRefused => '該 agent 未開放免 SSH 存取。';

  @override
  String get fullAccessInsecure =>
      '該 agent 僅在 TLS 或本機回環上開放免 SSH 存取，而目前連線是明文 HTTP。';

  @override
  String get permission => '權限';

  @override
  String get plugInType => '插入類型';

  @override
  String get preferDiskAmount => '優先顯示硬碟容量';

  @override
  String get privateKey => '私鑰';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return '未找到私鑰 [$keyId]。';
  }

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get proxyCommandOnlySupportedOnDesktop => 'ProxyCommand 僅支援桌面平台。';

  @override
  String get pveIgnoreCertTip => '不建議啟用，請注意安全風險！如果您使用的是 PVE 的預設憑證，則需要啟用此選項。';

  @override
  String get pveServerClientMissing => '目前伺服器的 SSH 用戶端不可用。';

  @override
  String get pveAddressMissing => '未設定 PVE 位址，請在伺服器設定中填寫。';

  @override
  String get pvePasswordRequired => '需要提供 PVE 密碼，請在伺服器設定中填寫。';

  @override
  String get pveOtpRequired => '此 PVE 伺服器已啟用雙因素認證，請輸入 OTP 驗證碼。';

  @override
  String get pveOtpChallengeExpired => 'OTP 驗證挑戰已過期，請重新整理後再試一次。';

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
  String get pveVersionLow => '此功能目前處於測試階段，僅在 PVE 8+ 上進行過測試。請謹慎使用。';

  @override
  String get pveLoadingForwarding => '正在建立 SSH 隧道...';

  @override
  String get pveLoadingLogin => '正在認證 PVE...';

  @override
  String get pveLoadingData => '正在獲取集群數據...';

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
  String get reconnecting => '重連中...';

  @override
  String get rememberPwdInMem => '在記憶體中記住密碼';

  @override
  String get rememberPwdInMemTip => '用於容器、暫停等';

  @override
  String get remotePath => '遠端路徑';

  @override
  String get sameIdServerExist => '已存在相同 ID 的伺服器';

  @override
  String get save => '儲存';

  @override
  String get second => '秒';

  @override
  String get serverDetailOrder => '詳情頁部件順序';

  @override
  String get serverFuncBtns => '伺服器功能按鈕';

  @override
  String get serverOrder => '伺服器順序';

  @override
  String get serverTabRequired => '服務器標籤不能被移除';

  @override
  String get shareServerRiskTip =>
      '此二維碼以明文包含伺服器的連線設定，其中有密碼。任何掃描或拍下它的人都能連線到這台伺服器。';

  @override
  String get sftpDlPrepare => '準備連線至伺服器...';

  @override
  String get sftpEditorTip =>
      '如果為空, 使用App內建的檔案編輯器。如果有值, 則使用遠端伺服器的編輯器, 例如 `vim`（建議根據 `EDITOR` 自動獲取）。';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 來刪除檔案夾';

  @override
  String get sftpSSHConnected => 'SFTP 已連線';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => '資料夾顯示在前';

  @override
  String get size => '大小';

  @override
  String get softWrap => '軟換行';

  @override
  String get specifyDev => '指定裝置';

  @override
  String get specifyDevTip => '例如網路流量統計預設是所有裝置，你可以在這裡指定特定的裝置。';

  @override
  String get tempIsCelsiusTip =>
      '啟用後，溫度值會以攝氏度而非毫攝氏度處理。僅在溫度顯示錯誤時開啟（例如顯示 0.1°C 而非 58°C）。';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗時：$time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return '所有伺服器均已存在（發現$duplicateCount個重複項）';
  }

  @override
  String get ssh => 'SSH';

  @override
  String get sshConnectionModeTip => '內建：使用 App 的終端。系統 SSH：在外部終端中啟動系統的 ssh 指令。';

  @override
  String get sshConnectionModeUseBuiltin => '使用內建終端';

  @override
  String get sshConnectionModeUseSystem => '使用系統 SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '將跳過$duplicateCount個重複項';
  }

  @override
  String get sshConfigFound => '我們在您的系統中發現了SSH設定';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '發現$totalCount個伺服器';
  }

  @override
  String get sshConfigImport => '匯入SSH設定';

  @override
  String get sshConfigImportPermission => '您是否希望允許讀取 ~/.ssh/config 並自動匯入伺服器設定？';

  @override
  String get sshConfigImportTip => '在建立第一個伺服器時提示讀取 ~/.ssh/config';

  @override
  String sshConfigImported(Object count) {
    return '已從SSH設定匯入$count個伺服器';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '伺服器 $serverName 的 SSH 主機金鑰已變更，僅在信任該伺服器時繼續。';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return '指紋（MD5 Base64）：$fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return '指紋（MD5 十六進位）：$fingerprint';
  }

  @override
  String get sshHostKeyType => 'SSH 主機金鑰類型';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '收到來自 $serverName 的新 SSH 主機金鑰，信任前請先檢查指紋。';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
    return '將匯入$importCount個伺服器';
  }

  @override
  String get sshTermHelp =>
      '在終端機可捲動時，橫向拖動可以選中文字。點擊鍵盤按鈕可以開啟/關閉鍵盤。檔案圖示會打開目前路徑 SFTP。剪貼簿按鈕會在有選中文字時複製內容，在未選中並且剪貼簿有內容時貼上內容到終端機。程式碼圖示會貼上程式碼片段到終端機並執行。';

  @override
  String get sshVirtualKeyAutoOff => '虛擬按鍵自動切換';

  @override
  String get stat => '統計';

  @override
  String get supportFmtArgs => '支援以下格式化參數：';

  @override
  String get suspendTip => 'suspend 功能需要 root 權限及 systemd 支援。';

  @override
  String switchTo(Object val) {
    return '切換到 $val';
  }

  @override
  String get syncAppSettings => '同步 App 設定';

  @override
  String get syncAppSettingsTip => '將主題、版面配置、編輯器、終端等裝置偏好一併納入自動同步。';

  @override
  String get system => '系統';

  @override
  String get termFontSizeTip => '此設定將影響終端機大小（寬度和高度）。您可以在終端機頁面縮放，來調整目前會話的字型大小。';

  @override
  String get textScaler => '字型縮放';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），僅作用於伺服器頁面部分字型，不建議修改。';

  @override
  String get time => '時間';

  @override
  String get times => '次';

  @override
  String get trySudo => '嘗試使用 sudo';

  @override
  String get sudoPromptNotFound => '目前沒有 sudo 密碼提示。';

  @override
  String get unknown => '未知';

  @override
  String get updateServerStatusInterval => '伺服器狀態更新間隔';

  @override
  String get useNoPwd => '將使用無密碼';

  @override
  String get usePodmanByDefault => '預設使用 Podman';

  @override
  String get used => '已使用';

  @override
  String get view => '檢視';

  @override
  String get viewDetails => '檢視詳情';

  @override
  String get viewErr => '查看錯誤';

  @override
  String get virtKeyHelpClipboard => '如果終端機有選中字元，則復製選中字元至剪貼簿，否則貼上剪貼簿內容至終端機。';

  @override
  String get virtKeyHelpIME => '打開/關閉鍵盤';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打開目前路徑。';

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
  String get wiki => 'Wiki';

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
  String get portForwardBeta => '此功能仍在 Beta 測試階段，不保證可正常運作。';

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
  String get portForward_type_local => '本機';

  @override
  String get portForward_type_remote => '遠端';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '刪除 $name？';
  }

  @override
  String get sponsor => '贊助';

  @override
  String get sort => '排序';

  @override
  String get sortByName => '依名稱';

  @override
  String get sortByJoinTime => '依加入時間';

  @override
  String get ascending => '遞增';

  @override
  String get descending => '遞減';

  @override
  String get serverHistory => '伺服器紀錄';

  @override
  String get clearHistory => '清除紀錄';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

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
  String get tmuxExistingSessions => '現有工作階段';

  @override
  String get tmuxNewSession => '新增工作階段';

  @override
  String get tmuxWindows => '視窗';

  @override
  String get tmuxNewWindow => '新增視窗';

  @override
  String get tmuxNoWindowsFound => '找不到視窗';

  @override
  String tmuxWindowCount(int count) {
    return '$count 個視窗';
  }

  @override
  String tmuxPaneCount(int count) {
    return '$count 個窗格';
  }

  @override
  String get tmuxAttached => '已附加';

  @override
  String get tmuxActive => '使用中';

  @override
  String tmuxActiveAt(String time) {
    return '活動：$time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return '附加：$time';
  }

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
  String get systemd => 'Systemd';

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
  String get watchServers => '手錶上的伺服器';

  @override
  String get watchServersTip =>
      '手錶自己向 monitor agent 取資料，因此只能選擇已設定 monitor 的伺服器。';

  @override
  String get watchNoMonitorServer => '沒有伺服器設定了 monitor';

  @override
  String get watchLegacyUrls => '舊版 status 連結';

  @override
  String get accessoryWidgetServer => '鎖定畫面小工具伺服器';

  @override
  String get systemdMissing => '此伺服器沒有 systemd';

  @override
  String get systemdMissingTip => '機器上沒有安裝 `systemctl`，因此沒有 unit 可列。';

  @override
  String initSystemFmt(String init) {
    return '這台機器似乎使用 $init。';
  }

  @override
  String get systemdListFailed => '無法列出 unit';

  @override
  String get systemdUserScopeMissing => '未列出使用者 unit';

  @override
  String get systemdUserScopeMissingTip => '該帳號在伺服器上沒有使用者工作階段匯流排，因此只顯示系統 unit。';

  @override
  String get serverUnreachable => '無法在此伺服器上執行命令';

  @override
  String get containerNoRuntime => '此處沒有容器執行環境';

  @override
  String get containerNoRuntimeTip =>
      '這台機器上 `docker` 和 `podman` 都沒有回應。如果它裝在另一個帳號下，請在設定中開啟「嘗試使用 sudo」。';

  @override
  String get containerUnreadable => '容器執行環境回傳了無法解析的內容';
}
