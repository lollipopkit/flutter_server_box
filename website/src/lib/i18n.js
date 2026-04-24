import { baseLocale, locales as generatedLocales } from '../i18n/i18n-util'

export const defaultLocale = baseLocale

export const locales = [
  { code: 'en', label: 'English' },
  { code: 'zh-CN', label: '简体中文' },
].filter((locale) => generatedLocales.includes(locale.code))

export const localeStorageKey = 'mfuse.website.locale'

export function normalizeLocale(locale) {
  if (!locale) return defaultLocale
  if (generatedLocales.includes(locale)) return locale

  const lowerLocale = locale.toLowerCase()
  if (lowerLocale.startsWith('zh')) return 'zh-CN'
  if (lowerLocale.startsWith('en')) return 'en'

  return defaultLocale
}

export function getInitialLocale() {
  const params = new URLSearchParams(window.location.search)
  const queryLocale = normalizeLocale(params.get('lang'))
  if (params.has('lang')) return queryLocale

  const storedLocale = localStorage.getItem(localeStorageKey)
  if (storedLocale) return normalizeLocale(storedLocale)

  return normalizeLocale(navigator.languages?.[0] || navigator.language)
}

export function syncLocaleToUrl(locale) {
  const url = new URL(window.location.href)
  url.searchParams.set('lang', normalizeLocale(locale))
  window.history.replaceState({}, '', url)
}
