import type { Translation } from '../i18n-types.js'

const zhCN: Translation = {
  meta: {
    lang: 'zh-CN',
    title: 'ServerBox — 服务器监控、SSH 与运维工具',
    description:
      'ServerBox 提供状态图表、SSH 终端、SFTP、Docker、进程和 systemd 管理、S.M.A.R.T. 监控、推送通知、小组件及 watchOS 支持，可用于监控 Linux、Unix 和 Windows 服务器。',
  },
  nav: {
    features: '功能',
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
      'ServerBox 将状态图表、SSH 终端、SFTP、Docker、进程管理、systemd、S.M.A.R.T. 监控、推送通知、小组件和 watchOS 支持整合到一个 Flutter App 中。',
    primaryAction: '下载 ServerBox',
    secondaryAction: '查看功能',
  },
  screenshots: {
    label: '可交互的 ServerBox 截图',
    one: 'ServerBox 服务器概览截图',
    two: 'ServerBox 状态图表截图',
    three: 'ServerBox 终端截图',
    four: 'ServerBox 文件浏览器截图',
  },
  features: {
    title: '日常服务器维护所需的工具，集中在一个工作区。',
    subtitle: '功能紧凑实用，每个模块都对应实际的服务器维护场景。',
    list: {
      title: '服务器列表',
      description:
        '查看每台服务器的连接状态、CPU、内存、磁盘和网络数据。可按标签筛选，也可在地球视图中查看。',
    },
    charts: {
      title: '状态图表',
      description:
        '实时查看 CPU、内存、交换分区、磁盘、磁盘 I/O 和网络图表，以及传感器、GPU 和电池数据。也可切换到历史数据，或点击指标查看详情。',
    },
    terminal: {
      title: 'SSH 终端',
      description:
        '功能完整的终端。在手机上可使用虚拟按键操作，也可运行 htop、vim 等程序。支持直接连接、通过跳板机连接和使用 ProxyCommand。',
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
        '查看所有进程及其 CPU 和内存用量。可按需排序，按名称、用户或 PID 搜索，也可直接结束进程。',
    },
    services: {
      title: 'Systemd 服务',
      description:
        '失败的 systemd 单元显示在列表顶部。可一键重启单元或查看日志。',
    },
    users: {
      title: '用户与用户组',
      description:
        '查看系统账户及其登录 shell 和 sudo 权限。可添加或删除用户，也可添加、编辑或删除用户组。',
    },
    agent: {
      title: 'AI 助手',
      description:
        '使用 App 内置的助手管理服务器，并接入你选择的模型服务商、MCP server 和 skills。',
    },
    bench: {
      title: '基准测试',
      description:
        '运行 Yet Another Bench Script 测试服务器的磁盘、网络和 CPU，并保存结果。“更多”菜单还提供代码片段、远程桌面和虚拟化功能入口。',
    },
    virt: {
      title: '虚拟化',
      description:
        '管理 libvirt 和 Proxmox VE 上的虚拟机与容器。可启动或停止实例、调整 vCPU、内存和磁盘，以及打开控制台。',
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
      'ServerBox 将终端连接、文件传输、服务状态检查、硬件监控和设备原生通知整合到同一套工作流程中。',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux 与 Windows',
  },
  themes: {
    title: '换一身你喜欢的样子。',
    subtitle:
        '这里展示的官方主题也可在 App 内的主题商店中找到。打开“设置 → 外观 → 主题商店”即可安装；也可以下载主题包，再选择“安装主题 → 文件”。',
    empty:
      '暂时还没有官方主题。每款主题都是一个包含 manifest.toml 的目录，其中有浅色和深色配色、组件样式、图标、背景和启动画面。主题指南介绍了制作主题和提交到商店的方法。',
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
      '这里展示 ServerBox 的全部官方主题，呈现效果与 App 内一致，包括配色、组件、图标和启动画面。可在主题商店中安装，也可以下载主题包。',
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
    installSteps: '在 App 中打开“设置 → 外观 → 主题商店”，然后选择 {name}。也可以下载主题包，再选择“安装主题 → 文件”。',
    base: '默认',
    hovered: '悬停',
    pressed: '按下',
    disabled: '禁用',
    loadFailed: '无法加载这个主题的预览。',
    retry: '重试',
    previewNote:
      '预览只展示主题的图标和配色，其他界面仅供参考。',
    iconPacks: '图标包',
    iconPacksSubtitle:
      '图标包独立于主题选择，可与任何主题搭配使用。打开“设置 → 外观 → 主题商店 → 图标包”即可安装。',
  },
  plugins: {
    title: '扩展 ServerBox',
    subtitle: '安装 ServerBox 官方插件，进一步扩展应用功能。',
    empty: '暂时还没有官方插件。',
    download: '下载',
  },
  download: {
    title: '支持多个平台，提供多种下载渠道。',
    subtitle:
      '请选择可信的下载渠道。iOS 版可从 App Store 获取，也可从 GitHub Releases 下载未签名的 .ipa 文件并自行签名。macOS 版支持 Apple silicon 和 Intel，可通过 GitHub Releases 或 Homebrew 安装。Android、Linux 和 Windows 版可直接下载安装包。',
    copied: '已复制安装命令',
    copyPrompt: '复制此安装命令：',
    note:
      '请只从信任的来源下载安装包。如需服务器端推送、小组件数据和独立监控，请在服务器上另行安装 ServerBoxMonitor。',
  },
  cta: {
    title: 'ServerBox 是基于 AGPLv3 的免费开源软件。',
    subtitle:
      '可通过 App Store、GitHub Releases、F-Droid 或 OpenAPK 获取。',
    appStoreAction: '打开 App Store',
    githubAction: '从 GitHub Releases 下载',
  },
  footer: {
    features: '功能',
    capabilities: '能力',
    releases: '版本发布',
  },
}

export default zhCN
