import type { BaseTranslation } from '../i18n-types.js'

const en: BaseTranslation = {
  meta: {
    lang: 'en',
    title: 'ServerBox — Server monitoring, SSH, and operations in one app',
    description:
      'ServerBox helps monitor Linux, Unix, and Windows servers with status charts, an SSH terminal, SFTP, Docker, process and systemd management, S.M.A.R.T. monitoring, push notifications, widgets, and watchOS support.',
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
    titlePrefix: 'Server status,',
    titleSuffix: 'right in your pocket.',
    subtitle:
      'ServerBox brings status charts, an SSH terminal, SFTP, Docker, process management, systemd, S.M.A.R.T. monitoring, push notifications, widgets, and watchOS support together in one app.',
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
    title: 'The tools you need for everyday server maintenance, all in one workspace.',
    subtitle:
      'A practical set of focused tools, with every section built around a real server maintenance task.',
    list: {
      title: 'Server List',
      description:
        'See each server’s connection status, CPU, memory, disk and network at a glance. Filter by tag or find servers on the globe.',
    },
    charts: {
      title: 'Status Charts',
      description:
        'Live charts for CPU, memory, swap, disks, disk I/O and network, plus sensors, GPUs and batteries. Switch to historical data or open a metric for details.',
    },
    terminal: {
      title: 'SSH Terminal',
      description:
        'A full-featured terminal with virtual keys on phones, ready for htop, vim, and more. Connect directly, through a jump host, or with ProxyCommand.',
    },
    files: {
      title: 'Files over SFTP',
      description:
        'Browse, upload, download and edit files in place. Markdown files open in a rendered preview.',
    },
    containers: {
      title: 'Docker and Podman',
      description:
        'View containers grouped by Compose project, with CPU, memory and network usage. Start, stop, restart or remove containers, read their logs, or open a shell inside them. Images and settings have their own tabs.',
    },
    processes: {
      title: 'Processes',
      description:
        'View every process and its CPU and memory usage. Sort the list, search by name, user, or PID, and stop processes directly.',
    },
    services: {
      title: 'Systemd Services',
      description:
        'Failed systemd units appear at the top of the list. Restart a unit or view its logs with one tap.',
    },
    users: {
      title: 'Users and Groups',
      description:
        'View system accounts and their login shells and sudo access. Add or delete users, and add, edit, or delete groups.',
    },
    agent: {
      title: 'AI Agent',
      description:
        'An AI assistant built into the app to help manage your servers, connected to the model providers, MCP servers, and skills you choose.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Run Yet Another Bench Script to test a server’s disk, network, and CPU, then save the results. The More menu also links to snippets, remote desktop, and virtualization.',
    },
    virt: {
      title: 'Virtualization',
      description:
        'Manage virtual machines and containers on libvirt and Proxmox VE. Start or stop instances, adjust vCPUs, memory, and disks, and open their consoles.',
    },
    themes: {
      title: 'Theme Store',
      description:
        'Install official themes with their own colors, backgrounds and splash screens from inside the app. You can create your own themes too.',
    },
  },
  capabilities: {
    title: 'All the tools. One app.',
    subtitle:
      'ServerBox brings terminal connections, file transfers, service status checks, hardware monitoring, and native device notifications into one workflow.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, and Windows',
  },
  os: {
    metaTitle: 'ServerBox OS — the server side of ServerBox',
    metaDescription:
      'ServerBox OS is ServerBox Monitor on your server: a desktop in the browser with an App Store, storage, Agent mode, alerts and backups. Install it on Linux or boot it as the whole system.',
    heroTitle: 'ServerBox OS',
    tagline: 'The server side of ServerBox.',
    subtitle:
      'ServerBox Monitor runs on the server itself. The app connects to it, and its own desktop in the browser manages the machine without the app. Install it on a Linux server you already have, or boot it as the whole system.',
    installAction: 'Install on Linux',
    images: 'Download images',
    previewAction: 'Watch the tour',
    previewTitle: 'See it running',
    previewSubtitle:
      'ServerBox OS is in beta. A short tour on a real server: the desktop in the browser, its apps, and Agent mode at work.',
    previewPlay: 'Play the ServerBox OS tour',
    previewYoutube: 'Watch on YouTube',
    featuresTitle: 'What runs on the server',
    featuresSubtitle: 'One program on the machine, reached from the browser or from the app.',
    desk: {
      title: 'A desktop in the browser',
      description:
        "Open the server's address and every feature is an app in a window: status, files, terminal, containers, processes and services.",
    },
    apps: {
      title: 'App Store',
      description:
        'Deploy more than 40 self-hosted services with Docker Compose, such as Immich, Jellyfin, Gitea and Home Assistant, and add apps for Tailscale, reverse proxies, kernels and local AI models.',
    },
    storage: {
      title: 'Storage and sharing',
      description:
        'Partition, format and mount disks, build RAID arrays and ZFS pools, read S.M.A.R.T., and share folders over SMB and NFS.',
    },
    agent: {
      title: 'Agent mode',
      description:
        'Give an AI agent a task on the machine. It plans, asks before risky commands, uses sudo only when you allow it, and reaches deployed apps through MCP.',
    },
    alerts: {
      title: 'Alerts',
      description:
        'Rules on CPU, memory, disks and services notify the app, Telegram, Discord, ntfy, Bark, ServerChan, email or a webhook.',
    },
    backups: {
      title: 'Backups',
      description:
        'Its configuration backs up to WebDAV, encrypted with age; container data backs up on a schedule to a disk you choose.',
    },
    security: {
      title: 'One password',
      description:
        'One account signs in with its password. Anything beyond reading needs HTTPS, credentials are encrypted at rest, and sign-ins and root actions are audited.',
    },
    app: {
      title: 'With the app',
      description:
        'Add the server in ServerBox over HTTPS instead of SSH, or both: status and history, terminal, files, Agent mode tasks and web apps, from your phone.',
    },
    installTitle: 'Two ways to run it',
    installSubtitle: 'On a Linux server you already have, or as the whole system on a machine of its own.',
    linuxTitle: 'On a Linux server',
    promptUser: '# systemd: a user service, running as your own account',
    promptOpenrc: '# OpenRC (Alpine): root writes the service, which still runs as you',
    promptRoot: '# Either init system, as root',
    linuxNote:
      'The account it runs as is what it may do. Replace install with upgrade or uninstall to update or remove it.',
    copy: 'Copy install command',
    imageTitle: 'As the whole system',
    stepWrite: 'Download an image and write it to a USB stick (dd, Etcher, Ventoy), or attach it to a virtual machine.',
    stepBoot:
      'Boot it. The console shows the address to open, the certificate fingerprint to compare, and where the first password is.',
    stepInstall: 'sbm-install <disk> erases that disk and installs the system on it.',
    liveNote:
      'Until it is installed, it runs from memory: the database, images and app data are gone after a reboot.',
    note: 'ServerBox OS is open source under AGPLv3, like the app.',
    docs: 'Monitor docs',
    appAction: 'Get the app',
  },
  themes: {
    title: 'Make it yours.',
    subtitle:
      'The official themes shown here are also available in the app’s theme store. Install one from Settings → Appearance → Theme Store, or download a package and choose Install Theme → File.',
    empty:
      'No official themes yet. Each theme is a folder containing a manifest.toml, light and dark color schemes, component styles, icons, a background, and a splash screen. The theme guide explains how to create a theme and submit it to the store.',
    note:
      'The app checks every store package against its SHA-256 before installing it.',
    authoring: 'Make a theme',
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
    noMatch: 'No theme matches. Try another name or mode.',
    storeTitle: 'Theme store',
    storeSubtitle:
      'Browse all official ServerBox themes, shown as they appear in the app, including their colors, components, icons, and splash screens. Install a theme from the app or download its package.',
    browse: 'Open the theme store',
    back: 'All themes',
    details: 'Details',
    icons: 'Icons',
    tabIcons: 'Tabs, and when selected',
    navIcons: 'Symbols',
    palette: 'Palette',
    components: 'Components',
    splash: 'Splash screen',
    install: 'Install',
    installSteps:
      'In the app, open “Settings → Appearance → Theme Store” and select {name}. You can also download a theme package and choose “Install Theme → File”.',
    base: 'Default',
    hovered: 'Hovered',
    pressed: 'Pressed',
    disabled: 'Disabled',
    loadFailed: 'This theme\'s preview could not be loaded.',
    retry: 'Try again',
    iconPacks: 'Icon packs',
    iconPacksSubtitle:
      'Icon packs are selected separately from themes and work with any theme. Install one from “Settings → Appearance → Theme Store → Icon Packs”.',
  },
  plugins: {
    title: 'Extend ServerBox',
    subtitle:
      'Install official ServerBox plugins to add more features to the app.',
    empty: 'No official plugins yet.',
    download: 'Download',
  },
  download: {
    title: 'Multiple platforms, with several download options.',
    subtitle:
      'Choose a trusted download source. Get the iOS app from the App Store, or download an unsigned .ipa from GitHub Releases and sign it yourself. The macOS app supports Apple silicon and Intel and is available from GitHub Releases or Homebrew. Android, Linux, and Windows installers are available for direct download.',
    copied: 'Install command copied',
    copyPrompt: 'Copy this install command:',
    note:
      'Download packages only from sources you trust. To use server-side push notifications, widget data, and standalone monitoring, install ServerBox OS on your servers.',
  },
  cta: {
    title: 'ServerBox is free and open source under AGPLv3.',
    subtitle:
      'Get ServerBox from the App Store, GitHub Releases, F-Droid, or OpenAPK.',
    appStoreAction: 'Open App Store',
    githubAction: 'Download from GitHub Releases',
  },
  footer: {
    features: 'Features',
    capabilities: 'Capabilities',
    releases: 'Releases',
  },
}

export default en
