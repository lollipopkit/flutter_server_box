import type { Translation } from '../i18n-types.js'

const ja: Translation = {
  meta: {
    lang: 'ja',
    title: 'ServerBox — サーバー状態、SSH、運用を 1 つの Flutter アプリで',
    description:
      'ServerBox は、状態チャート、SSH ターミナル、SFTP、Docker、プロセス、systemd、S.M.A.R.T、通知、ウィジェット、watchOS で Linux、Unix、Windows サーバーを監視します。',
  },
  nav: {
    features: '機能',
    capabilities: 'ツール',
    download: 'ダウンロード',
    docs: 'ドキュメント',
    themes: 'テーマ',
    plugins: 'プラグイン',
    languageLabel: '言語',
  },
  hero: {
    titlePrefix: 'サーバー状態を、',
    titleSuffix: 'ポケットの中に。',
    subtitle:
      'ServerBox はチャート、SSH ターミナル、SFTP、Docker、プロセス制御、systemd、S.M.A.R.T、通知、ウィジェット、watchOS を 1 つの Flutter アプリにまとめます。',
    primaryAction: 'ServerBox をダウンロード',
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
    title: '日常のサーバーメンテナンスに使える小さな作業場。',
    subtitle:
      '装飾を抑え、実際のメンテナンス作業に対応する機能だけを集めています。',
    list: {
      title: 'サーバー一覧',
      description:
        '各サーバーの接続状態や CPU・メモリ・ディスク・ネットワークの使用状況を一覧できます。タグで絞り込んだり、地球儀上で確認したりできます。',
    },
    charts: {
      title: 'ステータスチャート',
      description:
        'CPU・メモリ・スワップ・ディスク・ディスク I/O・ネットワークのリアルタイムチャートに加え、センサー・GPU・バッテリーも。履歴に切り替えたり、各項目の詳細を開いたりできます。',
    },
    terminal: {
      title: 'SSH ターミナル',
      description:
        'スマートフォンでは仮想キーを使える本格的なターミナル。htop や vim などを実行できます。直接接続、踏み台ホスト経由、ProxyCommand に対応しています。',
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
        'すべてのプロセスの CPU とメモリ。並べ替えや名前・ユーザー・PID での検索ができ、一覧から停止できます。',
    },
    services: {
      title: 'Systemd サービス',
      description:
        '失敗したユニットを先頭に表示。ワンタップで再起動やログ確認ができます。',
    },
    users: {
      title: 'ユーザーとグループ',
      description:
        'システムアカウントの一覧で、ログインシェルと sudo を表示。ユーザーの追加・削除、グループの追加・編集・削除ができます。',
    },
    agent: {
      title: 'AI エージェント',
      description:
        'サーバーのことを知っているアプリ内アシスタント。モデルプロバイダー、MCP サーバー、スキルは自分で選べます。',
    },
    bench: {
      title: 'ベンチマーク',
      description:
        'Yet Another Bench Script でサーバーのディスク・ネットワーク・CPU を計測し、結果を保存できます。「その他」メニューからスニペット、リモートデスクトップ、仮想化も開けます。',
    },
    virt: {
      title: '仮想化',
      description:
        'libvirt と Proxmox VE の仮想マシンとコンテナを起動・停止し、vCPU・メモリ・ディスクを変更し、コンソールを開けます。',
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
      'ServerBox はターミナル、ファイル転送、サービス確認、ハードウェア状態、デバイス通知を同じ流れにまとめます。',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux、Windows',
  },
  themes: {
    title: '自分好みの見た目に。',
    subtitle:
      'ServerBox の公式テーマです。アプリのテーマストアと同じものを掲載しています。アプリの 設定 → 外観 → テーマストア からインストールするか、パッケージをダウンロードして テーマをインストール → ファイル を選んでください。',
    empty:
      '公式テーマはまだありません。テーマは manifest.toml を含むフォルダーで、ライトとダークの配色、コンポーネントのスタイル、アイコン、背景、スプラッシュを指定できます。作り方とストアへの公開方法はガイドを参照してください。',
    note: 'アプリはストアのパッケージをインストールする前に SHA-256 を検証します。',
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
      'ServerBox の公式テーマを、アプリが描くとおりに表示します。配色、コンポーネント、アイコン、スプラッシュを確認できます。アプリのテーマストアからインストールするか、パッケージをダウンロードしてください。',
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
      'アプリで 設定 → 外観 → テーマストア を開き、{name} を選びます。パッケージをダウンロードして テーマをインストール → ファイル を選ぶこともできます。',
    base: '通常',
    hovered: 'ホバー',
    pressed: '押下',
    disabled: '無効',
    loadFailed: 'このテーマのプレビューを読み込めませんでした。',
    retry: '再試行',
    previewNote:
      'プレビューで正確なのはテーマのアイコンと配色のみです。そのほかの画面は参考用です。',
    iconPacks: 'アイコンパック',
    iconPacksSubtitle:
      'テーマとは別に選び、使用中のテーマの上に表示するアイコンです。アプリの 設定 → 外観 → テーマストア → アイコンパック からインストールできます。',
  },
  plugins: {
    title: 'プラグイン。',
    subtitle: 'ServerBox の公式プラグイン。アプリのプラグインストアからインストールします。',
    empty: '公式プラグインはまだありません。',
    download: 'ダウンロード',
  },
  download: {
    title: 'すべてのプラットフォーム、すべての配布元。',
    subtitle:
      'デバイスに合った信頼できる配布元を選んでください。iOS 版は App Store から入手できます。macOS の App Store 版は Apple シリコンにのみ対応しており、Intel Mac では GitHub Releases または Homebrew からインストールできます。Android、Linux、Windows 向けには直接ダウンロードも用意されています。',
    copied: 'インストールコマンドをコピーしました',
    copyPrompt: 'このインストールコマンドをコピーしてください:',
    note:
      '信頼できる配布元からのみダウンロードしてください。サーバー側の通知、ウィジェット、companion 監視には、サーバーに ServerBoxMonitor を別途インストールしてください。',
  },
  cta: {
    title: 'ServerBox は AGPLv3 の無料オープンソースです。',
    subtitle:
      'App Store、GitHub Releases、F-Droid、または OpenAPK からインストールできます。',
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
