// Loads the one locale in use, each dictionary being its own chunk (all of
// them at once were 1.3 MB of the first load). Prefer the persisted locale,
// then fall back to the browser language. Custom detection keeps
// storage access on `window.localStorage` (via lib/prefs) for the test shim in
// `tests/setup.ts`.
import type { Locales } from './i18n-types.js'
import { isLocale, locales } from './i18n-util.js'
import { loadLocaleAsync } from './i18n-util.async.js'
import { locale, setLocale } from './i18n-svelte.js'
import { readPref, writePref } from '../lib/prefs.js'

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
	const stored = readPref('locale')
	if (stored && isLocale(stored)) return stored
	return fromBrowserLanguage(navigator.language)
}

/// Loads [locale]'s dictionary, then switches to it.
async function use(locale: Locales) {
	await loadLocaleAsync(locale)
	setLocale(locale)
}

export function persistLocale(locale: Locales): Promise<void> {
	writePref('locale', locale)
	return use(locale)
}

// Screen readers pick the voice from <html lang>, which index.html can only
// state once
locale.subscribe((l) => {
	if (l) document.documentElement.lang = l
})

/// The detected locale, loaded (English when its chunk cannot be): the panel
/// mounts once this settles.
export const ready: Promise<void> = use(detectLocale()).catch(() => use('en'))
