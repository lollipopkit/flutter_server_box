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
    four: 'ServerBox tools screenshot',
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
    items: {
      statusChart: 'Status chart',
      sshTerminal: 'SSH Terminal',
      sftp: 'SFTP',
      docker: 'Docker',
      process: 'Process',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: 'Sensors',
      push: 'Push',
      homeWidget: 'Home Widget',
      watchos: 'watchOS',
    },
  },
  download: {
    title: 'Every platform, every source.',
    subtitle:
      'Choose the channel that matches your device and trust model. iOS uses the App Store; macOS uses the App Store or Homebrew; Android, Linux, and Windows also have direct package downloads.',
    copied: 'Install command copied',
    copyPrompt: 'Copy this install command:',
    note:
      'Only download packages from a source you trust. For server-side push, widgets, and companion monitoring, install ServerBoxMonitor separately on your servers.',
  },
  cta: {
    title: 'ServerBox is free and open source under AGPLv3.',
    subtitle:
      'Install from the App Store, GitHub Releases, F-Droid, OpenAPK, or the project CDN. Only download packages from sources you trust.',
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
