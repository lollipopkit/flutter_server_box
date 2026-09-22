// Load the small locale dictionaries synchronously. Prefer the persisted
// locale, then fall back to the browser language. Custom detection keeps
// storage access on `window.localStorage` for the test shim in `tests/setup.ts`.
import type { Locales } from './i18n-types.js'
import { isLocale, locales } from './i18n-util.js'
import { loadAllLocales } from './i18n-util.sync.js'
import { setLocale } from './i18n-svelte.js'

// Map Chinese script and region variants to the supported Simplified or
// Traditional Chinese locale.
const primarySubtagFallbacks: Record<string, Locales> = {
	zh: 'zh-CN',
	'zh-hans': 'zh-CN',
	'zh-hant': 'zh-TW',
	'zh-hk': 'zh-TW',
	'zh-mo': 'zh-TW',
}

function fromBrowserLanguage(language: string | undefined): Locales {
	if (!language) return 'en'
	const lower = language.toLowerCase()

	// Exact match first (e.g. 'zh-TW')
	const exact = locales.find((l) => l.toLowerCase() === lower)
	if (exact) return exact

	// Region-qualified fallbacks that don't map to their primary subtag directly
	if (primarySubtagFallbacks[lower]) return primarySubtagFallbacks[lower]

	// Primary subtag match (e.g. 'de-AT' -> 'de', 'pt-BR' -> 'pt')
	const primary = lower.split('-')[0]
	if (primarySubtagFallbacks[primary]) return primarySubtagFallbacks[primary]
	const primaryMatch = locales.find((l) => l.toLowerCase() === primary)
	if (primaryMatch) return primaryMatch

	return 'en'
}

export function detectLocale(): Locales {
	const stored = window.localStorage.getItem('locale')
	if (stored && isLocale(stored)) return stored
	return fromBrowserLanguage(navigator.language)
}

export function persistLocale(locale: Locales) {
	window.localStorage.setItem('locale', locale)
	setLocale(locale)
}

loadAllLocales()
setLocale(detectLocale())
