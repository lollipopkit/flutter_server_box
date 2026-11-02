// The node project's tests reach code that speaks through the dictionaries
// (an insecure agent URL's refusal): English, loaded as the panel would.
import { setLocale } from '../i18n/i18n-svelte'
import { loadLocale } from '../i18n/i18n-util.sync'

loadLocale('en')
setLocale('en')
