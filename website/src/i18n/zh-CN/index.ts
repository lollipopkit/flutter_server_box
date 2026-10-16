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
    monitor: 'Monitor',
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
      '可从 App Store、GitHub Releases、F-Droid 或 OpenAPK 安装。',
    appStoreAction: '打开 App Store',
    githubAction: '从 GitHub Releases 下载',
  },
  footer: {
    features: '特性',
    capabilities: '能力',
    releases: '版本发布',
  },
  monitor: {
    meta: {
      title: 'ServerBox Monitor — 替你守着服务器的 agent',
      description: 'ServerBox Monitor 运行在你的服务器上：记录状态历史，把告警推送到手机，让小组件和 Watch 应用保持最新，并提供 Web 面板。',
    },
    nav: {
      why: '为什么用 agent',
      panel: 'Web 面板',
      alerts: '告警',
      access: '权限',
      install: '安装',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: '每 7 秒采样一次。记下来。告诉你的手机。',
      subtitle: '一个运行在服务器上的小型 Rust agent。它把状态历史存进 SQLite，发送告警，让 ServerBox 的小组件和 Watch 应用保持最新，还自带 Web 面板 —— App 连接它不需要 SSH。',
      installLabel: '在使用 systemd 或 OpenRC 的 Linux 上安装',
      installNote: '它以你自己的账号运行，而不是 root。',
      copy: '复制',
      copied: '已复制',
      guide: '配置指南',
      terminalLabel: '正在安装、随后开始采样的 agent',
      installed: '已安装为 systemctl --user 服务',
      listening: '正在监听 0.0.0.0:3770',
      sampled: '已采样',
      cadence: '每 7 秒 —— 即 interval_seconds 的默认值',
      pushLabel: 'iPhone 锁屏上来自 agent 的告警',
      widgetLabel: '由 agent 提供数据的 ServerBox 桌面小组件',
    },
    keywords: {
      history: 'SQLite 历史',
      push: '推送告警',
      panel: 'Web 面板',
      roles: '角色与授权',
      docker: 'Docker',
    },
    why: {
      title: 'agent 在 SSH 之外多了什么',
      subtitle: '查看一台服务器，SSH 就够了。agent 在你不看的时候继续看着。',
      history: {
        title: '打开 App 之前的历史',
        description: 'agent 自己采样并保存结果，所以图表能看到你睡着时的那一夜。保留多久由你决定。',
      },
      alerts: {
        title: '告警直达手机',
        description: '针对 CPU、内存、swap、磁盘、网络和温度的规则，推送到 iOS、Bark、Server 酱或任意 webhook。',
      },
      widgets: {
        title: '一直最新的小组件和 Watch',
        description: '桌面小组件和 Watch 应用直接读取 agent，ServerBox 关着也会更新。',
      },
      reach: {
        title: '不用开放 SSH',
        description: 'App 通过 HTTP 和 agent 通信。SSH 连不上的地方可以用它，也可以和 SSH 一起用在同一台服务器上。',
      },
    },
    panel: {
      title: '每个 agent 都自带 Web 面板',
      subtitle: '每个 agent 都在 3770 端口提供自己的面板。也可以只部署一份面板，在同一个页面里登录多个 agent。',
      dashboard: {
        title: '实时图表和保存下来的历史',
        description: 'CPU、内存、磁盘、网络、GPU 和传感器，既有实时数据，也能回看 agent 保存的历史 —— 旁边还有你自定义命令的输出。',
      },
      terminal: {
        title: '浏览器里的终端和文件',
        description: '标签页关掉后终端仍在运行，回来时接着之前的位置；文件浏览只限于你指定的目录。',
      },
      machine: {
        title: '机器上会变的那些部分',
        description: 'Docker 或 Podman 上的容器、服务、进程、cron、防火墙和系统用户。每个操作都由 agent 构建并检查，面板只负责发起。',
      },
      reach: {
        title: '服务器旁边的东西',
        description: '通过 agent 访问 RDP 和 VNC 桌面、基于 Redfish 的 BMC，以及 Proxmox VE 或 libvirt 上的虚拟机。',
      },
    },
    alerts: {
      title: '告警出现在你本来就会看的地方',
      subtitle: '一条规则就是一个指标加一个阈值。触发时，你配置的每个渠道都会收到。',
      rule: 'config.toml 里的一条规则',
      push: 'iOS 推送',
      webhook: '推送到聊天应用的 webhook',
      widget: '桌面小组件',
    },
    access: {
      title: '每个账号能做什么，由你决定',
      subtitle: '查看状态对所有账号开放。其余的都需要授予，也随时可以收回。',
      roles: {
        title: '角色与授权',
        description: 'shell、文件、端口转发和虚拟化都是管理员授予角色的权限。收回一项，用到它的东西会立即关闭。',
      },
      transport: {
        title: '超出查看范围就需要 TLS',
        description: '命令、文件和转发需要 TLS，或来自同一台主机的请求。内置 TLS、反向代理或隧道都可以。',
      },
      account: {
        title: '以你的身份运行',
        description: '安装脚本让 agent 以你自己的账号运行，所以它给出的 shell 是这个账号的 shell，不是 root 的。',
      },
      audit: {
        title: '每次访问都有记录',
        description: '谁、何时、从哪里、做了什么、结果如何。密码和密钥永远不会被记录。',
      },
    },
    install: {
      title: '安装',
      subtitle: '从一台新服务器到手机上看到它的状态，只需三步。',
      step1: {
        title: '安装 agent',
        description: '安装脚本会自动选择 systemd 或 OpenRC，并下载最新版本。加上 --permissions read，管理员账号一开始就不带任何授权。',
      },
      step2: {
        title: '登录',
        description: '首次启动会创建 admin 账号并生成随机密码，保存在数据库旁的 initial-admin-credentials.txt 里。修改密码后删除这个文件：',
      },
      step3: {
        title: '添加到 ServerBox',
        description: '在 App 里把这台服务器添加为 Monitor agent，填写地址和账号。也可以直接打开 3770 端口上的面板。',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC（Alpine）',
        docker: 'Docker',
      },
      dockerNote: '从本仓库构建。',
    },
    cta: {
      title: '和 App 一样，免费且开源。',
      subtitle: 'agent 位于 ServerBox 仓库中，使用相同的许可证。',
      app: '获取 ServerBox',
      source: 'agent 源码',
    },
  },
}

export default zhCN
