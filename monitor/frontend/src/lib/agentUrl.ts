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
