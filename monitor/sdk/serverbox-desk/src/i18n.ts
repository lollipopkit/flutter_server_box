/// An app's own words by locale, in the panel's syntax: `{name}` puts a
/// value in, `{{s}}` / `{{one|other}}` / `{{zero|one|two|few|many|other}}`
/// follow the number before it (by `Intl.PluralRules`).
///
///   const t = translator({ en, de }, desk.info.locale)
///   t('count', { count: 3 }) // "3 items"

export type Dictionary = Record<string, string>
export type Translate = (key: string, values?: Record<string, string | number>) => string

/// The dictionary for [locale]: itself, its language (`zh-TW` → none, `de-AT`
/// → `de`), else English. A key missing there falls back to English, then
/// to the key.
export function translator(dictionaries: Record<string, Dictionary>, locale: string): Translate {
  const base = dictionaries.en ?? {}
  const own = dictionaries[locale] ?? dictionaries[locale.split('-')[0]] ?? base
  const rules = new Intl.PluralRules(dictionaries[locale] ? locale : 'en')
  return (key, values = {}) => {
    const text = own[key] ?? base[key] ?? key
    let last: number | undefined
    return text.replace(/\{\{([^}]*)\}\}|\{(\w+)\}/g, (_, forms: string | undefined, name: string | undefined) => {
      if (name !== undefined) {
        const v = values[name]
        if (typeof v === 'number') last = v
        return v === undefined ? `{${name}}` : String(v)
      }
      const parts = (forms ?? '').split('|')
      const n = last ?? 0
      if (parts.length === 1) return n === 1 ? '' : parts[0]
      if (parts.length === 2) return rules.select(n) === 'one' ? parts[0] : parts[1]
      if (n === 0) return parts[0]
      const order = ['zero', 'one', 'two', 'few', 'many', 'other']
      return parts[order.indexOf(rules.select(n))] ?? parts[parts.length - 1]
    })
  }
}
