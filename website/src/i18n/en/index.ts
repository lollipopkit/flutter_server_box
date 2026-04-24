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
    testimonials: 'Testimonials',
    download: 'Download',
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
    installIosPrompt: '# iOS and macOS',
    installReleasePrompt: '# Android, Linux, and Windows',
  },
  download: {
    title: 'Every platform, every official source.',
    subtitle:
      'Choose the channel that matches your device and trust model. iOS and macOS use the App Store; Android, Linux, and Windows also have direct package downloads.',
    platforms: {
      iosMacos: {
        title: 'iOS / macOS',
        description:
          'Use the App Store build for Apple platforms, including automatic updates through your Apple account.',
      },
      android: {
        title: 'Android',
        description:
          'Install from GitHub Releases, the project CDN, F-Droid, or OpenAPK depending on how you manage Android packages.',
      },
      linux: {
        title: 'Linux',
        description:
          'Download desktop packages from GitHub Releases or the project CDN.',
      },
      windows: {
        title: 'Windows',
        description:
          'Download Windows packages from GitHub Releases or the project CDN.',
      },
    },
    sources: {
      appStore: {
        name: 'App Store',
        note: 'Apple platforms',
      },
      github: {
        name: 'GitHub Releases',
        note: 'release builds',
      },
      cdn: {
        name: 'Project CDN',
        note: 'package mirror',
      },
      fdroid: {
        name: 'F-Droid',
        note: 'Android repo',
      },
      openapk: {
        name: 'OpenAPK',
        note: 'Android listing',
      },
    },
    note:
      'Only download packages from a source you trust. For server-side push, widgets, and companion monitoring, install ServerBoxMonitor separately on your servers.',
  },
  testimonials: {
    title: 'Trusted by people who maintain real machines.',
    admin: {
      quote:
        'ServerBox keeps the quick server checks I do every day in one place, without forcing me back to a laptop.',
      role: 'Server Administrator',
    },
    infra: {
      quote:
        'The jump from metrics to SSH and SFTP is direct. It removes a lot of small context switches during incidents.',
      role: 'Infrastructure Maintainer',
    },
    student: {
      quote:
        'It is lightweight enough for my personal servers, but still covers Docker, systemd, and health checks.',
      role: 'Homelab User',
    },
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
