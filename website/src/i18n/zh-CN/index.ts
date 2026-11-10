import type { Translation } from '../i18n-types.js'

const zhCN: Translation = {
  meta: {
    lang: 'zh-CN',
    title: 'ServerBox — 装进口袋的全平台服务器监控与运维工作台',
    description:
      'ServerBox 集实时状态图表、触控 SSH 终端、SFTP、Docker、systemd、S.M.A.R.T.、桌面小组件与 AI 运维助手于一体，支持 Linux、Unix 与 Windows 服务器。',
  },
  nav: {
    features: '功能',
    capabilities: '能力',
    download: '下载',
    docs: '文档',
    themes: '主题',
    os: 'ServerBox OS',
    beta: 'Beta',
    plugins: '插件',
    otherApps: '更多',
    signIn: '登录',
    languageLabel: '语言',
  },
  hero: {
    titlePrefix: '所有服务器，',
    titleSuffix: '尽在掌中。',
    subtitle:
      '将实时状态监控、专为触控优化的 SSH 终端、SFTP、容器管理与 AI 运维助手，凝练进一个轻快原生的多端工作台。',
    primaryAction: '立即下载',
    secondaryAction: '探索功能',
  },
  screenshots: {
    label: '可交互的 ServerBox 截图',
    one: 'ServerBox 服务器概览截图',
    two: 'ServerBox 状态图表截图',
    three: 'ServerBox 终端截图',
    four: 'ServerBox 文件浏览器截图',
  },
  features: {
    title: '为真实运维场景打磨。',
    subtitle: '日常巡检与紧急排障无需苦找电脑，高频操作一触即达。',
    list: {
      title: '全局服务器总览',
      description:
        '一屏掌握所有节点的在线状态与 CPU、内存、磁盘、网络负载；支持按标签分组筛选，或在 3D 地球视图中直观定位节点。',
    },
    charts: {
      title: '实时与历史监控',
      description:
        '细腻呈现 CPU、内存、Swap、磁盘 I/O、网络吞吐及 GPU、传感器、S.M.A.R.T. 健康度，随时回溯历史趋势。',
    },
    terminal: {
      title: '触控友好的 SSH 终端',
      description:
        '内置专为手机优化的虚拟功能键，从容驾驭 vim、tmux 与 htop；原生支持跳板机与 ProxyCommand。',
    },
    files: {
      title: 'SFTP 文件直编',
      description:
        '在线浏览、上传下载或直接就地修改远程配置，支持代码高亮与 Markdown 实时渲染预览。',
    },
    containers: {
      title: 'Docker 与 Podman',
      description:
        '按 Compose 项目聚合容器，实时监控资源占用；一键启停容器、追踪日志流或直连容器内部 Shell。',
    },
    processes: {
      title: '进程诊断',
      description:
        '按 CPU 或内存占用即时排序，支持按进程名、用户或 PID 快速检索，一键终止异常占用的失控进程。',
    },
    services: {
      title: 'Systemd 服务巡检',
      description:
        '异常退出的 systemd 单元自动置顶警示，一键重启服务或调阅 journal 日志，快速恢复线上业务。',
    },
    users: {
      title: '账户与权限管理',
      description:
        '直观审计系统账户、登录 Shell 与 sudo 权限，免背繁琐命令即可增删用户与用户组。',
    },
    agent: {
      title: 'AI 运维助手',
      description:
        '接入你惯用的大模型服务商、MCP Server 与 Skills，让 AI 协助分析故障日志、编写脚本并执行日常维护。',
    },
    bench: {
      title: '一键性能跑分',
      description:
        '内置 YABS 脚本测试磁盘、网络与算力表现并留存归档；同时集成代码片段、远程桌面与虚拟化入口。',
    },
    virt: {
      title: '虚拟化管控',
      description:
        '集中管理 Proxmox VE 与 libvirt 上的虚拟机和容器，随时启停实例、弹性调整 vCPU/内存/磁盘或打开控制台。',
    },
    themes: {
      title: '个性化主题商店',
      description:
        '在应用内一键换装官方精调配色、图标、背景与启动画面，亦可通过 TOML 规范自由创作专属主题。',
    },
  },
  capabilities: {
    title: '全栈工具，融于一处。',
    subtitle:
      '告别在多个终端、SFTP 客户端与监控面板之间频繁切换。',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android、Linux 与 Windows',
  },
  os: {
    metaTitle: 'ServerBox OS（原 ServerBox Monitor）— 运行在服务器端的 Web 桌面与监控引擎',
    metaDescription:
      'ServerBox OS（原 ServerBox Monitor）将浏览器桌面、40+ 一键自托管应用、RAID/ZFS 存储管理、AI Agent 运维、多渠道告警与加密备份带入你的服务器。',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: '原 ServerBox Monitor',
    navPreview: '演示',
    navInstall: '安装',
    navApp: 'ServerBox 客户端',
    tagline: '是浏览器里的云端桌面，也是 App 的最强服务端。',
    subtitle:
      '只需在 Linux 服务器上运行一个轻量程序，即可获得完整的浏览器窗口化桌面、40+ 一键自托管应用与 AI 运维模式，并通过 HTTPS 与 ServerBox 客户端无缝联动；也可直接作为独立系统镜像启动。',
    monitorNote:
      'ServerBox OS 即全面升级后的 ServerBox Monitor（server_box_monitor）。已安装旧版 Monitor 的服务器可使用同一条脚本原位升级，继续为客户端提供离线推送、桌面小组件、Apple Watch 与历史图表支持。',
    exploreAction: '了解 ServerBox OS',
    installAction: '在 Linux 上安装',
    images: '下载系统镜像',
    previewAction: '观看实机演示',
    previewTitle: '实机运行预览',
    previewSubtitle: '真实服务器实录：在浏览器中使用多窗口桌面、一键部署应用，以及让 AI Agent 自主执行运维任务。',
    previewPlay: '播放 ServerBox OS 演示',
    previewYoutube: '在 YouTube 上观看',
    featuresTitle: '服务端全能底座',
    featuresSubtitle: '单一二进制驻留主机，无论打开浏览器还是拿起手机都能即刻接管。',
    desk: {
      title: '浏览器窗口化桌面',
      description: '访问服务器地址即刻进入多窗口 Web 桌面，状态监控、文件、终端、容器、进程与服务各自独立成窗。',
    },
    apps: {
      title: '一键自托管应用商店',
      description:
        '基于 Docker Compose 一键部署 Immich、Jellyfin、Gitea、Home Assistant 等 40+ 热门服务，并支持 Tailscale、反向代理、内核管理与本地大模型。',
    },
    storage: {
      title: '存储池与 NAS 共享',
      description: '可视化完成磁盘分区、格式化与挂载，组建 RAID 阵列与 ZFS 存储池，监控 S.M.A.R.T. 并配置 SMB / NFS 局域网共享。',
    },
    agent: {
      title: '自主 AI Agent 模式',
      description: '向驻留本机的 AI 下达运维目标：自动规划步骤、高风险命令提前请示、按需受控提权 sudo，并通过 MCP 联动已部署应用。',
    },
    alerts: {
      title: '多渠道智能告警',
      description: '自定义 CPU、内存、磁盘与服务存活规则，异常时实时推送至 App、Telegram、Discord、ntfy、Bark、Server 酱、邮件或 Webhook。',
    },
    backups: {
      title: '加密备份与快照',
      description: '系统配置经 age 加密后自动同步至 WebDAV；容器数据卷支持按计划定时备份至指定磁盘。',
    },
    security: {
      title: '精简认证与全程审计',
      description: '单账户口令通行，一切写操作强制 HTTPS，凭据落盘加密，每次登录与 root 提权均留存完整审计日志。',
    },
    app: {
      title: '移动端原生联动',
      description: '在 ServerBox App 中以 HTTPS 接入服务器，免开持久 SSH 即可获取历史图表、原生推送、桌面小组件与 Agent 任务协同。',
    },
    installTitle: '两种部署方式',
    installSubtitle: '一行命令安装至现有 Linux 发行版，或使用专用镜像直接引导整机系统。',
    linuxTitle: '安装到现有 Linux 服务器',
    promptUser: '# systemd：以当前用户权限运行服务',
    promptOpenrc: '# OpenRC（Alpine）：由 root 注册服务，仍以当前用户身份运行',
    promptRoot: '# 任意 init 系统：以 root 权限全局运行',
    linuxNote: '服务运行所用的账户决定了其操作权限。将命令末尾的 install 替换为 upgrade 或 uninstall 即可升级或卸载。',
    copy: '复制安装命令',
    imageTitle: '作为独立操作系统启动',
    stepWrite: '下载镜像并写入 U 盘（dd、Etcher、Ventoy），或直接挂载至虚拟机。',
    stepBoot: '引导启动后，终端会打印 Web 访问地址、TLS 证书指纹及初始密码位置。',
    stepInstall: '执行 sbm-install <磁盘> 即可将系统永久写入目标磁盘。',
    liveNote: '写入磁盘前系统运行于内存 Live 模式，重启后数据会还原。',
    note: 'ServerBox OS 与客户端同样遵循 AGPLv3 协议免费开源。',
    docs: 'Monitor 文档',
    appAction: '下载客户端',
  },
  themes: {
    title: '换一身你喜欢的风格。',
    subtitle:
      '下方可直接实时预览官方主题。在 App 内打开“设置 → 外观 → 主题商店”即可一键应用，也支持导入 .fsbt 主题包。',
    empty:
      '暂无官方主题。参考主题制作指南即可快速打造并提交你的专属主题。',
    note: 'App 在安装任何商店主题包前，均会自动校验 SHA-256 签名。',
    authoring: '制作指南',
    download: '下载 .fsbt',
    source: '源码',
    light: '浅色',
    dark: '深色',
    search: '搜索主题或图标包',
    modeLabel: '模式',
    all: '全部',
    sortLabel: '排序',
    sortName: '按名称',
    sortUpdated: '最近更新',
    noMatch: '没有找到匹配的主题，换个关键词或模式试试。',
    storeTitle: '主题商店',
    storeSubtitle:
      '实时还原全部官方主题与图标包在 App 内的真实渲染效果，涵盖配色方案、组件状态、图标与启动画面。',
    browse: '浏览主题商店',
    back: '返回全部主题',
    details: '查看详情',
    icons: '图标',
    tabIcons: '底部标签页与选中态',
    navIcons: '导航与功能图标',
    palette: '色彩方案',
    components: '组件状态',
    splash: '启动画面',
    install: '安装方式',
    installSteps: '在 App 中打开“设置 → 外观 → 主题商店”选择 {name} 即可安装；也可下载 .fsbt 文件后通过“安装主题 → 文件”导入。',
    base: '默认',
    hovered: '悬停',
    pressed: '按下',
    disabled: '禁用',
    loadFailed: '无法加载该主题的预览数据。',
    retry: '重试',
    iconPacks: '图标包',
    iconPacksSubtitle:
      '图标包独立于主题，可与任意配色自由混搭。在“设置 → 外观 → 主题商店 → 图标包”中即可一键启用。',
  },
  plugins: {
    title: '扩展 ServerBox',
    subtitle: '安装官方插件，按需解锁更多运维能力。',
    empty: '暂无官方插件。',
    download: '下载',
  },
  download: {
    title: '全平台原生支持。',
    subtitle:
      '选择你的操作系统与习惯的发行渠道。',
    copied: '已复制安装命令',
    copyPrompt: '复制此安装命令：',
    note:
      '提示：搭配服务端 ServerBox OS 使用，可解锁离线推送通知、桌面小组件与历史监控图表。',
  },
  cta: {
    title: '基于 AGPLv3 免费开源。',
    subtitle:
      '代码完全透明，欢迎在 GitHub 参与共建，或立即下载体验。',
    appStoreAction: 'App Store 下载',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: '支持 LGBTQ+',
    title: '多元与包容，与骄傲同行。',
    description:
      'ServerBox 坚定支持 LGBTQ+ 群体。内置主题商店官方提供 Pride 主题，包含六色彩虹（Rainbow）、跨性别（Trans）与非二元（Nonbinary）三款旗帜变体。',
    rainbow: '六色彩虹',
    trans: '跨性别',
    nonbinary: '非二元',
  },
  otherApps: {
    title: '更多服务与应用。',
    subtitle: '同样秉持轻快体验、克制设计与实用主义的配套云服务及原生客户端。',
    servicesHeading: '服务',
    appsHeading: 'Apps',
    llmapi: {
      title: 'LLM API',
      description:
        '聚合主流前沿大模型的统一 API 网关，可直接接入 ServerBox AI 运维助手、LLMBox 或你的开发工具。',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        '轻量可靠的网站、接口与服务器在线率监控服务，支持公开状态页与掉线即时通知。',
    },
    llmbox: {
      title: 'LLMBox',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        '轻快原生的 OpenAI 及兼容大模型 API 第三方客户端，支持自定义接口、工具调用与本地优先的对话存储。',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        '基于 macOS 原生 File Provider，无需内核扩展即可将 SFTP、S3、WebDAV 等远程存储直接挂载进访达（Finder）。',
      action: 'mfuse.lollipopkit.com',
    },
  },
  footer: {
    features: '功能',
    capabilities: '能力',
    releases: '版本发布',
  },
}

export default zhCN
