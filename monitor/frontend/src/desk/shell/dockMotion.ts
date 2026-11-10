/// How a dock item comes and goes: it grows from nothing along the dock's
/// axis (its neighbours slide aside rather than jump), springing up from a
/// smaller scale; going, it shrinks away faster than it came. The gap after
/// it closes with it.

import { backOut, cubicIn } from 'svelte/easing'
import type { TransitionConfig } from 'svelte/transition'
import { systemPrefs } from '../sys/systemPrefs.svelte'

export interface DockMotion {
  /// The item's size along the dock, in px.
  size: number
  vertical: boolean
  /// The dock's gap between items, in px.
  gap?: number
  /// Coming (`in`) or going (`out`).
  leaving?: boolean
  /// No motion (the dock's first drawing).
  still?: boolean
}

function reduced(): boolean {
  if (systemPrefs.value.reduceMotion) return true
  return typeof window !== 'undefined' && !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
}

export function dockItem(_node: Element, { size, vertical, gap = 9, leaving = false, still = false }: DockMotion): TransitionConfig {
  const axis = vertical ? 'height' : 'width'
  const margin = vertical ? 'margin-bottom' : 'margin-right'
  return {
    duration: still || reduced() ? 0 : leaving ? 220 : 350,
    easing: leaving ? cubicIn : backOut,
    css: (t) => {
      // The size never overshoots (the neighbours would bounce); the icon does.
      const grow = Math.min(1, t)
      return `${axis}: ${grow * size}px; ${margin}: ${(grow - 1) * gap}px; transform: scale(${0.4 + 0.6 * t}); opacity: ${Math.min(1, t * 1.5)};`
    },
  }
}
