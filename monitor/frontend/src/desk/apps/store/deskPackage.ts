import { pick } from '../../../components/stack/text'
import type { InstalledApp, OfferedApp } from '../../../types'

/// A package manifest's text (its title or description), in [locale].
export function textOf(text: string | Record<string, string>, locale: string): string {
  return typeof text === 'string' ? text : pick(text, locale)
}

/// Where [o] stands among [installed]: not installed, waiting for approval,
/// an update (a later version than the one installed), or current (the same
/// package, or one as late or later: never offered as a step back).
export function standing(o: OfferedApp, installed: InstalledApp[]): 'none' | 'current' | 'waiting' | 'update' {
  const i = installed.find((a) => a.id === o.id)
  if (!i) return 'none'
  if (!i.approved_permissions) return 'waiting'
  if (i.sha256 !== o.sha256 && compareVersions(o.version, i.version) > 0) return 'update'
  return 'current'
}

/// [a] against [b] as `major.minor.patch` (a pre-release after a hyphen
/// before its release); a part that is not a number counts as 0.
export function compareVersions(a: string, b: string): number {
  const parse = (v: string) => {
    const [core, pre] = v.split('-', 2)
    return { parts: core.split('.').map((p) => Number.parseInt(p, 10) || 0), pre: pre ?? null }
  }
  const x = parse(a)
  const y = parse(b)
  for (let i = 0; i < Math.max(x.parts.length, y.parts.length); i++) {
    const d = (x.parts[i] ?? 0) - (y.parts[i] ?? 0)
    if (d !== 0) return Math.sign(d)
  }
  if (x.pre === y.pre) return 0
  if (x.pre === null) return 1
  if (y.pre === null) return -1
  return x.pre < y.pre ? -1 : 1
}
