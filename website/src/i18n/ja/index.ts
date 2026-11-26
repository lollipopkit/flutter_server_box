import type { Translation } from '../i18n-types.js'

const ja: Translation = {
  meta: {
    lang: 'ja',
    title: 'ServerBox — サーバー監視、SSH、運用をひとつにまとめたネイティブアプリ',
    description:
      'リアルタイムグラフ、タッチ対応 SSH ターミナル、SFTP、Docker、systemd、S.M.A.R.T.、ウィジェット、AI エージェントで Linux・Unix・Windows サーバーを快適に管理。',
  },
  nav: {
    features: '機能',
    capabilities: 'ツール',
    download: 'ダウンロード',
    docs: 'ドキュメント',
    themes: 'テーマ',
    os: 'ServerBox OS',
    security: 'セキュリティ',
    beta: 'ベータ',
    plugins: 'プラグイン',
    otherApps: 'その他',
    signIn: 'ログイン',
    languageLabel: '言語',
  },
  hero: {
    titlePrefix: 'すべてのサーバーを、',
    titleSuffix: 'その手の中に。',
    subtitle:
      'リアルタイム監視、タッチ操作に最適化した SSH ターミナル、SFTP、コンテナ管理、AI エージェントを、軽快なネイティブワークスペースに凝縮。',
    primaryAction: 'ダウンロード',
    secondaryAction: '機能を見る',
  },
  screenshots: {
    label: 'ServerBox のインタラクティブなスクリーンショット',
    one: 'ServerBox サーバー概要のスクリーンショット',
    two: 'ServerBox 状態チャートのスクリーンショット',
    three: 'ServerBox ターミナルのスクリーンショット',
    four: 'ServerBox ファイルブラウザのスクリーンショット',
  },
  features: {
    title: '現場のサーバー運用のために。',
    subtitle:
      '日常のチェックから緊急対応まで、PC を開かずに素早く完結できます。',
    list: {
      title: 'サーバー一覧',
      description:
        '全ノードの死活状態と CPU・メモリ・ディスク・通信量をひと目で把握。タグでの絞り込みや 3D 地球儀でのロケーション表示に対応。',
    },
    charts: {
      title: 'リアルタイム＆履歴チャート',
      description:
        'CPU、メモリ、スワップ、ディスク I/O、ネットワークに加え、GPU、センサー、S.M.A.R.T. 状態をライブ表示・履歴比較。',
    },
    terminal: {
      title: 'SSH ターミナル',
      description:
        'vim、tmux、htop も快適に扱える仮想キーを搭載。踏み台サーバーや ProxyCommand にもネイティブ対応。',
    },
    files: {
      title: 'SFTP ファイル管理',
      description:
        'リモートファイルの閲覧・転送・その場での編集に対応。Markdown はリアルタイムでプレビュー表示。',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Compose プロジェクト単位でコンテナを整理。リソース監視、ワンタップ再起動、ログ追跡、コンテナ内シェル接続が可能。',
    },
    processes: {
      title: 'プロセスマネージャー',
      description:
        'CPU・メモリ順のソートや名前・ユーザー・PID 検索で暴走プロセスを即座に特定し、その場で終了。',
    },
    services: {
      title: 'Systemd サービス',
      description:
        '異常終了したユニットを自動的に最上部へ固定。ワンタップでサービスの再起動やジャーナルログの確認が行えます。',
    },
    users: {
      title: 'ユーザーと権限',
      description:
        'アカウント一覧、ログインシェル、sudo 権限を視覚的に監査。コマンドを暗記せずにユーザーやグループを追加・編集。',
    },
    agent: {
      title: 'AI エージェント',
      description:
        '好みの LLM プロバイダー、MCP サーバー、スキルを接続し、障害調査や定型オペレーションを AI アシスタントに委任。',
    },
    bench: {
      title: 'ワンタップ・ベンチマーク',
      description:
        'YABS を実行してディスク・ネットワーク・CPU 性能を測定し記録。スニペットやリモートデスクトップへも素早くアクセス。',
    },
    virt: {
      title: '仮想化基盤の管理',
      description:
        'Proxmox VE や libvirt 上の VM・コンテナを操作。電源制御、vCPU・メモリ・ディスクの調整、コンソール接続に対応。',
    },
    themes: {
      title: 'テーマストア',
      description:
        '配色・背景・アイコン・起動画面をアプリ内ストアからワンタップで着せ替え。自作テーマの作成も可能。',
    },
  },
  capabilities: {
    title: 'すべての運用ツールを、ひとつに。',
    subtitle:
      'ターミナル、SFTP クライアント、監視ダッシュボードを行き来する必要はもうありません。',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux、Windows',
  },
  os: {
    metaTitle: 'ServerBox OS（旧 ServerBox Monitor）— ブラウザデスクトップと監視エンジンをサーバーに',
    metaDescription:
      'ServerBox OS（旧 ServerBox Monitor）はブラウザ内デスクトップ、40 以上のワンクリック Docker アプリ、ZFS/RAID 管理、AI エージェント、通知、暗号化バックアップを提供します。',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: '旧 ServerBox Monitor',
    navPreview: 'デモ',
    navInstall: '導入',
    navApp: 'ServerBox アプリ',
    tagline: 'ブラウザでも、アプリでも使えるサーバー基盤。',
    subtitle:
      '軽量な単一バイナリを Linux サーバーに入れるだけで、ブラウザ上のマルチウィンドウデスクトップ、40 以上のセルフホストアプリ、AI エージェント、ServerBox アプリとの HTTPS 連携がすぐに使えます。',
    monitorNote:
      'ServerBox OS は旧 ServerBox Monitor（server_box_monitor）の進化版です。既存の Monitor 環境も同じコマンドでそのままアップグレードでき、プッシュ通知・ウィジェット・watchOS・履歴グラフを引き続き提供します。',
    exploreAction: 'ServerBox OS を詳しく見る',
    installAction: 'Linux にインストール',
    images: 'OS イメージを入手',
    previewAction: 'デモを見る',
    previewTitle: '実際の動作を見る',
    previewSubtitle:
      '実機サーバーでのデモ：ブラウザ上のデスクトップ、アプリ導入、AI エージェントによる自律運用。',
    previewPlay: 'ServerBox OS のデモを再生',
    previewYoutube: 'YouTube で見る',
    featuresTitle: 'サーバー側で動くすべての機能',
    featuresSubtitle: 'ホスト上の 1 つのプログラムに、ブラウザからもスマートフォンからもアクセス。',
    desk: {
      title: 'ブラウザ内デスクトップ',
      description:
        'サーバーの URL を開けば、状態監視・ファイル・ターミナル・コンテナ・プロセス・サービスが独立したウィンドウとして動きます。',
    },
    apps: {
      title: 'ワンクリック・アプリストア',
      description:
        'Immich、Jellyfin、Gitea、Home Assistant など 40 以上の Docker Compose スタックや、Tailscale、リバースプロキシ、ローカル LLM を簡単導入。',
    },
    storage: {
      title: 'ストレージ & NAS 共有',
      description:
        'パーティション操作、RAID・ZFS プールの構築、S.M.A.R.T. 監視、SMB / NFS でのフォルダ共有を GUI で完結。',
    },
    agent: {
      title: '自律型 Agent モード',
      description:
        'AI が手順を計画し、危険なコマンドは事前確認、許可時のみ sudo を実行。MCP 経由で導入済みアプリとも連携します。',
    },
    alerts: {
      title: 'マルチチャネル通知',
      description:
        'CPU・メモリ・ディスク・サービスの異常を ServerBox アプリ、Telegram、Discord、ntfy、Bark、メール、Webhook へ即座に通知。',
    },
    backups: {
      title: '暗号化バックアップ',
      description:
        '設定は age で暗号化して WebDAV へ保存。コンテナデータは指定ディスクへスケジュールバックアップ。',
    },
    security: {
      title: 'セキュア認証と監査ログ',
      description:
        '変更操作には HTTPS を強制し、認証情報は暗号化保存。サインインと root 操作はすべて監査ログに記録されます。',
    },
    app: {
      title: 'アプリとのシームレス連携',
      description:
        'SSH の代わり、または併用で HTTPS 接続。履歴グラフ、プッシュ通知、ウィジェット、Agent タスクをスマホから利用可能。',
    },
    installTitle: '2 つの導入方法',
    installSubtitle: '既存の Linux サーバーへ 1 行で導入するか、専用 OS イメージとして起動。',
    linuxTitle: '既存の Linux サーバーに導入',
    promptUser: '# systemd：現在のユーザー権限でサービス実行',
    promptOpenrc: '# OpenRC (Alpine)：root で登録し、自分のユーザーとして実行',
    promptRoot: '# systemd / OpenRC：root 権限でシステム全体として実行',
    linuxNote:
      '実行アカウントの権限で動作します。install を upgrade や uninstall に変えるだけで更新・削除できます。',
    copy: 'コマンドをコピー',
    imageTitle: '専用 OS として起動',
    stepWrite: 'イメージを USB メモリに書き込む（dd、Etcher、Ventoy）か、VM にマウントします。',
    stepBoot:
      '起動すると、コンソールに接続先 URL、TLS フィンガープリント、初期パスワードの場所が表示されます。',
    stepInstall: 'sbm-install <ディスク> を実行すると対象ディスクへ本설定インストールします。',
    liveNote:
      'ディスクへインストールする前はメモリ上の Live モードで動作し、再起動でリセットされます。',
    note: 'ServerBox OS もアプリと同じく AGPLv3 のオープンソースです。',
    docs: 'Monitor ドキュメント',
    appAction: 'アプリを入手',
  },
  themes: {
    title: '自分好みのスタイルに。',
    subtitle:
      '公式テーマをその場でライブプレビュー。「設定 → 外観 → テーマストア」からワンタップで適用、または .fsbt パッケージを読み込めます。',
    empty:
      '公式テーマはまだありません。ガイドを参考に自作テーマを作成・投稿できます。',
    note: 'ストアの全パッケージはインストール前に SHA-256 チェックサムが検証されます。',
    authoring: 'テーマ作成ガイド',
    download: '.fsbt をダウンロード',
    source: 'ソース',
    light: 'ライト',
    dark: 'ダーク',
    search: 'テーマ・アイコンパックを検索',
    modeLabel: 'モード',
    all: 'すべて',
    sortLabel: '並び替え',
    sortName: '名前順',
    sortUpdated: '更新順',
    noMatch: '一致するテーマがありません。別のキーワードやモードをお試しください。',
    storeTitle: 'テーマストア',
    storeSubtitle:
      '公式テーマとアイコンパックを、アプリ内とまったく同じ配色・コンポーネント・アイコンでライブプレビュー。',
    browse: 'テーマストアを見る',
    back: 'すべてのテーマ',
    details: '詳細',
    icons: 'アイコン',
    tabIcons: 'タブと選択状態',
    navIcons: 'ナビゲーション記号',
    palette: 'カラーパレット',
    components: 'コンポーネント',
    splash: 'スプラッシュ画面',
    install: 'インストール',
    installSteps:
      'アプリの「設定 → 外観 → テーマストア」で {name} を選ぶか、.fsbt ファイルをダウンロードして「テーマをインストール → ファイル」から読み込みます。',
    base: '通常',
    hovered: 'ホバー',
    pressed: '押下',
    disabled: '無効',
    loadFailed: 'プレビューを読み込めませんでした。',
    retry: '再試行',
    iconPacks: 'アイコンパック',
    iconPacksSubtitle:
      'アイコンパックはどのテーマとも自由に組み合わせ可能。「設定 → 外観 → テーマストア → アイコンパック」から適用できます。',
  },
  plugins: {
    title: 'ServerBox を拡張',
    subtitle: '公式プラグインでさらに機能を追加。',
    empty: '公式プラグインはまだありません。',
    download: 'ダウンロード',
  },
  download: {
    title: 'あらゆるプラットフォームにネイティブ対応。',
    subtitle:
      'お使いの OS とお好みの配布元を選択してください。',
    copied: 'コピーしました',
    copyPrompt: 'インストールコマンドをコピー:',
    note:
      'ヒント：サーバー側に ServerBox OS を導入すると、プッシュ通知、ウィジェット、履歴グラフが利用できます。',
  },
  cta: {
    title: 'AGPLv3 の無料オープンソース。',
    subtitle:
      'コードの閲覧やコントリビュートは GitHub から。今すぐ最新リリースをお試しください。',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: 'LGBTQ+ フレンドリー',
    title: '誇りと多様性とともに。',
    description:
      'ServerBox は LGBTQ+ コミュニティを誇りをもって支持します。テーマストアでは Rainbow・Trans・Nonbinary の 3 バリアントを備えた公式 Pride テーマを配布しています。',
    rainbow: 'Rainbow',
    trans: 'Trans',
    nonbinary: 'Nonbinary',
  },
  otherApps: {
    title: 'その他のサービスとアプリ。',
    subtitle:
      '軽快な動作と洗練された設計思想を共有するクラウドサービスとネイティブアプリ。',
    servicesHeading: 'サービス',
    appsHeading: 'Apps',
    llmapi: {
      title: 'LLM API',
      description:
        '主要 LLM を束ねる統合 API ゲートウェイ。ServerBox の AI エージェントや LLMBox、各種開発ツールにそのまま接続できます。',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        'Web サイト、API、サーバーの稼働監視と公開ステータスページを提供する軽量モニタリングサービス。',
    },
    llmbox: {
      title: 'LLMBox',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        'OpenAI および互換 LLM API 向けの高速なネイティブクライアント。ローカル履歴保存、ツール呼び出し、カスタムエンドポイントに対応。',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        'macOS 標準の File Provider を通じて、カーネル拡張なしで SFTP・S3・WebDAV などのリモートストレージを Finder に直接マウント。',
      action: 'mfuse.lollipopkit.com',
    },
  },
  security: {
    metaTitle: '2要素エンドツーエンド暗号化 — ServerBox',
    metaDescription:
      'バックアップパスワード、128ビットクライアントシークレットキー、X25519暗号化、Ed25519署名によって同期データを保護する仕組み。',
    badge: 'ゼロ知識同期アーキテクチャ',
    navHow: '仕組み',
    navThreats: '脅威モデル',
    navDevices: 'マルチデバイス',
    heroTitle: '2要素エンドツーエンド暗号化、',
    heroHighlight: 'クラウド侵害を前提とした設計。',
    subtitle:
      '増加するサーバー侵害やデータ漏洩に備え、自動同期ではバックアップパスワードと128ビットのクライアントシークレットキーの両方が必須になりました。同期サーバーが完全に侵害されても、SSH秘密鍵や認証情報は復号できません。',
    zeroKnowledgeNotice:
      'ServerBoxはあなたのデータを見ることも、紛失したシークレットキーを復元することもできません。紛失すると暗号化された同期データは復号できなくなるため、パスワードマネージャーやオフライン媒体に安全に保管してください。',
    primaryAction: '仕組みを見る',
    docsAction: '技術ドキュメント',
    howTitle: '2つの独立した要素。',
    howSubtitle:
      '同期データの復号には、記憶しているパスワードと、端末外に送信されない高エントロピー鍵の両方が必要です。',
    factor1Tag: 'バックアップパスワード',
    factor1Title: '記憶しておく要素',
    factor1Desc:
      'シークレットキーを変更せずにいつでも変更可能です。端末キーチェーンのみの盗難を防ぎ、ローカルの手動 .age バックアップ暗号化にも使われます。',
    factor2Tag: 'シークレットキー（128ビット）',
    factor2Title: '端末内で生成、サーバーへ送信しない',
    factor2Desc:
      'OSのCSPRNGで生成した128ビットエントロピーをCrockford Base32と22ビットBLAKE3チェックサムで符号化。入力ミスは鍵導出前にローカルで検出されます。',
    diagramStep1: '1. ドメイン分離したBLAKE3でパスワードとシークレットキーをローカル結合',
    diagramStep2: '2. age scryptで identity.age 内のX25519同期鍵ペアを保護',
    diagramStep3: '3. すべての同期データをX25519公開鍵で暗号化（平文同期を拒否）',
    diagramStep4: '4. LK Cloud個人書き込みにEd25519署名と単調増加バージョン検証を適用',
    primitivesLabel: '暗号プリミティブ',
    threatsTitle: '脅威モデル。',
    threatsSubtitle: 'サーバー侵害、改ざん、または鍵紛失時のクライアント挙動です。',
    colScenario: 'シナリオ',
    colBehavior: '挙動',
    threats: {
      breach: {
        scenario: '同期サーバーまたはオブジェクトストレージの侵害',
        behavior:
          '攻撃者が得られるのは identity.age とX25519暗号文のみです。128ビットのシークレットキーなしではオフライン総当たり攻撃は現実的に不可能です。',
      },
      downgrade: {
        scenario: '侵害サーバーによる平文や単一要素バックアップの注入',
        behavior:
          'リモート自動同期は平文データとパスワード単体バックアップを拒否します。2要素暗号化へ移行後はローカルマーカーによりダウングレードを遮断します。',
      },
      tamper: {
        scenario: '侵害されたLK Cloudサーバーによる書き込み偽造やロールバック',
        behavior:
          '個人LK Cloudファイル・ログバッチ・スナップショットはEd25519 AccountKeyで署名されます。クライアントは署名を検証し、ローカルの単調ウォーターマークでロールバックやリプレイを拒否します。',
      },
      loss: {
        scenario: 'すべての端末でシークレットキーを紛失',
        behavior:
          'ServerBoxも同期バックエンドもシークレットキーの複製を保持しません。既存のクラウド同期データは復号・復元できません。',
      },
    },
    devicesTitle: 'マルチデバイス同期とアップグレード。',
    devicesSubtitle: '新規インストールを保護し、既存同期ユーザーのSSH利用を妨げずに移行できます。',
    devices: {
      apple: {
        tag: 'iOS · macOS',
        title: 'Appleキーチェーン自動同期',
        description:
          '同じiCloudアカウントのApple端末間ではiCloudキーチェーン経由でシークレットキーが自動同期され、手入力なしで同期を継続できます。',
      },
      crossPlatform: {
        tag: 'Android · Windows · Linux',
        title: 'QRスキャンまたは手動インポート',
        description:
          'QRコードのスキャンまたは S1-... 文字列の入力で非Apple端末へ追加できます。紛らわしい文字（I/L→1、O→0）を自動正規化しチェックサムを検証します。',
      },
      existing: {
        tag: '既存ユーザー',
        title: 'パスワードを維持したまま移行',
        description:
          '最初にアップグレードした端末は既存のバックアップパスワードを維持し、シークレットキーの保存確認後に identity.age を2要素暗号化へ更新します。他端末は鍵をインポートするまで同期のみ一時停止します。',
      },
    },
    footerNote: 'Rustによる暗号化と署名の実装は fl_lib と ServerBox でAGPLv3のもと公開されています。',
    privacyLink: 'プライバシーポリシー',
  },
  footer: {
    features: '機能',
    capabilities: 'ツール',
    releases: 'リリース',
  },
}

export default ja
