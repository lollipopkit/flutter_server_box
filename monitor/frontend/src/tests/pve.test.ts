import { describe, expect, it, beforeAll } from 'vitest'
import { ApiError } from '../lib/api'
import { pveRefusalDetail, pveRefusalText } from '../lib/pveRefusal'
import { pveSettingsPayload, pveSettingsState } from '../components/PveSettingsForm.svelte'
import { setLocale } from '../i18n/i18n-svelte'
import type { PveSettingsView } from '../types'

/// The view the agent answers with: `secret` is always null and `secret_set`
/// says whether one is held.
function view(overrides: Partial<PveSettingsView> = {}): PveSettingsView {
  return {
    configured: true,
    url: 'https://10.0.0.7:8006',
    auth: 'password',
    username: 'root',
    realm: 'pam',
    token_id: '',
    secret: null,
    secret_set: true,
    ignore_cert: true,
    editable: true,
    ...overrides,
  }
}

beforeAll(async () => {
  await setLocale('en')
})

describe('pve refusals', () => {
  it('phrases every code the agent sends', () => {
    const codes = [
      'notConfigured',
      'invalidUrl',
      'missingUsername',
      'missingRealm',
      'missingTokenId',
      'invalidAuth',
      'invalidKind',
      'invalidAction',
      'invalidNode',
      'invalidVmid',
      'unreachable',
      'loginFailed',
      'needTfa',
      'forbidden',
      'invalidResponse',
      'upstream',
    ]
    for (const code of codes) {
      const sentence = pveRefusalText(code)
      // A code shown as itself means this build has no sentence for it, which
      // is the one thing a refusal list cannot afford to be missing.
      expect(sentence, code).not.toBe(code)
      expect(sentence.length).toBeGreaterThan(0)
    }
    expect(pveRefusalText('loginFailed')).toMatch(/credential/)
    expect(pveRefusalText('forbidden')).toMatch(/not allowed|may not/)
  })

  it('shows an unknown code as the agent sent it', () => {
    // A refusal added since this build: a sentence invented here would
    // misdescribe it.
    expect(pveRefusalText('someCodeFromALaterAgent')).toBe('someCodeFromALaterAgent')
  })

  it('appends the agent\'s own detail under the sentence', () => {
    const error = new ApiError('upstream', 400, {
      error: 'upstream',
      detail: 'no such node',
    })
    const text = pveRefusalDetail(error)
    expect(text.startsWith(pveRefusalText('upstream'))).toBe(true)
    expect(text).toContain('no such node')
  })

  it('says only the sentence when the agent sent no detail', () => {
    expect(pveRefusalDetail(new ApiError('forbidden', 400, { error: 'forbidden' }))).toBe(
      pveRefusalText('forbidden'),
    )
  })
})

describe('pve settings payload', () => {
  it('seeds the fields without a secret', () => {
    const state = pveSettingsState(view())
    expect(state.secret).toBe('')
    expect(state.secretSet).toBe(true)
    expect(state.clearSecret).toBe(false)
    expect(state.username).toBe('root')
  })

  it('keeps the stored secret when the field was left blank', () => {
    // The rule the push channels use: a client that cannot read a credential
    // cannot clear it by sending nothing.
    expect(pveSettingsPayload(pveSettingsState(view())).secret).toBeNull()
  })

  it('replaces the stored secret with what was typed', () => {
    const state = pveSettingsState(view())
    state.secret = 'hunter2'
    expect(pveSettingsPayload(state).secret).toBe('hunter2')
  })

  it('clears the stored secret when asked to', () => {
    const state = pveSettingsState(view())
    state.clearSecret = true
    expect(pveSettingsPayload(state).secret).toBe('')
  })

  it('sends the whole section, trimming what was typed', () => {
    const state = pveSettingsState(view({ auth: 'token', token_id: 'automation' }))
    state.url = '  https://pve.example:8006  '
    state.username = ' root '
    expect(pveSettingsPayload(state)).toEqual({
      url: 'https://pve.example:8006',
      auth: 'token',
      username: 'root',
      realm: 'pam',
      token_id: 'automation',
      secret: null,
      ignore_cert: true,
    })
  })

  it('clears the section with an empty address', () => {
    // An empty address is how the section is cleared, and the secret survives
    // it: the agent keeps what it holds unless it is told to drop it.
    const state = pveSettingsState(view())
    state.url = ''
    const payload = pveSettingsPayload(state)
    expect(payload.url).toBe('')
    expect(payload.secret).toBeNull()
  })
})
