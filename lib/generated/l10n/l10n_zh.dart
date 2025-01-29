import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get aboutThanks => '感谢以下参与的各位。';

  @override
  String get acceptBeta => '接受测试版更新推送';

  @override
  String get addSystemPrivateKeyTip => '当前没有任何私钥，是否添加系统自带的（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已添加至任务列表';

  @override
  String get addr => '地址';

  @override
  String get alreadyLastDir => '已经是最上层目录了';

  @override
  String get authFailTip => '认证失败，请检查密码/密钥/主机/用户等是否错误';

  @override
  String get autoBackupConflict => '只能同时开启一个自动备份';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoRun => '自动运行';

  @override
  String get autoUpdateHomeWidget => '自动更新桌面小部件';

  @override
  String get backupTip => '导出的数据仅进行了简单加密，请妥善保管。';

  @override
  String get backupVersionNotMatch => '备份版本不匹配，无法恢复';

  @override
  String get battery => '电池';

  @override
  String get bgRun => '后台运行';

  @override
  String get bgRunTip => '此开关只代表程序会尝试在后台运行，具体能否后台运行取决于是否开启了权限。原生 Android 请关闭本 App 的“电池优化”，MIUI / HyperOS 请修改省电策略为“无限制”。';

  @override
  String get closeAfterSave => '保存后关闭';

  @override
  String get cmd => '命令';

  @override
  String get collapseUITip => '是否默认折叠 UI 中的长列表';

  @override
  String get conn => '连接';

  @override
  String get container => '容器';

  @override
  String get containerTrySudoTip => '例如：在应用内将用户设置为 aaa，但是 Docker 安装在root用户下，这时就需要启用此选项';

  @override
  String get convert => '转换';

  @override
  String get copyPath => '复制路径';

  @override
  String get cpuViewAsProgressTip => '以进度条样式显示每个 CPU 的使用率（旧版样式）';

  @override
  String get cursorType => '光标类型';

  @override
  String get customCmd => '自定义命令';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki/主页#自定义命令';

  @override
  String get customCmdHint => '\"命令名称\": \"命令\"';

  @override
  String get decode => '解码';

  @override
  String get decompress => '解压缩';

  @override
  String get deleteServers => '批量删除服务器';

  @override
  String get dirEmpty => '请确保文件夹为空';

  @override
  String get disconnected => '连接断开';

  @override
  String get disk => '磁盘';

  @override
  String get diskIgnorePath => '忽略的磁盘路径';

  @override
  String get displayCpuIndex => '显示 CPU 索引';

  @override
  String dl2Local(Object fileName) {
    return '下载 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems => '没有正在运行的容器。\n这可能是因为：\n- Docker 安装用户与 App 内配置的用户名不同\n- 环境变量 DOCKER_HOST 没有被正确读取。可以通过在终端内运行 `echo \$DOCKER_HOST` 来获取。';

  @override
  String dockerImagesFmt(Object count) {
    return '共 $count 个镜像';
  }

  @override
  String get dockerNotInstalled => 'Docker 未安装';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount 个正在运行, $stoppedCount 个已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count 个容器正在运行';
  }

  @override
  String get doubleColumnMode => '双列模式';

  @override
  String get doubleColumnTip => '此选项仅开启功能，实际是否能开启还取决于设备的宽度';

  @override
  String get editVirtKeys => '编辑虚拟按键';

  @override
  String get editor => '编辑器';

  @override
  String get editorHighlightTip => '目前的代码高亮性能较为糟糕，可以选择关闭以改善。';

  @override
  String get encode => '编码';

  @override
  String get envVars => '环境变量';

  @override
  String get experimentalFeature => '实验性功能';

  @override
  String get extraArgs => '额外参数';

  @override
  String get fallbackSshDest => '备选 SSH 目标';

  @override
  String get fdroidReleaseTip => '如果你是从 F-Droid 下载的本应用，推荐关闭此选项';

  @override
  String get fgService => '前台服务';

  @override
  String get fgServiceTip => '开启后，可能会导致部分机型闪退。关闭可能导致部分机型无法后台保持 SSH 连接。请在系统设置内允许 ServerBox 通知权限、后台运行、自我唤醒。';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '文件 \'$file\' 过大 \'$size\'，超过了 $sizeMax';
  }

  @override
  String get followSystem => '跟随系统';

  @override
  String get font => '字体';

  @override
  String get fontSize => '字体大小';

  @override
  String get force => '强制';

  @override
  String get fullScreen => '全屏模式';

  @override
  String get fullScreenJitter => '全屏模式抖动';

  @override
  String get fullScreenJitterHelp => '防止烧屏';

  @override
  String get fullScreenTip => '当设备旋转为横屏时，是否开启全屏模式。此选项仅作用于服务器 Tab 页。';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

  @override
  String get hideTitleBar => '隐藏标题栏';

  @override
  String get highlight => '代码高亮';

  @override
  String get homeWidgetUrlConfig => '桌面部件链接配置';

  @override
  String get host => '主机';

  @override
  String httpFailedWithCode(Object code) {
    return '请求失败, 状态码: $code';
  }

  @override
  String get ignoreCert => '忽略证书';

  @override
  String get image => '镜像';

  @override
  String get imagesList => '镜像列表';

  @override
  String get init => '初始化';

  @override
  String get inner => '内置';

  @override
  String get install => '安装';

  @override
  String get installDockerWithUrl => '请先 https://docs.docker.com/engine/install docker';

  @override
  String get invalid => '无效';

  @override
  String get jumpServer => '跳板服务器';

  @override
  String get keepForeground => '请保持应用处于前台！';

  @override
  String get keepStatusWhenErr => '保留上次的服务器状态';

  @override
  String get keepStatusWhenErrTip => '仅限于执行脚本出错';

  @override
  String get keyAuth => '密钥认证';

  @override
  String get letterCache => '输入法字符缓存';

  @override
  String get letterCacheTip => '推荐关闭，但是关闭后无法输入 CJK 等文字';

  @override
  String get license => '证书';

  @override
  String get location => '位置';

  @override
  String get loss => '丢包率';

  @override
  String madeWithLove(Object myGithub) {
    return '用❤️制作 by $myGithub';
  }

  @override
  String get manual => '手动';

  @override
  String get max => '最大';

  @override
  String get maxRetryCount => '服务器尝试重连次数';

  @override
  String get maxRetryCountEqual0 => '会无限重试';

  @override
  String get min => '最小';

  @override
  String get mission => '任务';

  @override
  String get more => '更多';

  @override
  String get moveOutServerFuncBtnsHelp => '开启：可以在服务器 Tab 页的每个卡片下方显示。关闭：在服务器详情页顶部显示。';

  @override
  String get ms => '毫秒';

  @override
  String get needHomeDir => '如果你是群晖用户，[看这里](https://kb.synology.cn/zh-cn/DSM/tutorial/ssh_could_not_chdir_to_home_directory)。其他系统用户，需搜索如何创建家目录（home directory）.';

  @override
  String get needRestart => '需要重启 App';

  @override
  String get net => '网络';

  @override
  String get netViewType => '网络视图类型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noLineChart => '不使用折线图';

  @override
  String get noLineChartForCpu => 'CPU 不使用折线图';

  @override
  String get noPrivateKeyTip => '私钥不存在，可能已被删除/配置错误';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get node => '节点';

  @override
  String get notAvailable => '不可用';

  @override
  String get onServerDetailPage => '在服务器详情页';

  @override
  String get onlyOneLine => '仅显示为一行（可滚动）';

  @override
  String get onlyWhenCoreBiggerThan8 => '仅当核心数大于 8 时生效';

  @override
  String get openLastPath => '打开上次的路径';

  @override
  String get openLastPathTip => '不同的服务器会有不同的记录，且记录的是退出时的路径';

  @override
  String get parseContainerStatsTip => 'Docker 解析占用状态较为缓慢';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size 的 $percent%';
  }

  @override
  String get permission => '权限';

  @override
  String get pingAvg => '平均:';

  @override
  String get pingInputIP => '请输入目标IP或域名';

  @override
  String get pingNoServer => '没有服务器可用于 Ping\n请在服务器 tab 添加服务器后再试';

  @override
  String get pkg => '包管理';

  @override
  String get plugInType => '插入类型';

  @override
  String get port => '端口';

  @override
  String get preview => '预览';

  @override
  String get privateKey => '私钥';

  @override
  String get process => '进程';

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get pveIgnoreCertTip => '不推荐开启，注意安全隐患！如果你使用的 PVE 默认证书，需要开启该选项';

  @override
  String get pveLoginFailed => '登录失败。无法使用服务器配置内的用户/密码，以 Linux PAM 方式登录。';

  @override
  String get pveVersionLow => '当前该功能处于测试阶段，仅在 PVE 8+ 上测试过，请谨慎使用';

  @override
  String get pwd => '密码';

  @override
  String get read => '读';

  @override
  String get reboot => '重启';

  @override
  String get rememberPwdInMem => '在内存中记住密码';

  @override
  String get rememberPwdInMemTip => '用于容器、挂起等';

  @override
  String get rememberWindowSize => '记住窗口大小';

  @override
  String get remotePath => '远端路径';

  @override
  String get restart => '重启';

  @override
  String get result => '结果';

  @override
  String get rotateAngel => '旋转角度';

  @override
  String get route => '路由';

  @override
  String get run => '运行';

  @override
  String get running => '运行中';

  @override
  String get sameIdServerExist => '已存在相同 id 的服务器';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get second => '秒';

  @override
  String get sensors => '传感器';

  @override
  String get sequence => '顺序';

  @override
  String get server => '服务器';

  @override
  String get serverDetailOrder => '详情页部件顺序';

  @override
  String get serverFuncBtns => '服务器功能按钮';

  @override
  String get serverOrder => '服务器顺序';

  @override
  String get sftpDlPrepare => '准备连接至服务器...';

  @override
  String get sftpEditorTip => '如果为空, 使用App内置的文件编辑器. 如果有值, 这是用远程服务器的编辑器, 例如 `vim` (建议根据 `EDITOR` 自动获取).';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 来删除文件夹';

  @override
  String get sftpSSHConnected => 'SFTP 已连接...';

  @override
  String get sftpShowFoldersFirst => '文件夹显示在前';

  @override
  String get showDistLogo => '显示发行版 Logo';

  @override
  String get shutdown => '关机';

  @override
  String get size => '大小';

  @override
  String get snippet => '代码片段';

  @override
  String get softWrap => '自动换行';

  @override
  String get specifyDev => '指定设备';

  @override
  String get specifyDevTip => '例如网络流量统计默认是所有设备，你可以在这里指定特定的设备';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗时: $time';
  }

  @override
  String get sshTermHelp => '在终端可滚动时，横向拖动可以选中文字。点击键盘按钮可以开启/关闭键盘。文件图标会打开当前路径 SFTP。剪切板按钮会在有选中文字时复制内容，在未选中并且剪切板有内容时粘贴内容到终端。代码图标会粘贴代码片段到终端并执行。';

  @override
  String sshTip(Object url) {
    return '该功能目前处于测试阶段。\n\n请在 $url 反馈问题，或者加入我们开发。';
  }

  @override
  String get sshVirtualKeyAutoOff => '虚拟按键自动切换';

  @override
  String get start => '开始';

  @override
  String get stat => '统计';

  @override
  String get stats => '统计';

  @override
  String get stop => '停止';

  @override
  String get stopped => '已停止';

  @override
  String get storage => '存储';

  @override
  String get supportFmtArgs => '支持以下格式化参数：';

  @override
  String get suspend => '挂起';

  @override
  String get suspendTip => 'suspend 功能需要 root 权限及 systemd 支持。';

  @override
  String switchTo(Object val) {
    return '切换到 $val';
  }

  @override
  String get sync => '同步';

  @override
  String get syncTip => '可能需要重新启动，某些更改才能生效。';

  @override
  String get system => '系统';

  @override
  String get tag => '标签';

  @override
  String get temperature => '温度';

  @override
  String get termFontSizeTip => '此设置会影响终端大小（宽和高）。可以在终端页面缩放来调整当前会话的字体大小';

  @override
  String get terminal => '终端';

  @override
  String get test => '测试';

  @override
  String get textScaler => '字体缩放';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），仅作用于服务器页面部分字体，不建议修改。';

  @override
  String get theme => '主题';

  @override
  String get time => '时间';

  @override
  String get times => '次';

  @override
  String get total => '总共';

  @override
  String get traffic => '流量';

  @override
  String get trySudo => '尝试使用 sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => '未知';

  @override
  String get unkownConvertMode => '未知转换模式';

  @override
  String get update => '更新';

  @override
  String get updateIntervalEqual0 => '你设置为 0，服务器状态不会自动刷新。\n且不能计算 CPU 使用情况。';

  @override
  String get updateServerStatusInterval => '服务器状态刷新间隔';

  @override
  String get upload => '上传';

  @override
  String get upsideDown => '上下交换';

  @override
  String get uptime => '启动时长';

  @override
  String get useCdn => '使用 CDN';

  @override
  String get useCdnTip => '非中国大陆用户推荐使用 CDN，是否使用？';

  @override
  String get useNoPwd => '将会使用无密码';

  @override
  String get usePodmanByDefault => '默认使用 Podman';

  @override
  String get used => '已用';

  @override
  String get view => '视图';

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
  String get wolTip => '在配置 WOL 后，每次连接服务器都会先发送一次 WOL 请求';

  @override
  String get write => '写';

  @override
  String get writeScriptFailTip => '写入脚本失败，可能是没有权限/目录不存在等';

  @override
  String get writeScriptTip => '在连接服务器后，会向 ~/.config/server_box 写入脚本来监测系统状态，你可以审查脚本内容。';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw(): super('zh_TW');

  @override
  String get aboutThanks => '感謝以下參與的各位。';

  @override
  String get acceptBeta => '接受測試版更新推送';

  @override
  String get addSystemPrivateKeyTip => '當前沒有任何私鑰，是否添加系統自帶的 (~/.ssh/id_rsa)？';

  @override
  String get added2List => '已添加至任務列表';

  @override
  String get addr => '位址';

  @override
  String get alreadyLastDir => '已經是最上層目錄了';

  @override
  String get authFailTip => '認證失敗，請檢查密碼/密鑰/主機/用戶等是否錯誤。';

  @override
  String get autoBackupConflict => '只能同時開啓一個自動備份';

  @override
  String get autoConnect => '自動連接';

  @override
  String get autoRun => '自動運行';

  @override
  String get autoUpdateHomeWidget => '自動更新桌面小部件';

  @override
  String get backupTip => '匯出的資料僅進行了簡單加密，請妥善保管。';

  @override
  String get backupVersionNotMatch => '備份版本不匹配，無法還原';

  @override
  String get battery => '電池';

  @override
  String get bgRun => '後台運行';

  @override
  String get bgRunTip => '此開關只代表程式會嘗試在後台運行，具體能否在後臺運行取決於是否開啟了權限。 原生 Android 請關閉本 App 的“電池優化”，MIUI / HyperOS 請修改省電策略為“無限制”。';

  @override
  String get closeAfterSave => '儲存後關閉';

  @override
  String get cmd => '命令';

  @override
  String get collapseUITip => '是否預設折疊 UI 中存在的長列表';

  @override
  String get conn => '連接';

  @override
  String get container => '容器';

  @override
  String get containerTrySudoTip => '例如：App 內設置使用者為 aaa，但是 Docker 安裝在 root 使用者，這時就需要開啟此選項';

  @override
  String get convert => '轉換';

  @override
  String get copyPath => '複製路徑';

  @override
  String get cpuViewAsProgressTip => '以進度條樣式顯示每個CPU的使用率（舊版樣式）';

  @override
  String get cursorType => '游標類型';

  @override
  String get customCmd => '自訂命令';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki/主页#自定义命令';

  @override
  String get customCmdHint => '\"命令名稱\": \"命令\"';

  @override
  String get decode => '解碼';

  @override
  String get decompress => '解壓縮';

  @override
  String get deleteServers => '批量刪除伺服器';

  @override
  String get dirEmpty => '請確保資料夾為空';

  @override
  String get disconnected => '連接斷開';

  @override
  String get disk => '磁碟';

  @override
  String get diskIgnorePath => '忽略的磁碟路徑';

  @override
  String get displayCpuIndex => '顯示 CPU 索引';

  @override
  String dl2Local(Object fileName) {
    return '下載 $fileName 到本地？';
  }

  @override
  String get dockerEmptyRunningItems => '沒有正在運行的容器。\n這可能是因為：\n- Docker 安裝使用者與 App 內配置的使用者名稱不同\n- 環境變量 DOCKER_HOST 沒有被正確讀取。你可以通過在終端內運行 `echo \$DOCKER_HOST` 來獲取。';

  @override
  String dockerImagesFmt(Object count) {
    return '共 $count 個鏡像';
  }

  @override
  String get dockerNotInstalled => 'Docker 未安裝';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount 個正在運行, $stoppedCount 個已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count 個容器正在運行';
  }

  @override
  String get doubleColumnMode => '雙列模式';

  @override
  String get doubleColumnTip => '此選項僅開啟功能，實際是否能開啟還取決於設備的寬度';

  @override
  String get editVirtKeys => '編輯虛擬按鍵';

  @override
  String get editor => '編輯器';

  @override
  String get editorHighlightTip => '目前的代碼高亮性能較為糟糕，可以選擇關閉以改善。';

  @override
  String get encode => '編碼';

  @override
  String get envVars => '環境變量';

  @override
  String get experimentalFeature => '實驗性功能';

  @override
  String get extraArgs => '額外參數';

  @override
  String get fallbackSshDest => '備選 SSH 目標';

  @override
  String get fdroidReleaseTip => '如果你是從 F-Droid 下載的本應用，推薦關閉此選項';

  @override
  String get fgService => '前台服務';

  @override
  String get fgServiceTip => '開啟後，可能會導致部分機型閃退。關閉可能導致部分機型無法後台保持 SSH 連接。請在系統設置內允許 ServerBox 通知權限、後台運行、自我喚醒。';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '文件 \'$file\' 過大 \'$size\'，超過了 $sizeMax';
  }

  @override
  String get followSystem => '跟隨系統';

  @override
  String get font => '字型';

  @override
  String get fontSize => '字型大小';

  @override
  String get force => '強制';

  @override
  String get fullScreen => '全螢幕模式';

  @override
  String get fullScreenJitter => '全螢幕模式抖動';

  @override
  String get fullScreenJitterHelp => '防止燒屏';

  @override
  String get fullScreenTip => '當設備旋轉為橫屏時，是否開啟全熒幕模式？此選項僅適用於伺服器選項卡。';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

  @override
  String get hideTitleBar => '隱藏標題欄';

  @override
  String get highlight => '代碼高亮';

  @override
  String get homeWidgetUrlConfig => '桌面部件鏈接配置';

  @override
  String get host => '主機';

  @override
  String httpFailedWithCode(Object code) {
    return '請求失敗, 狀態碼: $code';
  }

  @override
  String get ignoreCert => '忽略證書';

  @override
  String get image => '鏡像';

  @override
  String get imagesList => '鏡像列表';

  @override
  String get init => '初始化';

  @override
  String get inner => '內建';

  @override
  String get install => '安裝';

  @override
  String get installDockerWithUrl => '請先 https://docs.docker.com/engine/install docker';

  @override
  String get invalid => '無效';

  @override
  String get jumpServer => '跳板伺服器';

  @override
  String get keepForeground => '請保持應用處於前台！';

  @override
  String get keepStatusWhenErr => '保留上次的伺服器狀態';

  @override
  String get keepStatusWhenErrTip => '僅在執行腳本出錯時';

  @override
  String get keyAuth => '密鑰認證';

  @override
  String get letterCache => '输入法字符緩存';

  @override
  String get letterCacheTip => '建議關閉，但關閉後將無法輸入 CJK 等文字。';

  @override
  String get license => '證書';

  @override
  String get location => '位置';

  @override
  String get loss => '丟包率';

  @override
  String madeWithLove(Object myGithub) {
    return '用❤️製作 by $myGithub';
  }

  @override
  String get manual => '手動';

  @override
  String get max => '最大';

  @override
  String get maxRetryCount => '伺服器嘗試重連次數';

  @override
  String get maxRetryCountEqual0 => '會無限重試';

  @override
  String get min => '最小';

  @override
  String get mission => '任務';

  @override
  String get more => '更多';

  @override
  String get moveOutServerFuncBtnsHelp => '開啟：可以在伺服器 Tab 頁的每個卡片下方顯示。關閉：在伺服器詳情頁頂部顯示。';

  @override
  String get ms => '毫秒';

  @override
  String get needHomeDir => '如果你是群暉用戶，[看這裡](https://kb.synology.com/DSM/tutorial/user_enable_home_service)。其他系統用戶，需搜索如何創建家目錄（home directory）。';

  @override
  String get needRestart => '需要重啓 App';

  @override
  String get net => '網路';

  @override
  String get netViewType => '網路視圖類型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noLineChart => '不使用折線圖';

  @override
  String get noLineChartForCpu => 'CPU 不使用折線圖';

  @override
  String get noPrivateKeyTip => '私鑰不存在，可能已被刪除/配置錯誤。';

  @override
  String get noPromptAgain => '不再提示';

  @override
  String get node => '節點';

  @override
  String get notAvailable => '不可用';

  @override
  String get onServerDetailPage => '在伺服器詳情頁';

  @override
  String get onlyOneLine => '僅顯示為一行（可滾動）';

  @override
  String get onlyWhenCoreBiggerThan8 => '僅當核心數大於 8 時生效';

  @override
  String get openLastPath => '打開上次的路徑';

  @override
  String get openLastPathTip => '不同的伺服器會有不同的記錄，且記錄的是退出時的路徑';

  @override
  String get parseContainerStatsTip => 'Docker 解析佔用狀態較為緩慢';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size 的 $percent%';
  }

  @override
  String get permission => '權限';

  @override
  String get pingAvg => '平均:';

  @override
  String get pingInputIP => '請輸入目標 IP 或域名';

  @override
  String get pingNoServer => '沒有伺服器可用於 Ping\n請在伺服器 Tab 新增伺服器後再試';

  @override
  String get pkg => '包管理';

  @override
  String get plugInType => '插入類型';

  @override
  String get port => '埠';

  @override
  String get preview => '預覽';

  @override
  String get privateKey => '私鑰';

  @override
  String get process => '行程';

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get pveIgnoreCertTip => '不建議啟用，請注意安全風險！如果您使用的是 PVE 的默認證書，則需要啟用此選項。';

  @override
  String get pveLoginFailed => '登錄失敗。無法使用伺服器配置中的使用者名稱/密碼以 Linux PAM 方式登錄。';

  @override
  String get pveVersionLow => '此功能目前處於測試階段，僅在 PVE 8+ 上進行過測試。請謹慎使用。';

  @override
  String get pwd => '密碼';

  @override
  String get read => '读';

  @override
  String get reboot => '重启';

  @override
  String get rememberPwdInMem => '在記憶體中記住密碼';

  @override
  String get rememberPwdInMemTip => '用於容器、暫停等';

  @override
  String get rememberWindowSize => '記住窗口大小';

  @override
  String get remotePath => '遠端路徑';

  @override
  String get restart => '重啓';

  @override
  String get result => '結果';

  @override
  String get rotateAngel => '旋轉角度';

  @override
  String get route => '路由';

  @override
  String get run => '運行';

  @override
  String get running => '運作中';

  @override
  String get sameIdServerExist => '已存在相同 ID 的伺服器';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get second => '秒';

  @override
  String get sensors => '感測器';

  @override
  String get sequence => '順序';

  @override
  String get server => '伺服器';

  @override
  String get serverDetailOrder => '詳情頁部件順序';

  @override
  String get serverFuncBtns => '伺服器功能按鈕';

  @override
  String get serverOrder => '伺服器順序';

  @override
  String get sftpDlPrepare => '準備連接至伺服器...';

  @override
  String get sftpEditorTip => '如果為空, 使用App內置的文件編輯器。如果有值, 則使用遠程伺服器的編輯器, 例如 `vim`（建議根據 `EDITOR` 自動獲取）。';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 來刪除文件夾';

  @override
  String get sftpSSHConnected => 'SFTP 已連接...';

  @override
  String get sftpShowFoldersFirst => '資料夾顯示在前';

  @override
  String get showDistLogo => '顯示發行版 Logo';

  @override
  String get shutdown => '關機';

  @override
  String get size => '大小';

  @override
  String get snippet => '程式片段';

  @override
  String get softWrap => '軟換行';

  @override
  String get specifyDev => '指定裝置';

  @override
  String get specifyDevTip => '例如網路流量統計預設是所有裝置，你可以在這裡指定特定的裝置。';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗時: $time';
  }

  @override
  String get sshTermHelp => '在終端可滾動時，橫向拖動可以選中文字。點擊鍵盤按鈕可以開啟/關閉鍵盤。文件圖標會打開當前路徑 SFTP。剪貼簿按鈕會在有選中文字時複製內容，在未選中並且剪貼簿有內容時貼上內容到終端。代碼圖標會貼上代碼片段到終端並執行。';

  @override
  String sshTip(Object url) {
    return '該功能目前處於測試階段。\n\n請在 $url 反饋問題，或者加入我們開發。';
  }

  @override
  String get sshVirtualKeyAutoOff => '虛擬按鍵自動切換';

  @override
  String get start => '開始';

  @override
  String get stat => '統計';

  @override
  String get stats => '統計';

  @override
  String get stop => '停止';

  @override
  String get stopped => '已停止';

  @override
  String get storage => '存儲';

  @override
  String get supportFmtArgs => '支援以下格式化參數：';

  @override
  String get suspend => '挂起';

  @override
  String get suspendTip => 'suspend 功能需要 root 權限及 systemd 支持。';

  @override
  String switchTo(Object val) {
    return '切換到 $val';
  }

  @override
  String get sync => '同步';

  @override
  String get syncTip => '可能需要重新啟動，某些更改才能生效。';

  @override
  String get system => '系統';

  @override
  String get tag => '标签';

  @override
  String get temperature => '溫度';

  @override
  String get termFontSizeTip => '此設置將影響終端大小（寬度和高度）。您可以在終端頁面縮放，來調整當前會話的字型大小。';

  @override
  String get terminal => '终端機';

  @override
  String get test => '測試';

  @override
  String get textScaler => '字型縮放';

  @override
  String get textScalerTip => '1.0 => 100%（原大小），僅作用於伺服器頁面部分字型，不建議修改。';

  @override
  String get theme => '主題';

  @override
  String get time => '時間';

  @override
  String get times => '次';

  @override
  String get total => '總共';

  @override
  String get traffic => '流量';

  @override
  String get trySudo => '嘗試使用 sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => '未知';

  @override
  String get unkownConvertMode => '未知轉換模式';

  @override
  String get update => '更新';

  @override
  String get updateIntervalEqual0 => '你設置為 0，伺服器狀態不會自動更新。\n且不能計算CPU使用情況。';

  @override
  String get updateServerStatusInterval => '伺服器狀態更新間隔';

  @override
  String get upload => '上傳';

  @override
  String get upsideDown => '上下交換';

  @override
  String get uptime => '啟動時長';

  @override
  String get useCdn => '使用 CDN';

  @override
  String get useCdnTip => '非中國大陸用戶建議使用 CDN，是否使用？';

  @override
  String get useNoPwd => '将使用無密碼';

  @override
  String get usePodmanByDefault => '默認使用 Podman';

  @override
  String get used => '已用';

  @override
  String get view => '視圖';

  @override
  String get viewErr => '查看錯誤';

  @override
  String get virtKeyHelpClipboard => '如果終端有選中字元，則復製選中字元至剪貼簿，否則粘貼剪貼簿內容至終端。';

  @override
  String get virtKeyHelpIME => '打開/關閉鍵盤';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打開當前路徑。';

  @override
  String get waitConnection => '請等待連接建立';

  @override
  String get wakeLock => '保持喚醒';

  @override
  String get watchNotPaired => '沒有已配對的 Apple Watch';

  @override
  String get webdavSettingEmpty => 'WebDav 設置項爲空';

  @override
  String get whenOpenApp => '當打開 App 時';

  @override
  String get wolTip => '在配置 WOL（網絡喚醒）後，每次連接伺服器都會先發送一次 WOL 請求。';

  @override
  String get write => '写';

  @override
  String get writeScriptFailTip => '寫入腳本失敗，可能是沒有權限/目錄不存在等。';

  @override
  String get writeScriptTip => '連接到伺服器後，將會在 ~/.config/server_box 中寫入一個腳本來監測系統狀態。你可以審查腳本內容。';
}
