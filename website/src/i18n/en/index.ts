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
      'Install from the App Store, GitHub Releases, F-Droid, OpenAPK, or the project CDN. Only download packages from sources you trust.',
    appStoreAction: 'Open App Store',
    githubAction: 'Download from GitHub Releases',
  },
  plugins: {
    metaTitle: 'ServerBox plugins — extend the app without waiting for a release',
    metaDescription:
      'Plugins extend ServerBox with new pages, cards and status readings. Each one is a small sandboxed module that names the permissions it needs, and the app verifies every package it downloads.',
    title: 'Extend the app without waiting for a release.',
    subtitle:
      'A plugin adds a page, a card, a home tab, or extra status readings. It is one small module, it runs in a sandbox, and it can only do what its manifest asked for and you agreed to.',
    how: {
      sandbox: {
        title: 'Runs in a sandbox',
        description:
          'A plugin is JavaScript in an isolated runtime with no file system, no network, and no server connection of its own. Everything it does, it asks the app to do.',
      },
      permissions: {
        title: 'Asks before it acts',
        description:
          'Its manifest names what it needs — running a command, reaching a host, seeing your server list — and that list is what you agree to when you install it. An ungranted call fails on the spot.',
      },
      anyRepo: {
        title: 'Any repository, checked bytes',
        description:
          'The app installs from any repository address over HTTPS — one request for its latest tree — and checks each package against the checksum its file named. One that names none is refused unless you say otherwise.',
      },
    },
    listTitle: 'In the official repository',
    listSubtitle:
      '{count} plugins, built in this repository and released separately from the app.',
    asks: 'Asks for',
    asksNothing: 'nothing',
    appearsIn: 'Appears in',
    languages: 'Languages',
    source: 'Source',
    install: {
      title: 'Installing one',
      stepOne: 'In the app, open Settings → Plugins → Plugin store.',
      stepTwo:
        'Pick a plugin and press Install. The official repository is already listed.',
      stepThree:
        'Read what it asks for, then agree. The app checks the download against the repository’s checksum before anything runs.',
      address: 'The repository address, if you removed it and want it back:',
      copy: 'Copy address',
    },
    write: {
      title: 'Writing one',
      description:
        'A plugin is one ES module in TypeScript or JavaScript, tested against a mock host with bun test — no app and no build step. On a desktop you can point the app at its directory, and editing it is the whole cycle.',
      sdk: 'SDK',
      examples: 'Example plugins',
      repository: 'Official repository',
    },
    home: 'Home',
  },
  footer: {
    features: 'Features',
    capabilities: 'Capabilities',
    releases: 'Releases',
  },
}

export default en
