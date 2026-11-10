import type { Dictionary } from 'serverbox-desk'

const files = import.meta.glob<Dictionary>('../locales/*.json', { eager: true, import: 'default' })

/// Every locale's words, by locale (`en`, `zh-CN`, …).
export const dictionaries: Record<string, Dictionary> = Object.fromEntries(
  Object.entries(files).map(([path, d]) => [path.slice(path.lastIndexOf('/') + 1, -'.json'.length), d]),
)
