// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get crashCollect => '診断データ';

  @override
  String get crashCollectIntro =>
      'ServerBox は問題を修正できるよう、実行中に起きたことを記録します。送信する情報量を選べます。';

  @override
  String get crashCollectNone => '送信しない';

  @override
  String get crashCollectNoneTip => 'レポートは端末に残り、クラッシュ後に手動で送信できます。';

  @override
  String get crashCollectBasic => '基本情報';

  @override
  String get crashCollectBasicTip =>
      'クラッシュ情報のみを含み、ログやパフォーマンスデータは含みません。**アプリの改善やバグの修正に役立ちます。**';

  @override
  String get crashCollectFooter =>
      'どのレベルでも、既知のサーバー名・アドレス・ユーザー名は記録時にプレースホルダーへ置き換えられます。設定であとから収集レベルを変更できます。';

  @override
  String get privacy => 'プライバシー';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get crashLastRunFailed => 'ServerBox は前回の実行中に予期せず終了しました。';

  @override
  String get crashReportTitle => 'クラッシュレポート';

  @override
  String get crashReportHint =>
      'これは前回の実行ログです。既知のサーバー名とアドレスはプレースホルダーに置き換えられていますが、他の情報が残っている場合があります。送信する前によく読んでください。';

  @override
  String get crashReportSubmit => 'コピーして報告';

  @override
  String get preReleaseUpdates => 'プレリリース版の更新を受け取る';

  @override
  String get addSystemPrivateKeyTip =>
      '現在秘密鍵がありません。システムのデフォルト(~/.ssh/id_rsa)を追加しますか？';

  @override
  String get added2List => 'タスクリストに追加されました';

  @override
  String get askAi => 'AI に質問';

  @override
  String get askAiInsertTerminal => 'ターミナルに挿入';

  @override
  String get remoteDesktop => 'リモートデスクトップ';

  @override
  String get askAiRiskReadOnly => '読み取り専用';

  @override
  String get askAiRiskCaution => 'システムを変更';

  @override
  String get askAiRiskUnvetted => '未確認のホスト';

  @override
  String get askAiRiskDestructive => '高リスク';

  @override
  String get askAiAutoRunSafeCommands => '読み取り専用コマンドを自動実行';

  @override
  String get askAiAutoRunSafeCommandsTip => 'モデルとローカルの検査がどちらも読み取り専用と判断したときだけ実行';

  @override
  String get askAiHistory => '会話履歴';

  @override
  String get askAiNewConversation => '新しい会話';

  @override
  String get askAiUntitledConversation => '無題';

  @override
  String get askAiRenameConversation => '会話の名前を変更';

  @override
  String get askAiDeleteConversationTitle => 'この会話を削除しますか？';

  @override
  String get askAiDeleteConversationTip => 'この端末から削除します。元に戻せません。';

  @override
  String get agentNoHistory => '保存されたグローバルのエージェント会話はありません';

  @override
  String get agentClearHistoryTitle => 'グローバルのエージェント履歴を消去しますか？';

  @override
  String get agentClearHistoryTip => 'グローバルのエージェント会話がすべてこの端末から削除されます。';

  @override
  String get agentToolShell => 'シェル';

  @override
  String get agentToolReadFile => 'ファイルを読む';

  @override
  String get agentToolWriteFile => 'ファイルを書く';

  @override
  String get floatOverTabs => '他のタブの上に浮かべる';

  @override
  String get agentToolSshConnect => 'SSH 接続';

  @override
  String get agentToolSshDisconnect => 'SSH 切断';

  @override
  String get agentSshConnectTitle => '新しいホストに接続';

  @override
  String get agentAuthMethod => '認証方式';

  @override
  String get agentSshConnectTip => 'Agent が SSH 接続を求めています。ここにパスワードを入力してください';

  @override
  String get agentAdHocSessions => '一時的な接続';

  @override
  String get agentSaveServerTitle => 'サーバーとして保存';

  @override
  String get agentSaveServerTip => 'このホストと入力したパスワードはこの端末に保存されます';

  @override
  String get agentMonitorOptional => 'monitor エージェント（任意）';

  @override
  String get authFailTip => '認証に失敗しました。情報を確認してください';

  @override
  String get autoBackupConflict => '自動バックアップは一度に一つしか開始できません';

  @override
  String get autoConnect => '自動接続';

  @override
  String get autoRun => '自動実行';

  @override
  String get autoUpdateHomeWidget => 'ホームウィジェットを自動更新';

  @override
  String get availableTabs => '利用可能なタブ';

  @override
  String get backupEncrypted => 'バックアップは暗号化されています';

  @override
  String get backupNotEncrypted => 'バックアップは暗号化されていません';

  @override
  String get backupPassword => 'バックアップパスワード';

  @override
  String get backupPasswordRemoved => 'バックアップパスワードが削除されました';

  @override
  String get backupPasswordSet => 'バックアップパスワードが設定されました';

  @override
  String get backupPasswordTip =>
      'バックアップファイルを暗号化するためのパスワードを設定してください。暗号化を無効にするには空白のままにしてください。';

  @override
  String get backupPasswordWrong => 'バックアップパスワードが間違っています';

  @override
  String get connectAll => 'すべて接続';

  @override
  String get disconnectAll => 'すべて切断';

  @override
  String get distIcon => 'ディストリビューション標識';

  @override
  String get distIconIntroLegal =>
      'マークは、この端末がリモートシステムから読み取った内容を示すだけで、その情報は誤っていたり古かったりすることがあり、派生版・再構築版・特定のバージョンを表すものでもありません。判別できない場合は汎用のアイコンを表示します。\n\n各マークはそれぞれの所有者の商標であり、ここではそれが指すシステムを示す目的にのみ使用しています。';

  @override
  String get distIconTip => '各サーバーの横に、動作していると思われるシステムの小さな標識を表示します';

  @override
  String get distNameMap => '名前の対応付け';

  @override
  String get distNameMapTip =>
      'マークの置き場でファイル名がこのアプリの呼び方と違うディストリビューションにだけ使います。キーはこのアプリが使う名前、値は実際に取得する名前です。表示できないマークがなければ設定は不要です。';

  @override
  String get logoUrl => 'ロゴの URL';

  @override
  String get logoUrlTip => 'サーバー詳細ページの上部に出る大きな画像。元の色のまま表示します。';

  @override
  String get globe => '地球儀';

  @override
  String get locationTip =>
      '地球儀上でこのサーバーを描く位置。緯度、経度の順に度単位で入力します。例: 39.9042, 116.4074';

  @override
  String get markUrl => 'マークの URL';

  @override
  String get markUrlTip => '一覧でサーバー名の横に出る小さなマーク。空なら表示しません。\n\nロゴとは別の画像です';

  @override
  String get navTabMenuTip => 'タブを長押し（マウスは右クリック）すると、その中のすべてをまとめて接続・切断できます。';

  @override
  String nTags(int count) {
    return '$count 個のタグ';
  }

  @override
  String get remoteBackupPasswordRequired => 'リモートバックアップには空でないバックアップパスワードが必要です';

  @override
  String get monitorHttpsRequired =>
      'リモートの monitor エージェントには HTTPS が必要です（HTTP を許可した場合を除く）。';

  @override
  String get monitorAllowInsecureHttp => 'HTTP を許可';

  @override
  String get plainHttpTitle => 'この agent は平文 HTTP で公開されています';

  @override
  String get plainHttpTip => 'パスワードとこのアプリが取得する内容が暗号化されずに送られます。まだ何も送信していません。';

  @override
  String get allowForThisServer => 'このサーバーにだけ許可';

  @override
  String get viewError => 'エラーを見る';

  @override
  String get monitorAllowInsecureHttpTip =>
      'HTTP 以外で通信自体が暗号化される信頼できるプライベートネットワークでのみ。たとえば Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'SSH でコマンドを実行する代わりに、**monitor** の HTTP API からこのサーバーの状態を読み取ります。\n\n先にサーバーへ monitor を導入する必要があります。推移のグラフ、ウォッチ App、ホーム画面ウィジェットはこれに依存します。\n\n[monitor の導入方法]($url)';
  }

  @override
  String get backupThemesNotRestored =>
      '復元しましたが、これらのテーマは復元されませんでした。テーマストアまたは元のファイルから再インストールしてください。';

  @override
  String get backupTip => 'エクスポートされたデータはパスワードで暗号化できます。 \n適切に保管してください。';

  @override
  String get icloudBackupStatusTitle => 'バックアップの状態';

  @override
  String get icloudBackupStatusLoading => 'iCloud バックアップの状態を読み込み中…';

  @override
  String get icloudBackupStatusError => 'iCloud バックアップのメタデータを読み取れません';

  @override
  String get icloudBackupStatusEmpty => 'iCloud のバックアップファイルはまだ見つかりません';

  @override
  String get icloudBackupStateUploading => 'アップロード中';

  @override
  String get icloudBackupStateConflict => '競合を検出';

  @override
  String get icloudBackupStateUploaded => 'アップロード済み';

  @override
  String get icloudBackupStateWaiting => 'iCloud を待機中';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return '最終バックアップ: $lastModified\n状態: $remoteState';
  }

  @override
  String get bgRun => 'バックグラウンド実行';

  @override
  String get bgRunTip =>
      'このスイッチはプログラムがバックグラウンドで実行を試みることを意味しますが、実際にバックグラウンドで実行できるかどうかは、権限が有効になっているかに依存します。AOSPベースのAndroid ROMでは、このアプリの「バッテリー最適化」をオフにしてください。MIUIでは、省エネモードを「無制限」に変更してください。';

  @override
  String get trayReadings => '測定値';

  @override
  String get trayChart => 'グラフ';

  @override
  String get trayChartNone => 'なし';

  @override
  String get trayCompact => 'コンパクトな行';

  @override
  String get trayCompactTip =>
      'グラフなしで、サーバーごとに1行で表示します。Linux はパネルメニューを D-Bus 経由で送信し、カスタムレイアウトではなくラベルを渡すため、常に1行レイアウトになりますが、選択したグラフを画像として含めることはできます。';

  @override
  String get trayKeepRunning => 'トレイで実行し続ける';

  @override
  String get trayKeepRunningTip =>
      'ウィンドウを閉じてもアプリはメニューバーまたは通知領域に残り、サーバーの監視を続けます。オフにすると、閉じるボタンでアプリを終了します。';

  @override
  String get bgRunNeedsNotification =>
      'バックグラウンド実行には常駐通知が必要ですが、このアプリには通知の許可がありません。タップして通知を許可してください。';

  @override
  String get clearAllStatsContent => 'すべてのサーバー接続統計を削除してもよろしいですか？この操作は元に戻せません。';

  @override
  String get clearAllStatsTitle => 'すべての統計をクリア';

  @override
  String clearServerStatsContent(String serverName) {
    return 'サーバー\"$serverName\"の接続統計を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return '$serverNameの統計をクリア';
  }

  @override
  String get clearThisServerStats => 'このサーバーの統計をクリア';

  @override
  String get closeAfterSave => '保存して閉じる';

  @override
  String get collapseUITip => 'UIの長いリストをデフォルトで折りたたむかどうか';

  @override
  String get connectionDetails => '接続の詳細';

  @override
  String get connectionStats => '接続統計';

  @override
  String get connectionStatsDesc => 'サーバー接続成功率と履歴を表示';

  @override
  String get containerTrySudoTip =>
      '例：アプリ内でユーザーをaaaに設定しているが、Dockerがrootユーザーでインストールされている場合、このオプションを有効にする必要があります';

  @override
  String get containerSudoPasswordRequired =>
      'Dockerにアクセスするにはsudoパスワードが必要です。パスワードを入力してください。';

  @override
  String get containerSudoPasswordIncorrect =>
      'sudoパスワードが正しくないか、許可されていません。再試行してください。';

  @override
  String get copyPath => 'パスをコピー';

  @override
  String get customCmd => 'カスタムコマンド';

  @override
  String get deleteServers => 'サーバーを一括削除';

  @override
  String get deleteDirRecursive => 'フォルダーとその中身をすべて削除';

  @override
  String get dirEmpty => 'フォルダーが空であることを確認してください';

  @override
  String get discoverSshServers => 'SSHサーバーの発見';

  @override
  String get discoveryFailed => '発見に失敗';

  @override
  String get discoverySettings => '発見設定';

  @override
  String get distro => 'ディストリビューション';

  @override
  String get diskHealth => 'ディスクの健康状態';

  @override
  String dl2Local(String fileName) {
    return '$fileNameをローカルにダウンロードしますか？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '実行中のコンテナがありません。\nこれは次の理由による可能性があります：\n- Dockerのインストールユーザーとアプリ内の設定されたユーザー名が異なる\n- 環境変数DOCKER_HOSTが正しく読み込まれていない。ターミナルで`echo \$DOCKER_HOST`を実行して取得できます。';

  @override
  String get dockerProjectOther => 'その他';

  @override
  String get dockerPruneTip => '未使用のデータを削除してディスク容量を解放します';

  @override
  String get dockerStatistics => 'Docker 統計';

  @override
  String get editVirtKeys => '仮想キー';

  @override
  String get editorHighlightTip =>
      '現在のコードハイライトのパフォーマンスはかなり悪いため、改善するために無効にすることを選択できます。';

  @override
  String get enableMdns => 'mDNSを有効化';

  @override
  String get enableMdnsDesc => 'mDNS/BonjourでSSHサービスを発見';

  @override
  String get envVars => '環境変数';

  @override
  String get extraArgs => '追加引数';

  @override
  String get fallbackSshDest => 'フォールバックSSH宛先';

  @override
  String get fdroidReleaseTip =>
      'このアプリをF-Droidからダウンロードした場合、このオプションをオフにすることをお勧めします。';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'ファイル \'$file\' は大きすぎます \'$size\'、$sizeMax を超えています';
  }

  @override
  String get fileDirGone => 'このフォルダはもうありません';

  @override
  String get fileDirGoneTip => '削除または名前変更されました';

  @override
  String get fullScreen => 'フルスクリーン';

  @override
  String get fullScreenJitter => 'フルスクリーンモードのジッター';

  @override
  String get fullScreenJitterHelp => '焼き付き防止';

  @override
  String get fullScreenTip =>
      'デバイスが横向きに回転したときにフルスクリーンモードを有効にしますか？このオプションはサーバータブにのみ適用されます。';

  @override
  String get githubGistIdOptional => 'Gist ID（任意）';

  @override
  String get githubGistToken => 'GitHub Gist トークン';

  @override
  String get githubGistTokenEmpty => 'トークンが空です';

  @override
  String get githubGistIdInvalid =>
      'これは Gist ID でも Gist のリンクでもありません。gist のアドレスの末尾 (https://gist.github.com/<user>/<ID>) を使用するか、最初のバックアップ時に新しい secret gist を作成するには空欄にしてください。';

  @override
  String get githubGistNotFound =>
      'GitHub で、この ID の gist のうちこのトークンで読み取れるものが見つかりませんでした。ID が間違っている、gist が削除された、または別のアカウントに属している可能性があります。最初のバックアップ時に新しい secret gist を作成するには、ID を空欄にしてください。';

  @override
  String get githubGistTokenRejected =>
      'GitHub がこのトークンを拒否しました。トークンが間違っている、期限切れ、または取り消されているか、gist 権限がない可能性があります (classic token: \"gist\" scope; fine-grained token: Gists read and write)。';

  @override
  String get goto => '移動';

  @override
  String get homeTabs => 'ホームタブ';

  @override
  String get homeTabsCustomizeDesc => 'ホームページに表示するタブとその順序をカスタマイズします';

  @override
  String get ignoreCert => '証明書を無視する';

  @override
  String get image => 'イメージ';

  @override
  String get macDmgBody =>
      'App Store はこのアプリをサンドボックスで動かすことを要求し、サンドボックスではターミナルを開けません。DMG 版なら開けます。\n\nApp Store 版は今後更新が止まる可能性があります。';

  @override
  String get macDmgImportDenied => 'macOS が以前のバージョンのデータの読み取りを許可しませんでした';

  @override
  String get macDmgImported => '以前のバージョンのデータをインポートしました';

  @override
  String get macDmgImportFailed => '以前のバージョンのデータを読み取れませんでした';

  @override
  String get macDmgTip => 'ローカルターミナルと snippet のローカル実行（DMG 版）';

  @override
  String get macDmgTitle => 'DMG 版';

  @override
  String get showHiddenFiles => '隠しファイルを表示';

  @override
  String get sshKeyAlgorithm => 'アルゴリズム';

  @override
  String get sshKeyComment => 'コメント';

  @override
  String get sshKeyGenerate => '鍵ペアを生成';

  @override
  String get sshKeyGenerating => '生成中…';

  @override
  String sshKeyLockedFmt(String name) {
    return '秘密鍵 [$name] のロックが解除されていません。';
  }

  @override
  String get sshKeyPassphraseTip =>
      '任意。パスフレーズを設定すると秘密鍵は暗号化して保存され、接続でこの鍵を最初に使うときに入力を求められます。';

  @override
  String get sshKeyPassphraseWrong => 'パスフレーズが違います。';

  @override
  String get sshKeyPublicKey => '公開鍵';

  @override
  String get sshKeyPublicKeyTip =>
      'この行をサーバーの ~/.ssh/authorized_keys に追記してください。';

  @override
  String get sshKeyRecommended => '推奨';

  @override
  String sshKeyUnlockTip(String name) {
    return '秘密鍵 [$name] のパスフレーズを入力してください。';
  }

  @override
  String get ungrouped => '未分類';

  @override
  String get containerReclaimable => 'Reclaimable';

  @override
  String get unused => '未使用';

  @override
  String get dangling => '未タグ';

  @override
  String get pruneUnusedImages => '未使用イメージをクリーンアップ';

  @override
  String get pruneDanglingImages => '未タグイメージをクリーンアップ';

  @override
  String get pruneImages => 'イメージをクリーンアップ';

  @override
  String get unusedTaggedImages => '未使用タグ付き';

  @override
  String get pruneDanglingImagesTip => 'ダングリングイメージのみ削除します。';

  @override
  String get pruneUnusedImagesTip => 'どのコンテナからも使用されていないタグ付きイメージも削除します。';

  @override
  String get includeUnusedVolumesTip => 'どのコンテナからも使用されていないボリュームも削除します。';

  @override
  String get pruneCommandPreview => 'コマンドプレビュー';

  @override
  String get pruneForceSshTip => '-f は対話確認を省略し、SSH 実行では常に有効になります。';

  @override
  String get pruneVolumes => 'ボリュームをクリーンアップ';

  @override
  String get pruneUnusedData => '未使用データをクリーンアップ';

  @override
  String get pull => 'プル';

  @override
  String get invalidHostFormat => 'ホストの形式が無効です。IPv4、IPv6、ドメインで使える文字のみ利用できます。';

  @override
  String get jumpServer => 'ジャンプサーバー';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return '$serverName の踏み台サーバーが見つかりません: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '「$name」は既に存在します';
  }

  @override
  String get noJumpServerAvailable => '利用できる踏み台サーバーがありません。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '踏み台サーバーと ProxyCommand は併用できません。';

  @override
  String get noConnectionMethod => 'SSH、monitor、またはその両方を設定してください';

  @override
  String get keepForeground => 'アプリを前面に保ってください！';

  @override
  String get keepStatusWhenErr => 'エラー時に前回のサーバーステータスを保持';

  @override
  String get keepStatusWhenErrTip => 'スクリプトの実行エラーに限ります';

  @override
  String get keyAuth => 'キー認証';

  @override
  String get lastFailure => '最後の失敗';

  @override
  String get lastSuccess => '最後の成功';

  @override
  String get letterCache => '通常キーボード入力';

  @override
  String get letterCacheTip =>
      '有効にすると入力内容は通常のIMEを経由し、一部のシステムでターミナルにセキュアキーボードの案内が表示されるのを避けられます。';

  @override
  String get linuxShellTip => 'ターミナルを起動するシェル。空にすると /bin/sh に戻ります。';

  @override
  String get linuxNetTip => 'DNS サーバー。空にすると既定値に戻ります';

  @override
  String madeWithLove(String myGithub) {
    return '$myGithubによって❤️で作成済み';
  }

  @override
  String get maxConcurrency => '最大同時実行数';

  @override
  String get maxRetryCount => 'サーバーの再接続試行回数';

  @override
  String get mirror => 'ミラー';

  @override
  String get needRestart => 'アプリを再起動する必要があります';

  @override
  String get newContainer => '新しいコンテナを作成';

  @override
  String get noConnectionStatsData => '接続統計データがありません';

  @override
  String get noPrivateKeyTip => '秘密鍵が存在しません。削除されたか、設定ミスがある可能性があります。';

  @override
  String get noPromptAgain => '再度確認しない';

  @override
  String get openLastPath => '最後のパスを開く';

  @override
  String get openLastPathTip => '異なるサーバーには異なる記録があり、記録されているのは退出時のパスです';

  @override
  String get parseContainerStatsTip => 'Dockerの使用状況の解析は比較的遅いです';

  @override
  String get privateKey => '秘密鍵';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return '秘密鍵 [$keyId] が見つかりません。';
  }

  @override
  String get bmcPowerOnAction => '電源オン';

  @override
  String get bmcShutdown => 'シャットダウン';

  @override
  String get bmcForceOff => '強制電源オフ';

  @override
  String get restart => '再起動';

  @override
  String get bmcPowerCycle => '電源の入れ直し';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '$server に実行しますか？サービスには \"$resetType\" を送ります';
  }

  @override
  String get bmcPowerDone => '電源状態が変わりました';

  @override
  String get bmcPowerAccepted =>
      '受け付けられましたが、電源状態はまだ変わっていません。graceful な操作は OS 次第です';

  @override
  String get bmcPowerUnsupported => 'このサービスはその操作に対して何も許可していません';

  @override
  String get bmcUnauthorized => 'BMC がこのアカウントを拒否しました';

  @override
  String get bmcAccountMissing => 'この BMC にアカウントが設定されていません';

  @override
  String get bmcPowerOn => '電源オン';

  @override
  String get bmcPowerOff => '電源オフ';

  @override
  String get bmcCertRejected => '証明書が拒否されました — サーバー設定で確認してください';

  @override
  String get bmcNotAService => 'このアドレスに Redfish サービスがありません';

  @override
  String get bmcNoSystem => 'サービスはシステムを報告していません';

  @override
  String get bmcSensorsTruncated => '先頭のセンサーのみ表示しています';

  @override
  String get bmcMultipleSystems => '最初のシステムのみ表示しています';

  @override
  String get bmcTip =>
      'BMC はマザーボード上の独立したコンピューターで、ホスト OS が応答しないときも到達できます。ここで設定すると、サーバーが停止していても電源状態とハードウェアセンサーを読めます。Redfish が必要で、おおむね 2016 年以降のエンタープライズ機材なら備えています。';

  @override
  String get bmcCert => '証明書';

  @override
  String get bmcCertPinned => '確認済み・固定済み';

  @override
  String get bmcCertUnreviewed => '未確認 — タップして証明書を表示';

  @override
  String get bmcCertReview => '自己署名証明書です。受け入れる前に照合してください。以後はこの一枚だけが信頼されます。';

  @override
  String get bmcCertChanged => '証明書が一致しません。確認してください。';

  @override
  String get bmcCertExpired => '期限切れです。';

  @override
  String bmcCertWas(String fingerprint) {
    return '以前受け入れた証明書: $fingerprint';
  }

  @override
  String get bmcAddrInvalid => 'BMC のアドレスは URL である必要があります(例: https://10.0.0.9)';

  @override
  String get proxyCommandSandboxed =>
      'このビルドはサンドボックス内で動きます:コマンドが受け取る home は空で、あなたのものではないため、~/.ssh を読むものはすべて失敗します。DMG 版は違います。';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return '秘密鍵ファイル $path を読み込めません: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'このビルドはコンテナ外のファイルを読み込めないため、$path の鍵に到達できません。設定から鍵をインポートするか、DMG 版をご利用ください。';
  }

  @override
  String get pushToken => 'プッシュトークン';

  @override
  String get liveActivity => 'ライブアクティビティ';

  @override
  String get liveActivityTip =>
      'ロック画面と Dynamic Island にターミナルセッションを表示します。デバイスのロックを解除しなくても、サーバー名と接続状態を確認できます。';

  @override
  String get liveActivitySystemDisabled =>
      'iOS が許可していません。スイッチは「設定 › ServerBox › ライブアクティビティ」と「設定 › Face ID とパスコード › ライブアクティビティ」にあります。';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand はこの端末の Linux 環境で実行されます。先に Linux システムをインストールしてください。';

  @override
  String get proxyCommandMobileTip =>
      'スマートフォンでは、このコマンドは選択中の Linux システムで実行されます。使用するツール（nc、socat など）を先にそこへインストールしてください。';

  @override
  String get pveIgnoreCertTip =>
      'オプションを有効にすることは推奨されません、セキュリティリスクに注意してください！PVEのデフォルト証明書を使用している場合は、このオプションを有効にする必要があります。';

  @override
  String get pvePasswordRequired => 'PVE のパスワードが必要です。サーバー設定で指定してください。';

  @override
  String get pveOtpRequired => 'この PVE サーバーでは二要素認証が有効です。OTP コードを入力してください。';

  @override
  String get pveOtpCodeRequired => 'OTP コードが必要です。';

  @override
  String get pveOtpVerificationFailed => 'OTP の検証に失敗しました。新しいコードでやり直してください。';

  @override
  String get pveOtpTitle => 'OTP 検証';

  @override
  String get pveOtpLabel => 'OTP コード';

  @override
  String get pveInvalidResponseBody => 'PVE のログインが無効なレスポンス本文を返しました。';

  @override
  String get pveInvalidResponseData => 'PVE のログイン応答に有効なデータが含まれていませんでした。';

  @override
  String get pveMissingAuthTicket => 'PVE のログインには成功しましたが、認証チケットが返されませんでした。';

  @override
  String get pveLoadingConnect => '接続中…';

  @override
  String get pvePassword => 'PVE パスワード';

  @override
  String get pvePasswordHint => '鍵認証で SSH に接続する場合に必要です';

  @override
  String get read => '読み取り';

  @override
  String get recentConnections => '最近の接続';

  @override
  String get rememberPwdInMem => 'メモリにパスワードを記憶する';

  @override
  String get rememberPwdInMemTip => 'コンテナ、一時停止などに使用されます。';

  @override
  String get remotePath => 'リモートパス';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed が入っていて、$latest があります。更新はコンテナ全体を置き換えます：$pm のデータは失われます';
  }

  @override
  String linuxSystemInUse(String name) {
    return '$name のターミナルを閉じてから削除してください';
  }

  @override
  String get rootfsSubtitle => 'この端末上の Linux ユーザーランド';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return '$distro $version（約 $size MB）をダウンロードして端末に展開します。';
  }

  @override
  String get sameIdServerExist => '同じIDのサーバーが既に存在します';

  @override
  String get second => '秒';

  @override
  String get serverFilesUnavailableTip =>
      'このサーバーへの SSH、または server_box_monitor をファイル API 有効で入れておく必要があります。';

  @override
  String get back => '戻る';

  @override
  String get history => '履歴';

  @override
  String get homeDir => 'ホーム';

  @override
  String selected(int count) {
    return '$count 件選択';
  }

  @override
  String get sendTo => '送信先…';

  @override
  String get serverFuncBtns => 'サーバー機能ボタン';

  @override
  String get serverOrder => 'サーバー順序';

  @override
  String get serverOverview => 'サーバー概要';

  @override
  String get serverOverviewTip => 'サーバー一覧の上部に概要を、開いているサーバーの上部にサーバー切り替えバーを表示します';

  @override
  String get serverTabEmpty => 'サーバーはまだありません';

  @override
  String get serverTabConnBadge => 'サーバータブの接続数';

  @override
  String get serverTabConnBadgeTip => '接続中のサーバー数（例: 2/4）';

  @override
  String get serverTabRequired => 'サーバータブは削除できません';

  @override
  String get shareCodeHint => 'この数字は別の方法で受信者に伝えてください。QR コードには含まれていません。';

  @override
  String get shareCodePrompt => '6 桁のコード';

  @override
  String get shareCodeTitle => 'ワンタイムコード';

  @override
  String get shareExpired => 'この共有データは期限切れです。新しい共有データを依頼してください。';

  @override
  String get shareImportFile => '共有ファイルから';

  @override
  String get shareImportTitle => '共有サーバーをインポート';

  @override
  String get shareIncludesKey => '共有データに秘密鍵が含まれています。';

  @override
  String get shareOmittedBmc => 'BMC の認証情報。アドレスは含まれますが、認証情報は含まれません。';

  @override
  String get shareOmittedJump => '踏み台サーバー。この端末では別のサーバーとして保存されているためです。';

  @override
  String get shareOmittedKeyPath => '鍵ファイル。そのパスはこの端末でのみ有効なためです。';

  @override
  String get shareOmittedMissingKey => '秘密鍵。この端末の鍵ストアに保存されていないためです。';

  @override
  String get shareOmittedTip => '次の項目は含まれません。受信者側で設定してください：';

  @override
  String get sharePassphraseTip =>
      'このパスフレーズでファイルを暗号化します。サーバーのインポート時に必要となり、復元することはできません。';

  @override
  String shareQrTip(int minutes) {
    return 'この QR コードの接続情報は暗号化されています。共有データは $minutes 分後に期限切れになります。';
  }

  @override
  String get shareScanQr => 'QR コードをスキャン';

  @override
  String shareServerExists(String name) {
    return 'この端末の「$name」はすでに同じアドレスを使用しています。それでもインポートしますか？';
  }

  @override
  String get shareTooBigForQr => 'QR コードに収まりません。代わりにファイルとして共有してください。';

  @override
  String get shareTooNew =>
      'この共有データは新しいバージョンの ServerBox で作成されています。アプリを更新してから開いてください。';

  @override
  String get shareUnreadable => '有効な ServerBox の共有データではありません。';

  @override
  String get shareVia => '共有方法';

  @override
  String get sftpDlPrepare => 'サーバーへの接続を準備中...';

  @override
  String get sftpEditorTip =>
      '空なら内蔵エディタを使います。 たとえば `vim`（`EDITOR` から取るのがおすすめ）。';

  @override
  String get sftpRmrDirSummary => 'SFTPで`rm -r`を使用してフォルダーを削除';

  @override
  String get sftpSSHConnected => 'SFTPに接続されました...';

  @override
  String get sftpShowFoldersFirst => 'フォルダーを先に表示';

  @override
  String get sftpUnavailableUseScp =>
      '多くの組み込み機器のようにこのホストに SFTP サブシステムがない場合は、サーバー設定でファイル転送を SCP に変更してください。';

  @override
  String get sshFileTransportTip =>
      '最近の機器なら SFTP。SSH サーバーに SFTP サブシステムがない古い機器や組み込み機器では SCP を選んでください。`scp` コマンドと、`find`・`stat`・`mv`・`chmod` など一般的なファイル操作コマンドが揃った shell 環境が必要です。';

  @override
  String get specifyDev => 'デバイスを指定';

  @override
  String get specifyDevTip => 'ネットワーク流量は既定で全デバイスを合算します。ここで指定できます';

  @override
  String get tempIsCelsiusTip =>
      '有効にすると、温度の値をミリ摂氏ではなく摂氏として扱います。温度が正しく表示されない場合（58 °C ではなく 0.1 °C と表示されるなど）にのみ有効にしてください。';

  @override
  String spentTime(String time) {
    return '費した時間: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'すべてのサーバーがすでに存在します（$duplicateCount個の重複が見つかりました）';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount個の重複がスキップされます';
  }

  @override
  String get sshConfigFound => 'システムにSSH設定が見つかりました。';

  @override
  String sshConfigFoundServers(int totalCount) {
    return '$totalCount個のサーバーが見つかりました';
  }

  @override
  String get sshConfigImport => 'SSH設定のインポート';

  @override
  String get sshConfigImportPermission =>
      '~/.ssh/configを読み取ってサーバー設定を自動的にインポートする権限を与えますか？';

  @override
  String get sshConfigImportTip => '初回サーバー作成時に~/.ssh/configの読み取りを促す';

  @override
  String sshConfigImported(int count) {
    return 'SSH設定から$count個のサーバーをインポートしました';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return '$serverName の SSH ホスト鍵が変更されました。このサーバーを信頼できる場合のみ続行してください。';
  }

  @override
  String get sshHostKeyType => 'SSH ホストキーの種類';

  @override
  String get sshKnownHostKeys => '既知のホスト';

  @override
  String get sshKnownHostKeysTip => 'このアプリが受け入れたホスト鍵';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return '$serverName から新しい SSH ホスト鍵を受信しました。信頼する前にフィンガープリントを確認してください。';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return '保存済みフィンガープリント: $fingerprint';
  }

  @override
  String get sshVerificationCode => '確認コード';

  @override
  String get sshConfigManualSelect => 'SSH設定ファイルを手動で選択しますか？';

  @override
  String get sshConfigNoServers => 'SSH設定でサーバーが見つかりませんでした';

  @override
  String get sshConfigPermissionDenied => 'macOSの権限により、SSH設定ファイルにアクセスできません。';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount個のサーバーがインポートされます';
  }

  @override
  String get sshTermHelp =>
      'ターミナルがスクロール可能な場合、横にドラッグするとテキストを選択できます。キーボードボタンをクリックするとキーボードのオン/オフが切り替わります。ファイルアイコンは現在のパスSFTPを開きます。クリップボードボタンは、テキストが選択されているときに内容をコピーし、テキストが選択されておらずクリップボードに内容がある場合には、その内容をターミナルに貼り付けます。コードアイコンは、コードスニペットをターミナルに貼り付けて実行します。';

  @override
  String get sshVirtualKeyAutoOff => '仮想キーの自動オフ';

  @override
  String get supportFmtArgs => '以下のフォーマット引数がサポートされています：';

  @override
  String get suspendTip => 'suspend機能はroot権限とsystemdのサポートが必要です。';

  @override
  String switchTo(String val) {
    return '$valに切り替える';
  }

  @override
  String get syncAppSettings => 'アプリ設定を同期';

  @override
  String get syncAppSettingsTip => 'テーマ、レイアウト、エディター、ターミナルなど端末ごとの設定も自動同期に含めます。';

  @override
  String get termFontSizeTip =>
      'この設定は端末のサイズ（幅と高さ）に影響します。現在のセッションのフォントサイズを調整するために、端末ページを拡大縮小できます。';

  @override
  String get textScalerTip =>
      '1.0 => 100%（デフォルトサイズ）。サーバーページの一部のテキストにのみ適用されます。変更をお勧めしません。';

  @override
  String get times => '回';

  @override
  String get trySudo => 'sudoを試みる';

  @override
  String get sudoPromptNotFound => 'sudo のパスワード入力プロンプトがありません。';

  @override
  String get updateServerStatusInterval => 'サーバー状態の更新間隔';

  @override
  String get useNoPwd => 'パスワードなしで使用します';

  @override
  String get usePodmanByDefault => 'デフォルトでPodmanを使用';

  @override
  String get used => '使用済み';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get virtKeyHelpIME => 'キーボードのオン/オフ';

  @override
  String get virtKeyHelpSFTP => '現在のパスでSFTPを開く。';

  @override
  String get virtKeyHelpSnippet => 'スニペットを選んで、このターミナルで実行します。';

  @override
  String get virtKeyHelpTmux => 'tmux のセッションとウィンドウを切り替えます。';

  @override
  String get virtKeyIntroActions => 'ショートカット';

  @override
  String get virtKeyIntroActionsTip => 'これらは文字を入力せず、機能を開きます。長押しすると説明を読めます。';

  @override
  String get virtKeyIntroCustomizeTip =>
      'ターミナル設定で並べ替えたり、キーを追加したり（ファイル、sudo、F1–F12 など）、使わないキーを隠したりできます。';

  @override
  String get virtKeyIntroModifiers => '修飾キー';

  @override
  String get virtKeyIntroModifiersTip =>
      'タップして有効にしてから、キーボードの文字をタップします。有効なのは次の 1 キーだけです。';

  @override
  String get virtKeyIntroNav => 'カーソル移動';

  @override
  String get virtKeyIntroNavTip => 'これらはカーソルを動かします。矢印キーは長押しで連続入力できます。';

  @override
  String get virtKeyIntroSelect =>
      'ターミナルにスクロールできる内容があるときは、横にドラッグするとテキストを選択できます。';

  @override
  String get virtKeyRows => '同時に表示する行数';

  @override
  String get virtKeyRowsTip => '残りは別のページに置かれ、横にスワイプして切り替えます。';

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
  String get writeScriptFailTip =>
      'スクリプトの書き込みに失敗しました。権限がないかディレクトリが存在しない可能性があります。';

  @override
  String get writeScriptTip =>
      'サーバーへの接続後、システムステータスを監視するスクリプトが `~/.config/server_box` \n | `/tmp/server_box` に書き込まれます。スクリプトの内容を確認できます。';

  @override
  String get menuGitHubRepository => 'GitHub リポジトリ';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker エミュレーションが検出されました。設定で Podman に切り替えてください。';

  @override
  String get betaTip => 'この機能はまだベータ版です。動作は保証されません。';

  @override
  String get portForward_startPrompt => 'ポート転送のルールを追加して始めましょう';

  @override
  String get portForward_localHost => 'ローカルホスト';

  @override
  String get portForward_localPort => 'ローカルポート';

  @override
  String get portForward_remoteHost => 'リモートホスト';

  @override
  String get portForward_remotePort => 'リモートポート';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get sponsor => 'スポンサー';

  @override
  String get sortByJoinTime => '追加した順';

  @override
  String get tmuxAutoAttach => 'tmux に自動アタッチ';

  @override
  String get tmuxAuto => '自動 tmux';

  @override
  String get tmuxAutoTip => 'SSH 接続時に tmux を自動で開始またはアタッチします';

  @override
  String get tmuxSessionSelector => 'セッション選択';

  @override
  String get tmuxSessionSelectorTip => '接続時にセッション選択画面を表示します';

  @override
  String get tmuxDefaultSessionName => '既定のセッション名';

  @override
  String get tmuxSessionName => 'セッション名';

  @override
  String get tmuxNewSession => '新しいセッション';

  @override
  String get tmuxNewWindow => '新しいウィンドウ';

  @override
  String get tmuxNoWindowsFound => 'ウィンドウが見つかりません';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のウィンドウ',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'アタッチ中';

  @override
  String get tmuxSkip => 'スキップ';

  @override
  String get tmuxNotAvailable => 'tmux を利用できません';

  @override
  String containerSegmentsMismatch(int count) {
    return 'コンテナ応答のセグメント数が想定外です: $count';
  }

  @override
  String get containerOperationInProgress => '別のコンテナ操作がすでに実行中です';

  @override
  String processCount(int count) {
    return '$count 件のプロセス';
  }

  @override
  String get processParseUnsupportedOutput => 'このプロセス一覧の形式はサポートされていません。';

  @override
  String get processParseInvalidRows => '一部のプロセス項目を読み取れませんでした。';

  @override
  String get processParseInvalidWindowsJson => 'Windows のプロセス応答を読み取れませんでした。';

  @override
  String get processParseInvalidWindowsRows => '一部の Windows プロセス項目を読み取れませんでした。';

  @override
  String get processKillTargetChanged => 'プロセスが変更されたか終了しました。一覧を更新して再試行してください。';

  @override
  String get processSearchHint => '名前、ユーザー、PID';

  @override
  String processShowKernelThreads(int count) {
    return 'カーネルスレッドを $count 件表示';
  }

  @override
  String get processForceKill => 'Force kill';

  @override
  String get processStarted => 'Started';

  @override
  String get processThreads => 'Threads';

  @override
  String get watchServers => 'Watch に表示するサーバー';

  @override
  String get watchServersTip =>
      '時計は自分で monitor から取得するため、monitor のあるサーバーだけ選べます。';

  @override
  String get watchNoMonitorServer => 'monitor を設定したサーバーがありません';

  @override
  String get legacyStatusGoneTitle => 'ステータス URL は使用できなくなりました';

  @override
  String get legacyStatusGoneBody =>
      'ウォッチ App とホーム画面ウィジェットは、手入力した `/status` アドレスを読み取っていました。このエンドポイントは削除されました。現在値をテキストで返すことしかできず、グラフを表示できなかったのはそのためです。\n\n現在は monitor の認証付き API を読み取るため、推移を描画でき、App と自動的に同期します。App でサーバーを一度設定すれば、すべてのウォッチとウィジェットが受け取ります。';

  @override
  String get services => 'サービス';

  @override
  String get status => '状態';

  @override
  String get enable => '有効化';

  @override
  String get disable => '無効化';

  @override
  String get starting => '起動中';

  @override
  String get stopping => '停止中';

  @override
  String get serviceManagerUnsupported => '未対応のサービスマネージャー';

  @override
  String get serviceManagerUnsupportedTip =>
      'このサーバーのサービスマネージャーにはまだ対応していません。systemd、procd、OpenRC に対応しています。';

  @override
  String serviceManagerFmt(String manager) {
    return '$manager で管理';
  }

  @override
  String get serviceListFailed => 'サービスを一覧表示できませんでした';

  @override
  String get serviceDetailsUnavailable => '一部のサービス情報を取得できません';

  @override
  String get serviceDetailsUnavailableTip =>
      '一覧は利用できますが、状態または自動起動の情報がすべて返されませんでした。';

  @override
  String get systemdUserScopeMissing => 'ユーザー unit は表示されていません';

  @override
  String get systemdUserScopeMissingTip =>
      'このアカウントにはサーバー上のユーザーセッションバスがないため、システム unit のみ表示しています。';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    return '他 $count 件の unit';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => 'Type';

  @override
  String get serviceScope => 'Scope';

  @override
  String get serviceStartup => 'Startup';

  @override
  String serviceUpFor(String duration) {
    return 'up $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return 'down $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return 'next $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return '$duration 前に停止';
  }

  @override
  String serviceExitStatus(int code) {
    return '終了ステータス $code';
  }

  @override
  String get serviceFullJournal => 'Full journal';

  @override
  String get serviceUnitFile => 'Unit file';

  @override
  String serviceJournalRecent(int count) {
    return '最近の $count 行';
  }

  @override
  String get serviceJournalUnreadable => 'このアカウントでは journal を読めません';

  @override
  String get serverUnreachable => 'このサーバーでコマンドを実行できませんでした';

  @override
  String get containerNoRuntime => 'コンテナランタイムがありません';

  @override
  String get containerNoRuntimeTip =>
      'このマシンでは `docker` も `podman` も応答しませんでした。別のアカウントにインストールされている場合は、設定で「sudoを試みる」を有効にしてください。';

  @override
  String get containerUnreadable => 'コンテナランタイムの応答を解釈できませんでした';

  @override
  String get power => '電源';

  @override
  String get fan => 'ファン';

  @override
  String get clockSpeed => 'クロック';

  @override
  String get vendor => 'ベンダー';

  @override
  String get continueInTerminal => 'ターミナルで続ける';

  @override
  String get askAiRiskUnknown => '判定不能';

  @override
  String get agentLocalExec => 'このデバイスでコマンドを実行';

  @override
  String get agentLocalExecTip =>
      'ServerBox が動いているこの端末上で Agent に作業させます。読み取り専用のコマンドも確認が必要です';

  @override
  String get agentLocalExecRootfsTip =>
      'Agent をローカルで動かします。範囲は ServerBox が入れた Linux コンテナ内に限られます';

  @override
  String macDmgImportedPartly(String path) {
    return '以前インストールされていたビルドのデータを取り込みました。ダウンロードしたファイルは $path に残っています。';
  }

  @override
  String get bmcAccount => 'アカウント';

  @override
  String get bmcAccountUnset => '未選択 — タップして選択または作成';

  @override
  String bmcAccountShared(int count) {
    return '$count 台のサーバーで使用中';
  }

  @override
  String get bmcAccounts => 'BMC アカウント';

  @override
  String get bmcAccountSharedTip => 'ここでの変更はすべてに反映されます。';

  @override
  String bmcAccountInUse(int count) {
    return '$count 台のサーバーが使用中です。アドレスは残り、アカウントは失われます。';
  }

  @override
  String get bmcStaleWrite => '書き込み中に BMC が変更されました。再試行してください。';

  @override
  String get privacyBlur => 'バックグラウンドのプライバシー';

  @override
  String get privacyBlurTip => 'Appスイッチャーで内容を隠す';

  @override
  String get floatReturnToTab => 'タブに戻す';

  @override
  String get termInFloatWindow => 'このターミナルはフローティングウィンドウにあります';

  @override
  String get globeEnabledTip =>
      'サーバーをアドレスの所在地に基づいて地球儀上に表示します。オフにするとボタンが消え、一切の照会を行いません。';

  @override
  String get geoShardsConsentAttribution =>
      'IP 位置情報は [DB-IP](https://db-ip.com) 提供、CC BY 4.0。';

  @override
  String get geoMissPrivate => 'プライベートアドレス';

  @override
  String get geoMissNoData => '位置データなし';

  @override
  String get globeGuide => 'ここをタップすると、サーバーをアドレスの所在地に基づいて地球儀上に表示します。';

  @override
  String get publicIp => 'パブリック IP';

  @override
  String get geoData => '市区レベルのデータ';

  @override
  String get geoDataTip =>
      'ダウンロード後の位置情報検索には、この端末に保存されたデータが使用されます。サーバーのアドレスや検索状況がダウンロードサービスに送信されることはありません。';

  @override
  String get geoDataMissing => '未ダウンロード';

  @override
  String get geoDataUnreachable => 'データを取得できませんでした。';

  @override
  String get geoDataRemoveFailed => 'データを削除できませんでした。';

  @override
  String geoDataCurrent(String month) {
    return 'すでに $month のデータです。';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**ダウンロード：$download · 端末上の使用容量：$disk。** 完全なデータセットはこの端末に保存され、以後の位置情報検索はすべてローカルで行われます。サーバーのアドレスや検索状況がダウンロードサービスに送信されることはありません。\n\n毎月更新されます。新しいバージョンはインストール済みのデータを置き換え、追加のコピーは保持しません。データはいつでも削除できます。';
  }

  @override
  String get benchmark => 'ベンチマーク';

  @override
  String get benchmarkIntro =>
      'このサーバーで Yet Another Bench Script を実行し、ディスク、ネットワーク、CPU を測定します。すべてのテストには 10～20 分かかり、このページを離れたりアプリを閉じたりしても実行は継続します。';

  @override
  String get benchmarkNoRuns => 'ベンチマーク結果はまだありません。';

  @override
  String get benchmarkRunning => 'ベンチマーク実行中';

  @override
  String get benchmarkStartFailed => 'ベンチマークを開始できませんでした';

  @override
  String get benchmarkCancelConfirm => 'このベンチマークを停止しますか？ここまでの測定結果は失われます。';

  @override
  String get benchmarkDeleteConfirm => 'このベンチマーク結果を削除しますか？';

  @override
  String get benchmarkNothingSelected =>
      'すべてのテスト項目がオフです。システム情報のみを収集し、数秒で完了します。';

  @override
  String get benchmarkDiskTip =>
      '4 種類のブロックサイズで fio を実行します（約 3 分）。作業ディレクトリに 2 GB のテストファイルを書き込むため、同量の空き容量が必要です。';

  @override
  String get benchmarkNetworkTip => '公開サーバーに対して iperf3 を実行します（約 4 分）。';

  @override
  String get benchmarkReducedNetwork => '測定地点を減らす';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return '測定地点を 7 か所から 3 か所に減らします。推定通信量は $full から $reduced になります。';
  }

  @override
  String get benchmarkCpuTip =>
      'プロプライエタリソフトウェアの Geekbench をダウンロードし、**結果を geekbench.com の公開ページに掲載します**。CPU モデル、コア数、メモリも公開されます。';

  @override
  String get benchmarkSensitiveOptions =>
      '以下のオプションは、このサーバーにサードパーティ製ソフトウェアをダウンロードして実行するか、サーバー情報を第三者に送信します。デフォルトではオフです。';

  @override
  String get benchmarkIpInfoTip =>
      'このサーバーのグローバル IP アドレスを、暗号化されていない HTTP で ip-api.com に送信します。';

  @override
  String get benchmarkIpInfo => 'IP アドレスの所有者を検索';

  @override
  String get benchmarkPreferBin => 'fio と iperf3 をダウンロード';

  @override
  String get benchmarkPreferBinTip =>
      'ホストのパッケージを使わず、GitHub からダウンロードします。ホストにどちらもインストールされていない場合にのみ有効にしてください。';

  @override
  String get benchmarkWorkDir => '作業ディレクトリ';

  @override
  String get benchmarkWorkDirTip =>
      'ディスクテストで測定するファイルシステムを決定します。空欄の場合はログインアカウントのホームディレクトリを使用します。';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return '約 $minutes 分';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return '通信量：約 $size';
  }

  @override
  String get benchmarkPhaseSystem => 'システム情報を取得中';

  @override
  String get benchmarkPhaseDisk => 'ディスクを測定中';

  @override
  String get benchmarkPhaseNetwork => 'ネットワークを測定中';

  @override
  String get benchmarkPhaseCpu => 'CPU を測定中';

  @override
  String get benchmarkPhaseDone => '完了処理中';

  @override
  String get benchmarkResultUnreadable =>
      'この結果を JSON として読み取れませんでした。以下に元のテキストを表示します。';

  @override
  String get benchmarkViewOnGeekbench => 'Geekbench で表示';

  @override
  String get benchmarkGeekbenchPublic => 'この結果は上記リンクで一般公開されています。';

  @override
  String get benchmarkSingleCore => 'シングルコア';

  @override
  String get benchmarkMultiCore => 'マルチコア';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'アップロード';

  @override
  String get benchmarkRecv => 'ダウンロード';

  @override
  String get benchmarkLatency => 'レイテンシ';

  @override
  String get benchmarkVirt => '仮想化';

  @override
  String get benchmarkRawLog => '実行ログ';

  @override
  String benchmarkUpstream(String version) {
    return 'Yet Another Bench Script ($version) を使用';
  }

  @override
  String get benchmarkPhaseStarting => '開始中';

  @override
  String get benchmarkNoOutputYet =>
      'まだ出力はありません。YABS は最初の行を出力する前に、google.com と icanhazip.com に接続できるか確認します。いずれかのサイトがブロックされているネットワークでは、数分かかる場合があります。';

  @override
  String get tagsEmptyTip => 'まだタグはありません。サーバーの編集中に追加すると、ここに表示されます。';

  @override
  String get benchmarkNoServers => '先にサーバーを追加してから戻ると、ベンチマークを実行できます。';

  @override
  String get schemaTooNewTitle => 'このデータはアプリより新しいバージョンで作成されています';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'このデータは新しいバージョンの ServerBox で作成されました（保存形式 v$stored）。このバージョンで読み込めるのは v$supported までです。データは変更されていません。';
  }

  @override
  String get schemaTooNewReinstall => '新しいバージョンを再インストールすれば、すべて元どおり開けます。';

  @override
  String get schemaTooNewExportPlain => 'パスワードなしで書き出す';

  @override
  String get schemaTooNewPlainWarn =>
      'ファイルにはすべての SSH 秘密鍵、サーバーのパスワード、API キーが平文で保存されます。このファイルを入手した人は、すべての情報を取得できます。';

  @override
  String get schemaTooNewWipe => 'すべてのデータを削除';

  @override
  String get schemaTooNewWipeConfirm =>
      'このデバイス上のすべてのサーバー、鍵、スニペット、設定を削除します。この操作は取り消せません。ここで書き出したバックアップが残る唯一のコピーになります。';

  @override
  String get schemaTooNewWipeDone => 'データを削除しました。アプリを再度開いて最初から始めてください。';

  @override
  String get schemaTooNewWipeFailed =>
      '一部のデータを削除できなかったため、このバージョンでは残りのデータも開けません。新しいバージョンを再インストールしてアクセスしてください。';

  @override
  String get systemUsers => 'ユーザー';

  @override
  String get userManagerLinuxOnly => 'システムユーザー管理は現在 Linux サーバーにのみ対応しています。';

  @override
  String get userRegularAccount => '一般アカウント';

  @override
  String get userCurrentAccount => '現在のアカウント';

  @override
  String get userSystemAccount => 'システムアカウント';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => 'ログイン状態';

  @override
  String get userLoginEnabled => 'ログイン可能';

  @override
  String get userDetailAccount => 'アカウント';

  @override
  String get userDetailSecurity => 'セキュリティ';

  @override
  String get userSshKeys => 'SSH 鍵';

  @override
  String get userExpires => '有効期限';

  @override
  String get userNever => '無期限';

  @override
  String get userPasswordSet => '設定済み';

  @override
  String get userPasswordLocked => 'ロック中';

  @override
  String get userPasswordNone => 'なし';

  @override
  String get userSuperuser => 'スーパーユーザー';

  @override
  String get userOpenShell => 'shell を開く';

  @override
  String get userRootChangesWarning => 'root への変更はすべてのセッションにすぐに反映されます。';

  @override
  String get userComment => 'コメント';

  @override
  String get userPrimaryGroup => 'プライマリグループ';

  @override
  String get userSupplementaryGroups => '補助グループ';

  @override
  String get userLoginShell => 'ログイン shell';

  @override
  String get userCreateHome => 'ホームディレクトリを作成';

  @override
  String get userMoveHome => 'パスの変更時に現在のホームディレクトリも移動';

  @override
  String get userRemoveHome => 'ホームディレクトリを削除';

  @override
  String get userPasswordCreateTip => 'パスワードを空にすると、パスワードログインが無効なアカウントを作成します。';

  @override
  String get userPasswordEditTip => '現在のパスワードを保持する場合は空のままにします。';

  @override
  String funcUnavailableFmt(String func) {
    return '$func はこのサーバーの接続方法では利用できません。';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return '$funcを使うには Monitor agent の $setting を有効にする必要があります。';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return '$funcを使うには Monitor agent の更新が必要です。';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      'Monitor agent 経由のリモート転送には新しいバージョンが必要です。サーバー上で更新してください。';

  @override
  String get rangeLive => 'リアルタイム';

  @override
  String get diskIo => 'ディスク I/O';

  @override
  String get peak => 'ピーク';

  @override
  String get hardware => 'ハードウェア';

  @override
  String get cores => 'コア数';

  @override
  String get historyNoStored =>
      '履歴を保存するのは monitor エージェントだけです。この接続では、アプリが接続後に見た分のみ保持します。';

  @override
  String get noHistoryYet => 'まだ計測データがありません';

  @override
  String get noData => 'データなし';

  @override
  String get from => '開始';

  @override
  String get to => '終了';

  @override
  String get beyondRetention => 'この agent の保持期間より前';

  @override
  String agentRetentionFmt(String kept) {
    return 'agent の保持期間は $kept';
  }

  @override
  String get agentServerTools => 'サーバーツール';

  @override
  String get agentServerToolsTip =>
      'サーバーでコマンドを実行し、ファイルを読み書きし、SSH で他のホストに接続し、ServerBox 自体の操作を使います。';

  @override
  String get agentTerminalTools => 'ターミナル';

  @override
  String get agentTerminalToolsTip =>
      'ターミナル自身のチャットで：画面の内容を読み取り、そのサーバーでコマンドを実行します。';

  @override
  String get agentToolTerminalScreen => '画面を読む';

  @override
  String get agentProviders => 'プロバイダー';

  @override
  String get agentProvidersTip => 'API キー、モデル、新しいチャットで使うモデル';

  @override
  String get agentTools => 'ツール';

  @override
  String get agentToolsTip => 'Agent が使えるツールと MCP サーバー';

  @override
  String get agentSnippetToolsTip => 'snippet の一覧、追加、変更、削除。変更は確認されます。';

  @override
  String get agentVirtToolsTip => '仮想化タブが読み込んだ VM とコンテナを読み取ります。';

  @override
  String get agentBenchmarkToolsTip => 'ベンチマーク結果を読み取り、承認を得て実行または停止します。';

  @override
  String get agentRemoteDesktopToolsTip =>
      'リモートデスクトップのプロファイルを一覧し、承認を得て接続または切断します。';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip => '特定の作業の手順書。GitHub やリンクからインストール';

  @override
  String get agentPermissions => '権限';

  @override
  String get agentEmptyHint => 'サーバーについて質問したり、サーバー上での作業を Agent に頼んだりできます。';

  @override
  String get agentTerminalEmptyHint =>
      'このサーバーについて質問できます。Agent はこのターミナルを読み取り、ここでコマンドを実行できます。';

  @override
  String oldestSampleFmt(String time) {
    return '最も古い取得は $time';
  }

  @override
  String get rangeEndsBeforeItStarts => '範囲の終了は開始より後である必要があります。';

  @override
  String get samples => 'サンプル';

  @override
  String get unavailable => '取得できません';

  @override
  String get metricUnavailableTip =>
      'このページの他の項目には影響ありません。ホスト側でこの値を取得するコマンドを確認してください。';

  @override
  String get waitingFirstSample => '最初の取得を待っています';

  @override
  String atTimeFmt(String time) {
    return '$time 時点';
  }

  @override
  String get stored => '保存済み';

  @override
  String lastSampleFmt(String ago) {
    return '最新の取得は$ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return '以下はすべて $time 時点（$ago）の値です。';
  }

  @override
  String noDataBeforeFmt(String time) {
    return '$time より前のデータはありません';
  }

  @override
  String loadingRangeFmt(String range) {
    return '$range を読み込み中…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return '$metric の保存された履歴はありません';
  }

  @override
  String devicesFmt(int count) {
    return '$count 台のデバイス';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count 台のデバイス · 最も負荷が高いのは $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$total 台中 $plotted 台';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return 'センサー $count 個 · 最高は $name';
  }

  @override
  String get oneDeviceAtLeast => 'グラフには少なくとも 1 台を残します。';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$what $total 件中 $shown 件';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$what $count 件';
  }

  @override
  String get unitDevices => 'デバイス';

  @override
  String get unitSensors => 'センサー';

  @override
  String get unitBatteries => 'バッテリー';

  @override
  String get unitCommands => 'コマンド';

  @override
  String get unitReadings => '測定値';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => '最高';

  @override
  String get oldest => '最長';

  @override
  String get notApplicable => '対象外';

  @override
  String get attributes => '属性';

  @override
  String get powerOnHours => '通電時間';

  @override
  String get powerCycles => '電源投入回数';

  @override
  String get lifeLeft => '残り寿命';

  @override
  String get lifetimeWrite => '総書き込み';

  @override
  String get lifetimeRead => '総読み込み';

  @override
  String get averageErase => '平均消去回数';

  @override
  String get unsafeShutdowns => '異常終了回数';

  @override
  String get diskAllPassed => 'すべて PASSED';

  @override
  String diskWarningFmt(int count) {
    return '警告 $count 件';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$total 台中 $wrong 台';
  }

  @override
  String get diskSmartSortedTip => '悪い順';

  @override
  String readAgoFmt(String ago) {
    return '$agoに取得';
  }

  @override
  String processesFmt(int count) {
    return '$count 個のプロセス';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count 台が異常';
  }

  @override
  String get diskSmartOpenTip => 'タップすると属性を表示';

  @override
  String get cycle => 'サイクル';

  @override
  String get window => '期間';

  @override
  String ofFmt(String total) {
    return '$total 中';
  }

  @override
  String get serverDetailCards => '詳細ページのカード';

  @override
  String get connection => '接続';

  @override
  String get connectionTip => '両方を同時に有効にできます。並び順が接続を試す順序です。';

  @override
  String get transportNoneOn => 'どちらも無効です — このサーバーには接続できません。';

  @override
  String get thisDevice => 'このデバイス';

  @override
  String get localServerTip =>
      'ステータススクリプトをこのデバイス上で実行して直接読み取ります。SSH と Monitor HTTP は使用せず、その設定は保持されます。';

  @override
  String get localServerUnsupported =>
      'このプラットフォームでは、このデバイスをサーバーとして読み取れません。Linux、Windows、macOS の DMG 版が対応しています。';

  @override
  String get remoteDesktopIntro =>
      'サーバーの RDP または VNC デスクトップをアプリ内で開きます。接続はサーバーの SSH 接続または Monitor エージェントを経由するため、デスクトップのポートをネットワークに公開する必要はありません。';

  @override
  String get remoteDesktopIntroProfiles =>
      'サーバーの「リモートデスクトップ」ボタン、または「リモートデスクトップ」タブから、デスクトップごとにプロファイルを保存します。';

  @override
  String get localServerIntro =>
      'ServerBox を実行しているデバイスをサーバーとして追加します。ステータス、プロセス、サービス、コンテナ、ターミナル、ファイルは SSH や Monitor エージェントなしで使えます。';

  @override
  String get localServerAdd => 'このデバイスを追加';

  @override
  String get localServerIntroFooter => '後からサーバーの編集ページの「接続」でも有効にできます。';

  @override
  String get transportSectionOff => '無効です。再び有効にするときのために、以下の項目はそのまま保持されます。';

  @override
  String get monitorAgent => 'Monitor エージェント';

  @override
  String get plainHttpEditTip =>
      '認証情報と計測値が暗号化されずにネットワークを通ります。LAN か Tailscale のアドレスに限定するか、エージェントを TLS の背後に置いてください。';

  @override
  String get behaviour => '動作';

  @override
  String get optional => '任意';

  @override
  String get sshAdvanced => 'SSH 詳細';

  @override
  String get sshAdvancedTip => '代替の接続先、ProxyCommand、踏み台、ファイル転送、リモートのパス';

  @override
  String get sshLegacyAlgorithms => '古いアルゴリズム';

  @override
  String get sshLegacyAlgorithmsTip =>
      'SHA-1 の `ssh-rsa` ホスト鍵または SHA-1 鍵交換しか提供しない古い SSH サーバー（ルーターやスイッチなど）向けです。安全性が低いため、必要なホストでのみ有効にしてください。';

  @override
  String get appearanceAndPlace => '外観と場所';

  @override
  String get appearanceAndPlaceTip => 'ロゴ、座標';

  @override
  String get statusCollection => 'ステータス収集';

  @override
  String get statusCollectionTip => '実行するコマンド、カスタムコマンド、読み取るデバイス';

  @override
  String get tagAllTags => 'すべてのタグ';

  @override
  String get tagMatching => '一致';

  @override
  String get tagNewHint => '新しいタグ';

  @override
  String tagCreateFmt(String tag) {
    return '#$tag を作成';
  }

  @override
  String get tagOnThisServer => 'このサーバー';

  @override
  String tagServersFmt(int count) {
    return '$count 台のサーバー';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return 'このサーバーに $count 個';
  }

  @override
  String get tagMatchesTyped => '入力に一致';

  @override
  String get tagEditorTip =>
      '入力するとリストが絞り込まれます。ボタンはタグを作成し、そのままこのサーバーに付けます。鉛筆は名前の変更で、そのタグを使うすべてのサーバーに及びます。どのサーバーも使わなくなったタグは保存時に消えます。';

  @override
  String get tagRenamesOnSave => '名前の変更は保存時に反映されます';

  @override
  String get scheduledTasks => 'スケジュールタスク';

  @override
  String get scheduledTaskLinuxOnly => 'スケジュールタスク管理は現在 Linux サーバーにのみ対応しています。';

  @override
  String get scheduledTaskUnavailable => 'このサーバーでは crontab を利用できません。';

  @override
  String get scheduledTaskPreserveTip =>
      'この crontab にあるコメント、環境変数、認識できない行は保持されます。';

  @override
  String get scheduledTaskSchedule => '実行スケジュール';

  @override
  String get scheduledTaskAdd => 'タスクを追加';

  @override
  String get scheduledTaskNextRun => '次回の実行';

  @override
  String scheduledTaskNextInFmt(String time) {
    return '$time 後';
  }

  @override
  String get scheduledTaskEnabled => '有効';

  @override
  String get scheduledTaskCommentedOut => 'コメントアウト済み';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    return '$total 件のタスク · $enabled 件が有効';
  }

  @override
  String get scheduledTaskFilterHint => 'タスクを絞り込む';

  @override
  String get scheduledTaskPreserved => '保持される行';

  @override
  String get scheduledTaskRaw => '元の crontab';

  @override
  String get scheduledTaskEnableNow => '今すぐ有効化';

  @override
  String get scheduledTaskEnableNowTip => 'オフにすると、この行はコメントアウトして書き込まれます。';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return '$user にスケジュールタスクはありません。ここで追加した内容は、そのアカウントの crontab に書き込まれます。';
  }

  @override
  String get scheduledTaskFieldMinute => '分';

  @override
  String get scheduledTaskFieldHour => '時';

  @override
  String get scheduledTaskFieldDayOfMonth => '日';

  @override
  String get scheduledTaskFieldMonth => '月';

  @override
  String get scheduledTaskFieldDayOfWeek => '曜日';

  @override
  String get cronErrScheduleEmpty => '実行スケジュールが必要です。';

  @override
  String get cronErrCommandEmpty => 'コマンドが必要です。';

  @override
  String get cronErrLineBreak => 'crontab の 1 行に改行は含められません。';

  @override
  String get cronErrMacro => 'macro は @reboot のような 1 語で指定します。';

  @override
  String get cronErrFieldCount =>
      'cron スケジュールは 5 つのフィールド、または @reboot のような macro で指定します。';

  @override
  String get cronAtBoot => '起動時';

  @override
  String get cronEveryMin => '毎分';

  @override
  String cronEveryMinsFmt(int minutes) {
    return '$minutes 分ごと';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return '毎時 :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return '$hours 時間ごと';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return '$hours 時間ごとの :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return '毎日 $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return '平日 $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return '毎週$day曜日 $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return '毎月 $day 日 $time';
  }

  @override
  String get monitorSettings => 'Monitor 設定';

  @override
  String get monitorAgentDefault => 'agent の初期値';

  @override
  String get monitorNeedsRestart => 'agent の再起動後に反映';

  @override
  String get monitorCollection => '収集';

  @override
  String get extendedInterval => '拡張収集の間隔';

  @override
  String get idlePause => '閲覧中のクライアントがないときは停止';

  @override
  String get idlePauseTip =>
      '拡張収集では smartctl、sensors、amd-smi を実行します。クライアントが取得していない間は停止し、読まれていないデータのためにディスクが起こされるのを防ぎます。';

  @override
  String get idlePauseThreshold => 'アイドルと判定するまで';

  @override
  String get monitorAlerts => 'アラート';

  @override
  String get monitoringRules => 'アラートルール';

  @override
  String get ruleMonitorType => '指標';

  @override
  String get ruleThreshold => 'しきい値';

  @override
  String get ruleMatcher => '対象';

  @override
  String get ruleTip =>
      '指標: cpu / memory / swap / disk / network / temperature。対象: CPU コアは cpu0、memory は used / free / avail、network は rx / tx。disk と temperature では無視されます。しきい値: >=80%、>=70c、>10m/s のように比較演算子と値を指定します。';

  @override
  String get pushChannels => '通知チャネル';

  @override
  String get pushType => '種類';

  @override
  String get pushRate => '送信頻度の上限';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'agent に設定済みのため非表示';

  @override
  String get pushSecretKeep => '空のままで現在の値を保持';

  @override
  String get pushTestTip => '保存前でも、現在表示されている設定でこのチャネルに通知を 1 件送信します。';

  @override
  String get pushTestSent => 'チャネルに受け付けられました';

  @override
  String get pushTestFailed => 'チャネルに拒否されました';

  @override
  String get pushTestMessage => 'ServerBox Monitor からのテスト通知';

  @override
  String get pushUnknownType =>
      'この agent はこの種類のチャネルに送信できないため、設定は表示されません。ここで削除するか、agent の config.toml で編集できます。';

  @override
  String get pushJsonInvalid => '有効な JSON ではありません';

  @override
  String get dataRetention => 'データ保持';

  @override
  String get dataRetentionTip => 'オフにすると agent はデータを削除せず、データベースは上限なく増え続けます。';

  @override
  String get retentionMetrics => '指標を保持';

  @override
  String get retentionAlerts => 'アラートを保持';

  @override
  String get retentionCleanup => 'クリーンアップの間隔';

  @override
  String get retentionMaxDbSize => 'データベース容量の上限';

  @override
  String get corsOrigins => 'CORS 許可オリジン';

  @override
  String get corsOriginsTip =>
      'ブラウザパネルからこの agent を呼び出せるオリジンです。空の場合は同一オリジンのみ許可します。';

  @override
  String get monitorNoRemoteAccess =>
      'この agent は監視専用に設定されています。ここからターミナルを開いたり、コマンドを実行したり、ファイルを閲覧したりすることはできません。これらの機能を有効にするには、agent の config.toml にある [remote_access] を編集してください。';

  @override
  String get alerts => 'アラート';

  @override
  String get online => 'オンライン';

  @override
  String get densityCards => 'カード';

  @override
  String get densityRows => '行';

  @override
  String get densityGrid => 'グリッド';

  @override
  String get connect => '接続';

  @override
  String get disconnect => '切断';

  @override
  String get searchServerTip => '名前とアドレスを検索します。編集画面で最初に尋ねられる2項目です。';

  @override
  String get addServerTip => '入力するか、QRコードをスキャンするか、共有されたファイルをインポートしてください。';

  @override
  String get move => '移動';

  @override
  String get moveToTop => '先頭へ移動';

  @override
  String get moveToBottom => '末尾へ移動';

  @override
  String get groupByTag => 'タグでグループ化';

  @override
  String get groupByTagTip => 'タグはサーバーの編集ページで設定します。';

  @override
  String get connecting => '接続中…';

  @override
  String get authShort => '認証';

  @override
  String get remoteDesktopFitToWindow => 'ウィンドウに合わせる';

  @override
  String get remoteDesktopActualSize => '実際のサイズ';

  @override
  String get remoteDesktopZoom => 'ズーム';

  @override
  String get remoteDesktopViewOnly => '表示のみ';

  @override
  String get remoteDesktopDisableViewOnly => '表示のみを無効にする';

  @override
  String get remoteDesktopSendClipboardText => 'クリップボードのテキストを送信';

  @override
  String get remoteDesktopShowKeyboard => 'キーボードを表示';

  @override
  String get remoteDesktopMoreControls => 'その他の操作';

  @override
  String get remoteDesktopUseDirectPointer => '直接ポインターを使う';

  @override
  String get remoteDesktopUseTouchpadPointer => 'タッチパッドポインターを使う';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Ctrl+Alt+Delete を送信';

  @override
  String get remoteDesktopReconnect => '再接続';

  @override
  String get remoteDesktopFullScreen => '全画面表示';

  @override
  String get remoteDesktopExitFullScreen => '全画面表示を終了';

  @override
  String get remoteDesktopCloseSession => 'セッションを閉じる';

  @override
  String get remoteDesktopConnected => '接続済み';

  @override
  String get remoteDesktopConnecting => '接続中';

  @override
  String get remoteDesktopReconnecting => '再接続中';

  @override
  String get remoteDesktopDisconnected => '切断';

  @override
  String get remoteDesktopGuideTouch => 'タッチパッド';

  @override
  String get remoteDesktopGuideTouchTip =>
      '1本指でタッチパッドのようにポインターを動かし、タップでクリックします。2本指タップで右クリック、2本指ドラッグでスクロール、ピンチでズームします。2回タップして指を離さずに動かすとドラッグできます。';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      '画面キーボードを開きます。入力した内容はリモートデスクトップに送信されます。';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'ポインターとキー入力の送信を止め、誤ってクリックせずに画面を確認できます。';

  @override
  String get remoteDesktopGuideMoreTip => 'Ctrl+Alt+Delete、再接続、全画面表示はここにあります。';

  @override
  String get remoteDesktopGuidePointerTip =>
      '指で触れた場所をクリックするダイレクトポインターにもここで切り替えられます。';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'VNC のクリップボードは Latin-1 テキストのみ対応しています。';

  @override
  String get remoteDesktopAddProfile => 'プロファイルを追加';

  @override
  String get remoteDesktopNoProfiles => 'リモートデスクトップのプロファイルがありません';

  @override
  String get remoteDesktopAdd => 'リモートデスクトップを追加';

  @override
  String get remoteDesktopEdit => 'リモートデスクトップを編集';

  @override
  String get remoteDesktopTargetTip =>
      '接続先は SSH サーバーまたは Monitor エージェントから解決されます。localhost はそのマシンを指します。';

  @override
  String get remoteDesktopDomain => 'ドメイン（任意）';

  @override
  String get remoteDesktopPassword => 'パスワード（任意）';

  @override
  String get remoteDesktopSavePassword => 'パスワードを保存';

  @override
  String get remoteDesktopSavePasswordTip =>
      '暗号化データベースに保存されます。バックアップには保存済みのパスワードが含まれ、バックアップパスワードを設定した場合にのみ暗号化されます。';

  @override
  String get remoteDesktopShareSession => 'セッションを共有';

  @override
  String get remoteDesktopProtocol => 'プロトコル';

  @override
  String get remoteDesktopUniqueName => 'このサーバーではプロファイル名を重複させられません。';

  @override
  String get remoteDesktopNameRequired => 'プロファイル名を入力してください。';

  @override
  String get remoteDesktopHostRequired => '接続先ホストを入力してください。';

  @override
  String get remoteDesktopPortRequired => '有効なポートを入力してください。';

  @override
  String get remoteDesktopUsernameRequired => 'RDP のユーザー名を入力してください。';

  @override
  String get remoteDesktopNameInvalid => 'プロファイル名は 64 文字以内で、改行は使えません。';

  @override
  String get remoteDesktopHostInvalid => '接続先ホストに空白や改行は使えません。';

  @override
  String get remoteDesktopCredentialInvalid =>
      'ユーザー名とドメインは 256 文字以内で、改行は使えません。';

  @override
  String get remoteDesktopVncPasswordHint => '従来の VNC では最初の 8 文字のみ使用されます';

  @override
  String get remoteDesktopVncPasswordAscii =>
      '従来の VNC パスワードは ASCII 文字のみ使用できます。';

  @override
  String get remoteDesktopCertificateRequired => '証明書の確認が必要です';

  @override
  String get remoteDesktopWaiting => 'デスクトップを待機しています…';

  @override
  String get remoteDesktopCertificateChanged => 'リモートデスクトップの証明書が変更されました';

  @override
  String get remoteDesktopTrustCertificate => '証明書を信頼しますか？';

  @override
  String get remoteDesktopCertificateChangedTip =>
      '証明書のフィンガープリントが保存された値と一致しません。信頼を置き換える前に新しいフィンガープリントを確認してください。';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'システムはこの証明書を検証できませんでした。続行する前に SHA-256 フィンガープリントを確認してください。';

  @override
  String get remoteDesktopReplaceTrust => '信頼を置き換える';

  @override
  String get remoteDesktopTrustReconnect => '信頼して再接続';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'リモートデスクトップのプロファイル「$name」を削除しますか？';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return '再接続中（$attempt/3）…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return '以前に信頼したフィンガープリント\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'サブジェクト：$subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return '発行者：$issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return '有効期間：$start – $end';
  }

  @override
  String get pveAuthToken => 'API トークン';

  @override
  String get pveVersionLow => 'この機能は現在テスト段階にあり、PVE 8+でのみテストされています。ご利用の際は慎重に。';

  @override
  String get pveTokenId => 'トークン ID';

  @override
  String get pveTokenSecret => 'トークンシークレット';

  @override
  String get pveTokenTip =>
      'PVE の データセンター → 権限 → API トークン で作成します。表示するパスに VM.Audit、VM.PowerMgmt、VM.Console、VM.Snapshot、VM.Snapshot.Rollback、Datastore.Audit、Sys.Audit が必要です。権限の分離が有効な場合は、トークン自体に付与してください。';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'トークン $account はこのホストで何も参照できません。権限分離が有効なトークンはユーザーの権限を継承しないため、PVE ホストで権限を付与してください:\n$command\nまたはトークンの「Privilege Separation」を外してください。';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account はこのホストで何も参照できません。PVE ホストで権限を付与してください:\n$command';
  }

  @override
  String get pveTokenIdInvalid => 'トークン ID は user@realm!tokenid の形式にしてください';

  @override
  String get pvePasswordAuthTip =>
      'SSH ユーザーとして PAM レルムにログインし、SSH パスワードを使います。SSH が鍵を使う場合は下の PVE パスワードを使います。必要に応じて二要素認証コードを求めます。';

  @override
  String get pveCertUnpinned =>
      'まだ確認されていません。信頼された CA が署名していない場合、次の接続時に証明書を表示して確認を求めます。';

  @override
  String get pveCertForget => '証明書を忘れる';

  @override
  String get pveCertForgetTip => '次の接続時に PVE の証明書を再度表示して確認を求めます。';

  @override
  String get virtualization => '仮想化';

  @override
  String get virtIntro =>
      'Proxmox VE と libvirt/KVM ホスト上の仮想マシンとコンテナを管理します：状態、電源操作、コンソール。';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE はサーバーページからこのタブに移動しました。サーバーの PVE カードからここを開けます。';

  @override
  String get virtIntroLibvirt =>
      'libvirt の virsh がインストールされたサーバーは、QEMU/KVM 仮想マシンとともにホストとして表示されます。';

  @override
  String get virtIntroTransports =>
      'どちらも SSH、Monitor エージェント経由、またはこのデバイス上で動作します。';

  @override
  String get virtIntroTokens =>
      'PVE はパスワードの代わりに API トークンでログインできます。サーバーの編集ページの PVE で設定します。';

  @override
  String get virtIntroInBar => 'タブバーに追加されました。';

  @override
  String get virtIntroInMore => '「その他」にあります。設定のホームタブでタブバーに移動できます。';

  @override
  String get virtGuests => '仮想マシン';

  @override
  String get virtHosts => 'ホスト';

  @override
  String get virtCheckServer => 'このサーバーを確認';

  @override
  String get virtCheckAll => 'すべてのサーバーを確認';

  @override
  String get virtProbeNotChecked => '未確認';

  @override
  String get virtProbeAbsent => 'ホストではありません';

  @override
  String virtProbeContainer(String kind) {
    return '$kind コンテナ';
  }

  @override
  String get virtProbeContainerTip =>
      'このサーバーはコンテナ内で動作しているため、ホストではなくゲストです。これを実行しているホストから管理してください。';

  @override
  String get virtProbePve => 'PVE、未設定';

  @override
  String virtPveSetupTip(String version) {
    return 'このサーバーでは $version が動作しています。サーバー設定で API アクセス（API トークン推奨）を入力すると、ここで仮想マシンとコンテナを管理できます。';
  }

  @override
  String get virtNoHosts => '仮想化ホストがありません';

  @override
  String get virtNoHostsTip =>
      'Proxmox VE が動作し API アクセスが入力されたサーバーと、virsh が応答するサーバーがホストになります。その他のサーバーはホスト切り替えから確認できます。';

  @override
  String get virtNoGuests => '仮想マシンもコンテナもありません';

  @override
  String get virtPaused => '一時停止中';

  @override
  String get virtStarting => '起動中…';

  @override
  String get virtStopping => '停止中…';

  @override
  String get virtRebooting => '再起動中…';

  @override
  String get virtMigrating => '移行中…';

  @override
  String get virtBackingUp => 'バックアップ中…';

  @override
  String get virtResume => '再開';

  @override
  String get virtOverview => '概要';

  @override
  String get virtConsole => 'コンソール';

  @override
  String get virtConsoleNone => 'このゲストにはコンソールが設定されていません';

  @override
  String get virtConsoleGraphical => 'グラフィカル';

  @override
  String get virtVncPasswordNeeded => 'このディスプレイにはパスワードが必要です';

  @override
  String get virtConsoleSerialTip =>
      'ホスト上の virsh でゲストのシリアルコンソールを開きます。切断または Ctrl+] でホストのシェルに戻ります。';

  @override
  String virtConsoleVia(String transport) {
    return '$transport 経由';
  }

  @override
  String get virtConsoleEnterTip => '出力がない場合は Enter を押してください';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return '$seconds 秒後に Enter を押してプロンプトを表示します';
  }

  @override
  String get virtConsoleEnterNow => '今すぐ';

  @override
  String get virtOffTip => '起動すると、CPU・メモリ・ディスク・ネットワークがここにリアルタイムで表示されます。';

  @override
  String get virtAllocated => '割り当て済み';

  @override
  String virtRunningCount(int running, int total) {
    return '$running 台実行中 · 全 $total 台';
  }

  @override
  String get virtTemplate => 'テンプレート';

  @override
  String get virtAutostart => 'ホストと同時に起動';

  @override
  String get virtErrUnreachable => 'このホストに接続できません';

  @override
  String get virtErrNotConfigured => 'このサーバーの PVE 設定が不完全です';

  @override
  String get virtErrNotConfiguredTip =>
      'サーバー設定でアドレスと、パスワードまたは API トークンを確認してください。';

  @override
  String get virtErrAuthFailed => 'ホストがログインを拒否しました';

  @override
  String get virtErrCertUnconfirmed => 'ホストの証明書を確認してください';

  @override
  String get virtErrCertChanged => 'ホストの証明書が変更されました';

  @override
  String get virtErrRelayNotGranted => 'Monitor エージェントは接続を中継しません';

  @override
  String get virtErrExecNotGranted => 'Monitor エージェントはコマンドを実行しません';

  @override
  String get virtErrNotInstalled => 'このサーバーには virsh がインストールされていません';

  @override
  String get virtErrServerRemoved => 'このサーバーは削除されました';

  @override
  String get virtErrSudoRequired => 'libvirt にアクセスするには sudo のパスワードが必要です';

  @override
  String get virtErrSudoRejected => 'sudo がパスワードを拒否しました';

  @override
  String get virtErrInvalidResponse => 'ホストから予期しない形式の応答がありました';

  @override
  String get virtErrActionFailed => 'ホストが操作を拒否しました';

  @override
  String get remoteSessionIdleTimeout => '離れたら閉じる';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'リモートデスクトップやゲストのコンソールから離れた後、接続を維持する時間。閉じる前に通知が表示され、10 秒以内なら維持できます。';

  @override
  String get remoteSessionKeepAlive => '維持する';

  @override
  String get remoteSessionClosedAway => 'アイドルのため閉じました';

  @override
  String remoteSessionClosingIn(int seconds) {
    return '$seconds 秒後に閉じます';
  }

  @override
  String get virtSnapshots => 'スナップショット';

  @override
  String get virtSnapshotCreate => 'スナップショットを作成';

  @override
  String get virtSnapshotNone => 'スナップショットはまだありません';

  @override
  String get virtSnapshotWithMemory => 'ディスクとメモリ';

  @override
  String get virtSnapshotDiskOnly => 'ディスクのみ';

  @override
  String get virtSnapshotParent => '親';

  @override
  String get virtSnapshotRevert => '復元';

  @override
  String get virtSnapshotMemory => 'メモリを含める';

  @override
  String get virtSnapshotMemoryTip => '復元するとこの時点から実行が再開されます。';

  @override
  String get virtSnapshotMemoryAlways => 'ここでは、実行中のゲストのスナップショットには常にメモリが含まれます。';

  @override
  String get virtSnapshotMemoryOff => 'ゲストが実行されていないため、ディスクのみ保存されます。';

  @override
  String get virtSnapshotNameInvalid => '先頭は英字、以降は英数字・-・_、2〜40 文字。';

  @override
  String get virtSnapshotNameTaken => 'この名前のスナップショットは既に存在します。';

  @override
  String get virtSnapshotRevertTip => '復元すると、スナップショット以降のすべての変更が失われます。';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return '$guest を $snapshot に復元しますか？それ以降の変更はすべて失われます。';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'このスナップショットにはメモリがありません：$guest は停止されます。';
  }

  @override
  String get virtSnapshotStartAfter => 'その後起動する';

  @override
  String get virtVolumes => 'ボリューム';

  @override
  String get virtNoPools => 'ストレージプールがありません';

  @override
  String get virtNoNetworks => 'ネットワークがありません';

  @override
  String get virtPoolInactive => 'プールがアクティブでないため、ボリュームを一覧表示できません。';

  @override
  String get virtShared => 'ノード間で共有';

  @override
  String get virtBackingFile => 'バッキングファイル';

  @override
  String get virtNetIsolated => '分離';

  @override
  String get virtNetBridged => 'ブリッジ';

  @override
  String get virtNetRouted => 'ルーティング';

  @override
  String get virtBridge => 'ブリッジ';

  @override
  String get virtPorts => 'ポート';

  @override
  String get virtAttachedGuests => '接続中のゲスト';

  @override
  String get virtNoAttachedGuests => '接続中のゲストはありません';

  @override
  String get virtCreateVm => '新しい仮想マシン';

  @override
  String get virtCreateLxc => '新しいコンテナ';

  @override
  String get virtCreateGuest => '新しい仮想マシンまたはコンテナ';

  @override
  String get virtKindVm => '仮想マシン';

  @override
  String get virtKindLxc => 'コンテナ';

  @override
  String get virtHostname => 'ホスト名';

  @override
  String get virtInstallMedia => 'インストールメディア';

  @override
  String get virtNoIsos => 'このホストに ISO イメージがありません';

  @override
  String get virtNoTemplates =>
      'このホストにコンテナテンプレートがありません。PVE のストレージの CT テンプレートからダウンロードできます。';

  @override
  String get virtNoDiskStorage => 'このホストに新しいディスクを作れるストレージがありません';

  @override
  String get virtStartAfterCreate => '作成後に起動';

  @override
  String get virtUnprivileged => '非特権コンテナ';

  @override
  String get virtUnprivilegedTip => 'コンテナ内の root はホスト上の一般ユーザーになります。';

  @override
  String get virtSshKeys => 'SSH 公開鍵';

  @override
  String get virtCredentialsTip => 'root パスワード、SSH 鍵、またはその両方。';

  @override
  String virtCreated(String name) {
    return '$name を作成しました';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name を作成しましたが、起動しませんでした';
  }

  @override
  String get virtErrExists => '同じ名前のゲストまたはディスクが既にあります';

  @override
  String get virtCreateNameInvalidLibvirt => '英数字、.、_、- で、先頭は英数字。63 文字まで。';

  @override
  String get virtCreateNameInvalidPve => '英数字と - で、ドットで区切った部分から成る名前。63 文字まで。';

  @override
  String get virtCreateNameTaken => '同じ名前のゲストがあります。';

  @override
  String get virtCreateVmidTaken => 'この VMID は使用中です。';

  @override
  String get virtCreateCoresInvalid => 'このホストで使えるコア数を超えています。';

  @override
  String get virtCreateMemoryInvalid => 'メモリが足りません。';

  @override
  String get virtCreateStorageMissing => 'ディスクの置き場所を選んでください。';

  @override
  String get virtCreateDiskInvalid => '1 GiB から 64 TiB まで。';

  @override
  String get virtCreateTemplateMissing => 'テンプレートを選んでください。';

  @override
  String get virtCreateCredentialsMissing => 'root パスワードか SSH 鍵を設定してください。';

  @override
  String virtCreatePasswordShort(int min) {
    return '$min 文字以上。';
  }

  @override
  String get virtCreateSshKeysInvalid => '1 行に OpenSSH 公開鍵を 1 つ。';

  @override
  String get virtDeleteDisks => 'ディスクも削除する';

  @override
  String get virtDeleteDisksPve => 'ディスクは一緒に削除されます。インストールメディアは残ります。';

  @override
  String virtDeleted(String name) {
    return '$name を削除しました';
  }

  @override
  String get pveTokenTipCreate =>
      'ゲストの作成と削除には VM.Allocate、VM.Config.*、Datastore.AllocateSpace、SDN.Use も必要です。';

  @override
  String get pveTokenTipHardware =>
      'ハードウェアの編集には VM.Config.CPU、VM.Config.Memory、VM.Config.Disk、VM.Config.CDROM、VM.Config.Network、VM.Config.Options が必要です。ディスクやインターフェースの追加には Datastore.AllocateSpace と SDN.Use も必要です。ビデオカードと USB・PCI デバイスには VM.Config.HWType も必要です。リソースマッピング経由のデバイスにはそのマッピングの Mapping.Use、マッピングの一覧には Mapping.Audit が必要です。';

  @override
  String get pveTokenTipBackup =>
      'クローンには VM.Clone、バックアップと復元には VM.Backup、テンプレート化には VM.Allocate が必要です。バックアップジョブの読み取りには Sys.Audit、作成・編集・削除には / に対する Sys.Modify も必要で、コピーやバックアップの保存先には Datastore.AllocateSpace が要ります。';

  @override
  String get virtErrConflict => '他の場所で変更済み';

  @override
  String get virtErrConflictTip =>
      'ここで読み込んだ後にこの設定が他の誰かに変更されたため、何も変更していません。再読み込みしたので、必要なら改めて変更してください。';

  @override
  String get virtHardware => 'ハードウェア';

  @override
  String get virtHwAddDisk => 'ディスクを追加';

  @override
  String get virtHwAddMount => 'マウントポイントを追加';

  @override
  String get virtHwAddNic => 'ネットワークインターフェースを追加';

  @override
  String get virtHwAppliesOnRestart => '保存しました。次回起動時に反映されます。';

  @override
  String get virtHwAutostart => 'ホストと一緒に起動';

  @override
  String get virtHwAutostartPve => 'onboot · VMID 順に起動';

  @override
  String get virtHwBalloonLibvirt => '現在のメモリ';

  @override
  String get virtHwBalloonNote => 'メモリ不足時にホストがゲストの空きメモリを回収できるようにします';

  @override
  String get virtHwBoot => 'ブート';

  @override
  String get virtHwBootOrder => '起動順序';

  @override
  String get virtHwBootTip => '矢印で並べ替え、タップでそのデバイスから起動するかを切り替えます。';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => '設定ファイル';

  @override
  String get virtHwCores => 'コア';

  @override
  String get virtHwCpuTypeDefault => 'デフォルト';

  @override
  String get virtHwDeleteVolume => 'ボリュームも削除する';

  @override
  String get virtHwDetach => '切り離す';

  @override
  String get virtHwDiskHotplug => 'ホットプラグ対応: 実行中でも追加できます';

  @override
  String get virtHwDisksLxc => 'ルートディスクとマウントポイント';

  @override
  String get virtHwEject => '取り出し';

  @override
  String get virtHwEmpty => 'メディアなし';

  @override
  String get virtHwFirewall => 'ファイアウォール';

  @override
  String virtHwFree(String size) {
    return '空き $size';
  }

  @override
  String get virtHwGrow => '拡張';

  @override
  String get virtHwGrowNote => 'ディスクは現在の容量から拡張のみ可能です。';

  @override
  String get virtHwGrowNoteRunning =>
      '拡張のみ可能です。実行中に拡張した場合はゲスト内でパーティションを拡張してください。';

  @override
  String get virtHwGuestUsed => 'ゲスト使用量';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'ホスト $threads スレッド · 割り当て済み $allocated';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'ホスト $total · 割り当て済み $allocated';
  }

  @override
  String get virtHwHotplugNow => 'ホットプラグ: すぐに反映されます。';

  @override
  String get virtHwIssueBootEmpty => '少なくとも 1 つのデバイスをチェックしてください';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'vCPU の合計は 1〜$max';
  }

  @override
  String get virtHwIssueCpuOnline => 'オンライン vCPU は 1〜合計数';

  @override
  String get virtHwIssueDiskShrink => '現在より大きく: ディスクは拡張のみ可能';

  @override
  String get virtHwIssueDiskSize => '1〜65536 GiB';

  @override
  String virtHwIssueMemory(int min, int max) {
    return '$min〜$max MiB';
  }

  @override
  String get virtHwIssueMemoryMin => 'メモリ以下';

  @override
  String get virtHwIssueMountPoint => '/data のような絶対パス';

  @override
  String get virtHwIssueStorageSpace => 'ストレージの空き容量を超えています';

  @override
  String get virtHwLater => '再起動後に反映';

  @override
  String get virtHwLess => '減らす';

  @override
  String get virtHwLinkDown => '切断';

  @override
  String get virtHwLinkNote => 'オフにするとゲストからはケーブルが抜けたように見えます。再起動は不要です';

  @override
  String get virtHwLinkUp => '接続';

  @override
  String get virtHwMac => 'MAC アドレス';

  @override
  String get virtHwModel => 'モデル';

  @override
  String get virtHwMore => '増やす';

  @override
  String get virtHwMountFromPool => 'マウントポイントはストレージから直接割り当てられます';

  @override
  String get virtHwMountPoint => 'マウントポイント';

  @override
  String get virtHwMoveDown => '下へ';

  @override
  String get virtHwMoveUp => '上へ';

  @override
  String get virtHwNewDisk => '新しいディスク';

  @override
  String get virtHwNewMount => '新しいマウントポイント';

  @override
  String get virtHwNewNic => '新しいネットワークインターフェース';

  @override
  String get virtHwNicHotplug => 'virtio NIC はホットプラグ対応です';

  @override
  String get virtHwNics => 'ネットワークインターフェース';

  @override
  String get virtHwNoMedia => 'メディアなし';

  @override
  String get virtHwNoNetworks => 'ネットワークまたはブリッジがありません';

  @override
  String get virtHwNoStorage => 'ディスクを置けるストレージがありません';

  @override
  String get virtHwOnline => 'オンライン vCPU';

  @override
  String get virtHwPendingBanner => '一部のハードウェア変更は再起動後に反映されます';

  @override
  String get virtHwPickNet => 'ネットワークを選択';

  @override
  String get virtHwPickPool => 'ストレージと容量を選択';

  @override
  String get virtHwProcessor => 'プロセッサ';

  @override
  String get virtHwRemove => '削除';

  @override
  String get virtHwRemoveCdrom => 'CD-ROM を削除';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return '$guest から $disk を削除しますか？';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return '$guest から $nic を削除しますか？';
  }

  @override
  String get virtHwResources => 'リソース';

  @override
  String get virtHwRestartNow => '今すぐ再起動';

  @override
  String get virtHwRevert => '元に戻す';

  @override
  String get virtHwRevertAll => 'すべて元に戻す';

  @override
  String get virtSetRenameStopped =>
      '名前を変更するにはシャットダウンしてください：libvirt は停止中のゲストしか名前を変更できません。';

  @override
  String virtSetIssueDescription(int max) {
    return '$max バイト（UTF-8）まで、制御文字は使えません。';
  }

  @override
  String get virtSetManualStart => '手動で起動';

  @override
  String get virtSetProtection => '保護';

  @override
  String get virtSetProtectionNote => 'ゲストの削除とディスクの変更を禁止します';

  @override
  String get virtSetIrreversible => '元に戻せません';

  @override
  String get virtSetDeleteStopFirst => '削除する前にシャットダウンしてください。';

  @override
  String get virtSetDeleteProtected => '保護が有効です：先に「一般」でオフにしてください。';

  @override
  String get virtSetDeleteAgain => 'もう一度押して確定';

  @override
  String virtSetDeleteConfirm(String name) {
    return '$name を削除';
  }

  @override
  String get virtSetDeleteVm => '仮想マシンを削除';

  @override
  String get virtSetDeleteLxc => 'コンテナを削除';

  @override
  String get virtHwSockets => 'ソケット';

  @override
  String get virtHwSource => 'ソース';

  @override
  String get virtHwSwap => 'スワップ';

  @override
  String get virtHwTopology => 'ソケット × コア';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets ソケット × $cores コア × $threads スレッド';
  }

  @override
  String virtHwTotal(String size) {
    return '合計 $size';
  }

  @override
  String get virtHwVolumeKept =>
      '削除しましたが、実行中のゲストがまだディスクを使用しているため、ボリュームは残しました。次回起動時に切り離されます。';

  @override
  String get virtHwBus => 'バス';

  @override
  String get virtHwCache => 'キャッシュ';

  @override
  String get virtHwBusStopped => 'バスはゲスト停止中のみ変更できます。';

  @override
  String get virtHwMacGenerate => '生成';

  @override
  String get virtHwIssueMac => 'ユニキャスト MAC アドレスを入力してください（例: 52:54:00:12:34:56）';

  @override
  String get virtHwIssueStopFirst => '先にゲストを停止してください';

  @override
  String get virtHwIssueStorageMissing => '先にストレージを選んでください';

  @override
  String get virtHwIssueDevice => '先にデバイスを選んでください';

  @override
  String get virtHwDevices => 'CD-ROM とパススルー';

  @override
  String get virtHwDevicesEmpty => 'USB と PCI のパススルー、CD-ROM、TPM';

  @override
  String get virtHwAddDevice => 'デバイスを追加';

  @override
  String get virtHwNewDevice => '新しいデバイス';

  @override
  String get virtHwUsbHotplug => 'USB パススルーはホットプラグに対応しています。';

  @override
  String get virtHwPci => 'PCI パススルー';

  @override
  String get virtHwIommuOffTitle => 'ホストに IOMMU がありません';

  @override
  String get virtHwIommuOffBody =>
      '先にホストの BIOS で VT-d または AMD-Vi を、カーネルで IOMMU を有効にしてください。それまで PCI デバイスを付けたゲストは起動しません。';

  @override
  String get virtHwPciTitle => 'ホストで IOMMU が必要です';

  @override
  String get virtHwPciBody => 'パススルーするとホストはそのデバイスを使えず、ゲストはライブマイグレーションできません。';

  @override
  String virtHwIommuGroup(int group) {
    return 'IOMMU グループ $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '同じ IOMMU グループの $count 台のデバイスが一緒にパススルーされます';
  }

  @override
  String get virtHwNoHostDevices => 'このホストにパススルーできるデバイスはありません';

  @override
  String get virtHwMappingsOnly =>
      'ここではリソースマッピングのみ使えます: PVE は生のデバイスのパススルーを、パスワードでログインした root@pam にのみ許可します。データセンター → リソースマッピング でマッピングを作成してください。';

  @override
  String get virtHwTpmNote => 'Windows 11 には TPM 2.0 が必要です。';

  @override
  String get virtHwDisplay => 'ディスプレイ';

  @override
  String get virtHwProtocol => 'プロトコル';

  @override
  String get virtHwListen => '待ち受け';

  @override
  String get virtHwGpu => 'ビデオカード';

  @override
  String get virtHwListenAllTitle => 'コンソールがネットワークに公開されています';

  @override
  String get virtHwListenAllBody =>
      'すべてのアドレスで待ち受けると、ホストに届く誰でもコンソールに接続できます。127.0.0.1 のまま SSH トンネル経由で接続してください。';

  @override
  String get virtHwFirmware => 'ファームウェア';

  @override
  String get virtHwUefiSub => 'OVMF · Secure Boot 対応、Windows 11 に必要';

  @override
  String get virtHwBiosSub => 'SeaBIOS · 古いシステムと MBR ディスク';

  @override
  String get virtHwSecureBootNote => '署名済みのカーネルとブートローダーのみ起動します';

  @override
  String get virtHwFirmwareWarnTitle => 'インストール済みシステムのファームウェアは切り替えないでください';

  @override
  String get virtHwFirmwareWarnBody =>
      'UEFI と BIOS を切り替えると、インストール済みのシステムが起動しなくなります。';

  @override
  String get virtHwFirmwareStopped => 'ファームウェアはゲスト停止中のみ変更できます。';

  @override
  String get virtHwSecureBootVars =>
      'Secure Boot のオン/オフで EFI 変数が作り直され、保存されていたブートエントリは失われます。';

  @override
  String get virtHwEfiStorage => 'EFI 変数の保存先';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return '$guest を $firmware に切り替えますか？';
  }

  @override
  String get virtCloneName => '新しい名前';

  @override
  String get virtCloneFull => '完全クローン';

  @override
  String get virtCloneCopyDisks => 'ディスクの内容をコピー';

  @override
  String get virtCloneLinkedNote => 'オフ: テンプレートのディスクに依存するリンククローン';

  @override
  String get virtCloneFullOnly => 'リンククローンにできるのはテンプレートだけです';

  @override
  String get virtCloneEmptyNote => 'オフ: 同じサイズの空のディスクを新規作成';

  @override
  String get virtCloneStopFirst => 'クローンの前にシャットダウンしてください。';

  @override
  String get virtCloneFullShort => '完全';

  @override
  String get virtCloneLinkedShort => 'リンク';

  @override
  String get virtCloneEmptyShort => '空のディスク';

  @override
  String get virtCloning => 'クローン中…';

  @override
  String virtCloned(String name) {
    return '$name としてクローンしました';
  }

  @override
  String get virtBackupPlan => 'スケジュール';

  @override
  String get virtBackupPlanWhere => 'データセンター → バックアップ';

  @override
  String get virtBackupNoPlanShort => 'スケジュールなし';

  @override
  String get virtBackupNoPlan => 'このゲストを含む定期バックアップジョブはありません。';

  @override
  String get virtBackupKeep => '保持';

  @override
  String get virtBackupJobDisabled => 'このジョブは無効です。';

  @override
  String virtBackupCount(int count) {
    return '$count 件';
  }

  @override
  String virtSnapshotCount(int count) {
    return '$count 件';
  }

  @override
  String get virtBackupNoStorage => 'このノードにはバックアップを保存できるストレージがありません。';

  @override
  String get virtBackupLiveTip => '実行中: snapshot モード、停止なし';

  @override
  String get virtBackupStoppedTip => '停止中: 現在の状態でバックアップ';

  @override
  String get virtBackupNow => '今すぐバックアップ';

  @override
  String get virtBackupNotes => 'メモ';

  @override
  String get virtBackupProtected => '保護中: PVE で保護を外すまで削除できません。';

  @override
  String virtBackupVerified(String state) {
    return '検証: $state';
  }

  @override
  String get virtBackupRestoreOverwrites => '復元すると現在のディスクは上書きされます';

  @override
  String get virtBackupStopFirst => '復元の前にシャットダウンしてください。';

  @override
  String get virtBackupRestoreAgain => 'ゲストのディスクと設定はバックアップのものに置き換わります。';

  @override
  String get virtBackupDeleteConfirm => 'バックアップを削除';

  @override
  String get virtBackupRestoreNew => '新規として復元';

  @override
  String get virtBackupRestoreConfirm => '上書きして復元';

  @override
  String get virtBackupDone => 'バックアップ完了';

  @override
  String get virtBackupDeleted => 'バックアップを削除しました';

  @override
  String virtBackupRestored(String time) {
    return '$time から復元しました';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account には $path での $privilege 権限がありません。PVE ホストで付与してください:\n$command';
  }

  @override
  String get virtCanDelete => '削除できます';

  @override
  String get virtInUse => '使用中';

  @override
  String get virtOps => '操作';

  @override
  String get virtPool => 'ストレージプール';

  @override
  String get virtPoolNew => '新しいストレージプール';

  @override
  String get virtStorageAdd => 'ストレージを追加';

  @override
  String virtPoolUsedPct(String pct) {
    return '$pct% 使用';
  }

  @override
  String get virtPoolInUse => 'ここのボリュームを仮想マシンが使用中のため、プールを停止・削除できません。';

  @override
  String get virtPoolDelete => 'プールを削除';

  @override
  String get virtStorageRemove => 'ストレージを削除';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'プール $name を削除しますか？定義は削除され、ボリュームはそのまま残ります。';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'PVE の設定からストレージ $name を削除しますか？中身は残ります。';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '$count 個のボリュームはディスクに残ります。';
  }

  @override
  String get virtPoolDeleteStorage => 'ディレクトリも削除する（空の場合のみ）';

  @override
  String virtPoolStopAsk(String name) {
    return 'プール $name を停止しますか？再開するまでボリュームの一覧表示や作成はできません。';
  }

  @override
  String get virtStorageClusterWide => 'この変更は、このストレージを持つクラスタ内のすべてのノードに適用されます。';

  @override
  String get virtStorageDisable => '無効化';

  @override
  String get virtStorageEnable => '有効化';

  @override
  String virtStorageDisableAsk(String name) {
    return 'ストレージ $name を無効にしますか？再度有効にするまで、ここにディスクがある仮想マシンは起動できません。';
  }

  @override
  String get virtPoolLogicalNote => '既存のボリュームグループをそのまま使用し、何もフォーマットしません。';

  @override
  String get virtPoolMountPoint => 'マウントポイント';

  @override
  String get virtPoolSourceNfs => 'ソース (host:/path)';

  @override
  String get virtPoolSourceVg => 'ボリュームグループ';

  @override
  String get virtPoolSourceThin => 'ボリュームグループ / thin pool';

  @override
  String get virtPoolSourceZfs => 'ZFS プール';

  @override
  String get virtPoolTypeVg => 'LVM ボリュームグループ';

  @override
  String get virtResNameEmpty => '名前を入力してください';

  @override
  String get virtResNotFound => 'このホストにはもうありません';

  @override
  String get virtResUnsupported => 'このホストでは行えません';

  @override
  String get virtResNameInvalid => 'このホストでは使えない名前です（英数字、. _ -）';

  @override
  String get virtResSourceInvalid => '有効なパスまたはソースではありません';

  @override
  String get virtResTargetInvalid => '絶対パスを指定してください';

  @override
  String get virtResCidrInvalid => 'プレフィックス付きアドレス（例: 192.168.150.1/24）';

  @override
  String get virtResDhcpInvalid => 'ネットワーク内の 2 つのアドレス（昇順、ホスト自身のアドレスを除く）';

  @override
  String get virtResSubnetTaken => 'このサブネットは別のネットワークが使用中です';

  @override
  String get virtResBridgeInvalid => 'インターフェース名ではありません';

  @override
  String get virtResFormat => 'このプールはこの形式に対応していません';

  @override
  String get virtVolNew => '新しいボリューム';

  @override
  String virtVolCount(int count) {
    return '$count 個のボリューム';
  }

  @override
  String get virtVolNone => 'このプールにはまだボリュームがありません。';

  @override
  String get virtVolEmptyAttach => '新しいボリュームは後で任意の仮想マシンに接続できます';

  @override
  String get virtVolEmptyUpload => 'ISO を直接アップロードすることもできます';

  @override
  String get virtVolPveName => 'PVE はボリュームを所属する仮想マシンで命名します: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => '使用中の仮想マシン';

  @override
  String get virtVolAllocated => '割り当て済み';

  @override
  String get virtVolGrowFromGuest => '仮想マシンが使用中です。その仮想マシンのハードウェア画面から拡張してください';

  @override
  String get virtVolInUse => 'このボリュームは仮想マシンが使用中です';

  @override
  String virtVolBackingOf(String names) {
    return '$names のバッキングファイル';
  }

  @override
  String get virtVolIsBase => 'このボリュームをベースにした他のボリュームがあり、削除するとそれらが壊れます';

  @override
  String get virtVolAttach => '仮想マシンに接続';

  @override
  String get virtVolAttachNote => '最初のディスクと同じバスに新しいディスクとして接続します';

  @override
  String virtVolAttached(String name) {
    return '$name に接続しました';
  }

  @override
  String get virtVolInsert => 'CD-ROM に挿入';

  @override
  String virtVolInserted(String name) {
    return '$name の CD-ROM に挿入しました';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name には CD-ROM ドライブがありません';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return '$pool からボリューム $name を削除しますか？中身は完全に失われます。';
  }

  @override
  String get virtUploadIso => 'ISO をアップロード';

  @override
  String virtUploadTo(String pool) {
    return '$pool にアップロード';
  }

  @override
  String virtUploadDone(String name) {
    return '$name をアップロードしました';
  }

  @override
  String get virtNetConfig => '構成';

  @override
  String get virtNetConfigFile => '設定ファイル';

  @override
  String get virtNetInternal => '内部';

  @override
  String get virtNetBridgePorts => 'ブリッジポート';

  @override
  String get virtNetHostBridge => 'ホストのブリッジ';

  @override
  String get virtNetPortsHint => 'eno2。空欄なら内部ブリッジ';

  @override
  String get virtNetDhcpRange => 'DHCP 範囲';

  @override
  String get virtNetDhcpTip => 'dnsmasq が仮想マシンにアドレスを割り当てます';

  @override
  String get virtNetVlanTip => '仮想マシンの NIC で VLAN タグを使用できます';

  @override
  String get virtNetNatTip => 'ホスト経由: 仮想マシンは外に出られますが、外部からは届きません';

  @override
  String get virtNetRoutedTip => 'NAT なしでホストがルーティング: LAN 側に戻りの経路が必要です';

  @override
  String get virtNetIsolatedTip => '仮想マシン同士とホストのみが通信できます';

  @override
  String get virtNetBridgedTip => '仮想マシンはホストのブリッジに参加し、物理ネットワークに直接つながります';

  @override
  String get virtNetNew => '新しいネットワーク';

  @override
  String get virtNetNewBridge => '新しい Linux ブリッジ';

  @override
  String get virtNetVirtual => '仮想ネットワーク';

  @override
  String get virtNetDelete => 'ネットワークを削除';

  @override
  String virtNetDeleteAsk(String name) {
    return 'ネットワーク $name を削除しますか？停止され、定義が削除されます。';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return '$node からブリッジ $name を削除しますか？今は保留中の構成から外れ、適用後にホストから消えます。';
  }

  @override
  String virtNetInUse(int count) {
    return '接続中の仮想マシン: $count。削除できません。';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return '$name を停止しますか？接続中の $count 台の仮想マシンは再開するまでネットワークを失います。';
  }

  @override
  String get virtNetInactivePve => '非アクティブ: 新しいブリッジは適用されるまで保留中の構成にあります。';

  @override
  String get virtNetPveApplyNote =>
      '保留中の変更として保存され、構成を適用すると有効になります（ifreload -a）。';

  @override
  String get virtNetPendingSaved => '保留中として保存しました。構成を適用すると有効になります';

  @override
  String virtNetPendingTitle(String node) {
    return '$node の保留中のネットワーク変更';
  }

  @override
  String get virtNetPendingTip =>
      'PVE はネットワーク変更を適用されるまで interfaces.new に保持します。';

  @override
  String get virtNetPendingShow => '変更を表示';

  @override
  String get virtNetApply => '構成を適用';

  @override
  String virtNetApplyAsk(String node) {
    return '$node の保留中のネットワーク構成を適用しますか？PVE はホストのネットワークを再読み込みします（ifreload -a）。誤りがあるとホストに接続できなくなることがあります。';
  }

  @override
  String virtNetRevertAsk(String node) {
    return '$node の保留中のネットワーク構成を破棄しますか？';
  }

  @override
  String get pveTokenTipStorage =>
      'ストレージの管理には /storage での Datastore.Allocate（追加・無効化・削除）、Datastore.AllocateSpace（ボリューム）、Datastore.AllocateTemplate（アップロード）が必要です。Linux ブリッジとネットワーク構成の適用にはノードでの Sys.Modify が必要です。';

  @override
  String get virtCreateUnnamed => '名前なし';

  @override
  String get virtCreateNotChosen => '未選択';

  @override
  String get virtCreateKindVmSub => 'qm · 完全な KVM 仮想マシン';

  @override
  String get virtCreateKindLxcSub => 'pct · ホストのカーネルを共有、より軽量';

  @override
  String get virtCloudImage => 'クラウドイメージ';

  @override
  String get virtCloudImageTip =>
      'システム入りのディスク: コピーしてストレージのサイズまで拡張し、初回起動時に cloud-init で設定します。イメージ自体は変更しません。';

  @override
  String get virtNoCloudImagesLibvirt =>
      'クラウドイメージがありません: どの VM も使っていない qcow2 または raw イメージをプールに置いてください（ストレージでアップロード）。';

  @override
  String get virtNoCloudImagesPve =>
      'クラウドイメージがありません: qcow2、raw、vmdk イメージを Import コンテンツのストレージにアップロードしてください（PVE 8.2+）。';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 には UEFI と TPM 2.0 が必要です';

  @override
  String get virtCreateWindowsBody => '上で UEFI を選び、TPM をオンにしてください。';

  @override
  String get virtCreateWindowsNoTpm =>
      'このホストにはソフトウェア TPM (swtpm) がありません。VM に付けるにはインストールしてください。';

  @override
  String virtCreateImageSize(String size) {
    return 'イメージは $size です。ディスクは少なくともその大きさが必要です。';
  }

  @override
  String get virtCreateImageMissing => 'クラウドイメージを選んでください。';

  @override
  String get virtCreateIncomplete => 'まずオレンジ色の部分を入力してください。';

  @override
  String virtCreateOn(String host) {
    return '$host に作成';
  }

  @override
  String get virtCiTip => 'sudo 付きのアカウント。パスワード、SSH 鍵、または両方でログインします。';

  @override
  String get virtCiUserInvalid => '小文字、数字、_、- のみ。先頭は英字か _';

  @override
  String get virtCiCredentialsMissing => 'パスワードか SSH 鍵を設定してください。';

  @override
  String get virtCiHostnamePve => 'ホスト名は VM の名前です。';

  @override
  String get virtCiStatic => '静的';

  @override
  String get virtCiAddressInvalid => 'プレフィックス付きの IPv4 アドレス（例: 10.0.0.5/24）';

  @override
  String get virtCiGatewayInvalid => 'IPv4 アドレス（例: 10.0.0.1）';

  @override
  String get virtCiDnsFromDhcp => '空欄: DHCP から';

  @override
  String get virtCiDnsInvalid => 'IP アドレス（空白またはカンマ区切り）';

  @override
  String get virtCiSearch => '検索ドメイン';

  @override
  String get virtCiSeedNote =>
      'ディスクの隣の小さな ISO に書き込み、CD-ROM として接続し、VM と一緒に削除します。保存するのはパスワードのハッシュだけです。';

  @override
  String get virtCiNoToolTitle => 'ホストに cloud-init データを作るツールがありません';

  @override
  String virtCiNoToolBody(String tools) {
    return 'ホストに $tools のいずれかをインストールしてください。cloud-init がないと、ログインできるアカウントなしで起動します。';
  }

  @override
  String get virtHwCloudInitNote =>
      'cloud-init が初回起動時に読むデータです。インストールメディアではないため、ここでは入れ替えません。';

  @override
  String get virtHwCdromLater => '実行中はドライブが次回起動時に追加されます（SATA と IDE はホットプラグ不可）。';

  @override
  String virtCreateDiskKept(String size) {
    return 'ディスクはイメージ自体のサイズ $size のままです（指定より大きい）。ディスクを中のシステムより小さく切り詰めることはありません。';
  }

  @override
  String get virtCiEditTip =>
      'cloud-init がこの VM で設定する内容: sudo 付きのアカウント、そのログイン方法、ホスト名、アドレス。';

  @override
  String get virtCiForeignTitle => 'この seed にはこのアプリが書かない設定があります';

  @override
  String get virtCiForeignBody =>
      '他の場所で作られた設定（パッケージ、コマンド、別のアカウント）はここに表示されません。保存すると seed はここに表示された内容に置き換わります。';

  @override
  String get virtCiPasswordKept => '設定済み。空欄のままなら変更しません';

  @override
  String get virtCiRemovePassword => 'パスワードを削除';

  @override
  String get virtCiRemovePasswordNote => 'SSH 鍵でのみログイン';

  @override
  String get virtCiKeysAdded =>
      '鍵はアカウントに追加されます。ここで外した鍵はシステム内で削除するまで残り、新しいユーザー名は古いアカウントとは別の新しいアカウントを作ります。';

  @override
  String get virtCiEffectTitle => '次回の起動時に反映';

  @override
  String get virtCiEffectLibvirt => '保存すると新しいインスタンス ID で新しい seed を書き込みます。';

  @override
  String get virtCiEffectPve =>
      'PVE は cloud-init ドライブをすぐに書き直します。インスタンス ID はこれらの設定から計算されるため、ここでの変更はすべて新しい ID になります。';

  @override
  String get virtCiNewInstance =>
      '次回の起動時、cloud-init はシステムを新しいインスタンスとして扱います。ホスト名を設定し直し、アカウントがなければ作り、パスワードを設定し、鍵を追加し、ネットワーク設定を書き直します。SSH ホスト鍵も新しく作るため、SSH クライアントはホスト鍵の変更を警告します。その起動までは何も変わりません。';

  @override
  String get virtCiSaved => '保存しました。次回の起動時に反映されます。';

  @override
  String get virtSnapshotExternal => '起動中のままディスクのみ';

  @override
  String get virtSnapshotExternalTip =>
      'ゲストは稼働を続けます。各ディスクは選択したプールに qcow2 オーバーレイを持ち、ゲストはチェーン上に残ります。';

  @override
  String get virtSnapshotFormInternal => '内部（イメージ内）';

  @override
  String get virtSnapshotOverlayPool => 'オーバーレイプール';

  @override
  String get virtSnapshotOverlayBeside => '各ディスクと同じ場所';

  @override
  String get virtSnapshotExternalNoMemory =>
      '外部スナップショットはメモリを保存しません。ゲストは停止されません。';

  @override
  String get virtSnapshotChain => 'ディスクチェーン';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count 層';
  }

  @override
  String get virtSnapshotChainFile => 'ファイル';

  @override
  String get virtSnapshotChainActive => '現在使用中';

  @override
  String get virtSnapshotChainBase => 'ベースイメージ';

  @override
  String get virtSnapshotNoSupport => 'ゲストのストレージがスナップショットに対応していないため、作成できません。';

  @override
  String get virtSnapshotRevertChain =>
      'チェーン上で戻すと、稼働中のオーバーレイがイメージに統合され、それ以降のスナップショットは使えなくなります。戻せるのは最新のスナップショットだけです。';

  @override
  String get virtSnapshotRevertHasChildren => '後続のスナップショットがこの上にある間は拒否されます。';

  @override
  String get virtSnapshotDiff => '現在との差分';

  @override
  String get virtSnapshotDiffNone => 'このスナップショット以降、構成は変わっていません。';

  @override
  String get virtSnapshotDiffShow => '現在と比較';

  @override
  String get virtSnapshotDiffGroupCpu => 'プロセッサ';

  @override
  String get virtSnapshotDiffGroupMemory => 'メモリ';

  @override
  String get virtSnapshotDiffGroupDisks => 'ディスク';

  @override
  String get virtSnapshotDiffGroupNic => 'インターフェース';

  @override
  String get virtSnapshotDiffGroupFirmware => 'ファームウェア';

  @override
  String get virtSnapshotDiffGroupBoot => '起動';

  @override
  String get virtSnapshotDiffGroupOther => 'その他';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => '削除済み';

  @override
  String get virtSnapshotDiffAdded => '追加済み';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return '$snapshot に戻すと変わる内容：';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'ホストは差分を答えられませんでした：$error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'ゲストはすでに $count 層にあります。このスナップショットでさらに 1 層増えます。';
  }

  @override
  String get virtToTemplate => 'テンプレート化';

  @override
  String get virtToTemplateNote =>
      'テンプレートは起動できず、ゲストに戻すこともできません。ディスクはベースイメージになり、リンククローンがそれを共有します。';

  @override
  String virtToTemplateConfirm(String name) {
    return '$name をテンプレートにしますか？';
  }

  @override
  String get virtToTemplateIrreversible => '元に戻せません。テンプレートはゲストに戻せません。';

  @override
  String get virtToTemplateStopped => '先に停止してください。';

  @override
  String get virtToTemplateSnapshots => 'スナップショットのあるゲストはテンプレートにできません。';

  @override
  String virtTemplateCreated(String name) {
    return '$name はテンプレートになりました';
  }

  @override
  String get virtTemplateTip => 'テンプレートはクローンして初めて動作します。';

  @override
  String get virtCloneStorageSame => '元と同じ';

  @override
  String get virtCloneNodeSame => '元と同じ';

  @override
  String get virtCloneStorageContent => 'このストレージは VM ディスクを保持できません。';

  @override
  String get virtCloneStorageShared => '別ノードへのコピーには共有ストレージが必要です。';

  @override
  String get virtCloneNodeUnknown => 'このホストにそのノードはありません。';

  @override
  String get virtCloneLinkedTarget =>
      'リンククローンはテンプレートのディスクを共有するため、ストレージやノードを指定できません。';

  @override
  String get virtBackupJobs => 'バックアップジョブ';

  @override
  String get virtBackupJobsNone =>
      'スケジュールされたバックアップジョブはありません。追加すると定期的にゲストをバックアップできます。';

  @override
  String get virtBackupJobNew => '新しいジョブ';

  @override
  String get virtBackupJobRun => '今すぐ実行';

  @override
  String get virtBackupJobRunAsk => 'このバックアップジョブを今すぐ開始しますか？';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return 'バックアップジョブ $id を削除しますか？作成済みのバックアップは残ります。';
  }

  @override
  String get virtBackupJobSaved => 'ジョブを保存しました';

  @override
  String get virtBackupJobDeleted => 'ジョブを削除しました';

  @override
  String get virtBackupJobStarted => 'バックアップジョブを開始しました';

  @override
  String get virtBackupSchedule => 'スケジュール';

  @override
  String get virtBackupScheduleHelp =>
      'systemd カレンダーイベントのサブセット: 02:30、mon..fri 02:30、sat 03:00、daily、hourly、*/15。';

  @override
  String get virtBackupScheduleInvalid => 'ホストが受け付けないスケジュールです。';

  @override
  String virtBackupScheduleNext(String times) {
    return '次回実行: $times';
  }

  @override
  String get virtBackupSelection => 'ゲスト';

  @override
  String get virtBackupSelectionAll => 'すべてのゲスト';

  @override
  String get virtBackupSelectionList => '選択したゲスト';

  @override
  String get virtBackupSelectionNone => '少なくとも 1 つのゲストを選んでください。';

  @override
  String get virtBackupMail => '通知';

  @override
  String get virtBackupNotesTemplate => 'バックアップのメモ';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'メモはジョブが作成する各バックアップに付加されます。置換されるのは $vars です。';
  }

  @override
  String get virtBackupPrune => '保持';

  @override
  String get virtBackupPruneTip =>
      'PVE の保持オプション（例: keep-last=7,keep-daily=4）。空欄ならストレージまたはノードの設定。';

  @override
  String get virtBackupJobNode => 'ノード';

  @override
  String get virtBackupJobNodeAny => 'すべてのノード';

  @override
  String get virtBackupEnabled => '有効';

  @override
  String get virtBackupOptions => 'オプション';

  @override
  String get virtBackupProtect => '保護';

  @override
  String get virtBackupProtectTip => '保護されたバックアップは整理の対象にならず、保護を解除するまで削除できません。';

  @override
  String get virtBackupEditNotes => 'メモ';

  @override
  String get virtBackupSaveNotes => '保存';

  @override
  String get virtBackupEdited => 'バックアップを更新しました';

  @override
  String get virtBackupRestoreStorage => 'ストレージへ復元';

  @override
  String get virtBackupRestoreStorageSame => 'バックアップどおり';

  @override
  String get virtCloneStorageMissing => 'このノードに VM ディスクを保持できるストレージがありません。';

  @override
  String get virtBackupCompress => '圧縮';

  @override
  String get virtBackupUnprotect => '保護を解除';

  @override
  String get virtBackupModeStops => 'suspend と stop はコピー中に稼働中のゲストを中断します。';

  @override
  String get virtBackupScheduleValidate => 'ホストで確認';

  @override
  String virtBackupSelected(int count) {
    return '$count 件選択';
  }

  @override
  String get virtBackupExcludeTip => 'ノード上のすべてのゲストが対象です。オフにすると除外されます。';

  @override
  String virtNetEditAsk(int count) {
    return '実行中のネットワークは再起動するまで現在の状態を保ちます。再起動すると接続中の仮想マシン ($count) が切断されます。';
  }

  @override
  String get virtNetEditAskNoGuest => '実行中のネットワークは再起動するまで現在の状態を保ちます。';

  @override
  String get virtNetEditRestart => '再起動して今すぐ適用';

  @override
  String get virtNetEditRestartNote => '再起動中、接続中の仮想マシンはネットワークを失います。';

  @override
  String get virtNetEditPending => '定義に、実行中のネットワークにまだ反映されていない変更があります。';

  @override
  String get virtNetRestart => '再起動';

  @override
  String virtNetRestartAsk(String name, int count) {
    return '$name を再起動しますか？接続中の仮想マシン ($count) は復帰までネットワークを失います。';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return '$name を再起動しますか？何も接続されていません。';
  }

  @override
  String get virtNetHosts => '静的アドレス';

  @override
  String get virtNetHostAdd => 'アドレスを追加';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => 'アドレス';

  @override
  String get virtNetHostName => '名前 (任意)';

  @override
  String get virtNetHostEmpty =>
      '専用のアドレスを持つ MAC はありません: すべての仮想マシンは DHCP 範囲からアドレスを受け取ります。';

  @override
  String get virtNetHostOthers => 'その他の仮想マシンは DHCP 範囲からアドレスを受け取ります。';

  @override
  String get virtNetHostInvalid => 'ホストが拒否する MAC、アドレス、名前、または重複した MAC があります。';

  @override
  String get virtNetManagementIface =>
      'このインターフェースはホスト自身のアドレスを持っています。編集または適用するとホストへの接続が切れます。';

  @override
  String get virtNetManagementTip =>
      'ホストの管理トラフィックを担っているか、それを担うインターフェースの配下にあります: アプリでは編集しません。';

  @override
  String get virtNetPhysicalTip =>
      '物理インターフェースはホスト自身のものです: アプリで編集できるのはブリッジのみです。';

  @override
  String get virtNetVlanAware => 'VLAN 対応';

  @override
  String get virtCiExpire => 'パスワードを期限切れにする';

  @override
  String get virtCiExpireNote =>
      'このパスワードでの初回ログイン時に新しいパスワードの設定が必要です。libvirt のみ: PVE は \"expire: false\" を書き込み、この設定項目はありません。';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      '複数指定する場合はスペースで区切ります。resolv.conf には先頭のいくつかが残ります。';

  @override
  String virtCiNicsTip(int count) {
    return 'seed のネットワーク構成に NIC が $count 個あります。フォームでは最初の 1 つを編集します。';
  }

  @override
  String get virtUsbByVendor => 'ベンダーと製品で指定';

  @override
  String get virtUsbByAddress => 'アドレスで指定';

  @override
  String get virtUsbAddressTip =>
      'デバイスはこのアドレスに従います: そこに接続されたものが仮想マシンに渡されます。libvirt は USB hostdev をバス番号とデバイス番号で指定します。';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'バス $bus · ポート $port';
  }

  @override
  String get virtSbUnsupported =>
      'ホストのファームウェア記述子に、鍵が登録済みの Secure Boot ファームウェアがないため、これを有効にしたドメインは起動できません。';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote => '署名済みのカーネルとブートローダーのみ起動します。';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'バス $bus · デバイス $device';
  }

  @override
  String get virtHwRevertPendingTitle => '保留中の変更を破棄';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name を実行中の状態に戻します: 実行中の定義から定義を書き直し、次回起動時は現在とまったく同じ構成になります。NVRAM ファイルとファームウェアはそのままです。';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return '$name の次回起動を待っている変更をすべて破棄しますか？';
  }

  @override
  String get virtBackupPlanNew => '新しい計画';

  @override
  String get virtBackupPlanNewTip => 'このゲストだけをバックアップするスケジュール。';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他の $count 台のゲストもバックアップします',
      zero: '他のゲストはありません',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => '視差効果を減らす';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String funcNeedsAgentPermission(String func) {
    return 'この Monitor agent 上のあなたのアカウントには $func の権限がありません。agent の管理者に依頼してください。';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func にはこの Monitor agent への HTTPS 接続、または agent とこのアプリの両方での HTTP 許可が必要です。';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return 'この Monitor agent では $func が設定されていません。運用者が設定する必要があります。';
  }

  @override
  String get monitorFilesReadOnly =>
      '読み取り専用：このアカウントは agent 上のファイルを閲覧できますが、変更はできません。';

  @override
  String get monitorAccess => 'アクセス';

  @override
  String get monitorAccounts => 'アカウント';

  @override
  String get monitorRoles => 'ロール';

  @override
  String get monitorRole => 'ロール';

  @override
  String get monitorChangePassword => 'パスワードを変更';

  @override
  String get monitorNewPassword => '新しいパスワード';

  @override
  String get monitorCurrentPassword => '現在のパスワード';

  @override
  String get monitorReauthTip => 'アクセスを変更するには、もう一度パスワードを入力する必要があります。';

  @override
  String get monitorPasswordTooShort => '8 文字以上';

  @override
  String get monitorPasswordMismatch => 'パスワードが一致しません';

  @override
  String get monitorErrReauth => 'パスワードが正しくありません。';

  @override
  String get monitorErrLastAdmin => 'agent には少なくとも 1 つの管理者アカウントが必要です。';

  @override
  String get monitorErrConflict => '既に存在するか、まだ使用中です。';

  @override
  String get monitorErrForbidden => 'この操作は管理者のみ実行できます。';

  @override
  String get monitorRoleNameRule => '小文字、数字、- と _、32 文字まで';

  @override
  String get monitorGrantShell => 'シェルとコマンド';

  @override
  String get monitorGrantShellTip =>
      'ターミナル、プロセス、サービス、コンテナ、スニペット、電源 —— agent のアカウントで実行';

  @override
  String get monitorGrantSshTerminal => 'SSH 経由のパネルターミナル';

  @override
  String get monitorGrantVirt => '仮想化';

  @override
  String get monitorGrantVirtTip =>
      'エージェントの Web パネルで接続する Proxmox VE、libvirt、BMC';

  @override
  String get monitorGrantFiles => 'ファイル';

  @override
  String get monitorGrantConnect => '外向き接続';

  @override
  String get monitorGrantConnectTip => 'ローカル・動的ポート転送、リモートデスクトップ';

  @override
  String get monitorGrantConnectAllow =>
      '許可する接続先（IP または CIDR、任意で :ポート または :開始-終了。1 行に 1 つ、空欄は制限なし）';

  @override
  String get monitorGrantListen => 'サーバーで待ち受け';

  @override
  String get monitorGrantListenTip => 'リモートポート転送';

  @override
  String get monitorGrantListenPublic => 'loopback 以外のアドレス';

  @override
  String get monitorGrantPorts => 'ポート範囲（空欄は制限なし）';

  @override
  String get monitorGrantOff => 'オフ';

  @override
  String get monitorBuiltin => '組み込み';

  @override
  String get monitorAdminRoleTip => 'アカウント、ロール、agent の設定を管理します';

  @override
  String get monitorYou => 'あなた';

  @override
  String get monitorNoAccessToSettings => 'この agent の設定を変更できるのは管理者のみです。';

  @override
  String get monitorPasswordNotSaved =>
      'agent 上のパスワードは変更されましたが、App に保存できませんでした。このサーバーの設定で Monitor のパスワードを更新してください。';

  @override
  String get firewall => 'ファイアウォール';

  @override
  String get firewallLinuxOnly =>
      'ファイアウォール管理は ufw または firewalld を備えた Linux サーバーに対応しています。';

  @override
  String get firewallNeedsRoot =>
      'ファイアウォールのルールを読み取るには root 権限が必要です。続行するには sudo パスワードを入力してください。';

  @override
  String get firewallIncoming => '受信';

  @override
  String get firewallOutgoing => '送信';

  @override
  String get firewallRouted => '転送';

  @override
  String get firewallDefaultPolicy => 'デフォルトポリシー';

  @override
  String get firewallLogging => 'ログ';

  @override
  String get firewallRules => 'ルール';

  @override
  String get firewallRule => 'ルール';

  @override
  String get firewallAddRule => 'ルールを追加';

  @override
  String get firewallAnywhere => '任意';

  @override
  String firewallFromFmt(String source) {
    return '送信元 $source';
  }

  @override
  String get firewallFrom => '送信元';

  @override
  String get firewallTo => '宛先';

  @override
  String get firewallProtocol => 'プロトコル';

  @override
  String get firewallInterface => 'インターフェース';

  @override
  String get firewallComment => 'コメント';

  @override
  String get firewallAppProfile => 'アプリプロファイル';

  @override
  String get firewallPrepend => '他のすべてのルールより前に置く';

  @override
  String get firewallIpv6Off => 'IPv6 はオフです（IPV6=no）。v6 ルールは読み込まれません。';

  @override
  String get firewallReload => '再読み込み';

  @override
  String get firewallNothingMatched =>
      'ポート、アプリプロファイル、アドレス、またはインターフェースを入力してください。';

  @override
  String get firewallInvalidPort =>
      '無効なポートです。22、80,443、6000:6010 の形式で入力してください。';

  @override
  String get firewallTooManyPorts => 'ポートは最大 15 個までです（範囲は 2 個として数えます）。';

  @override
  String get firewallPortsNeedProtocol => 'ポートのリストや範囲には tcp または udp の指定が必要です。';

  @override
  String get firewallInvalidAddress =>
      '無効なアドレスです。IP アドレスまたは 192.168.1.0/24 のようなネットワークを入力してください。';

  @override
  String get firewallMixedIpVersions => '送信元と宛先は、両方とも IPv4 か両方とも IPv6 にしてください。';

  @override
  String get firewallInvalidInterface => '無効なインターフェース名です。';

  @override
  String get firewallInvalidComment => 'コメントに \' や改行は使用できません。';

  @override
  String get firewallInvalidProtocol => 'サポートされていないプロトコルです。';

  @override
  String get firewallInterfaceIn => '受信インターフェース';

  @override
  String get firewallInterfaceOut => '送信インターフェース';

  @override
  String get firewallSourcePort => '送信元ポート';

  @override
  String get firewallMoreOptions => 'その他のオプション';

  @override
  String get firewallNoneInstalled =>
      'このサーバーには ufw も firewalld もインストールされていません。システムのパッケージマネージャーでいずれかをインストールしてください（例: `apt install ufw`、`dnf install firewalld`）。';

  @override
  String get firewallKeepAccess => '先にこのアプリのポートを開いたままにする';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: このアプリからの新しい接続は拒否されます。使用中の接続は切断されるまで維持されます。';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: このアプリからの新しい接続は拒否される可能性があります。接続元のアドレスや受信インターフェースによりますが、アプリからは判別できません。';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: 接続にレート制限がかかります。30 秒以内に 6 回以上接続したアドレスは拒否され、このアプリはその頻度で再接続することがあります。';
  }

  @override
  String get firewallConflict =>
      'ufw と firewalld の両方が有効です。どちらもカーネルのルールを書き込み、最後に読み込まれた方が通過可否を決めます。';

  @override
  String get firewallDefaultZone => 'デフォルト zone';

  @override
  String get firewallZone => 'Zone';

  @override
  String get firewallTarget => 'Target';

  @override
  String get firewallMasquerade => 'Masquerade';

  @override
  String get firewallServices => 'サービス';

  @override
  String get firewallPorts => 'ポート';

  @override
  String get firewallSources => '送信元';

  @override
  String get firewallInterfaces => 'インターフェース';

  @override
  String get firewallRichRules => 'Rich rules';

  @override
  String get firewallForwardPorts => 'ポート転送';

  @override
  String get firewallRuntimeOnly => 'runtime のみ';

  @override
  String get firewallPermanentOnly => 'permanent のみ';

  @override
  String get firewallThisConnection => 'この接続';

  @override
  String get firewallDefaultTag => 'デフォルト';

  @override
  String get firewallDrift =>
      '現在有効な設定が保存済みの設定と異なります。reload または再起動すると保存済みの設定に置き換わります。';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'reload または再起動後、$access は拒否されます。保存済みの設定では許可されていません。';
  }

  @override
  String get firewallSaveRuntime => 'permanent として保存';

  @override
  String get firewallReloadLoses => 'permanent として保存されていない変更は失われます。';

  @override
  String get firewallPanic => 'panic モードがオンです。すべてのパケットが破棄されます。';

  @override
  String get firewallPanicOff => 'panic モードをオフにする';

  @override
  String get firewallStoppedNote => 'firewalld は停止しています。変更は保存され、起動時に有効になります。';

  @override
  String get firewallInvalidSource =>
      '無効な送信元です。アドレス、192.168.1.0/24 のようなネットワーク、ipset:名前、または MAC アドレスを入力してください。';

  @override
  String get firewallInvalidRichRule =>
      'rich rule は \"rule\" で始まり、1 行で記述する必要があります。';

  @override
  String get firewallInvalidForwardPort =>
      'port=80:proto=tcp:toport=8080 の形式で、toport、toaddr、またはその両方を指定してください。';

  @override
  String get monitorSyncNeedsServer =>
      'バックアップを保存する Monitor エージェントのサーバーを選択してください。';

  @override
  String get monitorBackupUnsupported =>
      'この Monitor エージェントはバックアップを保存できません。エージェントを更新してください。';

  @override
  String get monitorBackupAdminOnly =>
      'Monitor エージェントにバックアップを保存できるのは管理者アカウントのみです。';

  @override
  String monitorBackupTooLarge(String max) {
    return 'バックアップが Monitor エージェントの上限サイズ（$max）を超えています。';
  }

  @override
  String get monitorBackupTooMany =>
      'Monitor エージェントのバックアップ数が上限に達しています。先に 1 つ削除してください。';

  @override
  String get virtCreateVmidInvalid => 'VMID は 100 から 999999999 までです。';

  @override
  String get virtCreateNodeOffline => 'そのノードはオンラインではありません。';

  @override
  String get virtCreateMediaMissing => 'そのインストールメディアはこのホストにありません。';

  @override
  String get virtCreateNetworkMissing => '新しい仮想マシンはそのネットワークを使えません。';

  @override
  String get virtCreateNotOffered => 'このホストは新しい VM にそれを提供していません。';

  @override
  String get virtCreateSecureBootNeedsUefi => 'Secure Boot には UEFI が必要です。';

  @override
  String get virtGuestNotStopped => '先にシャットダウンしてください。';

  @override
  String get virtGuestIsTemplate => 'すでにテンプレートです。';

  @override
  String get virtCreateImageBigger =>
      'イメージがディスクより大きいです。ディスクを少なくとも同じ大きさにしてください。';

  @override
  String get virtBackupIssueStorage => 'そのストレージはこのノードでバックアップを保持しません。';

  @override
  String get virtBackupIssueOption => 'PVE が受け付けるモードや圧縮ではありません。';

  @override
  String get virtBackupIssueNodeOffline => 'ジョブのノードはオンラインではありません。';

  @override
  String get programWaiting => '操作待ち';

  @override
  String get programWaitingPermission => '承認待ち';

  @override
  String get programWaitingQuestion => '回答待ち';

  @override
  String get programWaitingAuth => 'サインイン待ち';

  @override
  String get programStatus => 'プログラムの状態';

  @override
  String get programIdle => '待機中';

  @override
  String get programThisShell => 'この shell';

  @override
  String get programProgress => '進行状況';

  @override
  String get programCommandRunning => 'コマンドを実行中';

  @override
  String get programCommandSucceeded => '最後のコマンドは成功しました';

  @override
  String programCommandFailed(int code) {
    return '最後のコマンドは終了コード $code で終了しました';
  }

  @override
  String get programStatusAlerts => 'プログラムが応答を求めているときに通知';

  @override
  String get programStatusAlertsTip =>
      '画面に表示されていない terminal について、プログラムが自身の状態として待機・完了・失敗を報告したとき（OSC 7501、OSC 9;4）、または30秒以上実行されたコマンドが終了したとき（OSC 133）に通知します。';

  @override
  String get termLineHeight => '行の高さ';

  @override
  String get termLineHeightTip =>
      '端末の1行が占める高さを、フォントサイズの倍率（1.0～2.0）で指定します。フォントサイズと同様に、表示できる行数に影響します。';

  @override
  String get termFontTip =>
      'フォントファイルを選択していない場合、端末はシステムの等幅フォントを使用し、不足する文字には CJK と emoji のグリフを含むフォントを使用します。';

  @override
  String get netSpeed => '通信速度';

  @override
  String get inRange => '期間内';

  @override
  String threadsFmt(int count) {
    return '$count スレッド';
  }
}
