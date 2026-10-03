export function isSecureAgentUrl(input: string): boolean {
  if (input === '') return true
  try {
    const url = new URL(input)
    if (url.protocol === 'https:') return true
    const host = url.hostname.toLowerCase()
    const loopback = host === 'localhost' || host === '127.0.0.1' || host === '[::1]' || host === '::1'
    return url.protocol === 'http:' && loopback
  } catch {
    return false
  }
}

export function normalizeAgentUrl(input: string): string {
  const normalized = input.trim().replace(/\/+$/, '')
  if (!isSecureAgentUrl(normalized)) {
    throw new Error('Remote monitor agents require HTTPS; HTTP is allowed only on loopback.')
  }
  return normalized
}

/// Turns the agent's base URL into a WebSocket URL for `path`.
///
/// Built by string surgery rather than through `URL`, which would read a bare
/// `agent.example.com:3770` as the scheme `agent.example.com:`. An entry
/// without a scheme inherits the page's, so a panel served over HTTPS never
/// silently downgrades a socket to `ws:`.
export function agentWsUrl(base: string, path: string): string {
  const origin = (base || window.location.origin).trim().replace(/\/+$/, '')
  const ws = /^https?:\/\//i.test(origin)
    ? origin.replace(/^http/i, 'ws')
    : `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${origin}`
  return `${ws}${path}`
}

/// A WebSocket ticket as the subprotocol the agent reads it from: a browser
/// cannot set a header on the upgrade, and a query string lands in access logs.
export function wsTicketProtocol(ticket: string): string {
  return `sbm-ticket.${ticket}`
}
