import type { FsEntry } from '../types'

/// Paths the agent takes are absolute and POSIX-shaped, whatever the panel is
/// running on — the agent resolves them against its roots and refuses anything
/// landing outside, so there is no client-side notion of a working directory
/// beyond the string being displayed.

export function joinPath(dir: string, name: string): string {
  return dir.endsWith('/') ? `${dir}${name}` : `${dir}/${name}`
}

/// The directory above [path], or null where there is nowhere to go.
///
/// A root has no parent *here* even where it has one on the machine: the agent
/// refuses everything outside its roots, so the button would only ever produce
/// an error. The same test is applied to the answer, not just to [path] — a
/// parent that falls outside every root is no more reachable than a root's own
/// parent is.
///
/// `/etc` under a root of `/` goes up to `/` rather than to the empty string:
/// the root is a path like any other, and whether it can be reached is decided
/// by [roots] and nothing else.
export function parentOf(path: string, roots: readonly string[]): string | null {
  if (roots.includes(path)) return null
  const cut = path.lastIndexOf('/')
  if (cut < 0) return null
  const parent = cut === 0 ? '/' : path.slice(0, cut)
  const within = roots.some(
    (root) => parent === root || parent.startsWith(root.endsWith('/') ? root : `${root}/`),
  )
  return within ? parent : null
}

/// Directories first, then by name.
///
/// Sorted here because the order the agent lists in is the filesystem's, which
/// is arbitrary and differs between two machines showing the same tree.
/// Returns a new array; the caller's is left alone.
export function sortEntries(entries: readonly FsEntry[]): FsEntry[] {
  return [...entries].sort((a, b) => {
    const byKind = Number(b.kind === 'dir') - Number(a.kind === 'dir')
    return byKind !== 0 ? byKind : a.name.localeCompare(b.name)
  })
}

/// `644`, as the field is labelled and as the agent takes it back.
export function modeText(mode: number | null): string {
  return mode === null ? '' : mode.toString(8).padStart(3, '0')
}

/// The octal a permissions field was filled in with, or null when it is not one
/// the agent would accept. Refused here rather than sent, so a typo comes back
/// as nothing happening instead of as an error from the far side.
export function parseMode(text: string): number | null {
  const trimmed = text.trim()
  if (!/^[0-7]{1,4}$/.test(trimmed)) return null
  return Number.parseInt(trimmed, 8)
}
