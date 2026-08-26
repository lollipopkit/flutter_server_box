// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get acceptBeta => 'テストバージョンの更新を受け入れる';

  @override
  String get addSystemPrivateKeyTip =>
      '現在秘密鍵がありません。システムのデフォルト(~/.ssh/id_rsa)を追加しますか？';

  @override
  String get added2List => 'タスクリストに追加されました';

  @override
  String get askAi => 'AI に質問';

  @override
  String get askAiAwaitingResponse => 'AI の応答を待機中...';

  @override
  String get askAiEndpointTip => 'ドメインまたは完全な URL。パスは選んだプロトコルから補完されます。';

  @override
  String get askAiProtocolTip => '自動は Responses、次に Chat Completions を試します。';

  @override
  String get askAiCommandInserted => 'コマンドをターミナルに挿入しました';

  @override
  String askAiConfigMissing(Object fields) {
    return '設定で $fields を構成してください。';
  }

  @override
  String get askAiDisclaimer => 'AI が誤る可能性があります。注意してご利用ください。';

  @override
  String get askAiInsertTerminal => 'ターミナルに挿入';

  @override
  String get askAiNoResponse => '応答なし';

  @override
  String get askAiAgentWelcome => 'このサーバーで何をしますか？';

  @override
  String get askAiAgentPromptHint => 'エージェントに調査や修正を依頼…';

  @override
  String get askAiAnalyzeSelectionPrompt => '選択したターミナル出力を分析し、何が起きたか説明して';

  @override
  String get askAiTerminalContext => 'ターミナルのコンテキスト';

  @override
  String get askAiReviewNeeded => '要確認';

  @override
  String get askAiReviewAction => '提案されたコマンドを確認';

  @override
  String get askAiReviewBeforeContinuing => '先に現在の提案を確認するか拒否してください';

  @override
  String get askAiApproveRun => '承認して実行';

  @override
  String get askAiDecline => '拒否';

  @override
  String get askAiActionDeclined => '提案されたコマンドは拒否されました。';

  @override
  String get askAiInterrupted => 'エージェントの応答が中断されました。';

  @override
  String get askAiRiskReadOnly => '読み取り専用';

  @override
  String get askAiRiskCaution => 'システムを変更';

  @override
  String get askAiRiskUnvetted => '未確認のホスト';

  @override
  String get askAiRiskDestructive => '高リスク';

  @override
  String get askAiHighRiskConfirmTitle => '高リスクのコマンドを実行しますか？';

  @override
  String get askAiHighRiskConfirmBody =>
      'このコマンドは元に戻しにくい変更をする可能性があります。よく確認してください。';

  @override
  String get askAiNoCommandOutput => 'コマンドは出力なしで終了しました。';

  @override
  String get askAiOutputTruncated => '長い出力はエージェントに返す前に切り詰められました。';

  @override
  String get askAiAutoApproved => '自動承認';

  @override
  String get askAiAutoRunSafeCommands => '読み取り専用コマンドを自動実行';

  @override
  String get askAiAutoRunSafeCommandsTip => 'モデルとローカルの検査がどちらも読み取り専用と判断したときだけ実行';

  @override
  String get askAiSendOnEnter => 'Enter で送信';

  @override
  String get askAiSendOnEnterTip =>
      'Enter で送信、Shift+Enter で改行。オフ：Enter で改行、Cmd/Ctrl+Enter で送信。';

  @override
  String get askAiApiKeyOptional => 'ローカルや認証不要なら空のままで';

  @override
  String get askAiHistory => '会話履歴';

  @override
  String get askAiNewConversation => '新しい会話';

  @override
  String get askAiNoHistory => '保存された会話はまだありません';

  @override
  String get askAiNoHistoryMessages => 'メッセージはまだありません';

  @override
  String get askAiUntitledConversation => '無題';

  @override
  String get askAiRenameConversation => '会話の名前を変更';

  @override
  String get askAiDeleteConversationTitle => 'この会話を削除しますか？';

  @override
  String get askAiDeleteConversationTip => 'この端末から削除します。元に戻せません。';

  @override
  String get askAiClearHistoryTitle => 'このサーバーのエージェント履歴を消去しますか？';

  @override
  String get askAiClearHistoryTip => 'このサーバーの保存済み Agent 会話がすべて削除されます。';

  @override
  String get askAiRestoredReview => 'このコマンドは履歴からのものです。もう一度確認してください';

  @override
  String get agentWelcome => 'サーバー全体で何をしますか？';

  @override
  String get agentWelcomeTip => 'Agent に問題の診断や運用作業を任せられます';

  @override
  String get agentPromptHint => 'エージェントにサーバーの調査や操作を依頼…';

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
  String get agentToolFailed => 'ツールの実行に失敗しました。';

  @override
  String agentToolCallsFmt(Object count) {
    return 'ツール呼び出し $count 件';
  }

  @override
  String get agentFloat => '他のタブの上に浮かべる';

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
  String get distIconConsent => 'そのサーバーが動かしている可能性のあるディストリビューションを示すためだけに使います。';

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
  String get markUrl => 'マークの URL';

  @override
  String get markUrlTip => '一覧でサーバー名の横に出る小さなマーク。空なら表示しません。\n\nロゴとは別の画像です';

  @override
  String get navTabMenuTip => 'タブを長押し（マウスは右クリック）すると、その中のすべてをまとめて接続・切断できます。';

  @override
  String nTags(Object count) {
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
  String get monitorAllowInsecureHttpTip =>
      'HTTP 以外で通信自体が暗号化される信頼できるプライベートネットワークでのみ。たとえば Tailscale';

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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return '最終バックアップ: $lastModified\n状態: $remoteState';
  }

  @override
  String get bgRun => 'バックグラウンド実行';

  @override
  String get bgRunTip =>
      'このスイッチはプログラムがバックグラウンドで実行を試みることを意味しますが、実際にバックグラウンドで実行できるかどうかは、権限が有効になっているかに依存します。AOSPベースのAndroid ROMでは、このアプリの「バッテリー最適化」をオフにしてください。MIUIでは、省エネモードを「無制限」に変更してください。';

  @override
  String get bgRunNeedsNotification =>
      'バックグラウンド実行には常駐通知が必要ですが、このアプリには通知の許可がありません。タップして通知を許可してください。';

  @override
  String get clearAllStatsContent => 'すべてのサーバー接続統計を削除してもよろしいですか？この操作は元に戻せません。';

  @override
  String get clearAllStatsTitle => 'すべての統計をクリア';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'サーバー\"$serverName\"の接続統計を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '$serverNameの統計をクリア';
  }

  @override
  String get clearThisServerStats => 'このサーバーの統計をクリア';

  @override
  String get compactDatabase => 'データベースを圧縮';

  @override
  String compactDatabaseContent(Object size) {
    return 'データベースサイズ: $size\n\nこれにより、ファイルサイズを小さくするためにデータベースが再編成されます。データは削除されません。';
  }

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
  String get cpuViewAsProgressTip => '各CPUの使用率をプログレスバースタイルで表示する（旧スタイル）';

  @override
  String get customCmd => 'カスタムコマンド';

  @override
  String get deleteServers => 'サーバーを一括削除';

  @override
  String get deleteDirRecursive => 'フォルダーとその中身をすべて削除';

  @override
  String get desktopTerminalTip => 'SSHセッションを起動する際に使用されるターミナルエミュレーターを開くコマンド。';

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
  String distroSwitchTip(Object from, Object to) {
    return '$from を $to に置き換えます。$from の中にインストールしたものはすべて削除され、代わりに $to をダウンロードして展開します。';
  }

  @override
  String get diskHealth => 'ディスクの健康状態';

  @override
  String get displayCpuIndex => 'CPUインデックスを表示する';

  @override
  String dl2Local(Object fileName) {
    return '$fileNameをローカルにダウンロードしますか？';
  }

  @override
  String get dockerEmptyRunningItems =>
      '実行中のコンテナがありません。\nこれは次の理由による可能性があります：\n- Dockerのインストールユーザーとアプリ内の設定されたユーザー名が異なる\n- 環境変数DOCKER_HOSTが正しく読み込まれていない。ターミナルで`echo \$DOCKER_HOST`を実行して取得できます。';

  @override
  String dockerImagesFmt(Object count) {
    return '合計$countイメージ';
  }

  @override
  String get dockerProjectOther => 'その他';

  @override
  String get dockerPruneTip => '未使用のデータを削除してディスク容量を解放します';

  @override
  String get dockerStatistics => 'Docker 統計';

  @override
  String get doubleColumnMode => 'ダブルカラムモード';

  @override
  String get doubleColumnTip =>
      'このオプションは機能を有効にするだけで、実際に有効にできるかどうかはデバイスの幅に依存します';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
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
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '$serverName の踏み台サーバーが見つかりません: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '「$name」は既に存在します';
  }

  @override
  String get noJumpServerAvailable => '利用できる踏み台サーバーがありません。';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '踏み台サーバーと ProxyCommand は併用できません。';

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
  String madeWithLove(Object myGithub) {
    return '$myGithubによって❤️で作成済み';
  }

  @override
  String get maxConcurrency => '最大同時実行数';

  @override
  String get maxRetryCount => 'サーバーの再接続試行回数';

  @override
  String mismatchSystem(Object system) {
    return 'システムが一致しません: $system';
  }

  @override
  String get mirror => 'ミラー';

  @override
  String get needRestart => 'アプリを再起動する必要があります';

  @override
  String get netViewType => 'ネットワークビュータイプ';

  @override
  String get newContainer => '新しいコンテナを作成';

  @override
  String get noConnectionStatsData => '接続統計データがありません';

  @override
  String get noLineChart => '折れ線グラフを使用しない';

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
  String get plugInType => '挿入タイプ';

  @override
  String get preferDiskAmount => 'ディスク容量を優先的に表示';

  @override
  String get privateKey => '秘密鍵';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand はデスクトップのみ対応しています。';

  @override
  String get pveIgnoreCertTip =>
      'オプションを有効にすることは推奨されません、セキュリティリスクに注意してください！PVEのデフォルト証明書を使用している場合は、このオプションを有効にする必要があります。';

  @override
  String get pveServerClientMissing => 'このサーバーの SSH クライアントを利用できません。';

  @override
  String get pveAddressMissing => 'PVE のアドレスがありません。サーバー設定で指定してください。';

  @override
  String get pvePasswordRequired => 'PVE のパスワードが必要です。サーバー設定で指定してください。';

  @override
  String get pveOtpRequired => 'この PVE サーバーでは二要素認証が有効です。OTP コードを入力してください。';

  @override
  String get pveOtpChallengeExpired => 'OTP チャレンジの有効期限が切れました。更新してからやり直してください。';

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
  String get pveVersionLow => 'この機能は現在テスト段階にあり、PVE 8+でのみテストされています。ご利用の際は慎重に。';

  @override
  String get pveLoadingForwarding => 'SSH トンネルを確立中…';

  @override
  String get pveLoadingLogin => 'PVE で認証中…';

  @override
  String get pveLoadingData => 'クラスターのデータを取得中…';

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
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed が入っていて、$latest があります。更新はコンテナ全体を置き換えます：$pm のデータは失われます';
  }

  @override
  String linuxSystemInUse(Object name) {
    return '$name のターミナルを閉じてから削除してください';
  }

  @override
  String get rootfsSubtitle => 'この端末上の Linux ユーザーランド';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
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
  String selected(Object count) {
    return '$count 件選択';
  }

  @override
  String get sendTo => '送信先…';

  @override
  String get serverDetailOrder => '詳細ページのウィジェット順序';

  @override
  String get serverFuncBtns => 'サーバー機能ボタン';

  @override
  String get serverOrder => 'サーバー順序';

  @override
  String get serverTabRequired => 'サーバータブは削除できません';

  @override
  String get shareServerRiskTip =>
      'この QR コードはサーバーの接続設定を平文で含みます。読み取った人や撮影した人は誰でも接続できます。';

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
  String spentTime(Object time) {
    return '費した時間: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'すべてのサーバーがすでに存在します（$duplicateCount個の重複が見つかりました）';
  }

  @override
  String get sshConnectionModeTip =>
      '内蔵: アプリのターミナルを使います。システム SSH: 外部ターミナルでシステムの ssh コマンドを起動します。';

  @override
  String get sshConnectionModeUseBuiltin => '内蔵ターミナルを使う';

  @override
  String get sshConnectionModeUseSystem => 'システムの SSH を使う';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount個の重複がスキップされます';
  }

  @override
  String get sshConfigFound => 'システムにSSH設定が見つかりました。';

  @override
  String sshConfigFoundServers(Object totalCount) {
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
  String sshConfigImported(Object count) {
    return 'SSH設定から$count個のサーバーをインポートしました';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '$serverName の SSH ホスト鍵が変更されました。このサーバーを信頼できる場合のみ続行してください。';
  }

  @override
  String get sshHostKeyType => 'SSH ホストキーの種類';

  @override
  String get sshKnownHostKeys => '既知のホスト';

  @override
  String get sshKnownHostKeysTip => 'このアプリが受け入れたホスト鍵';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '$serverName から新しい SSH ホスト鍵を受信しました。信頼する前にフィンガープリントを確認してください。';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
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
  String switchTo(Object val) {
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
  String get view => 'ビュー';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get virtKeyHelpClipboard =>
      '端末に選択された文字がある場合は、選択された文字をクリップボードにコピーします。そうでない場合は、クリップボードの内容を端末に貼り付けます。';

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
  String get virtKeyIntroCustomizeTip => 'ターミナル設定で並べ替えたり、使わないキーを隠したりできます。';

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
  String portForward_deleteConfirmFmt(Object name) {
    return '$name を削除しますか？';
  }

  @override
  String get sponsor => 'スポンサー';

  @override
  String get sortByJoinTime => '追加した順';

  @override
  String get serverHistory => 'サーバー履歴';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

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
  String get tmuxExistingSessions => '既存のセッション';

  @override
  String get tmuxNewSession => '新しいセッション';

  @override
  String get tmuxWindows => 'ウィンドウ';

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
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のペイン',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'アタッチ中';

  @override
  String get tmuxActive => 'アクティブ';

  @override
  String tmuxActiveAt(String time) {
    return 'アクティブ: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'アタッチ: $time';
  }

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
  String get systemdMissing => 'このサーバーには systemd がありません';

  @override
  String get systemdMissingTip =>
      '`systemctl` がインストールされていないため、一覧表示できる unit はありません。';

  @override
  String initSystemFmt(String init) {
    return 'このマシンは $init を使用しているようです。';
  }

  @override
  String get systemdListFailed => 'unit を一覧表示できませんでした';

  @override
  String get systemdUserScopeMissing => 'ユーザー unit は表示されていません';

  @override
  String get systemdUserScopeMissingTip =>
      'このアカウントにはサーバー上のユーザーセッションバスがないため、システム unit のみ表示しています。';

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
  String get send => '送信';

  @override
  String get privacyBlur => 'バックグラウンドのプライバシー';

  @override
  String get privacyBlurTip => 'Appスイッチャーで内容を隠す';
}
