import type { Translation } from '../i18n-types.js'

const zhCN: Translation = {
  meta: {
    lang: 'zh-CN',
    title: 'ServerBox — 服务器状态、SSH 与运维工具',
    description:
      'ServerBox 用状态图表、SSH 终端、SFTP、Docker、进程、systemd、S.M.A.R.T、推送、小组件和 watchOS 支持监控 Linux、Unix 与 Windows 服务器。',
  },
  nav: {
    features: '特性',
    capabilities: '能力',
    download: '下载',
    languageLabel: '语言',
  },
  hero: {
    titlePrefix: '服务器状态，',
    titleSuffix: '就在口袋里。',
    subtitle:
      'ServerBox 将图表、SSH 终端、SFTP、Docker、进程控制、systemd、S.M.A.R.T、推送提醒、小组件和 watchOS 支持整合到一个 Flutter 应用里。',
    primaryAction: '下载 ServerBox',
    secondaryAction: '查看特性',
  },
  screenshots: {
    label: '可交互的 ServerBox 截图',
    one: 'ServerBox 服务器概览截图',
    two: 'ServerBox 状态图表截图',
    three: 'ServerBox 终端截图',
    four: 'ServerBox 工具截图',
  },
  features: {
    title: '一个紧凑工作区，覆盖日常服务器维护。',
    subtitle: '能力密度高，没有装饰性填充；每个模块都对应真实维护工作流。',
    charts: {
      title: '状态图表',
      description:
        '通过高密度移动端图表跟踪 CPU、内存、传感器、GPU、网络、磁盘和主机健康状态。',
    },
    workspace: {
      title: '跨平台工作区',
      description:
        '在 iOS、Android、macOS、Linux 和 Windows 上使用同一个熟悉的 Flutter 界面。',
    },
    terminal: {
      title: 'SSH 终端与 SFTP',
      description:
        '从服务器卡片直接打开命令行和文件会话，底层基于 dartssh2 与 xterm.dart。',
    },
    native: {
      title: '设备原生能力',
      description:
        '生物认证、消息推送、桌面小组件和 watchOS 支持，让服务器上下文保持贴近。',
    },
    platforms: {
      title: 'Docker、进程、systemd',
      description:
        '无需离开监控流程，就能检查容器、进程和服务状态。',
    },
  },
  capabilities: {
    title: '所有工具，一个应用。',
    subtitle:
      'ServerBox 将终端访问、文件传输、服务检查、硬件健康和设备原生提醒放在同一个工作流中。',
    installIosPrompt: '# iOS 与 macOS',
    installReleasePrompt: '# Android、Linux 与 Windows',
  },
  download: {
    title: '所有平台，所有来源。',
    subtitle:
      '根据设备和信任模型选择下载渠道。iOS 与 macOS 使用 App Store；Android、Linux 和 Windows 也提供直接安装包。',
    copied: '已复制安装命令',
    copyPrompt: '复制此安装命令：',
    note:
      '请只从你信任的来源下载安装包。若需要服务器端推送、小组件和独立监控，请在服务器上单独安装 ServerBoxMonitor。',
  },
  cta: {
    title: 'ServerBox 是基于 AGPLv3 的免费开源软件。',
    subtitle:
      '可从 App Store、GitHub Releases、F-Droid、OpenAPK 或项目 CDN 安装。',
    appStoreAction: '打开 App Store',
    githubAction: '从 GitHub Releases 下载',
  },
  footer: {
    features: '特性',
    capabilities: '能力',
    releases: '版本发布',
  },
}

export default zhCN
