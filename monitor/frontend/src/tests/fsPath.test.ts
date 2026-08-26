import { describe, expect, it } from 'vitest'
import { joinPath, modeText, parentOf, parseMode, sortEntries } from '../lib/fsPath'
import type { FsEntry } from '../types'

function entry(name: string, kind: FsEntry['kind'] = 'file'): FsEntry {
  return { name, kind, size: null, modified: null, mode: null, link_target: null }
}

describe('joinPath', () => {
  it('does not double the separator', () => {
    expect(joinPath('/home/lk', 'a.txt')).toBe('/home/lk/a.txt')
    expect(joinPath('/home/lk/', 'a.txt')).toBe('/home/lk/a.txt')
    // A root of `/` is the case that produced `//etc`.
    expect(joinPath('/', 'etc')).toBe('/etc')
  })
})

describe('parentOf', () => {
  const roots = ['/home', '/var/log']

  it('walks up inside a root', () => {
    expect(parentOf('/home/lk/notes', roots)).toBe('/home/lk')
    expect(parentOf('/home/lk', roots)).toBe('/home')
  })

  it('stops at a root, which has nowhere to go that the agent would allow', () => {
    // Not `/`: everything outside the roots is refused, so the button would
    // only ever produce an error.
    expect(parentOf('/home', roots)).toBeNull()
    expect(parentOf('/var/log', roots)).toBeNull()
  })

  it('reaches the root itself when the root is `/`', () => {
    expect(parentOf('/etc', ['/'])).toBe('/')
    expect(parentOf('/etc/ssh', ['/'])).toBe('/etc')
    // Still nowhere to go from the root itself.
    expect(parentOf('/', ['/'])).toBeNull()
  })

  it('refuses a parent that falls outside every root', () => {
    // `/etc` is not served here, so `/etc/ssh` has nowhere to go even though
    // its parent exists on the machine. Testing only `path` against the roots
    // would have offered a button that could only fail.
    expect(parentOf('/etc/ssh', ['/home'])).toBeNull()
    // A root is matched on a path boundary, not as a prefix: `/home2` is not
    // inside `/home`.
    expect(parentOf('/home2/x', ['/home'])).toBeNull()
  })
})

describe('sortEntries', () => {
  it('puts directories first, then sorts by name', () => {
    const sorted = sortEntries([
      entry('zeta.txt'),
      entry('beta', 'dir'),
      entry('alpha.txt'),
      entry('alpha', 'dir'),
    ])

    expect(sorted.map((e) => e.name)).toEqual(['alpha', 'beta', 'alpha.txt', 'zeta.txt'])
  })

  it("leaves the caller's array alone", () => {
    const original = [entry('b.txt'), entry('a.txt')]
    sortEntries(original)

    expect(original.map((e) => e.name)).toEqual(['b.txt', 'a.txt'])
  })

  it("treats a link as a file, since following it is the agent's business", () => {
    const sorted = sortEntries([entry('link', 'link'), entry('dir', 'dir')])

    expect(sorted.map((e) => e.name)).toEqual(['dir', 'link'])
  })
})

describe('modeText', () => {
  it('is octal, padded to the three digits chmod is written in', () => {
    expect(modeText(0o644)).toBe('644')
    expect(modeText(0o755)).toBe('755')
    // Setuid and friends are four digits and are not truncated to three.
    expect(modeText(0o4755)).toBe('4755')
    expect(modeText(0o7)).toBe('007')
  })

  it('is empty where the platform reported none', () => {
    expect(modeText(null)).toBe('')
  })
})

describe('parseMode', () => {
  it('reads what modeText wrote', () => {
    expect(parseMode('644')).toBe(0o644)
    expect(parseMode(' 755 ')).toBe(0o755)
    expect(parseMode('4755')).toBe(0o4755)
  })

  it('refuses anything the agent would not take', () => {
    // Decimal `8` and `9` are the trap: `parseInt(x, 8)` stops at the first
    // bad digit and answers a number, so `689` would have become 6.
    for (const bad of ['', '  ', '689', '99', '0x644', 'rwx', '-644', '77777']) {
      expect(parseMode(bad), bad).toBeNull()
    }
  })
})
