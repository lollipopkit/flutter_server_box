/// A stand-in for `lib/servers.svelte` whose `list` and `currentId` are
/// `$state`, so a test can change them *after* a render and have the sidebar
/// react — the real store is reactive too, and that is what a few of these
/// tests are about.
///
/// Only the surface `Sidebar` uses; anything more would be testing the mock.
/// `.svelte.ts` and not `.ts` because runes are compile-time.
import { vi } from 'vitest'

export interface FakeServerEntry {
  id: string
  url: string
  token: string | null
  username: string | null
}

export class FakeServers {
  list = $state<FakeServerEntry[]>([])
  currentId = $state('')
  servedByAgent = $state(false)
  select = vi.fn()
  logout = vi.fn()
  add = vi.fn()
  confirmSameOrigin = vi.fn(async () => {})
}

export const fakeServers = new FakeServers()

export function displayName(entry: FakeServerEntry): string {
  return entry.url || entry.id
}
