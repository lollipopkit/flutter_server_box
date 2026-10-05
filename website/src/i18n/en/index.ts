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
}

export default en
