/// Is there an agent at this URL.
///
/// Its own module because both stores that ask are on opposite sides of one:
/// `health` reads the server list, and `servers` uses this to decide whether
/// the origin it was served from belongs in that list.

const TIMEOUT_MS = 5_000

/// What `/api/v1/health` answered.
///
/// Three outcomes rather than a boolean, because the interesting case is
/// neither: a static host serves index.html for every path it does not know,
/// this one included, and 200-with-a-page would otherwise read as a healthy
/// agent. That is what the panel on Pages was reporting about the origin it is
/// itself served from.
export type Reachability = 'healthy' | 'unreachable' | 'not-an-agent'

export async function probe(url: string): Promise<Reachability> {
  let res: Response
  try {
    res = await fetch(`${url}/api/v1/health`, { signal: AbortSignal.timeout(TIMEOUT_MS) })
  } catch {
    return 'unreachable'
  }
  // An agent answering badly is still an agent. Only a well-formed answer from
  // something that is not one earns 'not-an-agent', which is what callers act
  // on destructively.
  if (!res.ok) return 'unreachable'
  try {
    const body: unknown = await res.json()
    if ((body as { status?: string } | null)?.status === 'healthy') return 'healthy'
  } catch {
    // Not JSON at all.
  }
  return 'not-an-agent'
}
