/// Words a web app's manifest carries in several languages: the panel's
/// locale, else its language (`zh` for `zh-CN`), else English.

import type { LocalizedText } from '../../types'

export function pick(text: LocalizedText | null | undefined, locale: string): string {
  if (!text) return ''
  return text[locale] ?? text[locale.split('-')[0]] ?? text.en ?? Object.values(text)[0] ?? ''
}

/// Where a web app's window enters its proxy: the app's own host when the
/// agent takes apps by host (`url`), else the agent's host (the server's
/// address, or this page's for the agent serving it) on the proxy's own port.
export function enterUrl(
  serverUrl: string,
  entry: { ticket: string; port: number; tls: boolean; path: string; enter: string; url?: string | null },
): string {
  const url = entry.url
    ? new URL(entry.enter, entry.url)
    : new URL(`${entry.tls ? 'https' : 'http'}://${new URL(serverUrl || window.location.origin).hostname}:${entry.port}${entry.enter}`)
  url.searchParams.set('ticket', entry.ticket)
  url.searchParams.set('next', entry.path)
  return url.toString()
}

/// Mebibytes as the panel shows sizes.
export function mib(n: number): string {
  return n >= 1024 ? `${(n / 1024).toFixed(n % 1024 === 0 ? 0 : 1)} GiB` : `${n} MiB`
}
