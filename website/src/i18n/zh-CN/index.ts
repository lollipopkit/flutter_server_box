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
  plugins: {
    metaTitle: 'ServerBox 插件 —— 不必等新版本就能扩展',
    metaDescription:
      '插件为 ServerBox 增加页面、卡片和状态读数。每个插件都是运行在沙箱里的小模块，声明它需要的权限，而应用会校验下载到的每一个包。',
    title: '不必等新版本，就能扩展应用。',
    subtitle:
      '一个插件可以增加一个页面、一张卡片、一个首页标签，或额外的状态读数。它是一个很小的模块，运行在沙箱里，只能做它在 manifest 里声明、并且你同意过的事。',
    how: {
      sandbox: {
        title: '运行在沙箱里',
        description:
          '插件是运行在隔离运行时里的 JavaScript：没有文件系统、没有网络，也没有属于它自己的服务器连接。它做的每一件事，都是请求应用去做。',
      },
      permissions: {
        title: '先申请，再动手',
        description:
          'manifest 里写明它需要什么 —— 执行命令、访问某个地址、看到你的服务器列表 —— 安装时你同意的就是这份清单。没被授予的调用会当场失败。',
      },
      anyRepo: {
        title: '任意仓库，逐字节校验',
        description:
          '应用可以从任何 HTTPS 的仓库地址安装 —— 一次请求取回它最新的整棵树 —— 并按插件文件给出的 checksum 校验每个包。没有 checksum 的包默认被拒绝，除非你明确同意。',
      },
    },
    listTitle: '官方仓库里的插件',
    listSubtitle: '{count} 个插件，源码在本仓库，发布节奏与应用分开。',
    asks: '申请权限',
    asksNothing: '无',
    appearsIn: '出现在',
    languages: '语言',
    source: '源码',
    install: {
      title: '怎么安装',
      stepOne: '在应用里打开 设置 → 插件 → 插件商店。',
      stepTwo: '选一个插件按安装。官方仓库已经在列表里。',
      stepThree:
        '看清它申请的权限再同意。运行任何东西之前，应用会先用仓库给出的 checksum 校验下载内容。',
      address: '如果你删掉了官方仓库，想加回来：',
      copy: '复制地址',
    },
    write: {
      title: '怎么写一个',
      description:
        '一个插件就是一个 TypeScript 或 JavaScript 的 ES module，用 bun test 对着 mock 宿主测试 —— 不需要应用，也不需要构建步骤。桌面端可以直接指向插件目录，改完重启就是整个开发循环。',
      sdk: 'SDK',
      examples: '示例插件',
      repository: '官方仓库',
    },
    home: '首页',
  },
  footer: {
    features: '特性',
    capabilities: '能力',
    releases: '版本发布',
  },
}

export default zhCN
