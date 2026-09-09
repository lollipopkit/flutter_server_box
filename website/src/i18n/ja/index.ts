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
      'App Store、GitHub Releases、F-Droid、OpenAPK、またはプロジェクト CDN からインストールできます。',
    appStoreAction: 'App Store を開く',
    githubAction: 'GitHub Releases からダウンロード',
  },
  plugins: {
    metaTitle: 'ServerBox プラグイン — 次のリリースを待たずに拡張する',
    metaDescription:
      'プラグインは ServerBox にページ、カード、ステータス項目を追加します。それぞれサンドボックスで動く小さなモジュールで、必要な権限を宣言し、アプリはダウンロードしたパッケージを毎回検証します。',
    title: '次のリリースを待たずに拡張する。',
    subtitle:
      'プラグインはページ、カード、ホームタブ、追加のステータス項目を加えます。小さなモジュールがサンドボックスで動き、マニフェストで求めてあなたが許可したことだけができます。',
    how: {
      sandbox: {
        title: 'サンドボックスで動く',
        description:
          'プラグインは隔離されたランタイム上の JavaScript です。ファイルシステムもネットワークも自前のサーバー接続も持たず、必要なことはすべてアプリに依頼します。',
      },
      permissions: {
        title: '先に許可を求める',
        description:
          'マニフェストに必要なもの — コマンドの実行、特定のホストへの接続、サーバー一覧の参照 — が書かれ、インストール時に許可するのはその一覧です。許可されていない呼び出しはその場で失敗します。',
      },
      anyRepo: {
        title: 'どのリポジトリでも、バイト列を検証',
        description:
          'HTTPS のリポジトリアドレスであればどこからでもインストールでき（最新のツリーを一度の要求で取得します）、各パッケージをプラグインファイルが示したチェックサムで検証します。チェックサムのないパッケージは、明示的に許可しない限り拒否されます。',
      },
    },
    listTitle: '公式リポジトリのプラグイン',
    listSubtitle:
      '{count} 個のプラグイン。ソースはこのリポジトリにあり、リリースはアプリとは別に行われます。',
    asks: '要求する権限',
    asksNothing: 'なし',
    appearsIn: '表示される場所',
    languages: '言語',
    source: 'ソース',
    install: {
      title: 'インストール',
      stepOne: 'アプリで 設定 → プラグイン → プラグインストア を開きます。',
      stepTwo:
        'プラグインを選んでインストールを押します。公式リポジトリは最初から登録されています。',
      stepThree:
        '要求する権限を読んで許可します。何かを実行する前に、アプリはリポジトリのチェックサムでダウンロードを検証します。',
      address: '公式リポジトリを削除して戻したいときのアドレス:',
      copy: 'アドレスをコピー',
    },
    write: {
      title: '自分で書く',
      description:
        'プラグインは TypeScript か JavaScript の ES モジュール 1 つで、bun test でモックホストに対してテストできます — アプリもビルド手順も要りません。デスクトップ版はディレクトリを直接指定できるので、編集して再起動するだけで反映されます。',
      sdk: 'SDK',
      examples: 'サンプルプラグイン',
      repository: '公式リポジトリ',
    },
    home: 'ホーム',
  },
  footer: {
    features: '機能',
    capabilities: 'ツール',
    releases: 'リリース',
  },
}

export default ja
