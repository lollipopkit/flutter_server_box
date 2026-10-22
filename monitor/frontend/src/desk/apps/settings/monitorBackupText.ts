/// The monitor backup's failure codes (`/monitor-backup*`, a backup's
/// `last_error`, the `backup.failed` notice) in the reader's language.

import type { TranslationFunctions } from '../../../i18n/i18n-types'
import { ApiError } from '../../../lib/api'
import { errorText } from '../../../lib/errorText'

export function monitorBackupCodeText(code: string, ll: TranslationFunctions): string | null {
  switch (code) {
    case 'invalidUrl':
    case 'webdav.invalidUrl':
      return ll.monitorBackupErrInvalidUrl()
    case 'invalidUsername':
      return ll.monitorBackupErrInvalidUsername()
    case 'invalidPassword':
      return ll.monitorBackupErrInvalidPassword()
    case 'passwordRequired':
      return ll.monitorBackupErrPasswordRequired()
    case 'invalidKeep':
      return ll.monitorBackupErrInvalidKeep()
    case 'weakPassphrase':
      return ll.monitorBackupErrWeakPassphrase()
    case 'notConfigured':
    case 'notReady':
      return ll.monitorBackupErrNotReady()
    case 'disabled':
      return ll.monitorBackupErrDisabled()
    case 'wrongPassphrase':
      return ll.monitorBackupErrWrongPassphrase()
    case 'keyMissing':
      return ll.monitorBackupErrKeyMissing()
    case 'invalidKeyFile':
    case 'excessiveWork':
      return ll.monitorBackupErrInvalidKeyFile()
    case 'invalidBackup':
    case 'wrongKey':
    case 'invalidName':
      return ll.monitorBackupErrInvalidBackup()
    case 'backupNewer':
      return ll.monitorBackupErrNewer()
    case 'tooLarge':
    case 'webdav.tooLarge':
      return ll.monitorBackupErrTooLarge()
    case 'notFound':
      return ll.monitorBackupErrNotFound()
    case 'webdav.unauthorized':
      return ll.monitorBackupErrUnauthorized()
    case 'webdav.forbidden':
      return ll.monitorBackupErrForbidden()
    case 'webdav.notFound':
      return ll.monitorBackupErrFolderMissing()
    case 'webdav.unreachable':
      return ll.monitorBackupErrUnreachable()
    case 'webdav.serverFull':
      return ll.monitorBackupErrServerFull()
    case 'webdav.notWebdav':
      return ll.monitorBackupErrNotWebdav()
    case 'webdav.serverError':
    case 'webdav.io':
    case 'uploadMissing':
      return ll.monitorBackupErrServer()
    default:
      return null
  }
}

/// [e] (a thrown request or a stored code) as words.
export function monitorBackupErrorText(e: unknown, ll: TranslationFunctions): string {
  // These endpoints answer `{"error": <code>}` with no `message`, which
  // `errorFromBody` keeps as the message: the code either way.
  const code = typeof e === 'string' ? e : e instanceof ApiError ? (e.code ?? e.message) : undefined
  return (code && monitorBackupCodeText(code, ll)) ?? (typeof e === 'string' ? ll.monitorBackupErrOther({ code: e }) : errorText(e))
}
