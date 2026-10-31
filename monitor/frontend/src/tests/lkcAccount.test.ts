import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import LkcAccount from '../desk/apps/settings/LkcAccount.svelte'
import { ApiError, api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { LkcState, LkcSignIn } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getLkc: vi.fn(),
    startLkcSignIn: vi.fn(),
    cancelLkcSignIn: vi.fn(),
    signOutLkc: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const signIn = (failed?: LkcSignIn['failed']): LkcSignIn => ({
  user_code: 'AbCd1234',
  verification_uri: 'https://auth.example/device',
  verification_uri_complete: 'https://auth.example/device?code=AbCd1234',
  expires_at_ms: Date.now() + 300_000,
  failed,
})

const signedIn: LkcState = {
  user: { id: 'u1', name: 'Ada', group: 'user', avatar: null },
  sign_in: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
})

describe('LK Cloud account', () => {
  it('starts a device sign-in and shows its code', async () => {
    mocked.getLkc.mockResolvedValueOnce({ user: null, sign_in: null })
    render(LkcAccount)
    const button = await screen.findByRole('button', { name: 'Sign in' })
    mocked.startLkcSignIn.mockResolvedValue({ sign_in: signIn() })
    mocked.getLkc.mockResolvedValue({ user: null, sign_in: signIn() })
    await fireEvent.click(button)
    expect(mocked.startLkcSignIn).toHaveBeenCalledOnce()
    expect(await screen.findByText('AbCd1234')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Open sign-in page' })).toBeInTheDocument()
  })

  it('shows the account and signs out of it', async () => {
    mocked.getLkc.mockResolvedValueOnce(signedIn)
    render(LkcAccount)
    expect(await screen.findByText('Ada')).toBeInTheDocument()
    mocked.signOutLkc.mockResolvedValue(undefined)
    mocked.getLkc.mockResolvedValue({ user: null, sign_in: null })
    await fireEvent.click(screen.getByRole('button', { name: 'Sign out' }))
    expect(mocked.signOutLkc).toHaveBeenCalledOnce()
    expect(await screen.findByRole('button', { name: 'Sign in' })).toBeInTheDocument()
  })

  it('says why a sign-in ended without signing in', async () => {
    mocked.getLkc.mockResolvedValue({ user: null, sign_in: signIn('denied') })
    render(LkcAccount)
    expect(await screen.findByText('The sign-in was declined.')).toBeInTheDocument()
  })

  it('says when the account service cannot be reached', async () => {
    mocked.getLkc.mockResolvedValue({ user: null, sign_in: null })
    mocked.startLkcSignIn.mockRejectedValue(new ApiError('LK Cloud cannot be reached', 502, 'lkc_unreachable'))
    render(LkcAccount)
    await fireEvent.click(await screen.findByRole('button', { name: 'Sign in' }))
    expect(await screen.findByText('The account service cannot be reached.')).toBeInTheDocument()
  })
})
