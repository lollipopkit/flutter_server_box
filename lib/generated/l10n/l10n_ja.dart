import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get aboutThanks => '以下の参加者に感謝します。';

  @override
  String get acceptBeta => 'テストバージョンの更新を受け入れる';

  @override
  String get addSystemPrivateKeyTip => '現在秘密鍵がありません。システムのデフォルト(~/.ssh/id_rsa)を追加しますか？';

  @override
  String get added2List => 'タスクリストに追加されました';

  @override
  String get addr => 'アドレス';

  @override
  String get alreadyLastDir => 'すでに最上位のディレクトリです';

  @override
  String get authFailTip => '認証に失敗しました。パスワード/鍵/ホスト/ユーザーなどが間違っていないか確認してください。';

  @override
  String get autoBackupConflict => '自動バックアップは一度に一つしか開始できません';

  @override
  String get autoConnect => '自動接続';

  @override
  String get autoRun => '自動実行';

  @override
  String get autoUpdateHomeWidget => 'ホームウィジェットを自動更新';

  @override
  String get backupTip => 'エクスポートされたデータは簡単に暗号化されています。適切に保管してください。';

  @override
  String get backupVersionNotMatch => 'バックアップバージョンが一致しないため、復元できません';

  @override
  String get battery => 'バッテリー';

  @override
  String get bgRun => 'バックグラウンド実行';

  @override
  String get bgRunTip => 'このスイッチはプログラムがバックグラウンドで実行を試みることを意味しますが、実際にバックグラウンドで実行できるかどうかは、権限が有効になっているかに依存します。AOSPベースのAndroid ROMでは、このアプリの「バッテリー最適化」をオフにしてください。MIUIでは、省エネモードを「無制限」に変更してください。';

  @override
  String get closeAfterSave => '保存して閉じる';

  @override
  String get cmd => 'コマンド';

  @override
  String get collapseUITip => 'UIの長いリストをデフォルトで折りたたむかどうか';

  @override
  String get conn => '接続';

  @override
  String get container => 'コンテナ';

  @override
  String get containerTrySudoTip => '例：アプリ内でユーザーをaaaに設定しているが、Dockerがrootユーザーでインストールされている場合、このオプションを有効にする必要があります';

  @override
  String get convert => '変換';

  @override
  String get copyPath => 'パスをコピー';

  @override
  String get cpuViewAsProgressTip => '各CPUの使用率をプログレスバースタイルで表示する（旧スタイル）';

  @override
  String get cursorType => 'カーソルタイプ';

  @override
  String get customCmd => 'カスタムコマンド';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"コマンド名\": \"コマンド\"';

  @override
  String get decode => 'デコード';

  @override
  String get decompress => '解凍';

  @override
  String get deleteServers => 'サーバーを一括削除';

  @override
  String get dirEmpty => 'フォルダーが空であることを確認してください';

  @override
  String get disconnected => '接続が切断されました';

  @override
  String get disk => 'ディスク';

  @override
  String get diskIgnorePath => '無視されたディスクパス';

  @override
  String get displayCpuIndex => 'CPUインデックスを表示する';

  @override
  String dl2Local(Object fileName) {
    return '$fileNameをローカルにダウンロードしますか？';
  }

  @override
  String get dockerEmptyRunningItems => '実行中のコンテナがありません。\nこれは次の理由による可能性があります：\n- Dockerのインストールユーザーとアプリ内の設定されたユーザー名が異なる\n- 環境変数DOCKER_HOSTが正しく読み込まれていない。ターミナルで`echo \$DOCKER_HOST`を実行して取得できます。';

  @override
  String dockerImagesFmt(Object count) {
    return '合計$countイメージ';
  }

  @override
  String get dockerNotInstalled => 'Dockerがインストールされていません';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount個が実行中、$stoppedCount個が停止中';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count個のコンテナが実行中';
  }

  @override
  String get doubleColumnMode => 'ダブルカラムモード';

  @override
  String get doubleColumnTip => 'このオプションは機能を有効にするだけで、実際に有効にできるかどうかはデバイスの幅に依存します';

  @override
  String get editVirtKeys => '仮想キーを編集';

  @override
  String get editor => 'エディター';

  @override
  String get editorHighlightTip => '現在のコードハイライトのパフォーマンスはかなり悪いため、改善するために無効にすることを選択できます。';

  @override
  String get encode => 'エンコード';

  @override
  String get envVars => '環境変数';

  @override
  String get experimentalFeature => '実験的な機能';

  @override
  String get extraArgs => '追加引数';

  @override
  String get fallbackSshDest => 'フォールバックSSH宛先';

  @override
  String get fdroidReleaseTip => 'このアプリをF-Droidからダウンロードした場合、このオプションをオフにすることをお勧めします。';

  @override
  String get fgService => 'フォアグラウンドサービス';

  @override
  String get fgServiceTip => '有効にすると、一部の機種でクラッシュする可能性があります。無効にすると、一部の機種でバックグラウンドでのSSH接続を維持できなくなる可能性があります。システム設定でServerBoxの通知権限、バックグラウンド実行、自己起動を許可してください。';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'ファイル \'$file\' は大きすぎます \'$size\'、$sizeMax を超えています';
  }

  @override
  String get followSystem => 'システムに従う';

  @override
  String get font => 'フォント';

  @override
  String get fontSize => 'フォントサイズ';

  @override
  String get force => '強制';

  @override
  String get fullScreen => 'フルスクリーンモード';

  @override
  String get fullScreenJitter => 'フルスクリーンモードのジッター';

  @override
  String get fullScreenJitterHelp => '焼き付き防止';

  @override
  String get fullScreenTip => 'デバイスが横向きに回転したときにフルスクリーンモードを有効にしますか？このオプションはサーバータブにのみ適用されます。';

  @override
  String get goBackQ => '戻りますか？';

  @override
  String get goto => '移動';

  @override
  String get hideTitleBar => 'タイトルバーを非表示にする';

  @override
  String get highlight => 'コードハイライト';

  @override
  String get homeWidgetUrlConfig => 'ホームウィジェットURL設定';

  @override
  String get host => 'ホスト';

  @override
  String httpFailedWithCode(Object code) {
    return 'リクエスト失敗、ステータスコード: $code';
  }

  @override
  String get ignoreCert => '証明書を無視する';

  @override
  String get image => 'イメージ';

  @override
  String get imagesList => 'イメージリスト';

  @override
  String get init => '初期化する';

  @override
  String get inner => '内蔵';

  @override
  String get install => 'インストール';

  @override
  String get installDockerWithUrl => '最初に https://docs.docker.com/engine/install dockerをインストールしてください';

  @override
  String get invalid => '無効';

  @override
  String get jumpServer => 'ジャンプサーバー';

  @override
  String get keepForeground => 'アプリを前面に保ってください！';

  @override
  String get keepStatusWhenErr => 'エラー時に前回のサーバーステータスを保持';

  @override
  String get keepStatusWhenErrTip => 'スクリプトの実行エラーに限ります';

  @override
  String get keyAuth => 'キー認証';

  @override
  String get letterCache => '文字キャッシング';

  @override
  String get letterCacheTip => '無効にすることを推奨しますが、無効にした後はCJK文字を入力することができなくなります。';

  @override
  String get license => 'オープンソースライセンス';

  @override
  String get location => '場所';

  @override
  String get loss => 'パケットロス';

  @override
  String madeWithLove(Object myGithub) {
    return '$myGithubによって❤️で作成済み';
  }

  @override
  String get manual => 'マニュアル';

  @override
  String get max => '最大';

  @override
  String get maxRetryCount => 'サーバーの再接続試行回数';

  @override
  String get maxRetryCountEqual0 => '無限に再試行します';

  @override
  String get min => '最小';

  @override
  String get mission => 'ミッション';

  @override
  String get more => 'もっと';

  @override
  String get moveOutServerFuncBtnsHelp => '有効にする：サーバータブの各カードの下に表示されます。無効にする：サーバーの詳細ページの上部に表示されます。';

  @override
  String get ms => 'ミリ秒';

  @override
  String get needHomeDir => 'Synologyユーザーの場合は、[こちらをご覧ください](https://kb.synology.com/DSM/tutorial/user_enable_home_service)。他のシステムのユーザーは、ホームディレクトリの作成方法を検索する必要があります。';

  @override
  String get needRestart => 'アプリを再起動する必要があります';

  @override
  String get net => 'ネットワーク';

  @override
  String get netViewType => 'ネットワークビュータイプ';

  @override
  String get newContainer => '新しいコンテナを作成';

  @override
  String get noLineChart => '折れ線グラフを使用しない';

  @override
  String get noLineChartForCpu => 'CPUに折れ線グラフを使わない';

  @override
  String get noPrivateKeyTip => '秘密鍵が存在しません。削除されたか、設定ミスがある可能性があります。';

  @override
  String get noPromptAgain => '再度確認しない';

  @override
  String get node => 'ノード';

  @override
  String get notAvailable => '利用不可';

  @override
  String get onServerDetailPage => 'サーバーの詳細ページで';

  @override
  String get onlyOneLine => '一行のみ表示（スクロール可能）';

  @override
  String get onlyWhenCoreBiggerThan8 => 'コア数が8より大きい場合にのみ有効';

  @override
  String get openLastPath => '最後のパスを開く';

  @override
  String get openLastPathTip => '異なるサーバーには異なる記録があり、記録されているのは退出時のパスです';

  @override
  String get parseContainerStatsTip => 'Dockerの使用状況の解析は比較的遅いです';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size の $percent%';
  }

  @override
  String get permission => '権限';

  @override
  String get pingAvg => '平均:';

  @override
  String get pingInputIP => '対象のIPまたはドメインを入力してください';

  @override
  String get pingNoServer => 'Pingに使用するサーバーがありません\nサーバータブでサーバーを追加してから再試行してください';

  @override
  String get pkg => 'パッケージ管理';

  @override
  String get plugInType => '挿入タイプ';

  @override
  String get port => 'ポート';

  @override
  String get preview => 'プレビュー';

  @override
  String get privateKey => '秘密鍵';

  @override
  String get process => 'プロセス';

  @override
  String get pushToken => 'プッシュトークン';

  @override
  String get pveIgnoreCertTip => 'オプションを有効にすることは推奨されません、セキュリティリスクに注意してください！PVEのデフォルト証明書を使用している場合は、このオプションを有効にする必要があります。';

  @override
  String get pveLoginFailed => 'ログインに失敗しました。Linux PAMログインのためにサーバー構成からのユーザー名/パスワードで認証できません。';

  @override
  String get pveVersionLow => 'この機能は現在テスト段階にあり、PVE 8+でのみテストされています。ご利用の際は慎重に。';

  @override
  String get pwd => 'パスワード';

  @override
  String get read => '読み取り';

  @override
  String get reboot => '再起動';

  @override
  String get rememberPwdInMem => 'メモリにパスワードを記憶する';

  @override
  String get rememberPwdInMemTip => 'コンテナ、一時停止などに使用されます。';

  @override
  String get rememberWindowSize => 'ウィンドウサイズを記憶する';

  @override
  String get remotePath => 'リモートパス';

  @override
  String get restart => '再開';

  @override
  String get result => '結果';

  @override
  String get rotateAngel => '回転角度';

  @override
  String get route => 'ルーティング';

  @override
  String get run => '実行';

  @override
  String get running => '実行中';

  @override
  String get sameIdServerExist => '同じIDのサーバーが既に存在します';

  @override
  String get save => '保存';

  @override
  String get saved => '保存されました';

  @override
  String get second => '秒';

  @override
  String get sensors => 'センサー';

  @override
  String get sequence => '順序';

  @override
  String get server => 'サーバー';

  @override
  String get serverDetailOrder => '詳細ページのウィジェット順序';

  @override
  String get serverFuncBtns => 'サーバー機能ボタン';

  @override
  String get serverOrder => 'サーバー順序';

  @override
  String get sftpDlPrepare => 'サーバーへの接続を準備中...';

  @override
  String get sftpEditorTip => '空の場合は、アプリ内蔵のファイルエディタを使用します。値がある場合は、リモートサーバーのエディタ（例：`vim`）を使用します（`EDITOR` に従って自動検出することをお勧めします）。';

  @override
  String get sftpRmrDirSummary => 'SFTPで`rm -r`を使用してフォルダーを削除';

  @override
  String get sftpSSHConnected => 'SFTPに接続されました...';

  @override
  String get sftpShowFoldersFirst => 'フォルダーを先に表示';

  @override
  String get showDistLogo => 'ディストリビューションのロゴを表示';

  @override
  String get shutdown => 'シャットダウン';

  @override
  String get size => 'サイズ';

  @override
  String get snippet => 'スニペット';

  @override
  String get softWrap => 'ソフトラップ';

  @override
  String get specifyDev => 'デバイスを指定';

  @override
  String get specifyDevTip => '例えば、ネットワークトラフィック統計はデフォルトですべてのデバイスに対するものです。ここで特定のデバイスを指定できます。';

  @override
  String get speed => '速度';

  @override
  String spentTime(Object time) {
    return '費した時間: $time';
  }

  @override
  String get sshTermHelp => 'ターミナルがスクロール可能な場合、横にドラッグするとテキストを選択できます。キーボードボタンをクリックするとキーボードのオン/オフが切り替わります。ファイルアイコンは現在のパスSFTPを開きます。クリップボードボタンは、テキストが選択されているときに内容をコピーし、テキストが選択されておらずクリップボードに内容がある場合には、その内容をターミナルに貼り付けます。コードアイコンは、コードスニペットをターミナルに貼り付けて実行します。';

  @override
  String sshTip(Object url) {
    return 'この機能は現在テスト段階にあります。\n\n問題がある場合は、$urlでフィードバックしてください。';
  }

  @override
  String get sshVirtualKeyAutoOff => '仮想キーの自動オフ';

  @override
  String get start => '開始';

  @override
  String get stat => '統計';

  @override
  String get stats => '統計';

  @override
  String get stop => '停止';

  @override
  String get stopped => '停止しました';

  @override
  String get storage => 'ストレージ';

  @override
  String get supportFmtArgs => '以下のフォーマット引数がサポートされています：';

  @override
  String get suspend => '中断';

  @override
  String get suspendTip => 'suspend機能はroot権限とsystemdのサポートが必要です。';

  @override
  String switchTo(Object val) {
    return '$valに切り替える';
  }

  @override
  String get sync => '同期する';

  @override
  String get syncTip => '再起動が必要な場合があります。一部の変更はその後に有効になります。';

  @override
  String get system => 'システム';

  @override
  String get tag => 'タグ';

  @override
  String get temperature => '温度';

  @override
  String get termFontSizeTip => 'この設定は端末のサイズ（幅と高さ）に影響します。現在のセッションのフォントサイズを調整するために、端末ページを拡大縮小できます。';

  @override
  String get terminal => 'ターミナル';

  @override
  String get test => 'テスト';

  @override
  String get textScaler => 'テキストスケーラー';

  @override
  String get textScalerTip => '1.0 => 100%（デフォルトサイズ）。サーバーページの一部のテキストにのみ適用されます。変更をお勧めしません。';

  @override
  String get theme => 'テーマ';

  @override
  String get time => '時間';

  @override
  String get times => '回';

  @override
  String get total => '合計';

  @override
  String get traffic => 'トラフィック';

  @override
  String get trySudo => 'sudoを試みる';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => '不明';

  @override
  String get unkownConvertMode => '未知の変換モード';

  @override
  String get update => '更新';

  @override
  String get updateIntervalEqual0 => '0に設定すると、サーバーの状態は自動的に更新されず、CPU使用率も計算できません。';

  @override
  String get updateServerStatusInterval => 'サーバー状態の更新間隔';

  @override
  String get upload => 'アップロード';

  @override
  String get upsideDown => '上下逆転';

  @override
  String get uptime => '稼働時間';

  @override
  String get useCdn => 'CDNの使用';

  @override
  String get useCdnTip => '中国以外のユーザーにはCDNの使用が推奨されています。ご利用しますか？';

  @override
  String get useNoPwd => 'パスワードなしで使用します';

  @override
  String get usePodmanByDefault => 'デフォルトでPodmanを使用';

  @override
  String get used => '使用済み';

  @override
  String get view => 'ビュー';

  @override
  String get viewErr => 'エラーを表示';

  @override
  String get virtKeyHelpClipboard => '端末に選択された文字がある場合は、選択された文字をクリップボードにコピーします。そうでない場合は、クリップボードの内容を端末に貼り付けます。';

  @override
  String get virtKeyHelpIME => 'キーボードのオン/オフ';

  @override
  String get virtKeyHelpSFTP => '現在のパスでSFTPを開く。';

  @override
  String get waitConnection => '接続の確立を待ってください';

  @override
  String get wakeLock => '起動を保つ';

  @override
  String get watchNotPaired => 'ペアリングされたApple Watchがありません';

  @override
  String get webdavSettingEmpty => 'Webdavの設定が空です';

  @override
  String get whenOpenApp => 'アプリを開くとき';

  @override
  String get wolTip => 'WOL（Wake-on-LAN）を設定した後、サーバーに接続するたびにWOLリクエストが送信されます。';

  @override
  String get write => '書き込み';

  @override
  String get writeScriptFailTip => 'スクリプトの書き込みに失敗しました。権限がないかディレクトリが存在しない可能性があります。';

  @override
  String get writeScriptTip => 'サーバーに接続すると、システムの状態を監視するためのスクリプトが ~/.config/server_box に書き込まれます。スクリプトの内容を確認できます。';
}
