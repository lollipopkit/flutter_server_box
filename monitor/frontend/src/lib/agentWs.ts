/// Where an agent's WebSocket endpoints are, and how a browser authenticates to
/// one.
///
/// Shared by the terminal and the desktop relay, which are two endpoints of the
/// same agent reached the same way: a browser cannot put a bearer token on a
/// WebSocket handshake, so the session token is exchanged for a single-use
/// ticket that travels as the first subprotocol. A helper per endpoint would be
/// the same forty characters written twice, and the one that drifted would be
/// the one that authenticated wrongly.

/// Turns an agent's base URL into the WebSocket URL for one of its endpoints.
///
/// Built by string surgery rather than through `URL`, which would read a bare
/// `agent.example.com:3770` as the scheme `agent.example.com:`. An entry
/// without a scheme inherits the page's, so a panel served over HTTPS never
/// silently downgrades its connection to `ws:`.
export function agentWsUrl(base: string, path: string): string {
  const origin = (base || window.location.origin).trim().replace(/\/+$/, '')
  const ws = /^https?:\/\//i.test(origin)
    ? origin.replace(/^http/i, 'ws')
    : `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${origin}`
  return `${ws}${path}`
}

/// The subprotocol that carries a ticket through the upgrade.
///
/// A subprotocol rather than a query parameter: a token in a URL lands in the
/// agent's access log, and the handshake offers nowhere else to put it. The
/// agent reads the first offered protocol with this prefix, so a client that
/// offers anything else first is refused — which is why the socket is created
/// here rather than by a protocol client that has its own idea of subprotocols.
export const TICKET_PROTOCOL_PREFIX = 'sbm-ticket.'

export function wsTicketProtocol(ticket: string): string {
  return `${TICKET_PROTOCOL_PREFIX}${ticket}`
}
