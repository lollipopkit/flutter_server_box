/// How a window leaves when it is closed: it falls away faster than it came
/// (`lk-window-in`), fading as it shrinks a little toward where it stood.

import type { TransitionConfig } from 'svelte/transition'
import { systemPrefs } from '../sys/systemPrefs.svelte'

function reduced(): boolean {
  if (systemPrefs.value.reduceMotion) return true
  return typeof window !== 'undefined' && !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
}

/// `--ease-exit` (cubic-bezier(0.4, 0, 1, 1), close to u²: slow, then fast)
/// for an outro, whose `t` runs from 1 to 0: `1 - (1 - t)²`.
function exit(t: number): number {
  return 1 - (1 - t) * (1 - t)
}

export interface WindowClose {
  /// Closed, rather than taken into another window (a merge, which has its
  /// own motion) or gone with the desk.
  closed: boolean
}

export function windowClose(_node: Element, { closed }: WindowClose): TransitionConfig {
  if (!closed) return { duration: 0 }
  const still = reduced()
  return {
    // `--dur-base`, as the design system's reduced motion shortens it.
    duration: still ? 120 : 220,
    easing: exit,
    css: (t) => `opacity: ${t}; pointer-events: none;${still ? '' : ` transform: scale(${0.92 + 0.08 * t});`}`,
  }
}
