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
    four: 'ServerBox ツールのスクリーンショット',
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
    items: {
      statusChart: '状態チャート',
      sshTerminal: 'SSH ターミナル',
      sftp: 'SFTP',
      docker: 'Docker',
      process: 'プロセス',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: 'センサー',
      push: '通知',
      homeWidget: 'ホームウィジェット',
      watchos: 'watchOS',
    },
  },
  download: {
    title: 'すべてのプラットフォーム、すべての配布元。',
    subtitle:
      'デバイスと信頼できる配布元に合わせて選択できます。iOS は App Store、macOS は App Store または Homebrew、Android、Linux、Windows は直接パッケージも利用できます。',
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
  footer: {
    features: '機能',
    capabilities: 'ツール',
    releases: 'リリース',
  },
}

export default ja
