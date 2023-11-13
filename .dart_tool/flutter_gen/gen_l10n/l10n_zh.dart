import 'l10n.dart';

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get about => '关于';

  @override
  String get aboutThanks => '感谢以下参与的各位。';

  @override
  String get add => '新增';

  @override
  String get addAServer => '添加服务器';

  @override
  String get addPrivateKey => '添加一个私钥';

  @override
  String get addSystemPrivateKeyTip => '当前没有任何私钥，是否添加系统自带的（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已添加至任务列表';

  @override
  String get all => '所有';

  @override
  String get alreadyLastDir => '已经是最上层目录了';

  @override
  String get alterUrl => '备选链接';

  @override
  String askContinue(Object msg) {
    return '$msg，继续吗？';
  }

  @override
  String get attention => '注意';

  @override
  String get authRequired => '需要认证';

  @override
  String get auto => '自动';

  @override
  String get autoCheckUpdate => '自动检查更新';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoUpdateHomeWidget => '自动更新桌面小部件';

  @override
  String get backup => '备份';

  @override
  String get backupAndRestore => '备份和恢复';

  @override
  String get backupTip => '导出的数据仅进行了简单加密，请妥善保管。';

  @override
  String get backupVersionNotMatch => '备份版本不匹配，无法恢复';

  @override
  String get bgRun => '后台运行';

  @override
  String get bioAuth => '生物认证';

  @override
  String get canPullRefresh => '可以下拉刷新';

  @override
  String get cancel => '取消';

  @override
  String get choose => '选择';

  @override
  String get chooseFontFile => '选择字体文件';

  @override
  String get choosePrivateKey => '选择私钥';

  @override
  String get clear => '清除';

  @override
  String get close => '关闭';

  @override
  String get cmd => '命令';

  @override
  String get conn => '连接';

  @override
  String get connected => '已连接';

  @override
  String get containerName => '容器名';

  @override
  String get containerStatus => '容器状态';

  @override
  String get convert => '转换';

  @override
  String get copy => '复制';

  @override
  String get copyPath => '复制路径';

  @override
  String get createFile => '创建文件';

  @override
  String get createFolder => '创建文件夹';

  @override
  String get dark => '暗';

  @override
  String get debug => '调试';

  @override
  String get decode => '解码';

  @override
  String get decompress => '解压缩';

  @override
  String get delete => '删除';

  @override
  String get deleteScripts => '同时删除服务器脚本';

  @override
  String get deleteServers => '批量删除服务器';

  @override
  String get dirEmpty => '请确保文件夹为空';

  @override
  String get disabled => '已禁用';

  @override
  String get disconnected => '连接断开';

  @override
  String get disk => '硬盘';

  @override
  String get diskIgnorePath => '忽略的磁盘路径';

  @override
  String get displayName => '显示名称';

  @override
  String dl2Local(Object fileName) {
    return '下载 $fileName 到本地？';
  }

  @override
  String get dockerEditHost => '编辑 DOCKER_HOST';

  @override
  String get dockerEmptyRunningItems => '没有正在运行的容器。\n这可能是因为环境变量 DOCKER_HOST 没有被正确读取。你可以通过在终端内运行 `echo \$DOCKER_HOST` 来获取。';

  @override
  String dockerImagesFmt(Object count) {
    return '共 $count 个镜像';
  }

  @override
  String get dockerNotInstalled => 'Docker 未安装';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount个正在运行, $stoppedCount个已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count个容器正在运行';
  }

  @override
  String get doubleColumnMode => '双列模式';

  @override
  String get download => '下载';

  @override
  String get edit => '编辑';

  @override
  String get editVirtKeys => '编辑虚拟按键';

  @override
  String get editor => '编辑器';

  @override
  String get editorHighlightTip => '目前的代码高亮性能较为糟糕，可以选择关闭以改善。';

  @override
  String get encode => '编码';

  @override
  String get error => '错误';

  @override
  String get exampleName => '名称示例';

  @override
  String get experimentalFeature => '实验性功能';

  @override
  String get export => '导出';

  @override
  String get extraArgs => '额外参数';

  @override
  String get failed => '失败';

  @override
  String get feedback => '反馈';

  @override
  String get feedbackOnGithub => '如果你有任何问题，请在GitHub反馈';

  @override
  String get fieldMustNotEmpty => '这些输入框不能为空。';

  @override
  String fileNotExist(Object file) {
    return '$file 不存在';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '文件 \'$file\' 过大 \'$size\'，超过了 $sizeMax';
  }

  @override
  String get files => '文件';

  @override
  String get finished => '已完成';

  @override
  String get followSystem => '跟随系统';

  @override
  String get font => '字体';

  @override
  String get fontSize => '字体大小';

  @override
  String foundNUpdate(Object count) {
    return '找到 $count 个更新';
  }

  @override
  String get fullScreen => '全屏模式';

  @override
  String get fullScreenJitter => '全屏模式抖动';

  @override
  String get fullScreenJitterHelp => '防止烧屏';

  @override
  String get getPushTokenFailed => '未能获取到推送token';

  @override
  String get gettingToken => '正在获取Token...';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

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
  String get icloudSynced => 'iCloud已同步，某些设置可能需要重启才能生效。';

  @override
  String get image => '镜像';

  @override
  String get imagesList => '镜像列表';

  @override
  String get import => '导入';

  @override
  String get inner => '内置';

  @override
  String get inputDomainHere => '在这里输入域名';

  @override
  String get install => '安装';

  @override
  String get installDockerWithUrl => '请先 https://docs.docker.com/engine/install docker';

  @override
  String get invalidJson => '无效的 JSON';

  @override
  String get invalidVersion => '不支持的版本';

  @override
  String invalidVersionHelp(Object url) {
    return '请确保正确安装了docker，或者使用的非自编译版本。如果没有以上问题，请在 $url 提交问题。';
  }

  @override
  String get isBusy => '当前正忙';

  @override
  String get jumpServer => '跳板服务器';

  @override
  String get keepForeground => '请保持应用处于前台！';

  @override
  String get keyAuth => '密钥认证';

  @override
  String get keyboardCompatibility => '可能会改善输入法兼容性';

  @override
  String get keyboardType => '键盘类型';

  @override
  String get language => '语言';

  @override
  String get languageName => '简体中文';

  @override
  String get lastTry => '最后尝试';

  @override
  String get launchPage => '启动页';

  @override
  String get license => '开源证书';

  @override
  String get light => '亮';

  @override
  String get loadingFiles => '正在加载目录。。。';

  @override
  String get location => '位置';

  @override
  String get log => '日志';

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
  String get moveOutServerFuncBtnsHelp => '开启：可以在服务器 Tab 页的每个卡片下方显示。关闭：在服务器详情页顶部显示。';

  @override
  String get ms => '毫秒';

  @override
  String get name => '名称';

  @override
  String get needRestart => '需要重启 App';

  @override
  String get net => '网络';

  @override
  String get netViewType => '网络视图类型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noClient => '没有SSH连接';

  @override
  String get noInterface => '没有可用的接口';

  @override
  String get noOptions => '无可选项';

  @override
  String get noResult => '无结果';

  @override
  String get noSavedPrivateKey => '没有已保存的私钥。';

  @override
  String get noSavedSnippet => '没有已保存的代码片段。';

  @override
  String get noServerAvailable => '没有可用的服务器。';

  @override
  String get noTask => '没有任务';

  @override
  String get noUpdateAvailable => '没有可用更新';

  @override
  String get notSelected => '未选择';

  @override
  String get note => '备注';

  @override
  String get nullToken => '无Token';

  @override
  String get ok => '好';

  @override
  String get onServerDetailPage => '在服务器详情页';

  @override
  String get open => '打开';

  @override
  String get openLastPath => '打开上次的路径';

  @override
  String get openLastPathTip => '不同的服务器会有不同的记录，且记录的是退出时的路径';

  @override
  String get paste => '粘贴';

  @override
  String get path => '路径';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size 的 $percent%';
  }

  @override
  String get pickFile => '选择文件';

  @override
  String get pingAvg => '平均:';

  @override
  String get pingInputIP => '请输入目标IP或域名';

  @override
  String get pingNoServer => '没有服务器可用于Ping\n请在服务器tab添加服务器后再试';

  @override
  String get pkg => '包管理';

  @override
  String get platformNotSupportUpdate => '当前平台不支持更新，请编译最新源码后手动安装';

  @override
  String get plzEnterHost => '请输入主机';

  @override
  String get plzSelectKey => '请选择私钥';

  @override
  String get port => '端口';

  @override
  String get preview => '预览';

  @override
  String get primaryColorSeed => '主题色种子';

  @override
  String get privateKey => '私钥';

  @override
  String get process => '进程';

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get pwd => '密码';

  @override
  String get read => '读';

  @override
  String get reboot => '重启';

  @override
  String get remotePath => '远端路径';

  @override
  String get rename => '重命名';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return '请到 $url 提交问题';
  }

  @override
  String get restart => '重启';

  @override
  String get restore => '恢复';

  @override
  String get restoreSuccess => '恢复成功，需要重启App来应用更改';

  @override
  String get result => '结果';

  @override
  String get rotateAngel => '旋转角度';

  @override
  String get run => '运行';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get second => '秒';

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
  String get serverTabConnecting => '连接中...';

  @override
  String get serverTabEmpty => '现在没有服务器。\n点击右下方按钮来添加。';

  @override
  String get serverTabFailed => '失败';

  @override
  String get serverTabLoading => '加载中...';

  @override
  String get serverTabPlzSave => '请再次保存该私钥';

  @override
  String get serverTabUnkown => '未知状态';

  @override
  String get setting => '设置';

  @override
  String get sftpDlPrepare => '准备连接至服务器...';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 来删除文件夹';

  @override
  String get sftpSSHConnected => 'SFTP 已连接...';

  @override
  String get showDistLogo => '显示发行版 Logo';

  @override
  String get shutdown => '关机';

  @override
  String get snippet => '代码片段';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗时: $time';
  }

  @override
  String sshTip(Object url) {
    return '该功能目前处于测试阶段。\n\n请在 $url 反馈问题，或者加入我们开发。';
  }

  @override
  String get sshVirtualKeyAutoOff => '虚拟按键自动切换';

  @override
  String get start => '开始';

  @override
  String get stats => '统计';

  @override
  String get stop => '停止';

  @override
  String get success => '成功';

  @override
  String get suspend => '挂起';

  @override
  String get suspendTip => 'suspend 功能需要 root 权限及 systemd 支持。';

  @override
  String get syncTip => '可能需要重新启动，某些更改才能生效。';

  @override
  String get system => '系统';

  @override
  String get tag => '标签';

  @override
  String get temperature => '温度';

  @override
  String get terminal => '终端';

  @override
  String get theme => '主题';

  @override
  String get themeMode => '主题模式';

  @override
  String get times => '次';

  @override
  String get traffic => '流量';

  @override
  String get ttl => '缓存时间';

  @override
  String get unknown => '未知';

  @override
  String get unknownError => '未知错误';

  @override
  String get unkownConvertMode => '未知转换模式';

  @override
  String get update => '更新';

  @override
  String get updateAll => '更新全部';

  @override
  String get updateIntervalEqual0 => '你设置为0，服务器状态不会自动刷新。\n且不能计算CPU使用情况。';

  @override
  String get updateServerStatusInterval => '服务器状态刷新间隔';

  @override
  String updateTip(Object newest) {
    return '新版本: v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return '当前版本过低，请升级至 v1.0.$newest';
  }

  @override
  String get upload => '上传';

  @override
  String get upsideDown => '上下交换';

  @override
  String get urlOrJson => '链接或JSON';

  @override
  String get useNoPwd => '将会使用无密码。';

  @override
  String get user => '用户';

  @override
  String versionHaveUpdate(Object build) {
    return '找到新版本：v1.0.$build, 点击更新';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return '当前：v1.0.$build，点击检查更新';
  }

  @override
  String versionUpdated(Object build) {
    return '当前：v1.0.$build, 已是最新版本';
  }

  @override
  String get viewErr => '查看错误';

  @override
  String get virtKeyHelpClipboard => '如果终端有选中字符，则复制选中字符至剪切板，否则粘贴剪切板内容至终端。';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打开当前路径。';

  @override
  String get waitConnection => '请等待连接建立';

  @override
  String get watchNotPaired => '没有已配对的 Apple Watch';

  @override
  String get whenOpenApp => '当打开 App 时';

  @override
  String get willTakEeffectImmediately => '更改将会立即生效';

  @override
  String get write => '写';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class SZhTw extends SZh {
  SZhTw(): super('zh_TW');

  @override
  String get about => '關於';

  @override
  String get aboutThanks => '感謝以下參與的各位。';

  @override
  String get add => '新增';

  @override
  String get addAServer => '新增服務器';

  @override
  String get addPrivateKey => '新增一個私鑰';

  @override
  String get addSystemPrivateKeyTip => '當前沒有任何私鑰，是否添加系統自帶的（~/.ssh/id_rsa）？';

  @override
  String get added2List => '已添加至任務列表';

  @override
  String get all => '所有';

  @override
  String get alreadyLastDir => '已經是最上層目錄了';

  @override
  String get alterUrl => '備選鏈接';

  @override
  String askContinue(Object msg) {
    return '$msg，繼續嗎？';
  }

  @override
  String get attention => '注意';

  @override
  String get authRequired => '需要認證';

  @override
  String get auto => '自動';

  @override
  String get autoCheckUpdate => '自動檢查更新';

  @override
  String get autoConnect => '自動連接';

  @override
  String get autoUpdateHomeWidget => '自動更新桌面小部件';

  @override
  String get backup => '備份';

  @override
  String get backupAndRestore => '備份和還原';

  @override
  String get backupTip => '導出的數據僅進行了簡單加密，請妥善保管。';

  @override
  String get backupVersionNotMatch => '備份版本不匹配，無法還原';

  @override
  String get bgRun => '背景運行';

  @override
  String get bioAuth => '生物認證';

  @override
  String get canPullRefresh => '可以下拉更新';

  @override
  String get cancel => '取消';

  @override
  String get choose => '選擇';

  @override
  String get chooseFontFile => '選擇字體文件';

  @override
  String get choosePrivateKey => '選擇私鑰';

  @override
  String get clear => '清除';

  @override
  String get close => '關閉';

  @override
  String get cmd => '命令';

  @override
  String get conn => '連接';

  @override
  String get connected => '已連接';

  @override
  String get containerName => '容器名稱';

  @override
  String get containerStatus => '容器狀態';

  @override
  String get convert => '轉換';

  @override
  String get copy => '複製';

  @override
  String get copyPath => '複製路徑';

  @override
  String get createFile => '創建文件';

  @override
  String get createFolder => '創建文件夾';

  @override
  String get dark => '暗';

  @override
  String get debug => '調試';

  @override
  String get decode => '解碼';

  @override
  String get decompress => '解壓縮';

  @override
  String get delete => '刪除';

  @override
  String get deleteScripts => '同時刪除服務器腳本';

  @override
  String get deleteServers => '批量刪除服務器';

  @override
  String get dirEmpty => '請確保文件夾為空';

  @override
  String get disabled => '已禁用';

  @override
  String get disconnected => '連接斷開';

  @override
  String get disk => '硬盤';

  @override
  String get diskIgnorePath => '忽略的磁盤路徑';

  @override
  String get displayName => '顯示名稱';

  @override
  String dl2Local(Object fileName) {
    return '下載 $fileName 到本地？';
  }

  @override
  String get dockerEditHost => '編輯 DOCKER_HOST';

  @override
  String get dockerEmptyRunningItems => '沒有正在運行的容器。\n這可能是因為環境變量 DOCKER_HOST 沒有被正確讀取。你可以通過在終端內運行 `echo \$DOCKER_HOST` 來獲取。';

  @override
  String dockerImagesFmt(Object count) {
    return '共 $count 個鏡像';
  }

  @override
  String get dockerNotInstalled => 'Docker 未安裝';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount個正在運行, $stoppedCount個已停止';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count個容器正在運行';
  }

  @override
  String get doubleColumnMode => '雙列模式';

  @override
  String get download => '下載';

  @override
  String get edit => '編輯';

  @override
  String get editVirtKeys => '編輯虛擬按鍵';

  @override
  String get editor => '編輯器';

  @override
  String get editorHighlightTip => '目前的代碼高亮性能較為糟糕，可以選擇關閉以改善。';

  @override
  String get encode => '編碼';

  @override
  String get error => '錯誤';

  @override
  String get exampleName => '名稱範例';

  @override
  String get experimentalFeature => '實驗性功能';

  @override
  String get export => '導出';

  @override
  String get extraArgs => '額外參數';

  @override
  String get failed => '失敗';

  @override
  String get feedback => '反饋';

  @override
  String get feedbackOnGithub => '如果你有任何問題，請在GitHub反饋';

  @override
  String get fieldMustNotEmpty => '這些輸入框不能為空。';

  @override
  String fileNotExist(Object file) {
    return '$file 不存在';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '文件 \'$file\' 過大 \'$size\'，超過了 $sizeMax';
  }

  @override
  String get files => '文件';

  @override
  String get finished => '已完成';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get font => '字體';

  @override
  String get fontSize => '字體大小';

  @override
  String foundNUpdate(Object count) {
    return '找到 $count 個更新';
  }

  @override
  String get fullScreen => '全屏模式';

  @override
  String get fullScreenJitter => '全屏模式抖動';

  @override
  String get fullScreenJitterHelp => '防止燒屏';

  @override
  String get getPushTokenFailed => '未能獲取到推送token';

  @override
  String get gettingToken => '正在獲取Token...';

  @override
  String get goBackQ => '返回？';

  @override
  String get goto => '前往';

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
  String get icloudSynced => 'iCloud已同步，某些設置可能需要重啟才能生效。';

  @override
  String get image => '鏡像';

  @override
  String get imagesList => '鏡像列表';

  @override
  String get import => '導入';

  @override
  String get inner => '內置';

  @override
  String get inputDomainHere => '在這裡輸入域名';

  @override
  String get install => '安裝';

  @override
  String get installDockerWithUrl => '請先 https://docs.docker.com/engine/install docker';

  @override
  String get invalidJson => '無效的 JSON';

  @override
  String get invalidVersion => '不支持的版本';

  @override
  String invalidVersionHelp(Object url) {
    return '請確保正確安裝了docker，或者使用的非自編譯版本。如果沒有以上問題，請在 $url 提交問題。';
  }

  @override
  String get isBusy => '當前正忙';

  @override
  String get jumpServer => '跳板服務器';

  @override
  String get keepForeground => '請保持應用處於前台！';

  @override
  String get keyAuth => '密鑰認證';

  @override
  String get keyboardCompatibility => '可能會改善輸入法兼容性';

  @override
  String get keyboardType => '鍵盤類型';

  @override
  String get language => '語言';

  @override
  String get languageName => '繁體中文';

  @override
  String get lastTry => '最後嘗試';

  @override
  String get launchPage => '啓動頁';

  @override
  String get license => '開源證書';

  @override
  String get light => '亮';

  @override
  String get loadingFiles => '正在加載目錄。。。';

  @override
  String get location => '位置';

  @override
  String get log => '日誌';

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
  String get maxRetryCount => '服務器嘗試重連次數';

  @override
  String get maxRetryCountEqual0 => '會無限重試';

  @override
  String get min => '最小';

  @override
  String get mission => '任務';

  @override
  String get moveOutServerFuncBtnsHelp => '開啟：可以在服務器 Tab 頁的每個卡片下方顯示。關閉：在服務器詳情頁頂部顯示。';

  @override
  String get ms => '毫秒';

  @override
  String get name => '名稱';

  @override
  String get needRestart => '需要重啓 App';

  @override
  String get net => '網絡';

  @override
  String get netViewType => '網絡視圖類型';

  @override
  String get newContainer => '新建容器';

  @override
  String get noClient => '沒有SSH連接';

  @override
  String get noInterface => '沒有可用的接口';

  @override
  String get noOptions => '無可選項';

  @override
  String get noResult => '無結果';

  @override
  String get noSavedPrivateKey => '沒有已保存的私鑰。';

  @override
  String get noSavedSnippet => '沒有已保存的程式片段。';

  @override
  String get noServerAvailable => '沒有可用的服務器。';

  @override
  String get noTask => '沒有任務';

  @override
  String get noUpdateAvailable => '沒有可用更新';

  @override
  String get notSelected => '未選擇';

  @override
  String get note => '備註';

  @override
  String get nullToken => '無Token';

  @override
  String get ok => '好';

  @override
  String get onServerDetailPage => '在服務器詳情頁';

  @override
  String get open => '打開';

  @override
  String get openLastPath => '打開上次的路徑';

  @override
  String get openLastPathTip => '不同的服務器會有不同的記錄，且記錄的是退出時的路徑';

  @override
  String get paste => '貼上';

  @override
  String get path => '路徑';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size 的 $percent%';
  }

  @override
  String get pickFile => '選擇文件';

  @override
  String get pingAvg => '平均:';

  @override
  String get pingInputIP => '請輸入目標IP或域名';

  @override
  String get pingNoServer => '沒有服務器可用於Ping\n請在服務器tab新增服務器後再試';

  @override
  String get pkg => '包管理';

  @override
  String get platformNotSupportUpdate => '當前平台不支持更新，請編譯最新源碼後手動安裝';

  @override
  String get plzEnterHost => '請輸入主機';

  @override
  String get plzSelectKey => '請選擇私鑰';

  @override
  String get port => '端口';

  @override
  String get preview => '預覽';

  @override
  String get primaryColorSeed => '主要色調種子';

  @override
  String get privateKey => '私鑰';

  @override
  String get process => '進程';

  @override
  String get pushToken => '消息推送 Token';

  @override
  String get pwd => '密碼';

  @override
  String get read => '读';

  @override
  String get reboot => '重启';

  @override
  String get remotePath => '遠端路徑';

  @override
  String get rename => '重命名';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return '請到 $url 提交問題';
  }

  @override
  String get restart => '重啓';

  @override
  String get restore => '恢復';

  @override
  String get restoreSuccess => '恢復成功，需要重啓App來應用更改';

  @override
  String get result => '結果';

  @override
  String get rotateAngel => '旋轉角度';

  @override
  String get run => '運行';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get second => '秒';

  @override
  String get sequence => '順序';

  @override
  String get server => '服務器';

  @override
  String get serverDetailOrder => '詳情頁部件順序';

  @override
  String get serverFuncBtns => '服務器功能按鈕';

  @override
  String get serverOrder => '服務器順序';

  @override
  String get serverTabConnecting => '連接中...';

  @override
  String get serverTabEmpty => '現在沒有服務器。\n點擊右下方按鈕來新增。';

  @override
  String get serverTabFailed => '失敗';

  @override
  String get serverTabLoading => '加載中...';

  @override
  String get serverTabPlzSave => '請再次保存該私鑰';

  @override
  String get serverTabUnkown => '未知狀態';

  @override
  String get setting => '設置';

  @override
  String get sftpDlPrepare => '準備連接至服務器...';

  @override
  String get sftpRmrDirSummary => '在 SFTP 中使用 `rm -r` 來刪除文件夾';

  @override
  String get sftpSSHConnected => 'SFTP 已連接...';

  @override
  String get showDistLogo => '顯示發行版 Logo';

  @override
  String get shutdown => '关机';

  @override
  String get snippet => '程式片段';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '耗時: $time';
  }

  @override
  String sshTip(Object url) {
    return '該功能目前處於測試階段。\n\n請在 $url 反饋問題，或者加入我們開發。';
  }

  @override
  String get sshVirtualKeyAutoOff => '虛擬按鍵自動切換';

  @override
  String get start => '開始';

  @override
  String get stats => '統計';

  @override
  String get stop => '停止';

  @override
  String get success => '成功';

  @override
  String get suspend => '挂起';

  @override
  String get suspendTip => 'suspend 功能需要 root 權限及 systemd 支持。';

  @override
  String get syncTip => '可能需要重新啟動，某些更改才能生效。';

  @override
  String get system => '系統';

  @override
  String get tag => '标签';

  @override
  String get temperature => '溫度';

  @override
  String get terminal => '终端機';

  @override
  String get theme => '主題';

  @override
  String get themeMode => '主題模式';

  @override
  String get times => '次';

  @override
  String get traffic => '流量';

  @override
  String get ttl => '緩存時間';

  @override
  String get unknown => '未知';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get unkownConvertMode => '未知轉換模式';

  @override
  String get update => '更新';

  @override
  String get updateAll => '更新全部';

  @override
  String get updateIntervalEqual0 => '你設置為0，服務器狀態不會自動更新。\n且不能計算CPU使用情況。';

  @override
  String get updateServerStatusInterval => '服務器狀態更新間隔';

  @override
  String updateTip(Object newest) {
    return '新版本: v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return '當前版本過低，請升級至 v1.0.$newest';
  }

  @override
  String get upload => '上傳';

  @override
  String get upsideDown => '上下交換';

  @override
  String get urlOrJson => '鏈接或JSON';

  @override
  String get useNoPwd => '将使用無密碼。';

  @override
  String get user => '用戶';

  @override
  String versionHaveUpdate(Object build) {
    return '找到新版本：v1.0.$build, 點擊更新';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return '當前：v1.0.$build，點擊檢查更新';
  }

  @override
  String versionUpdated(Object build) {
    return '當前：v1.0.$build, 已是最新版本';
  }

  @override
  String get viewErr => '查看錯誤';

  @override
  String get virtKeyHelpClipboard => '如果終端有選中字符，則復製選中字符至剪切板，否則粘貼剪切板內容至終端。';

  @override
  String get virtKeyHelpSFTP => '在 SFTP 中打開當前路徑。';

  @override
  String get waitConnection => '請等待連接建立';

  @override
  String get watchNotPaired => '沒有已配對的 Apple Watch';

  @override
  String get whenOpenApp => '當打開 App 時';

  @override
  String get willTakEeffectImmediately => '更改將會立即生效';

  @override
  String get write => '写';
}
