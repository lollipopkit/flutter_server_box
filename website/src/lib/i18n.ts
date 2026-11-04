import { baseLocale, isLocale, locales as generatedLocales } from '../i18n/i18n-util'
import type { Locales } from '../i18n/i18n-types'

type LocaleOption = {
  code: Locales
  label: string
}

export const defaultLocale = baseLocale

const allLocales: LocaleOption[] = [
  { code: 'en', label: 'English' },
  { code: 'zh-CN', label: '简体中文' },
  { code: 'fr', label: 'Français' },
  { code: 'it', label: 'Italiano' },
  { code: 'kr', label: '한국어' },
  { code: 'ja', label: '日本語' },
  { code: 'es', label: 'Español' },
]

export const locales = allLocales.filter((locale) => generatedLocales.includes(locale.code))

// New key so old auto-written `serverbox.website.locale` entries do not override
// browser/Cloudflare language detection when the user never manually chose one.
export const localeStorageKey = 'serverbox.website.user_locale'
const userCookieKey = 'sb_locale'
const cfCookieKey = 'sb_cf_locale'

function readCookie(name: string): string | undefined {
  if (typeof document === 'undefined') return undefined
  const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${name}=([^;]+)`))
  return match ? decodeURIComponent(match[1]) : undefined
}

function readStoredLocale(): string | undefined {
  try {
    return localStorage.getItem(localeStorageKey) || readCookie(userCookieKey) || undefined
  } catch {
    return readCookie(userCookieKey)
  }
}

export function persistUserLocale(locale: Locales): void {
  try {
    localStorage.setItem(localeStorageKey, locale)
  } catch {
    // private mode
  }
  if (typeof document !== 'undefined') {
    document.cookie = `${userCookieKey}=${encodeURIComponent(locale)}; Path=/; Max-Age=31536000; SameSite=Lax`
  }
}

export function matchLocaleTag(locale: string | null | undefined): Locales | undefined {
  if (!locale) return undefined
  if (isLocale(locale)) return locale

  const lowerLocale = locale.toLowerCase()
  if (lowerLocale.startsWith('zh')) return 'zh-CN'
  if (lowerLocale.startsWith('fr')) return 'fr'
  if (lowerLocale.startsWith('it')) return 'it'
  if (lowerLocale.startsWith('ko') || lowerLocale.startsWith('kr')) return 'kr'
  if (lowerLocale.startsWith('ja')) return 'ja'
  if (lowerLocale.startsWith('es')) return 'es'
  if (lowerLocale.startsWith('en')) return 'en'

  return undefined
}

export function normalizeLocale(locale: string | null | undefined): Locales {
  return matchLocaleTag(locale) ?? defaultLocale
}

function guessLocaleFromTimezone(): Locales | undefined {
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''
    if (
      tz === 'Asia/Shanghai' ||
      tz === 'Asia/Chongqing' ||
      tz === 'Asia/Harbin' ||
      tz === 'Asia/Urumqi' ||
      tz === 'Asia/Hong_Kong' ||
      tz === 'Asia/Macau' ||
      tz === 'Asia/Taipei'
    ) {
      return 'zh-CN'
    }
    if (tz === 'Asia/Tokyo') return 'ja'
    if (tz === 'Asia/Seoul') return 'kr'
  } catch {
    // ignore
  }
  return undefined
}

export function getInitialLocale(): Locales {
  const params = new URLSearchParams(window.location.search)
  if (params.has('lang')) {
    return normalizeLocale(params.get('lang'))
  }

  const storedLocale = matchLocaleTag(readStoredLocale())
  if (storedLocale) return storedLocale

  // 1. Check Cloudflare edge-detected locale cookie (`Accept-Language` + `CF-IPCountry`).
  const cfLocale = matchLocaleTag(readCookie(cfCookieKey))

  // 2. Check browser `navigator.languages` list.
  const browserTags =
    typeof navigator !== 'undefined'
      ? [...(navigator.languages || []), navigator.language].filter(Boolean)
      : []

  const primaryBrowser = matchLocaleTag(browserTags[0])
  if (primaryBrowser && primaryBrowser !== 'en') {
    return primaryBrowser
  }

  // If the primary browser UI is English (`en-*`), check if Cloudflare headers,
  // a secondary browser preference, or the system timezone indicates a specific locale.
  if (cfLocale && cfLocale !== 'en') {
    return cfLocale
  }

  for (const tag of browserTags.slice(1)) {
    const matched = matchLocaleTag(tag)
    if (matched && matched !== 'en') return matched
  }

  const tzLocale = guessLocaleFromTimezone()
  if (tzLocale) return tzLocale

  return primaryBrowser ?? cfLocale ?? defaultLocale
}

export function syncLocaleToUrl(locale: Locales, force = false): void {
  const url = new URL(window.location.href)
  if (force || url.searchParams.has('lang')) {
    url.searchParams.set('lang', normalizeLocale(locale))
    window.history.replaceState({}, '', url)
  }
}

export function docsHref(locale: Locales | undefined, subpath = ''): string {
  const clean = subpath.replace(/^\/+/, '')
  const prefix = locale === 'zh-CN' ? '/docs/zh/' : '/docs/'
  return clean ? `${prefix}${clean}` : prefix
}
