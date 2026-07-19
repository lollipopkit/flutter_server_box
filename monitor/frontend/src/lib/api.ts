import type { HistoryPoint, LoginRequest, LoginResponse, StatusResponse, SystemMetrics } from '../types'
import { servers } from './servers.svelte'

const TIMEOUT_MS = 10_000

export class ApiError extends Error {}

async function request<T>(path: string, init: RequestInit = {}, fallback = 'Request failed'): Promise<T> {
  const server = servers.current
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (server?.token) headers.Authorization = `Bearer ${server.token}`

  let res: Response
  try {
    res = await fetch(`${server?.url ?? ''}/api/v1${path}`, {
      ...init,
      headers,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch {
    throw new ApiError(fallback)
  }

  if (res.status === 401 && path !== '/login') {
    // Expired/invalid token: drop this server's session, App falls back to login
    servers.logout()
    throw new ApiError('Session expired')
  }
  if (!res.ok) {
    let message = fallback
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      // Non-JSON error body: keep the fallback message
    }
    throw new ApiError(message)
  }
  return res.json() as Promise<T>
}

/// Unauthenticated reachability probe for a candidate URL (add/edit server
/// form), independent of `servers.current` since the entry may not be saved yet
export async function testConnection(url: string): Promise<boolean> {
  try {
    const res = await fetch(`${url}/api/v1/health`, { signal: AbortSignal.timeout(TIMEOUT_MS) })
    return res.ok
  } catch {
    return false
  }
}

/// Logs into an explicit URL (add/edit server form) instead of `servers.current`
export async function loginTo(url: string, credentials: LoginRequest): Promise<LoginResponse> {
  let res: Response
  try {
    res = await fetch(`${url}/api/v1/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch {
    throw new ApiError('Login failed')
  }
  if (!res.ok) {
    let message = 'Login failed'
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      // Non-JSON error body: keep the fallback message
    }
    throw new ApiError(message)
  }
  return res.json() as Promise<LoginResponse>
}

export const api = {
  login: (credentials: LoginRequest) =>
    request<LoginResponse>(
      '/login',
      { method: 'POST', body: JSON.stringify(credentials) },
      'Login failed',
    ),
  getStatus: () => request<StatusResponse>('/status', {}, 'Failed to fetch status'),
  getMetrics: () => request<SystemMetrics>('/metrics', {}, 'Failed to fetch metrics'),
  getHistory: (minutes: number) =>
    request<HistoryPoint[]>(`/metrics/history?minutes=${minutes}`, {}, 'Failed to fetch history'),
}
