import type { BaseTranslation } from '../i18n-types.js'

const en: BaseTranslation = {
  meta: {
    lang: 'en',
    title: 'ServerBox — Server status, SSH, and operations in one Flutter app',
    description:
      'ServerBox monitors Linux, Unix, and Windows servers with status charts, SSH terminal, SFTP, Docker, process, systemd, S.M.A.R.T, push, widgets, and watchOS support.',
  },
  nav: {
    features: 'Features',
    capabilities: 'Capabilities',
    download: 'Download',
    docs: 'Docs',
    themes: 'Themes',
    plugins: 'Plugins',
    languageLabel: 'Language',
  },
  hero: {
    titlePrefix: 'Server status,',
    titleSuffix: 'right in your pocket.',
    subtitle:
      'ServerBox brings charts, SSH terminal, SFTP, Docker, process control, systemd, S.M.A.R.T, push alerts, widgets, and watchOS support into one Flutter app.',
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
    title: 'One compact workspace for everyday server maintenance.',
    subtitle:
      'A focused operational surface with no decorative filler — every block maps to a real maintenance workflow.',
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
        'A full terminal with virtual keys on phones, ready for htop, vim and more. Connect directly, through a jump host or with a ProxyCommand.',
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
        'Every process with its CPU and memory, sorted as you like and searchable by name, user or PID. Stop one from the list.',
    },
    services: {
      title: 'Systemd Services',
      description:
        'Failed units first, then everything else. Restart a unit or read its logs in one tap.',
    },
    users: {
      title: 'Users and Groups',
      description:
        'View system accounts with login shells and sudo access highlighted. Add or delete users, and add, edit or delete groups.',
    },
    agent: {
      title: 'AI Agent',
      description:
        'An assistant inside the app that knows your servers, using the model providers, MCP servers and skills you choose.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Run Yet Another Bench Script to test a server’s disk, network and CPU, then keep the results. The More menu also opens snippets, remote desktop and virtualization.',
    },
    virt: {
      title: 'Virtualization',
      description:
        'Virtual machines and containers on libvirt and Proxmox VE: start and stop them, change vCPUs, memory and disks, and open their consoles.',
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
      'ServerBox keeps terminal access, file transfer, service checks, hardware health, and device-native alerts in the same workflow.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, and Windows',
  },
  themes: {
    title: 'Make it yours.',
    subtitle:
      'Official themes for ServerBox, the same ones the app\'s theme store offers. Install them in the app from Settings → Appearance → Theme store, or download a package and choose Install theme → File.',
    empty:
      'No official themes yet. A theme is a folder with a manifest.toml: colors for light and dark, component styles, icons, a background and a splash. The guide covers making one and getting it into the store.',
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
      'Every official ServerBox theme, drawn the way the app draws it: its colors, components, icons and splash. Install from the app\'s theme store or download the package.',
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
      'In the app, open Settings → Appearance → Theme store and pick {name}. Or download the package and choose Install theme → File.',
    base: 'Default',
    hovered: 'Hovered',
    pressed: 'Pressed',
    disabled: 'Disabled',
    loadFailed: 'This theme\'s preview could not be loaded.',
    retry: 'Try again',
    previewNote:
      'Previews show the theme\'s icons and colors; the rest of the interface is illustrative.',
    iconPacks: 'Icon packs',
    iconPacksSubtitle:
      'Icons chosen apart from the theme and drawn over whichever one is in use. Install them in the app from Settings → Appearance → Theme store → Icon packs.',
  },
  plugins: {
    title: 'Plugins.',
    subtitle:
      'Official plugins for ServerBox, installed from the app\'s plugin store.',
    empty: 'No official plugins yet.',
    download: 'Download',
  },
  download: {
    title: 'Every platform, every source.',
    subtitle:
      'Choose a trusted source for your device. iOS comes from the App Store, or as an unsigned .ipa from GitHub Releases that you sign yourself. macOS builds for Apple silicon and Intel are on GitHub Releases and Homebrew. Android, Linux and Windows have direct downloads.',
    copied: 'Install command copied',
    copyPrompt: 'Copy this install command:',
    note:
      'Only download packages from a source you trust. For server-side push, widgets, and companion monitoring, install ServerBoxMonitor separately on your servers.',
  },
  cta: {
    title: 'ServerBox is free and open source under AGPLv3.',
    subtitle:
      'Install from the App Store, GitHub Releases, F-Droid or OpenAPK. Only download packages from sources you trust.',
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
