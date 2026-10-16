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
    monitor: 'Monitor',
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
  gallery: {
    title: 'すべての画面を、すべてのデバイスで。',
    subtitle:
      'iPhone・iPad・macOS の 31 枚のスクリーンショット。ページを軽く保つため、開くまで読み込みません。',
    count: '{count} 枚',
  },
  features: {
    title: '日常のサーバーメンテナンスに使える小さな作業場。',
    subtitle:
      '装飾を抑え、実際のメンテナンス作業に対応する機能だけを集めています。',
    charts: {
      title: '状態チャート',
      description:
        'CPU、メモリ、センサー、GPU、ネットワーク、ディスク、ホスト状態をモバイルチャートで確認できます。',
    },
    workspace: {
      title: 'クロスプラットフォーム',
      description:
        'iOS、Android、macOS、Linux、Windows で同じ Flutter インターフェースを使えます。',
    },
    terminal: {
      title: 'SSH ターミナルと SFTP',
      description:
        'サーバーカードからターミナルとファイルセッションを直接開けます。dartssh2 と xterm.dart を使用しています。',
    },
    native: {
      title: 'ネイティブ連携',
      description:
        '生体認証、通知、ホームウィジェット、watchOS により、サーバーの状況を近くに保てます。',
    },
    platforms: {
      title: 'Docker、プロセス、systemd',
      description:
        '監視の流れを離れずに、コンテナ、プロセス、サービスを確認できます。',
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
  monitor: {
    meta: {
      title: 'ServerBox Monitor — サーバーを見守るエージェント',
      description: 'ServerBox Monitor はサーバー上で動き、状態の履歴を記録し、スマートフォンに通知を送り、ウィジェットと Watch アプリを最新に保ち、Web パネルを提供します。',
    },
    nav: {
      why: 'エージェントを使う理由',
      panel: 'Web パネル',
      alerts: '通知',
      access: '権限',
      install: 'インストール',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: '7 秒ごとに計測。記録して、スマホに知らせる。',
      subtitle: 'サーバー上で動く小さな Rust 製エージェントです。状態の履歴を SQLite に保存し、通知を送り、ServerBox のウィジェットと Watch アプリを最新に保ち、Web パネルも提供します。アプリは SSH なしでつながります。',
      installLabel: 'systemd または OpenRC の Linux にインストール',
      installNote: 'root ではなく、あなた自身のアカウントで動きます。',
      copy: 'コピー',
      copied: 'コピーしました',
      guide: 'セットアップガイド',
      terminalLabel: 'インストールされ、計測を始めるエージェント',
      installed: 'systemctl --user サービスとしてインストール済み',
      listening: '0.0.0.0:3770 で待ち受け中',
      sampled: '計測',
      cadence: '7 秒ごと — interval_seconds の既定値',
      pushLabel: 'iPhone のロック画面に届いたエージェントの通知',
      widgetLabel: 'エージェントのデータを表示する ServerBox のホーム画面ウィジェット',
    },
    keywords: {
      history: 'SQLite の履歴',
      push: 'プッシュ通知',
      panel: 'Web パネル',
      roles: 'ロールと権限',
      docker: 'Docker',
    },
    why: {
      title: 'エージェントが SSH に加えるもの',
      subtitle: 'サーバーを見るだけなら SSH で十分です。エージェントは、あなたが見ていないあいだも見ています。',
      history: {
        title: 'アプリを開く前の履歴',
        description: 'エージェントが自分で計測して結果を残すので、眠っていた夜の様子もグラフに残ります。保存期間は自分で決められます。',
      },
      alerts: {
        title: 'スマホに届く通知',
        description: 'CPU、メモリ、スワップ、ディスク、ネットワーク、温度のルールを、iOS、Bark、ServerChan、または任意の Webhook に送ります。',
      },
      widgets: {
        title: 'いつも最新のウィジェットと Watch',
        description: 'ホーム画面ウィジェットと Watch アプリはエージェントから読み込むので、ServerBox を閉じていても更新されます。',
      },
      reach: {
        title: 'SSH を開けなくていい',
        description: 'アプリは HTTP でエージェントと通信します。SSH が届かない場所でも使え、同じサーバーで SSH と併用もできます。',
      },
    },
    panel: {
      title: 'すべてのエージェントに Web パネル',
      subtitle: 'エージェントはそれぞれ 3770 番ポートで自分のパネルを提供します。パネルを 1 か所に置いて、1 つのページから複数のエージェントにログインすることもできます。',
      dashboard: {
        title: 'リアルタイムのグラフと保存された履歴',
        description: 'CPU、メモリ、ディスク、ネットワーク、GPU、センサーをリアルタイムで、そしてエージェントが残した履歴まで — 自作コマンドの出力も並べて表示します。',
      },
      terminal: {
        title: 'ブラウザで使えるターミナルとファイル',
        description: 'タブを閉じても動き続け、戻ると続きから使えるターミナル。指定したディレクトリだけを見られるファイルブラウザ。',
      },
      machine: {
        title: 'マシンの中で動くもの',
        description: 'Docker や Podman のコンテナ、サービス、プロセス、cron、ファイアウォール、システムユーザー。操作はすべてエージェントが組み立てて検証し、パネルは依頼するだけです。',
      },
      reach: {
        title: 'サーバーの隣にあるもの',
        description: 'RDP と VNC のデスクトップ、Redfish 経由の BMC、Proxmox VE や libvirt の仮想マシンに、エージェントを通じて接続します。',
      },
    },
    alerts: {
      title: 'いつも見ている場所に届く通知',
      subtitle: 'ルールは 1 つの指標と 1 つのしきい値です。条件を満たすと、設定したすべてのチャンネルに届きます。',
      rule: 'config.toml のルール',
      push: 'iOS のプッシュ通知',
      webhook: 'チャットアプリへの Webhook',
      widget: 'ホーム画面ウィジェット',
    },
    access: {
      title: '各アカウントにできることは、あなたが決める',
      subtitle: '状態の閲覧はすべてのアカウントに開かれています。それ以外は付与するもので、取り消すこともできます。',
      roles: {
        title: 'ロールと権限',
        description: 'シェル、ファイル、ポート転送、仮想化は、管理者がロールに付与する権限です。取り消すと、それを使っていたものはすぐに閉じます。',
      },
      transport: {
        title: '閲覧以外には TLS が必要',
        description: 'コマンド、ファイル、中継には TLS か同じホストからの接続が必要です。内蔵の TLS、リバースプロキシ、トンネルのどれでも構いません。',
      },
      account: {
        title: 'あなたのアカウントで動く',
        description: 'インストーラーはエージェントをあなた自身のアカウントで動かします。エージェントが渡すシェルは root ではなく、そのアカウントのシェルです。',
      },
      audit: {
        title: 'すべてのアクセスを記録',
        description: '誰が、いつ、どこから、何を、どうなったか。パスワードと鍵は決して記録しません。',
      },
    },
    install: {
      title: 'インストール',
      subtitle: '新しいサーバーから、スマホで状態を見るまで 3 ステップ。',
      step1: {
        title: 'エージェントをインストール',
        description: 'インストーラーが systemd か OpenRC を選び、最新のリリースを取得します。--permissions read を付けると、権限を持たない管理者から始まります。',
      },
      step2: {
        title: 'サインイン',
        description: '初回起動時に admin アカウントがランダムなパスワードで作られ、データベースの隣の initial-admin-credentials.txt に保存されます。パスワードを変更してから、ファイルを削除してください:',
      },
      step3: {
        title: 'ServerBox に追加',
        description: 'アプリで、アドレスとアカウントを指定してサーバーを Monitor エージェントとして追加します。または 3770 番ポートのパネルを開きます。',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC（Alpine）',
        docker: 'Docker',
      },
      dockerNote: 'このリポジトリからビルドします。',
    },
    cta: {
      title: 'アプリと同じく、無料でオープンソース。',
      subtitle: 'エージェントは同じライセンスで ServerBox のリポジトリにあります。',
      app: 'ServerBox を入手',
      source: 'エージェントのソース',
    },
  },
}

export default ja
