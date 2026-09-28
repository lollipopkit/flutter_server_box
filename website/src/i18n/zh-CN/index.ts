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
    docs: '文档',
    themes: '主题',
    plugins: '插件',
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
    four: 'ServerBox 文件浏览器截图',
  },
  gallery: {
    title: '每个界面，每种设备。',
    subtitle:
      'iPhone、iPad 与 macOS 共 31 张截图，默认折叠，展开后才加载。',
    count: '{count} 张截图',
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
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux 与 Windows',
  },
  themes: {
    title: '换一身你喜欢的样子。',
    subtitle:
      'ServerBox 的官方主题，与应用内主题商店提供的一致。在应用中打开 设置 → 外观 → 主题商店 安装，或下载主题包后选择 安装主题 → 文件。',
    empty:
      '暂时还没有官方主题。一个主题就是一个带 manifest.toml 的目录：浅色和深色配色、组件样式、图标、背景和启动画面。指南介绍了如何制作主题以及如何上架商店。',
    note: '应用从商店安装主题包前，会逐一校验其 SHA-256。',
    authoring: '制作主题',
    download: '下载 .fsbt',
    source: '源码',
    light: '浅色',
    dark: '深色',
    search: '搜索主题',
    modeLabel: '模式',
    all: '全部',
    sortLabel: '排序',
    sortName: '名称',
    sortUpdated: '最近更新',
    noMatch: '没有匹配的主题。换个名称或模式试试。',
    storeTitle: '主题商店',
    storeSubtitle:
      'ServerBox 的全部官方主题，按应用的实际绘制方式呈现：配色、组件、图标和启动画面。可在应用内的主题商店安装，也可以下载主题包。',
    browse: '打开主题商店',
    back: '全部主题',
    details: '详情',
    icons: '图标',
    tabIcons: '标签页及其选中状态',
    navIcons: '符号',
    palette: '配色',
    components: '组件',
    splash: '启动画面',
    install: '安装',
    installSteps: '在应用中打开 设置 → 外观 → 主题商店，选择 {name}。也可以下载主题包，再选择 安装主题 → 文件。',
    base: '默认',
    hovered: '悬停',
    pressed: '按下',
    disabled: '禁用',
    loadFailed: '无法加载这个主题的预览。',
    retry: '重试',
    previewNote:
      '预览仅展示主题的图标和配色，其他界面仅作示意。',
  },
  plugins: {
    title: '插件。',
    subtitle: 'ServerBox 的官方插件，从应用内的插件商店安装。',
    empty: '暂时还没有官方插件。',
    download: '下载',
  },
  download: {
    title: '所有平台，所有来源。',
    subtitle:
      '请为你的设备选择可信的下载来源。iOS 版本可从 App Store 获取。macOS App Store 版本仅支持 Apple silicon；Intel Mac 用户可通过 GitHub Releases 或 Homebrew 安装。Android、Linux 和 Windows 也可直接下载安装包。',
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
