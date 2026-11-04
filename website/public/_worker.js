const COUNTRY_TO_LOCALE = {
  CN: 'zh-CN',
  HK: 'zh-CN',
  MO: 'zh-CN',
  TW: 'zh-CN',
  SG: 'zh-CN',
  JP: 'ja',
  KR: 'kr',
  FR: 'fr',
  IT: 'it',
  ES: 'es',
  MX: 'es',
  AR: 'es',
  CL: 'es',
  CO: 'es',
}

function matchTag(tag) {
  if (!tag) return undefined
  const lower = tag.trim().toLowerCase()
  if (lower.startsWith('zh')) return 'zh-CN'
  if (lower.startsWith('ja')) return 'ja'
  if (lower.startsWith('ko') || lower.startsWith('kr')) return 'kr'
  if (lower.startsWith('fr')) return 'fr'
  if (lower.startsWith('it')) return 'it'
  if (lower.startsWith('es')) return 'es'
  if (lower.startsWith('en')) return 'en'
  return undefined
}

function parseAcceptLanguage(header) {
  if (!header) return []
  return header
    .split(',')
    .map((part) => {
      const [rawTag, ...params] = part.trim().split(';')
      let q = 1
      for (const p of params) {
        const [k, v] = p.trim().split('=')
        if (k === 'q' && v) {
          const parsed = Number.parseFloat(v)
          if (!Number.isNaN(parsed)) q = parsed
        }
      }
      return { tag: rawTag, q }
    })
    .sort((a, b) => b.q - a.q)
    .map((item) => item.tag)
}

function readCookie(cookieHeader, name) {
  if (!cookieHeader) return undefined
  const match = cookieHeader.match(new RegExp(`(?:^|;\\s*)${name}=([^;]+)`))
  return match ? decodeURIComponent(match[1]) : undefined
}

function detectLocaleFromRequest(request) {
  const acceptTags = parseAcceptLanguage(request.headers.get('accept-language'))
  const country = (request.cf?.country || request.headers.get('cf-ipcountry') || '').toUpperCase()
  const countryLocale = COUNTRY_TO_LOCALE[country]

  const primary = matchTag(acceptTags[0])
  if (primary && primary !== 'en') return primary
  if (countryLocale && countryLocale !== 'en') return countryLocale

  for (const tag of acceptTags.slice(1)) {
    const matched = matchTag(tag)
    if (matched && matched !== 'en') return matched
  }

  return primary || countryLocale || 'en'
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url)
    const cookieHeader = request.headers.get('cookie') || ''
    const userLocale = matchTag(readCookie(cookieHeader, 'sb_locale'))
    const detectedLocale = userLocale || detectLocaleFromRequest(request)

    // Auto-redirect /docs/ root to /docs/zh/ for Chinese users unless they
    // explicitly selected English or are navigating from within /docs/.
    if (url.pathname === '/docs' || url.pathname === '/docs/') {
      const referer = request.headers.get('referer') || ''
      const fromDocs = referer.includes('/docs/')
      if (detectedLocale === 'zh-CN' && !fromDocs) {
        const target = new URL('/docs/zh/', url.origin)
        target.search = url.search
        return Response.redirect(target.toString(), 302)
      }
    }

    const response = await env.ASSETS.fetch(request)
    const headers = new Headers(response.headers)
    headers.append(
      'Set-Cookie',
      `sb_cf_locale=${encodeURIComponent(detectedLocale)}; Path=/; Max-Age=86400; SameSite=Lax`,
    )

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    })
  },
}
