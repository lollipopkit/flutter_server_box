import { describe, expect, it, beforeAll } from 'vitest'
import { bmcRefusalText } from '../lib/bmcRefusal'
import { bmcSettingsPayload, bmcSettingsState } from '../components/BmcSettingsForm.svelte'
import { setLocale } from '../i18n/i18n-svelte'
import type { BmcSettingsView } from '../types'

/// The view the agent answers with: `secret` is always null and `secret_set`
/// says whether one is held.
function view(overrides: Partial<BmcSettingsView> = {}): BmcSettingsView {
  return {
    configured: true,
    url: 'https://10.0.0.5',
    username: 'root',
    secret: null,
    secret_set: true,
    fingerprint: 'a'.repeat(64),
    fingerprint_pretty: 'AA:AA',
    fingerprint_set: true,
    editable: true,
    ...overrides,
  }
}

beforeAll(async () => {
  await setLocale('en')
})

describe('bmc refusals', () => {
  it('phrases every code the agent sends', () => {
    // Both vocabularies arrive through one field: this endpoint's own names for
    // what the caller got wrong, and `RedfishFailure`'s for what the machine or
    // the link to it did. A missing sentence is what a refusal list cannot
    // afford.
    const codes = [
      'notConfigured',
      'invalidUrl',
      'missingUsername',
      'missingFingerprint',
      'invalidIntent',
      'notAService',
      'noSystem',
      'certificateRejected',
      'unauthorized',
      'noCredential',
      'forbidden',
      'preconditionRequired',
      'unsupportedIntent',
      'invalidResponse',
      'unreachable',
    ]
    for (const code of codes) {
      const sentence = bmcRefusalText(code)
      // A code shown as itself means this build has no sentence for it.
      expect(sentence, code).not.toBe(code)
      expect(sentence.length).toBeGreaterThan(0)
    }
  })

  it('says what to do about the two the operator can fix', () => {
    // The certificate and the credential are the two the operator has to act
    // on, and neither sentence may be so general that it reads like the other.
    expect(bmcRefusalText('certificateRejected')).toMatch(/compare|review/i)
    expect(bmcRefusalText('unauthorized')).toMatch(/account|password/i)
    expect(bmcRefusalText('certificateRejected')).not.toBe(bmcRefusalText('unauthorized'))
  })

  it('tells an address that is not a controller apart from one that is not there', () => {
    // Both are the address being wrong, and the remedies differ.
    expect(bmcRefusalText('notAService')).toMatch(/Redfish/)
    expect(bmcRefusalText('unreachable')).toMatch(/reached|could not/i)
  })

  it('shows an unknown code as the agent sent it', () => {
    // A refusal added since this build: a sentence invented here would
    // misdescribe it.
    expect(bmcRefusalText('someCodeFromALaterAgent')).toBe('someCodeFromALaterAgent')
  })
})

describe('bmc settings payload', () => {
  it('seeds the fields without a password', () => {
    const state = bmcSettingsState(view())
    expect(state.secret).toBe('')
    expect(state.secretSet).toBe(true)
    expect(state.clearSecret).toBe(false)
    expect(state.username).toBe('root')
    // Seeded from the view, unlike the password: the fingerprint is public and
    // an editor that blanked it would refuse every save.
    expect(state.fingerprint).toBe('a'.repeat(64))
  })

  it('keeps the stored password when the field was left blank', () => {
    // The rule the push channels use: a client that cannot read a password
    // cannot clear it by sending nothing.
    expect(bmcSettingsPayload(bmcSettingsState(view())).secret).toBeNull()
  })

  it('replaces the stored password with what was typed', () => {
    const state = bmcSettingsState(view())
    state.secret = 'hunter2'
    expect(bmcSettingsPayload(state).secret).toBe('hunter2')
  })

  it('clears the stored password when asked to', () => {
    const state = bmcSettingsState(view())
    state.clearSecret = true
    expect(bmcSettingsPayload(state).secret).toBe('')
  })

  it('lets clearing win over a value typed beside it', () => {
    const state = bmcSettingsState(view())
    state.secret = 'hunter2'
    state.clearSecret = true
    expect(bmcSettingsPayload(state).secret).toBe('')
  })

  it('sends the whole section, trimming what was typed', () => {
    const state = bmcSettingsState(view())
    state.url = '  https://10.0.0.5  '
    state.username = ' root '
    state.fingerprint = ' aabb '
    expect(bmcSettingsPayload(state)).toEqual({
      url: 'https://10.0.0.5',
      username: 'root',
      secret: null,
      fingerprint: 'aabb',
    })
  })

  it('sends an empty fingerprint rather than inventing one', () => {
    // The agent refuses a save with an address and no readable fingerprint, and
    // that refusal is the point: a password must not be stored for a
    // certificate nobody looked at. Filling the field in here would be this
    // panel deciding to trust whatever answered.
    const state = bmcSettingsState(view({ fingerprint: '', fingerprint_set: false }))
    expect(bmcSettingsPayload(state).fingerprint).toBe('')
  })

  it('clears the section with an empty address', () => {
    // An empty address is how the section is cleared, and the password survives
    // it: the agent keeps what it holds unless it is told to drop it.
    const state = bmcSettingsState(view())
    state.url = ''
    const payload = bmcSettingsPayload(state)
    expect(payload.url).toBe('')
    expect(payload.secret).toBeNull()
  })
})
