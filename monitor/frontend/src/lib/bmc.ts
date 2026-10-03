/// The panel's half of `/api/v1/bmc` that is not drawing: the agent's and
/// the BMC's refusals in the viewer's language, and the form's draft.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'
import type { BmcIntent, BmcPowerState, BmcTarget, BmcTargetInput } from '../types'

/// Why a request to a BMC failed: `sbm_redfish::Failure`'s code in
/// `body.failure` (answered `502`, never the panel's own 401), or the agent's
/// refusal of a set (`api::bmc::Refusal`). A code this build does not know is
/// shown as sent.
export function bmcErrorText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const ll = get(LL)
  const failure = typeof e.body?.failure === 'string' ? e.body.failure : null
  switch (failure ?? e.message) {
    case 'certNotReviewed':
      return ll.bmcCertNotReviewed()
    case 'certificateRejected':
      return ll.bmcCertRejected()
    case 'unauthorized':
      return ll.bmcUnauthorized()
    case 'forbidden':
      return ll.bmcForbidden()
    case 'unreachable':
      return ll.bmcUnreachable()
    case 'notAService':
    case 'invalidResponse':
      return ll.bmcNotRedfish()
    case 'noSystem':
      return ll.bmcNoSystem()
    case 'notSupported':
      return ll.bmcNotSupported()
    case 'noSuchTarget':
      return ll.bmcGone()
    case 'invalidName':
    case 'duplicateName':
      return ll.bmcInvalidName()
    case 'invalidUrl':
      return ll.bmcInvalidUrl()
    case 'invalidUsername':
      return ll.bmcInvalidUsername()
    case 'invalidCertificate':
      return ll.bmcInvalidCertificate()
    default:
      return failure ? `${failure}${typeof e.body?.detail === 'string' ? `: ${e.body.detail}` : ''}` : e.message
  }
}

export function powerStateText(state: BmcPowerState): string {
  const ll = get(LL)
  switch (state) {
    case 'on':
      return ll.bmcStateOn()
    case 'off':
      return ll.bmcStateOff()
    case 'poweringOn':
      return ll.bmcStatePoweringOn()
    case 'poweringOff':
      return ll.bmcStatePoweringOff()
    case 'paused':
      return ll.bmcStatePaused()
    default:
      return ll.bmcStateUnknown()
  }
}

export function intentText(intent: BmcIntent): string {
  const ll = get(LL)
  switch (intent) {
    case 'on':
      return ll.bmcIntentOn()
    case 'gracefulShutdown':
      return ll.bmcIntentShutdown()
    case 'forceOff':
      return ll.bmcIntentForceOff()
    case 'restart':
      return ll.bmcIntentRestart()
    case 'powerCycle':
      return ll.bmcIntentPowerCycle()
  }
}

/// The set as a write sends it, every stored password kept (`null`).
export function keepPasswords(targets: BmcTarget[]): BmcTargetInput[] {
  return targets.map((t) => ({
    id: t.id,
    name: t.name,
    url: t.url,
    username: t.username,
    password: null,
    cert_sha256: t.cert_sha256,
  }))
}

/// `aa:bb:…`, the spelling a BMC's own console shows a fingerprint in.
export function prettyFingerprint(fingerprint: string): string {
  return (fingerprint.replace(/[^0-9a-fA-F]/g, '').toUpperCase().match(/.{2}/g) ?? []).join(':')
}
