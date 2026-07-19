// Locale bootstrap: load all locales synchronously (two small dictionaries)
// and pick the persisted choice, falling back to browser language detection.
// Custom detection instead of typesafe-i18n's detectors so storage access
// goes through window.localStorage (see tests/setup.ts for why).
import type { Locales } from './i18n-types.js'
import { loadAllLocales } from './i18n-util.sync.js'
import { setLocale } from './i18n-svelte.js'

export function detectLocale(): Locales {
	const stored = window.localStorage.getItem('locale')
	if (stored === 'en' || stored === 'zh-CN') return stored
	return navigator.language?.toLowerCase().startsWith('zh') ? 'zh-CN' : 'en'
}

export function persistLocale(locale: Locales) {
	window.localStorage.setItem('locale', locale)
	setLocale(locale)
}

loadAllLocales()
setLocale(detectLocale())
