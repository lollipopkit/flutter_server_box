/// Shared auth state (module-level runes): one source of truth for the login
/// gate, the dashboard header, and the API client's 401 handling
///
/// Storage access is via window.localStorage: vitest's SSR module pipeline
/// exposes window but not the bare localStorage global

class AuthStore {
  token = $state<string | null>(window.localStorage.getItem('token'))
  username = $state<string | null>(window.localStorage.getItem('username'))

  get authenticated(): boolean {
    return this.token !== null
  }

  login(token: string, username: string) {
    window.localStorage.setItem('token', token)
    window.localStorage.setItem('username', username)
    this.token = token
    this.username = username
  }

  logout() {
    window.localStorage.removeItem('token')
    window.localStorage.removeItem('username')
    this.token = null
    this.username = null
  }
}

export const auth = new AuthStore()
