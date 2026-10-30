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
  features: {
    title: '一个紧凑工作区，覆盖日常服务器维护。',
    subtitle: '能力密度高，没有装饰性填充；每个模块都对应真实维护工作流。',
    list: {
      title: '服务器列表',
      description:
        '一览每台服务器的连接状态、CPU、内存、磁盘和网络数据。可按标签筛选，也可在地球视图中查看。',
    },
    charts: {
      title: '状态图表',
      description:
        '实时查看 CPU、内存、交换分区、磁盘、磁盘 I/O 和网络图表，以及传感器、GPU 和电池数据。可切换到历史数据，或点开指标查看详情。',
    },
    terminal: {
      title: 'SSH 终端',
      description:
        '功能完整的终端，手机上提供虚拟按键，可运行 htop、vim 等程序。支持直连、通过跳板机连接和使用 ProxyCommand。',
    },
    files: {
      title: 'SFTP 文件',
      description:
        '浏览、上传、下载文件，也可直接编辑。Markdown 文件会以排版后的预览形式打开。',
    },
    containers: {
      title: 'Docker 与 Podman',
      description:
        '按 Compose 项目分组显示容器及其 CPU、内存和网络用量。可启动、停止、重启或删除容器、查看日志，也可进入容器 shell；镜像和设置分别位于独立标签页。',
    },
    processes: {
      title: '进程',
      description:
        '所有进程及其 CPU 和内存，可按需排序，按名称、用户或 PID 搜索，并直接结束进程。',
    },
    services: {
      title: 'Systemd 服务',
      description:
        '失败的单元排在最前，其余在后。一键重启或查看日志。',
    },
    users: {
      title: '用户与用户组',
      description:
        '查看系统账户，并标出登录 shell 和 sudo 权限。可添加或删除用户，也可添加、编辑或删除用户组。',
    },
    agent: {
      title: 'AI 助手',
      description:
        '了解你所管理服务器的 App 内助手，可搭配你选择的模型提供商、MCP server 和 skills 使用。',
    },
    bench: {
      title: '基准测试',
      description:
        '运行 Yet Another Bench Script 测试服务器的磁盘、网络和 CPU，并保存结果。“更多”菜单还可打开代码片段、远程桌面和虚拟化功能。',
    },
    virt: {
      title: '虚拟化',
      description:
        '管理 libvirt 和 Proxmox VE 上的虚拟机与容器：启动、停止，调整 vCPU、内存和磁盘，打开控制台。',
    },
    themes: {
      title: '主题商店',
      description:
        '在 App 内安装官方主题，每款主题都有自己的配色、背景和启动画面；也可以自行制作主题。',
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
    iconPacks: '图标包',
    iconPacksSubtitle:
      '独立于主题选择的图标，显示在当前使用的任意主题上。在 App 中通过 设置 → 外观 → 主题商店 → 图标包 安装。',
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
      '请为你的设备选择可信的下载来源。iOS 版本可从 App Store 获取，也可从 GitHub Releases 下载未签名的 .ipa 自行签名。macOS 版本支持 Apple silicon 和 Intel，可通过 GitHub Releases 或 Homebrew 安装。Android、Linux 和 Windows 可直接下载安装包。',
    copied: '已复制安装命令',
    copyPrompt: '复制此安装命令：',
    note:
      '请只从你信任的来源下载安装包。若需要服务器端推送、小组件和独立监控，请在服务器上单独安装 ServerBoxMonitor。',
  },
  cta: {
    title: 'ServerBox 是基于 AGPLv3 的免费开源软件。',
    subtitle:
      '可从 App Store、GitHub Releases、F-Droid 或 OpenAPK 安装。',
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
