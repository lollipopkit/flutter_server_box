/// What an installed app's permission lets it do, as the approval dialog and
/// the app's page say it. The agent's list is `api::apps` (`WEB_PERMISSIONS`,
/// `WASM_PERMISSIONS`); one the panel does not know yet is shown as is.

import type { TranslationFunctions } from '../i18n/i18n-types'

export function permissionText(ll: TranslationFunctions, permission: string): string {
  switch (permission) {
    case 'notifications':
      return ll.settingsPermNotifications()
    case 'background':
      return ll.settingsPermBackground()
    case 'status':
      return ll.settingsPermStatus()
    case 'process':
      return ll.settingsPermProcess()
    case 'root':
      return ll.settingsPermRoot()
    case 'providers':
      return ll.settingsPermProviders()
    default:
      return permission
  }
}
