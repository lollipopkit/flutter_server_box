/// The desk's apps: one entry each, the only list. The dock, the launchpad,
/// Spotlight, the window manager and the session all read it; an app is added
/// here and nowhere else (see `desk/CLAUDE.md`).

import type { Component } from 'svelte'
import type { IconTone } from './lk/AppIcon.svelte'
import type { TranslationFunctions } from '../i18n/i18n-types'
import { dashboardAccess } from '../lib/access'
import { enabledFeatures, type FeatureId } from '../lib/features'
import type { Capabilities } from '../types'
import type { WindowPolicy } from './windows.svelte'

export type AppId =
  | 'status'
  | 'files'
  | 'terminal'
  | 'containers'
  | 'process'
  | 'services'
  | 'cron'
  | 'system_users'
  | 'firewall'
  | 'snippets'
  | 'remote_desktop'
  | 'benchmark'
  | 'virt'
  | 'bmc'
  | 'backup'
  | 'settings'

export interface AppSpec extends WindowPolicy {
  id: AppId
  title: (ll: TranslationFunctions) => string
  /// Words Spotlight also finds it by, besides its title.
  keywords?: (ll: TranslationFunctions) => string[]
  /// The app icon's glyph (Material Symbols Rounded) and tile tone.
  glyph: string
  tone: IconTone
  /// Whether this server and this account can use it. `undefined`
  /// capabilities (not fetched yet) answer false for anything gated.
  available: (caps: Capabilities | undefined) => boolean
  /// The window's content. Lazy, so an app nobody opens is never loaded.
  load: () => Promise<{ default: Component }>
}

const always = () => true

function feature(id: FeatureId) {
  return (caps: Capabilities | undefined) => enabledFeatures(caps).some((f) => f.id === id)
}

const SIZE = { width: 1040, height: 680 }
const MIN = { width: 420, height: 300 }

export const APPS: AppSpec[] = [
  {
    id: 'status',
    title: (ll) => ll.deskAppStatus(),
    keywords: (ll) => [ll.cpuUsage(), ll.memory(), ll.diskUsage(), ll.network()],
    glyph: 'monitoring',
    tone: 'berry',
    available: always,
    instances: 1,
    size: { width: 1100, height: 720 },
    minSize: MIN,
    load: () => import('./apps/status/StatusApp.svelte'),
  },
  {
    id: 'files',
    title: (ll) => ll.files(),
    glyph: 'folder',
    tone: 'soft',
    available: (caps) => dashboardAccess(caps).files,
    instances: 4,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/files/FilesApp.svelte'),
  },
  {
    id: 'terminal',
    title: (ll) => ll.terminal(),
    glyph: 'terminal',
    tone: 'ink',
    available: (caps) => dashboardAccess(caps).terminal,
    instances: 6,
    size: { width: 860, height: 540 },
    minSize: { width: 360, height: 220 },
    load: () => import('./apps/terminal/TerminalApp.svelte'),
  },
  {
    id: 'containers',
    title: (ll) => ll.containers(),
    glyph: 'inventory_2',
    tone: 'sky',
    available: feature('containers'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/containers/ContainersApp.svelte'),
  },
  {
    id: 'process',
    title: (ll) => ll.processes(),
    glyph: 'browse_activity',
    tone: 'teal',
    available: feature('process'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/process/ProcessApp.svelte'),
  },
  {
    id: 'services',
    title: (ll) => ll.services(),
    glyph: 'dns',
    tone: 'violet',
    available: feature('services'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/services/ServicesApp.svelte'),
  },
  {
    id: 'cron',
    title: (ll) => ll.cron(),
    glyph: 'schedule',
    tone: 'amber',
    available: feature('cron'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/cron/CronApp.svelte'),
  },
  {
    id: 'system_users',
    title: (ll) => ll.systemUsers(),
    glyph: 'group',
    tone: 'leaf',
    available: feature('system_users'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/system_users/SystemUsersApp.svelte'),
  },
  {
    id: 'firewall',
    title: (ll) => ll.fwTitle(),
    glyph: 'shield_lock',
    tone: 'pale',
    available: feature('firewall'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/firewall/FirewallApp.svelte'),
  },
  {
    id: 'snippets',
    title: (ll) => ll.snippets(),
    glyph: 'code_blocks',
    tone: 'violet',
    available: feature('snippets'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/snippets/SnippetsApp.svelte'),
  },
  {
    id: 'remote_desktop',
    title: (ll) => ll.desktop(),
    keywords: () => ['VNC', 'RDP'],
    glyph: 'desktop_windows',
    tone: 'sky',
    available: feature('desktop'),
    instances: 4,
    size: { width: 1180, height: 760 },
    minSize: MIN,
    load: () => import('./apps/remote_desktop/RemoteDesktopApp.svelte'),
  },
  {
    id: 'benchmark',
    title: (ll) => ll.benchmark(),
    glyph: 'speed',
    tone: 'amber',
    available: feature('benchmark'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/benchmark/BenchmarkApp.svelte'),
  },
  {
    id: 'virt',
    title: (ll) => ll.virt(),
    keywords: () => ['KVM', 'libvirt', 'Proxmox', 'PVE'],
    glyph: 'deployed_code',
    tone: 'bright',
    available: feature('virt'),
    instances: 1,
    size: { width: 1180, height: 760 },
    minSize: MIN,
    load: () => import('./apps/virt/VirtApp.svelte'),
  },
  {
    id: 'bmc',
    title: (ll) => ll.bmc(),
    keywords: () => ['IPMI', 'Redfish'],
    glyph: 'developer_board',
    tone: 'teal',
    available: feature('bmc'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/bmc/BmcApp.svelte'),
  },
  {
    id: 'backup',
    title: (ll) => ll.backup(),
    glyph: 'backup',
    tone: 'leaf',
    available: feature('backup'),
    instances: 1,
    size: SIZE,
    minSize: MIN,
    load: () => import('./apps/backup/BackupApp.svelte'),
  },
  {
    id: 'settings',
    title: (ll) => ll.deskAppSettings(),
    glyph: 'settings',
    tone: 'mist',
    available: always,
    instances: 1,
    size: { width: 900, height: 640 },
    minSize: MIN,
    load: () => import('./apps/settings/SettingsApp.svelte'),
  },
]

const BY_ID = new Map<string, AppSpec>(APPS.map((a) => [a.id, a]))

export function app(id: string): AppSpec | undefined {
  return BY_ID.get(id)
}

/// The apps this server and account can use, in the registry's order.
export function availableApps(caps: Capabilities | undefined): AppSpec[] {
  return APPS.filter((a) => a.available(caps))
}

/// What a fresh desk's dock holds, before anyone arranged it.
export const DEFAULT_DOCK: AppId[] = ['status', 'files', 'terminal', 'containers', 'virt', 'settings']
