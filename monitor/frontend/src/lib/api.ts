import type { LoginRequest, LoginResponse, StatusResponse, SystemMetrics } from '../types'
import { auth } from './auth.svelte'

const BASE = '/api/v1'
const TIMEOUT_MS = 10_000

export class ApiError extends Error {}

async function request<T>(path: string, init: RequestInit = {}, fallback = 'Request failed'): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (auth.token) headers.Authorization = `Bearer ${auth.token}`

  let res: Response
  try {
    res = await fetch(`${BASE}${path}`, {
      ...init,
      headers,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch {
    throw new ApiError(fallback)
  }

  if (res.status === 401 && path !== '/login') {
    // Expired/invalid token: drop the session, App falls back to the login page
    auth.logout()
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

export const api = {
  login: (credentials: LoginRequest) =>
    request<LoginResponse>(
      '/login',
      { method: 'POST', body: JSON.stringify(credentials) },
      'Login failed',
    ),
  getStatus: () => request<StatusResponse>('/status', {}, 'Failed to fetch status'),
  getMetrics: () => request<SystemMetrics>('/metrics', {}, 'Failed to fetch metrics'),
}
