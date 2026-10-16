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
    monitor: 'Monitor',
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
  gallery: {
    title: 'Every screen, on every device.',
    subtitle:
      '31 screenshots across iPhone, iPad and macOS, folded so the page stays light until you ask for them.',
    count: '{count} screenshots',
  },
  features: {
    title: 'One compact workspace for everyday server maintenance.',
    subtitle:
      'A focused operational surface with no decorative filler — every block maps to a real maintenance workflow.',
    charts: {
      title: 'Status Charts',
      description:
        'Track CPU, memory, sensors, GPU, network, disk, and host health from dense mobile charts.',
    },
    workspace: {
      title: 'Cross-Platform Workspace',
      description:
        'Use ServerBox across iOS, Android, macOS, Linux, and Windows with one familiar Flutter interface.',
    },
    terminal: {
      title: 'SSH Terminal and SFTP',
      description:
        'Open command-line and file sessions directly from a server card, backed by dartssh2 and xterm.dart.',
    },
    native: {
      title: 'Native Device Hooks',
      description:
        'Biometric auth, message push, home widgets, and watchOS support keep server context nearby.',
    },
    platforms: {
      title: 'Docker, Process, Systemd',
      description:
        'Inspect containers, processes, and services without switching away from your monitoring flow.',
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
      'Choose a trusted source for your device. iOS is available from the App Store. On macOS, the App Store build supports Apple silicon only; Intel users can install the app from GitHub Releases or Homebrew. Direct downloads are also available for Android, Linux, and Windows.',
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
  monitor: {
    meta: {
      title: 'ServerBox Monitor — the agent that keeps watch on your server',
      description:
        'ServerBox Monitor runs on your server: it records status history, sends alerts to your phone, feeds widgets and the Watch app, and serves a web panel.',
    },
    nav: {
      why: 'Why an agent',
      panel: 'Web panel',
      alerts: 'Alerts',
      access: 'Access',
      install: 'Install',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: 'Samples every 7 seconds. Remembers. Tells your phone.',
      subtitle:
        'A small Rust agent that runs on your server. It keeps status history in SQLite, sends alerts, keeps ServerBox widgets and the Watch app current, and serves a web panel — and the app reaches it without SSH.',
      installLabel: 'Install on Linux with systemd or OpenRC',
      installNote: 'It runs as your own account, not root.',
      copy: 'Copy',
      copied: 'Copied',
      guide: 'Setup guide',
      terminalLabel: 'The agent being installed, then sampling',
      installed: 'installed as a systemctl --user service',
      listening: 'listening on 0.0.0.0:3770',
      sampled: 'sampled',
      cadence: 'every 7 s — interval_seconds, by default',
      pushLabel: 'Alerts from the agent on an iPhone lock screen',
      widgetLabel: 'A ServerBox home-screen widget fed by the agent',
    },
    keywords: {
      history: 'SQLite history',
      push: 'Push alerts',
      panel: 'Web panel',
      roles: 'Roles and grants',
      docker: 'Docker',
    },
    why: {
      title: 'What the agent adds to SSH',
      subtitle:
        'SSH is enough to look at a server. The agent keeps looking when you are not.',
      history: {
        title: 'History from before you opened the app',
        description:
          'The agent samples on its own and keeps the result, so charts show the night you slept through. Retention is yours to set.',
      },
      alerts: {
        title: 'Alerts on your phone',
        description:
          'Rules on CPU, memory, swap, disk, network and temperature, sent to iOS, Bark, ServerChan or any webhook.',
      },
      widgets: {
        title: 'Widgets and Watch that stay current',
        description:
          'Home-screen widgets and the Watch app read from the agent, so they update while ServerBox is closed.',
      },
      reach: {
        title: 'No SSH to open',
        description:
          'The app talks to the agent over HTTP. Use it where SSH is unreachable, or alongside SSH on the same server.',
      },
    },
    panel: {
      title: 'A web panel on every agent',
      subtitle:
        'Each agent serves its own panel on port 3770. Host the panel once instead, and sign in to several agents from one page.',
      dashboard: {
        title: 'Live charts and stored history',
        description:
          'CPU, memory, disks, network, GPU and sensors, live and back through what the agent kept — with the output of your own commands beside them.',
      },
      terminal: {
        title: 'A terminal and files in the browser',
        description:
          'A terminal that keeps running when the tab closes and picks up where it was, and a file browser limited to the directories you name.',
      },
      machine: {
        title: 'The parts of the machine that move',
        description:
          'Containers on Docker or Podman, services, processes, cron, the firewall and system users. The agent builds and checks every action; the panel only asks.',
      },
      reach: {
        title: 'What sits next to the server',
        description:
          'RDP and VNC desktops, BMCs over Redfish, and guests on Proxmox VE or libvirt, reached through the agent.',
      },
    },
    alerts: {
      title: 'Alerts where you already look',
      subtitle:
        'A rule is a metric and a threshold. When it trips, every channel you set up hears about it.',
      rule: 'A rule from config.toml',
      push: 'iOS push',
      webhook: 'A webhook into a chat app',
      widget: 'Home-screen widget',
    },
    access: {
      title: 'You decide what each account may do',
      subtitle: 'Reading status is open to every account. The rest is given, and can be taken back.',
      roles: {
        title: 'Roles and grants',
        description:
          'Shell, files, port forwarding and virtualization are grants an admin gives to a role. Take one away and whatever used it closes.',
      },
      transport: {
        title: 'TLS for anything beyond reading',
        description:
          'Commands, files and relays need TLS or a caller on the same host. Built-in TLS, a reverse proxy or a tunnel all count.',
      },
      account: {
        title: 'Runs as you',
        description:
          'The installer runs the agent under your own account, so a shell it gives is that account\'s shell, not root\'s.',
      },
      audit: {
        title: 'Every access recorded',
        description:
          'Who, when, from where, what and how it ended. Passwords and keys never are.',
      },
    },
    install: {
      title: 'Install',
      subtitle: 'Three steps from a fresh server to its status on your phone.',
      step1: {
        title: 'Install the agent',
        description:
          'The installer picks systemd or OpenRC and fetches the latest release. Add --permissions read to start with an admin that holds no grants.',
      },
      step2: {
        title: 'Sign in',
        description:
          'The first start creates the admin account with a random password, saved beside the database as initial-admin-credentials.txt. Change it, then delete the file:',
      },
      step3: {
        title: 'Add it to ServerBox',
        description:
          'In the app, add the server as a Monitor agent with its address and account. Or open the panel at port 3770.',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC (Alpine)',
        docker: 'Docker',
      },
      dockerNote: 'Built from this repository.',
    },
    cta: {
      title: 'Free and open source, like the app.',
      subtitle: 'The agent lives in the ServerBox repository, under the same license.',
      app: 'Get ServerBox',
      source: 'Agent source',
    },
  },
}

export default en
