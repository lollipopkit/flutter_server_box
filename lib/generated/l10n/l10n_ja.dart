// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appearanceSettings => '外観';

  @override
  String get appearancePreset => 'テーマプリセット';

  @override
  String get appearanceThemeSchemaRange => '対応テーマ schema';

  @override
  String get appearanceThemeInstall => 'テーマをインストール';

  @override
  String get appearanceThemeStore => 'テーマストア';

  @override
  String get appearanceInvalidTheme => 'テーマパッケージまたはカタログが無効です';

  @override
  String get themeStoreRefreshFailed => 'テーマカタログを読み取れませんでした。';

  @override
  String themeStoreDeleteTheme(String name) {
    return '「$name」を削除しますか？ファイルはこの端末から削除されます。使用中のテーマの場合、アプリは既定のテーマに戻ります。';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return '$agoに更新';
  }

  @override
  String get themeStoreUpdatedJustNow => 'たった今更新';

  @override
  String get themeStoreSortInUse => '使用中を先頭';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return '自分のテーマを作りたい方は[テーマ作成ガイド]($doc)をご覧ください。ご協力ありがとうございます！';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return '新しいバージョンのアプリが必要です: $version';
  }

  @override
  String get appearanceFontFamilies => 'UI フォントファミリー';

  @override
  String get appearanceFontFamiliesTip => '1 行に 1 つの名前を入力してください。上から順に使用します。';

  @override
  String get appearanceFontImport => 'UI フォントファイルをインポート';

  @override
  String get appearanceGradient => 'グラデーション';

  @override
  String get appearanceNoBackground => '背景なし';

  @override
  String get appearanceIcons => 'アプリ内アイコン';

  @override
  String get appearanceCorners => '角丸';

  @override
  String get appearanceCardCorners => 'カードの角丸';

  @override
  String get appearanceTileCorners => 'タイルの角丸';

  @override
  String get appearanceButtonCorners => 'ボタンの角丸';

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
  String get crashCollectFull => '完全な情報';

  @override
  String get crashCollectFullTip =>
      'クラッシュログに加え、パフォーマンスデータと機能の利用状況も含みます。**動作が遅い箇所の特定と、どの機能が実際に使われているかの把握に役立ちます。**';

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
  String get askAiAwaitingResponse => 'AI の応答を待機中...';

  @override
  String get askAiEndpointTip => 'ドメインまたは完全な URL。パスは選んだプロトコルから補完されます。';

  @override
  String get askAiProtocolTip => '自動は Responses、次に Chat Completions を試します。';

  @override
  String get askAiCommandInserted => 'コマンドをターミナルに挿入しました';

  @override
  String askAiConfigMissing(String fields) {
    return '設定で $fields を構成してください。';
  }

  @override
  String get askAiDisclaimer => 'AI が誤る可能性があります。注意してご利用ください。';

  @override
  String get askAiInsertTerminal => 'ターミナルに挿入';

  @override
  String get askAiNoResponse => '応答なし';

  @override
  String get remoteDesktop => 'リモートデスクトップ';

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
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip => 'このメッセージ以降の返答、コマンド、実行結果はすべて破棄されます。';

  @override
  String get askAiDeleteTip => 'このメッセージと、それ以降の返答、コマンド、実行結果はすべて削除されます。';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'models.dev から取得したモデル名別のコンテキストサイズです。App にも同梱されていますが、タップすると最新版を取得できます。';

  @override
  String get askAiContextFallback => '一覧にありません';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      '以前のやり取りを要約するまでに、モデルのコンテキストをどこまで使うかを指定します。早めに要約すると詳細が失われやすく、遅くするとモデルがリクエストを拒否する可能性が高まります。';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'このモデルが扱える token 数です。「自動」ではモデル名から検索します。provider がモデル本来の上限より短い範囲しか提供しない場合は、数値を指定してください。';

  @override
  String get askAiConversationCompacted => '会話を続けるため、以前のメッセージを要約しました。';

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
  String get askAiAllowInsecure => '平文 HTTP を許可';

  @override
  String get askAiAllowInsecureTip =>
      'localhost 以外のアドレスにあるセルフホストモデルへの http:// 接続を許可します。API キーと端末コンテキストは暗号化されずに送信されます。localhost には影響しません。';

  @override
  String get askAiInsecureEndpoint =>
      'このエンドポイントは http:// を使用します。使用するには AI 設定で「平文 HTTP を許可」をオンにしてください。';

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
  String agentToolCallsFmt(int count) {
    return 'ツール呼び出し $count 件';
  }

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
  String get diskHealth => 'ディスクの健康状態';

  @override
  String get displayCpuIndex => 'CPUインデックスを表示する';

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
  String get preferredTransport => '優先する接続';

  @override
  String get preferredTransportTip => 'ステータスの取得元と、コマンドが最初に開く接続。もう一方も引き続き使えます。';

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
  String mismatchSystem(String system) {
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
  String get preferDiskAmount => 'ディスク容量を優先的に表示';

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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand はデスクトップのみ対応しています。';

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
  String get serverTabEmpty => 'サーバーはまだありません';

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
  String get sshConnectionModeTip =>
      '内蔵: アプリのターミナルを使います。システム SSH: 外部ターミナルでシステムの ssh コマンドを起動します。';

  @override
  String get sshConnectionModeUseBuiltin => '内蔵ターミナルを使う';

  @override
  String get sshConnectionModeUseSystem => 'システムの SSH を使う';

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
  String portForward_deleteConfirmFmt(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get sponsor => 'スポンサー';

  @override
  String get sortByJoinTime => '追加した順';

  @override
  String get portForwardBetaTitle => 'ポートフォワード（ベータ）';

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
  String get send => '送信';

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
  String transportOrderFmt(String first, String second) {
    return 'ドラッグで順序を変更できます。最初に $first を試し、応答がなければ $second がセッションを引き受けます。';
  }

  @override
  String transportOnlyFmt(String name) {
    return '$name だけが有効なので、切り替え先はありません。';
  }

  @override
  String get transportNoneOn => 'どちらも無効です — このサーバーには接続できません。';

  @override
  String get transportOffKept => '無効 — 設定は保持され、接続は行いません';

  @override
  String get transportDialledFirst => '最初に試す';

  @override
  String get transportFallback => '予備';

  @override
  String get transportOnlyMethod => '唯一の方法';

  @override
  String get transportOff => '無効';

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
  String get optionalTip => '接続にはどれも必要ありません。開くと、その項目がフォームを置き換えます。';

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
  String get remoteDesktopVncPasswordLength =>
      '従来の VNC パスワードは 8 ASCII バイトまでです。';

  @override
  String get remoteDesktopNameRequired => 'プロファイル名を入力してください。';

  @override
  String get remoteDesktopHostRequired => '接続先ホストを入力してください。';

  @override
  String get remoteDesktopPortRequired => '有効なポートを入力してください。';

  @override
  String get remoteDesktopUsernameRequired => 'RDP のユーザー名を入力してください。';

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
  String appearanceThemeModeLocked(String mode) {
    return 'このテーマは$modeのみ対応しています。モードを変更するには、別のテーマを選択してください。';
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
  String get reopen => '再度開く';

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
}
