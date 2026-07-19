/// Lightweight i18n: rune-backed locale with browser detection and
/// localStorage persistence; `i18n.t(key)` is reactive to locale changes

export type Locale = 'en' | 'zh'

const dict = {
  en: {
    signInSubtitle: 'Sign in to access your server monitoring dashboard',
    username: 'Username',
    password: 'Password',
    enterUsername: 'Enter your username',
    enterPassword: 'Enter your password',
    signIn: 'Sign in',
    signingIn: 'Signing in...',
    addServer: 'Add server',
    removeServer: 'Remove server',
    serverName: 'Name',
    add: 'Add',
    welcome: 'Welcome,',
    logout: 'Logout',
    unknownServer: 'Unknown Server',
    thisServer: 'This server',
    cpuUsage: 'CPU Usage',
    memory: 'Memory',
    diskUsage: 'Disk Usage',
    network: 'Network',
    active: 'Active',
    na: 'N/A',
    history: 'History',
    usage: 'Usage',
    down: 'Down',
    up: 'Up',
    collectingData: 'Collecting data...',
    systemInformation: 'System Information',
    serverNameLabel: 'Server Name:',
    lastUpdated: 'Last Updated:',
    cpuUsageLabel: 'CPU Usage:',
    memoryUsageLabel: 'Memory Usage:',
    diskUsageLabel: 'Disk Usage:',
    temperature: 'Temperature:',
    quickActions: 'Quick Actions',
    refreshData: 'Refresh Data',
    autoRefreshNote: 'Data refreshes automatically every 5 seconds',
    themeSystem: 'System theme',
    themeLight: 'Light theme',
    themeDark: 'Dark theme',
    language: 'Language',
  },
  zh: {
    signInSubtitle: '登录以访问服务器监控面板',
    username: '用户名',
    password: '密码',
    enterUsername: '输入用户名',
    enterPassword: '输入密码',
    signIn: '登录',
    signingIn: '登录中...',
    addServer: '添加服务器',
    removeServer: '移除服务器',
    serverName: '名称',
    add: '添加',
    welcome: '欢迎,',
    logout: '退出',
    unknownServer: '未知服务器',
    thisServer: '本机',
    cpuUsage: 'CPU 使用率',
    memory: '内存',
    diskUsage: '磁盘使用',
    network: '网络',
    active: '正常',
    na: '无',
    history: '历史',
    usage: '使用率',
    down: '下行',
    up: '上行',
    collectingData: '数据采集中...',
    systemInformation: '系统信息',
    serverNameLabel: '服务器名称:',
    lastUpdated: '最后更新:',
    cpuUsageLabel: 'CPU 使用率:',
    memoryUsageLabel: '内存使用率:',
    diskUsageLabel: '磁盘使用率:',
    temperature: '温度:',
    quickActions: '快捷操作',
    refreshData: '刷新数据',
    autoRefreshNote: '数据每 5 秒自动刷新',
    themeSystem: '跟随系统',
    themeLight: '浅色模式',
    themeDark: '深色模式',
    language: '语言',
  },
} as const satisfies Record<Locale, Record<string, string>>

export type MsgKey = keyof (typeof dict)['en']

function detect(): Locale {
  const stored = window.localStorage.getItem('locale')
  if (stored === 'en' || stored === 'zh') return stored
  return navigator.language?.toLowerCase().startsWith('zh') ? 'zh' : 'en'
}

class I18nStore {
  locale = $state<Locale>(detect())

  t(key: MsgKey): string {
    return dict[this.locale][key] ?? dict.en[key]
  }

  toggle() {
    this.locale = this.locale === 'en' ? 'zh' : 'en'
    window.localStorage.setItem('locale', this.locale)
  }
}

export const i18n = new I18nStore()
