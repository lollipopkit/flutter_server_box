/// The monitor backup's failure codes (`/monitor-backup*`, a backup's
/// `last_error`, the `backup.failed` notice) in the reader's language.

import type { TranslationFunctions } from '../../../i18n/i18n-types'
import { ApiError } from '../../../lib/api'
import { errorText } from '../../../lib/errorText'
import { fmtBytes } from '../../../lib/format'

type MessageFn = (ll: TranslationFunctions) => string

const CODE_MESSAGES: Record<string, MessageFn> = {
  invalidUrl: (ll) => ll.monitorBackupErrInvalidUrl(),
  'webdav.invalidUrl': (ll) => ll.monitorBackupErrInvalidUrl(),
  invalidUsername: (ll) => ll.monitorBackupErrInvalidUsername(),
  invalidPassword: (ll) => ll.monitorBackupErrInvalidPassword(),
  passwordRequired: (ll) => ll.monitorBackupErrPasswordRequired(),
  invalidKeep: (ll) => ll.monitorBackupErrInvalidKeep(),
  weakPassphrase: (ll) => ll.monitorBackupErrWeakPassphrase(),
  notConfigured: (ll) => ll.monitorBackupErrNotReady(),
  notReady: (ll) => ll.monitorBackupErrNotReady(),
  disabled: (ll) => ll.monitorBackupErrDisabled(),
  wrongPassphrase: (ll) => ll.monitorBackupErrWrongPassphrase(),
  keyMissing: (ll) => ll.monitorBackupErrKeyMissing(),
  invalidKeyFile: (ll) => ll.monitorBackupErrInvalidKeyFile(),
  excessiveWork: (ll) => ll.monitorBackupErrInvalidKeyFile(),
  invalidBackup: (ll) => ll.monitorBackupErrInvalidBackup(),
  wrongKey: (ll) => ll.monitorBackupErrInvalidBackup(),
  invalidName: (ll) => ll.monitorBackupErrInvalidBackup(),
  backupNewer: (ll) => ll.monitorBackupErrNewer(),
  notFound: (ll) => ll.monitorBackupErrNotFound(),
  'webdav.unauthorized': (ll) => ll.monitorBackupErrUnauthorized(),
  'webdav.forbidden': (ll) => ll.monitorBackupErrForbidden(),
  'webdav.notFound': (ll) => ll.monitorBackupErrFolderMissing(),
  'webdav.unreachable': (ll) => ll.monitorBackupErrUnreachable(),
  'webdav.serverFull': (ll) => ll.monitorBackupErrServerFull(),
  'webdav.notWebdav': (ll) => ll.monitorBackupErrNotWebdav(),
  'webdav.serverError': (ll) => ll.monitorBackupErrServer(),
  'webdav.io': (ll) => ll.monitorBackupErrServer(),
  uploadMissing: (ll) => ll.monitorBackupErrServer(),
}

/// [maxBytes] is the agent's limit on a backup (`max_bytes`), which
/// `tooLarge` is worded with; without it, `tooLarge` is left to the caller's
/// generic wording rather than given a number that is not the agent's.
export function monitorBackupCodeText(code: string, ll: TranslationFunctions, maxBytes: number | undefined): string | null {
  if (code === 'tooLarge' || code === 'webdav.tooLarge') {
    return maxBytes === undefined ? null : ll.monitorBackupErrTooLarge({ max: fmtBytes(maxBytes) })
  }
  const formatter = Object.hasOwn(CODE_MESSAGES, code) ? CODE_MESSAGES[code] : undefined
  return formatter ? formatter(ll) : null
}

/// [e] (a thrown request or a stored code) as words.
export function monitorBackupErrorText(e: unknown, ll: TranslationFunctions, maxBytes: number | undefined): string {
  // These endpoints answer `{"error": <code>}` with no `message`, which
  // `errorFromBody` keeps as the message: the code either way.
  const code = typeof e === 'string' ? e : e instanceof ApiError ? (e.code ?? e.message) : undefined
  return (code && monitorBackupCodeText(code, ll, maxBytes)) ?? (typeof e === 'string' ? ll.monitorBackupErrOther({ code: e }) : errorText(e))
}
