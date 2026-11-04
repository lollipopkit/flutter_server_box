import type { BaseTranslation } from '../i18n-types.js'

const en: BaseTranslation = {
  meta: {
    lang: 'en',
    title: 'ServerBox — Server monitoring, SSH, and operations in one app',
    description:
      'Monitor and manage Linux, Unix, and Windows servers with live charts, a touch-ready SSH terminal, SFTP, Docker, systemd, S.M.A.R.T., widgets, and AI-assisted operations.',
  },
  nav: {
    features: 'Features',
    capabilities: 'Capabilities',
    download: 'Download',
    docs: 'Docs',
    themes: 'Themes',
    os: 'ServerBox OS',
    beta: 'Beta',
    plugins: 'Plugins',
    languageLabel: 'Language',
  },
  hero: {
    titlePrefix: 'Every server,',
    titleSuffix: 'in your pocket.',
    subtitle:
      'Live telemetry, a touch-first SSH terminal, SFTP, containers, and AI-assisted ops—crafted into one fast, native workspace for mobile and desktop.',
    primaryAction: 'Download ServerBox',
    secondaryAction: 'Explore features',
  },
  screenshots: {
    label: 'Interactive ServerBox screenshots',
    one: 'ServerBox server overview screenshot',
    two: 'ServerBox status chart screenshot',
    three: 'ServerBox terminal screenshot',
    four: 'ServerBox file browser screenshot',
  },
  features: {
    title: 'Built for real-world ops.',
    subtitle:
      'Skip the laptop for routine checks and urgent fixes—every view is designed for fast, focused action.',
    list: {
      title: 'Server Overview',
      description:
        'Spot CPU, memory, disk, and network load across all nodes at a glance. Filter by tag or visualize nodes on an interactive 3D globe.',
    },
    charts: {
      title: 'Live Telemetry',
      description:
        'Real-time and historical charts for CPU, memory, swap, disk I/O, network, GPUs, sensors, and S.M.A.R.T. health.',
    },
    terminal: {
      title: 'SSH Terminal',
      description:
        'Built for touch with custom virtual keys for vim, tmux, and htop. Supports jump hosts, Agent forwarding, and ProxyCommand.',
    },
    files: {
      title: 'SFTP File Manager',
      description:
        'Browse, transfer, and edit remote configs in place with syntax highlighting and live Markdown previews.',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Track containers grouped by Compose project. Inspect live resource usage, stream logs, open a shell, or restart services in one tap.',
    },
    processes: {
      title: 'Process Inspector',
      description:
        'Sort by CPU or memory, filter by user, name, or PID, and terminate runaway processes instantly.',
    },
    services: {
      title: 'Systemd Services',
      description:
        'Failed units are automatically pinned to the top so you can inspect journal logs and restart services immediately.',
    },
    users: {
      title: 'Users & Groups',
      description:
        'Audit system accounts, login shells, and sudo privileges. Create or remove users and groups without memorizing flags.',
    },
    agent: {
      title: 'AI Ops Agent',
      description:
        'Delegate diagnostics and routine maintenance to an integrated AI assistant connected to your own LLM providers, MCP servers, and skills.',
    },
    bench: {
      title: 'One-Tap Benchmark',
      description:
        'Run YABS to benchmark disk, network, and CPU performance and archive results alongside snippets and remote desktop tools.',
    },
    virt: {
      title: 'Virtualization',
      description:
        'Control VMs and LXC containers on Proxmox VE and libvirt. Toggle power states, tune vCPU and memory, and open consoles.',
    },
    themes: {
      title: 'Theme Store',
      description:
        'Customize palettes, component styles, icons, and splash screens from the built-in store—or craft your own.',
    },
  },
  capabilities: {
    title: 'One native workflow.',
    subtitle:
      'No juggling separate SSH clients, SFTP tools, and monitoring dashboards.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, and Windows',
  },
  os: {
    metaTitle: 'ServerBox OS — The server companion for ServerBox',
    metaDescription:
      'ServerBox OS brings a browser desktop, 40+ one-click Docker apps, ZFS/RAID storage, AI Agent ops, alerts, and encrypted backups to your server.',
    heroTitle: 'ServerBox OS',
    tagline: 'Your server, in the browser and the app.',
    subtitle:
      'A single lightweight daemon that gives any Linux machine a full browser desktop, one-click self-hosted apps, and instant HTTPS sync with the ServerBox app—or boots as a complete OS.',
    installAction: 'Install on Linux',
    images: 'Download images',
    previewAction: 'Watch the tour',
    previewTitle: 'See it in action',
    previewSubtitle:
      'A quick look at the browser desktop, one-click apps, and AI Agent mode running on a live server.',
    previewPlay: 'Play the ServerBox OS tour',
    previewYoutube: 'Watch on YouTube',
    featuresTitle: 'Everything on the server side',
    featuresSubtitle: 'One binary on the host—accessible from any browser or directly from the ServerBox app.',
    desk: {
      title: 'Browser Desktop',
      description:
        'Open your server URL for a windowed workspace with live metrics, files, terminal, containers, processes, and services.',
    },
    apps: {
      title: 'One-Click App Store',
      description:
        'Deploy 40+ self-hosted stacks via Docker Compose—Immich, Jellyfin, Gitea, Home Assistant—plus Tailscale, reverse proxies, and local LLMs.',
    },
    storage: {
      title: 'Storage & NAS Sharing',
      description:
        'Partition and mount disks, build RAID arrays and ZFS pools, monitor S.M.A.R.T., and share folders over SMB and NFS.',
    },
    agent: {
      title: 'Autonomous Agent Mode',
      description:
        'Assign tasks to an AI agent that plans steps, asks before risky commands, gates sudo behind your approval, and talks to apps via MCP.',
    },
    alerts: {
      title: 'Multi-Channel Alerts',
      description:
        'Push CPU, memory, disk, and service alerts to the ServerBox app, Telegram, Discord, ntfy, Bark, ServerChan, email, or webhooks.',
    },
    backups: {
      title: 'Encrypted Backups',
      description:
        'Back up settings to WebDAV with age encryption, and schedule automated container volume snapshots to local or external disks.',
    },
    security: {
      title: 'Audited & Encrypted',
      description:
        'Single-account auth with HTTPS enforcement for mutations, encrypted credentials at rest, and full audit logs for sign-ins and root actions.',
    },
    app: {
      title: 'Seamless App Sync',
      description:
        'Connect from the ServerBox app over HTTPS alongside or instead of SSH for historical charts, push alerts, Agent tasks, and web apps.',
    },
    installTitle: 'Two ways to deploy',
    installSubtitle: 'Install as a service on your existing Linux distro, or boot the dedicated appliance image.',
    linuxTitle: 'On an existing Linux server',
    promptUser: '# systemd: user service under your own account',
    promptOpenrc: '# OpenRC (Alpine): registered by root, runs as your user',
    promptRoot: '# systemd or OpenRC: system-wide service as root',
    linuxNote:
      'Permissions match the account it runs under. Replace install with upgrade or uninstall anytime.',
    copy: 'Copy install command',
    imageTitle: 'Boot as a dedicated OS',
    stepWrite: 'Flash an image to USB (dd, Etcher, Ventoy) or attach it to a VM.',
    stepBoot:
      'Boot the machine—the console prints the web URL, TLS fingerprint, and initial password location.',
    stepInstall: 'Run sbm-install <disk> to install permanently to disk.',
    liveNote:
      'Before disk installation, sbOS runs in live RAM mode—changes reset on reboot.',
    note: 'ServerBox OS is free and open source under AGPLv3.',
    docs: 'Monitor docs',
    appAction: 'Get the app',
  },
  themes: {
    title: 'Make it yours.',
    subtitle:
      'Preview official themes live below. Install in one tap from Settings → Appearance → Theme Store, or import a .fsbt package.',
    empty:
      'No official themes yet. Check the theme authoring guide to build and submit your own.',
    note:
      'Every store package is verified against its SHA-256 checksum before installation.',
    authoring: 'Theme guide',
    download: 'Download .fsbt',
    source: 'Source',
    light: 'Light',
    dark: 'Dark',
    search: 'Search themes',
    modeLabel: 'Mode',
    all: 'All',
    sortLabel: 'Sort',
    sortName: 'Name',
    sortUpdated: 'Recently updated',
    noMatch: 'No matching themes. Try another keyword or mode.',
    storeTitle: 'Theme Store',
    storeSubtitle:
      'Explore official ServerBox themes and icon packs rendered live with their real palettes, components, and icons.',
    browse: 'Browse Theme Store',
    back: 'All themes',
    details: 'Details',
    icons: 'Icons',
    tabIcons: 'Tab bar & active states',
    navIcons: 'Navigation symbols',
    palette: 'Color Palette',
    components: 'Components',
    splash: 'Splash screen',
    install: 'Install',
    installSteps:
      'In ServerBox, go to Settings → Appearance → Theme Store and pick {name}, or download the .fsbt file and choose Install Theme → File.',
    base: 'Default',
    hovered: 'Hovered',
    pressed: 'Pressed',
    disabled: 'Disabled',
    loadFailed: 'Could not load theme preview.',
    retry: 'Retry',
    iconPacks: 'Icon Packs',
    iconPacksSubtitle:
      'Mix and match icon packs with any theme via Settings → Appearance → Theme Store → Icon Packs.',
  },
  plugins: {
    title: 'Extend ServerBox',
    subtitle:
      'Add new capabilities with official ServerBox plugins.',
    empty: 'No official plugins yet.',
    download: 'Download',
  },
  download: {
    title: 'Native on every platform.',
    subtitle:
      'Pick your platform and preferred package source below.',
    copied: 'Command copied',
    copyPrompt: 'Copy install command:',
    note:
      'For push notifications, home screen widgets, and historical charts without keeping SSH open, pair the app with ServerBox OS.',
  },
  cta: {
    title: 'Free & open source under AGPLv3.',
    subtitle:
      'Inspect the code, contribute on GitHub, or grab the latest release for your device.',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  footer: {
    features: 'Features',
    capabilities: 'Capabilities',
    releases: 'Releases',
  },
}

export default en
