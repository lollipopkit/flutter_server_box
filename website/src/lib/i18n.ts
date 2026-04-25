import { baseLocale, isLocale, locales as generatedLocales } from '../i18n/i18n-util'
import type { Locales } from '../i18n/i18n-types'

type LocaleOption = {
  code: Locales
  label: string
}

export const defaultLocale = baseLocale

export const locales: LocaleOption[] = [
  { code: 'en', label: 'English' },
  { code: 'zh-CN', label: '简体中文' },
  { code: 'fr', label: 'Français' },
  { code: 'it', label: 'Italiano' },
  { code: 'kr', label: '한국어' },
  { code: 'ja', label: '日本語' },
  { code: 'es', label: 'Español' },
].filter((locale) => generatedLocales.includes(locale.code))

export const localeStorageKey = 'serverbox.website.locale'

function readStoredLocale(): string | undefined {
  try {
    return localStorage.getItem(localeStorageKey) || undefined
  } catch {
    return undefined
  }
}

export function normalizeLocale(locale: string | null | undefined): Locales {
  if (!locale) return defaultLocale
  if (isLocale(locale)) return locale

  const lowerLocale = locale.toLowerCase()
  if (lowerLocale.startsWith('zh')) return 'zh-CN'
  if (lowerLocale.startsWith('fr')) return 'fr'
  if (lowerLocale.startsWith('it')) return 'it'
  if (lowerLocale.startsWith('ko') || lowerLocale.startsWith('kr')) return 'kr'
  if (lowerLocale.startsWith('ja')) return 'ja'
  if (lowerLocale.startsWith('es')) return 'es'
  if (lowerLocale.startsWith('en')) return 'en'

  return defaultLocale
}

export function getInitialLocale(): Locales {
  const params = new URLSearchParams(window.location.search)
  const queryLocale = normalizeLocale(params.get('lang'))
  if (params.has('lang')) return queryLocale

  const storedLocale = readStoredLocale()
  if (storedLocale) return normalizeLocale(storedLocale)

  return normalizeLocale(navigator.languages?.[0] || navigator.language)
}

export function syncLocaleToUrl(locale: Locales): void {
  const url = new URL(window.location.href)
  url.searchParams.set('lang', normalizeLocale(locale))
  window.history.replaceState({}, '', url)
}
