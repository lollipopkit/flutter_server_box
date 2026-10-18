import { pick } from '../../../components/stack/text'
import type { InstalledApp, OfferedApp } from '../../../types'

/// A package manifest's text (its title or description), in [locale].
export function textOf(text: string | Record<string, string>, locale: string): string {
  return typeof text === 'string' ? text : pick(text, locale)
}

/// Where [o] stands among [installed]: not installed, the same package
/// (approved or waiting), or another version.
export function standing(o: OfferedApp, installed: InstalledApp[]): 'none' | 'current' | 'waiting' | 'update' {
  const i = installed.find((a) => a.id === o.id)
  if (!i) return 'none'
  if (i.sha256 !== o.sha256) return 'update'
  return i.approved_permissions ? 'current' : 'waiting'
}
