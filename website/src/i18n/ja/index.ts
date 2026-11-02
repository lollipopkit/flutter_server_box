import type { Translation } from '../i18n-types.js'

const ja: Translation = {
  meta: {
    lang: 'ja',
    title: 'ServerBox — サーバー監視、SSH、管理ツールを 1 つのアプリに',
    description:
      'ServerBox は、状態グラフ、SSH ターミナル、SFTP、Docker、プロセスと systemd の管理、S.M.A.R.T. 監視、プッシュ通知、ウィジェット、watchOS に対応し、Linux、Unix、Windows サーバーを管理できます。',
  },
  nav: {
    features: '機能',
    capabilities: 'ツール',
    download: 'ダウンロード',
    docs: 'ドキュメント',
    themes: 'テーマ',
    os: 'ServerBox OS',
    beta: 'ベータ',
    plugins: 'プラグイン',
    languageLabel: '言語',
  },
  hero: {
    titlePrefix: 'サーバー状態を、',
    titleSuffix: 'ポケットの中に。',
    subtitle:
      'ServerBox は、状態グラフ、SSH ターミナル、SFTP、Docker、プロセス管理、systemd、S.M.A.R.T. 監視、プッシュ通知、ウィジェット、watchOS を 1 つのアプリにまとめます。',
    primaryAction: 'ServerBox をダウンロード',
    secondaryAction: '機能を確認',
  },
  screenshots: {
    label: 'ServerBox のインタラクティブなスクリーンショット',
    one: 'ServerBox サーバー概要のスクリーンショット',
    two: 'ServerBox 状態チャートのスクリーンショット',
    three: 'ServerBox ターミナルのスクリーンショット',
    four: 'ServerBox ファイルブラウザのスクリーンショット',
  },
  features: {
    title: '日常のサーバー管理に必要なツールを 1 か所に。',
    subtitle:
      '実用的な機能をコンパクトにまとめ、それぞれが実際のサーバー管理に役立ちます。',
    list: {
      title: 'サーバー一覧',
      description:
        '各サーバーの接続状態、CPU・メモリ・ディスク・ネットワークの使用状況を確認できます。タグで絞り込んだり、地球儀上で確認したりできます。',
    },
    charts: {
      title: 'ステータスチャート',
      description:
        'CPU、メモリ、スワップ、ディスク、ディスク I/O、ネットワークのリアルタイムグラフに加え、センサー、GPU、バッテリーの情報も確認できます。履歴を表示したり、指標を選択して詳細を確認したりできます。',
    },
    terminal: {
      title: 'SSH ターミナル',
      description:
        'スマートフォンでは仮想キーを使って操作でき、htop や vim なども実行できる本格的なターミナルです。直接接続、踏み台ホスト経由、ProxyCommand に対応しています。',
    },
    files: {
      title: 'SFTP でファイル操作',
      description:
        'ファイルの閲覧・アップロード・ダウンロードに加え、その場で編集できます。Markdown ファイルはプレビュー表示で開きます。',
    },
    containers: {
      title: 'Docker と Podman',
      description:
        'Compose プロジェクトごとにコンテナを表示し、CPU・メモリ・ネットワークも確認。起動・停止・再起動・削除、ログの確認、コンテナ内のシェルに対応。イメージと設定は別タブです。',
    },
    processes: {
      title: 'プロセス',
      description:
        'すべてのプロセスと CPU・メモリ使用量を表示します。並べ替えや名前・ユーザー・PID での検索ができ、一覧から直接終了できます。',
    },
    services: {
      title: 'Systemd サービス',
      description:
        '失敗した systemd ユニットを一覧の上部に表示します。ワンタップで再起動したりログを確認したりできます。',
    },
    users: {
      title: 'ユーザーとグループ',
      description:
        'システムアカウントとログインシェル、sudo 権限を確認できます。ユーザーの追加・削除や、グループの追加・編集・削除ができます。',
    },
    agent: {
      title: 'AI エージェント',
      description:
        'アプリ内のアシスタントでサーバーを管理できます。利用するモデルプロバイダー、MCP サーバー、スキルを選べます。',
    },
    bench: {
      title: 'ベンチマーク',
      description:
        'Yet Another Bench Script でサーバーのディスク、ネットワーク、CPU を測定し、結果を保存できます。「その他」メニューからスニペット、リモートデスクトップ、仮想化にもアクセスできます。',
    },
    virt: {
      title: '仮想化',
      description:
        'libvirt と Proxmox VE の VM とコンテナを管理できます。起動・停止、vCPU・メモリ・ディスクの変更、コンソールの表示が可能です。',
    },
    themes: {
      title: 'テーマストア',
      description:
        '独自の配色・背景・スプラッシュを持つ公式テーマを、アプリ内からインストール。自分で作ることもできます。',
    },
  },
  capabilities: {
    title: '必要なツールを 1 つのアプリに。',
    subtitle:
      'ServerBox はターミナル接続、ファイル転送、サービス状態の確認、ハードウェア監視、デバイスへの通知を 1 つのワークフローにまとめます。',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux、Windows',
  },
  os: {
    metaTitle: 'ServerBox OS — ServerBox のサーバー側',
    metaDescription:
      'ServerBox OS はサーバー上で動作する ServerBox Monitor です。アプリストア、ストレージ、Agent mode、アラート、バックアップを備えたブラウザー内のデスクトップです。Linux にインストールするか、システム全体として起動できます。',
    heroTitle: 'ServerBox OS',
    tagline: 'ServerBox のサーバー側。',
    subtitle:
      'ServerBox Monitor はサーバー上で動作します。アプリから接続でき、ブラウザー内蔵のデスクトップからはアプリなしでマシンを管理できます。既存の Linux サーバーにインストールするか、システム全体として起動できます。',
    installAction: 'Linux にインストール',
    images: 'イメージをダウンロード',
    previewAction: 'デモを見る',
    previewTitle: '実際の動作',
    previewSubtitle:
      'ServerBox OS はベータ版です。実際のサーバーでの短いデモ：ブラウザーのデスクトップ、アプリ、そして Agent モードの動作。',
    previewPlay: 'ServerBox OS のデモを再生',
    previewYoutube: 'YouTube で見る',
    featuresTitle: 'サーバー上でできること',
    featuresSubtitle: 'マシン上で 1 つのプログラムが動作し、ブラウザーまたはアプリからアクセスできます。',
    desk: {
      title: 'ブラウザー内のデスクトップ',
      description:
        'サーバーのアドレスを開くと、状態、ファイル、ターミナル、コンテナ、プロセス、サービスなどの各機能がウィンドウ内のアプリとして表示されます。',
    },
    apps: {
      title: 'アプリストア',
      description:
        'Docker Compose で Immich、Jellyfin、Gitea、Home Assistant など 40 種類以上のセルフホストサービスをデプロイできます。Tailscale、リバースプロキシ、カーネル、ローカル AI モデル用のアプリも追加できます。',
    },
    storage: {
      title: 'ストレージと共有',
      description:
        'ディスクのパーティション作成、フォーマット、マウント、RAID アレイや ZFS プールの構築、S.M.A.R.T. の確認ができ、SMB と NFS でフォルダーを共有できます。',
    },
    agent: {
      title: 'Agent mode',
      description:
        'マシン上の AI Agent にタスクを依頼できます。計画を立て、リスクのあるコマンドの前に確認し、許可した場合のみ sudo を使い、MCP 経由でデプロイ済みのアプリにアクセスします。',
    },
    alerts: {
      title: 'アラート',
      description:
        'CPU、メモリ、ディスク、サービスのルールに基づき、アプリ、Telegram、Discord、ntfy、Bark、ServerChan、メール、Webhook に通知します。',
    },
    backups: {
      title: 'バックアップ',
      description:
        '設定は WebDAV に age で暗号化してバックアップされます。コンテナのデータは、選択したディスクにスケジュールに沿ってバックアップされます。',
    },
    security: {
      title: '1 つのパスワード',
      description:
        '1 つのアカウントにパスワードでサインインします。読み取り以外の操作には HTTPS が必要で、認証情報は保存時に暗号化され、サインインと root 操作は監査ログに記録されます。',
    },
    app: {
      title: 'アプリと連携',
      description:
        'ServerBox にサーバーを HTTPS で追加すれば SSH の代わりに、または SSH と併用して接続できます。スマートフォンから状態と履歴を確認し、ターミナル、ファイル、Agent mode のタスク、Web アプリを利用できます。',
    },
    installTitle: '2 つの実行方法',
    installSubtitle: '既存の Linux サーバーで実行するか、専用マシンのシステム全体として起動します。',
    linuxTitle: 'Linux サーバーで実行',
    promptUser: '# systemd：自分のアカウントで実行するユーザーサービス',
    promptOpenrc: '# OpenRC (Alpine)：root がサービスを作成し、サービスは引き続き自分のアカウントで実行',
    promptRoot: '# どちらの init システムでも root として実行',
    linuxNote:
      '実行に使うアカウントによって、できる操作が決まります。更新または削除するには install を upgrade または uninstall に置き換えてください。',
    copy: 'インストールコマンドをコピー',
    imageTitle: 'システム全体として起動',
    stepWrite: 'イメージをダウンロードして USB メモリに書き込む (dd、Etcher、Ventoy) か、仮想マシンに接続します。',
    stepBoot:
      '起動すると、コンソールにアクセス先のアドレス、照合する証明書のフィンガープリント、初期パスワードの場所が表示されます。',
    stepInstall: 'sbm-install <ディスク> はそのディスクを消去し、システムをインストールします。',
    liveNote:
      'インストールするまではメモリ上で動作するため、再起動するとデータベース、イメージ、アプリのデータは失われます。',
    note: 'ServerBox OS はアプリと同様に AGPLv3 のオープンソースです。',
    docs: 'Monitor のドキュメント',
    appAction: 'アプリを入手',
  },
  themes: {
    title: '自分好みの見た目に。',
    subtitle:
      'ここに掲載している ServerBox 公式テーマは、アプリ内のテーマストアでも利用できます。「設定 → 外観 → テーマストア」からインストールするか、パッケージをダウンロードして「テーマをインストール → ファイル」を選択してください。',
    empty:
      '公式テーマはまだありません。各テーマは manifest.toml を含むフォルダーで、ライト・ダークの配色、コンポーネントのスタイル、アイコン、背景、起動画面が含まれます。テーマの作成方法やストアへの申請方法はガイドをご覧ください。',
    note: 'アプリはストアからテーマをインストールする前に、各パッケージの SHA-256 を検証します。',
    authoring: 'テーマを作る',
    download: '.fsbt をダウンロード',
    source: 'ソース',
    light: 'ライト',
    dark: 'ダーク',
    search: 'テーマを検索',
    modeLabel: 'モード',
    all: 'すべて',
    sortLabel: '並び替え',
    sortName: '名前',
    sortUpdated: '最近の更新',
    noMatch: '一致するテーマがありません。別の名前やモードを試してください。',
    storeTitle: 'テーマストア',
    storeSubtitle:
      'ServerBox の公式テーマをすべて、アプリと同じ配色、コンポーネント、アイコン、起動画面で紹介します。アプリ内のテーマストアからインストールするか、パッケージをダウンロードできます。',
    browse: 'テーマストアを開く',
    back: 'すべてのテーマ',
    details: '詳細',
    icons: 'アイコン',
    tabIcons: 'タブと選択時',
    navIcons: 'シンボル',
    palette: '配色',
    components: 'コンポーネント',
    splash: 'スプラッシュ',
    install: 'インストール',
    installSteps:
      'アプリで「設定 → 外観 → テーマストア」を開き、{name} を選択してください。またはパッケージをダウンロードし、「テーマをインストール → ファイル」を選択してください。',
    base: '通常',
    hovered: 'ホバー',
    pressed: '押下',
    disabled: '無効',
    loadFailed: 'このテーマのプレビューを読み込めませんでした。',
    retry: '再試行',
    iconPacks: 'アイコンパック',
    iconPacksSubtitle:
      'アイコンパックはテーマとは別に選択でき、現在のテーマと組み合わせて使えます。「設定 → 外観 → テーマストア → アイコンパック」からインストールできます。',
  },
  plugins: {
    title: 'ServerBox を拡張',
    subtitle: 'ServerBox の公式プラグインをインストールして、アプリの機能を拡張できます。',
    empty: '公式プラグインはまだありません。',
    download: 'ダウンロード',
  },
  download: {
    title: '複数のプラットフォームとダウンロード方法に対応。',
    subtitle:
      'デバイスに合った信頼できる配布元を選んでください。iOS 版は App Store から、または GitHub Releases の未署名 .ipa を自分で署名して入手できます。macOS 版は Apple シリコンと Intel に対応し、GitHub Releases と Homebrew で配布しています。Android、Linux、Windows は直接ダウンロードできます。',
    copied: 'インストールコマンドをコピーしました',
    copyPrompt: 'このインストールコマンドをコピーしてください:',
    note:
      '信頼できる配布元からのみダウンロードしてください。サーバー側の通知、ウィジェットのデータ、独立した監視を利用するには、サーバーに ServerBox OS をインストールしてください。',
  },
  cta: {
    title: 'ServerBox は AGPLv3 の無料オープンソースです。',
    subtitle:
      'App Store、GitHub Releases、F-Droid、OpenAPK からダウンロードできます。',
    appStoreAction: 'App Store を開く',
    githubAction: 'GitHub Releases からダウンロード',
  },
  footer: {
    features: '機能',
    capabilities: 'ツール',
    releases: 'リリース',
  },
}

export default ja
