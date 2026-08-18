import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import LoginForm from '../components/LoginForm.svelte'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'

// Partial mock: ApiError stays real so instanceof narrowing works
vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { login: vi.fn(), getStatus: vi.fn(), getMetrics: vi.fn() },
}))
const mockedLogin = vi.mocked(api.login)

describe('Login', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    servers.logout()
  })

  it('renders login form', () => {
    render(LoginForm)

    expect(screen.getByLabelText('Username')).toBeInTheDocument()
    expect(screen.getByLabelText('Password')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument()
  })

  it('handles successful login', async () => {
    mockedLogin.mockResolvedValue({ token: 'test-token' })

    render(LoginForm)

    await fireEvent.input(screen.getByLabelText('Username'), { target: { value: 'admin' } })
    await fireEvent.input(screen.getByLabelText('Password'), { target: { value: 'password' } })
    await fireEvent.click(screen.getByRole('button', { name: /sign in/i }))

    await waitFor(() => {
      expect(mockedLogin).toHaveBeenCalledWith({ username: 'admin', password: 'password' })
      expect(servers.authenticated).toBe(true)
      expect(servers.current?.username).toBe('admin')
    })
  })

  it('displays error on failed login', async () => {
    mockedLogin.mockRejectedValue(new ApiError('Invalid credentials'))

    render(LoginForm)

    await fireEvent.input(screen.getByLabelText('Username'), { target: { value: 'wrong' } })
    await fireEvent.input(screen.getByLabelText('Password'), { target: { value: 'wrong' } })
    await fireEvent.click(screen.getByRole('button', { name: /sign in/i }))

    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument()
      expect(servers.authenticated).toBe(false)
    })
  })
})
