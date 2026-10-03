/// The panel's half of `/api/v1/backup` that is not drawing: which names the
/// agent takes, and its refusals in the viewer's language.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'

/// The name the app's sync reads and writes (`Miscs.bakFileName`).
export const APP_BACKUP_NAME = 'srvbox_bak_v3.json'

/// `api::backup::valid_name`: checked before an upload so the operator is
/// told before the bytes are sent. A chosen file keeps its own name, since
/// the app reads back the name it wrote.
export function validBackupName(name: string): boolean {
  return /^[A-Za-z0-9._-]{1,128}$/.test(name) && !name.startsWith('.')
}

export function backupRefusalText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const ll = get(LL)
  switch (e.message) {
    case 'invalidName':
      return ll.backupInvalidName()
    case 'tooLarge':
      return ll.backupTooLargeRefused()
    case 'tooMany':
      return ll.backupTooMany()
    case 'noSuchBlob':
      return ll.backupGone()
    default:
      return e.message
  }
}
