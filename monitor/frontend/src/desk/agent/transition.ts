/// The desk ⇄ Agent mode switch (the lollipopkit Design System's storyboard,
/// 820 ms in): the menubar stays put as the anchor of both; the Agent ground
/// opens as a circle from the menubar's Agent mode item; the windows recede
/// toward the middle of the screen, front first, and come back spring-like,
/// back first; the Agent content rises in after them and leaves together
/// and fast. Reduced motion is a 150 ms fade of each part, with no blur,
/// clip or movement.

import { reducedMotion } from '../sys/pageMotion'

/// The parts of a window that recede: a window, and how deep it is (0 the
/// front one).
interface Receding {
  el: HTMLElement
  /// Front to back.
  index: number
}

const FADE = 150

function ease(root: Element, name: string, fallback: string): string {
  const v = getComputedStyle(root).getPropertyValue(name).trim()
  return v || fallback
}

/// The windows on screen, front first.
function windows(root: HTMLElement): Receding[] {
  const els = [...root.querySelectorAll<HTMLElement>('.desk-window')].filter((el) => el.dataset.minimized !== 'true')
  els.sort((a, b) => Number(b.style.zIndex || 0) - Number(a.style.zIndex || 0))
  return els.map((el, index) => ({ el, index }))
}

/// Where [el] goes as it recedes: a little toward the middle of [root].
function inward(el: HTMLElement, root: HTMLElement): { dx: number; dy: number } {
  const r = el.getBoundingClientRect()
  const s = root.getBoundingClientRect()
  const dx = s.left + s.width / 2 - (r.left + r.width / 2)
  const dy = s.top + s.height / 2 - (r.top + r.height / 2)
  const clamp = (v: number, m: number) => Math.max(-m, Math.min(m, v))
  return { dx: Math.round(clamp(dx * 0.05, 26)), dy: Math.round(clamp(dy * 0.05, 18)) }
}

function hidden(el: HTMLElement, root: HTMLElement): Keyframe {
  const { dx, dy } = inward(el, root)
  return { transform: `translate(${dx}px, ${dy}px) scale(0.9)`, filter: 'blur(8px)' }
}

const shown: Keyframe = { transform: 'none', filter: 'blur(0px)' }

/// The desk's own parts that only fade: the desk icons and the dock.
function chrome(root: HTMLElement): HTMLElement[] {
  return [...root.querySelectorAll<HTMLElement>('[data-desk-fade]')]
}

/// The windows recede and the desk's chrome fades; resolves once they are
/// out of sight, for the desk to stop drawing them.
export async function deskAway(root: HTMLElement): Promise<void> {
  const reduce = reducedMotion(root)
  const exit = ease(root, '--ease-exit', 'cubic-bezier(0.4, 0, 1, 1)')
  const standard = ease(root, '--ease-standard', 'cubic-bezier(0.2, 0.8, 0.2, 1)')
  const anims: Animation[] = []
  for (const { el, index } of windows(root)) {
    if (reduce) {
      anims.push(el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: FADE, fill: 'forwards' }))
      continue
    }
    const delay = index * 40
    anims.push(el.animate([shown, hidden(el, root)], { duration: 320, delay, easing: exit, fill: 'forwards' }))
    anims.push(el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 260, delay, easing: exit, fill: 'forwards' }))
  }
  for (const el of chrome(root)) {
    anims.push(el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: reduce ? FADE : 160, easing: standard, fill: 'forwards' }))
  }
  await Promise.allSettled(anims.map((a) => a.finished))
  // The desk hides them now; what held them out of sight can go.
  requestAnimationFrame(() => anims.forEach((a) => a.cancel()))
}

/// The windows come back, back first, and the chrome fades in after them.
/// Called once they are drawn again.
export function deskBack(root: HTMLElement): void {
  const reduce = reducedMotion(root)
  const spring = ease(root, '--ease-spring', 'cubic-bezier(0.2, 0.8, 0.2, 1)')
  const standard = ease(root, '--ease-standard', 'cubic-bezier(0.2, 0.8, 0.2, 1)')
  const list = windows(root)
  for (const { el, index } of list) {
    if (reduce) {
      el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: FADE, fill: 'backwards' })
      continue
    }
    const delay = 90 + (list.length - 1 - index) * 45
    el.animate([hidden(el, root), shown], { duration: 450, delay, easing: spring, fill: 'backwards' })
    el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 220, delay, easing: standard, fill: 'backwards' })
  }
  for (const el of chrome(root)) {
    el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: reduce ? FADE : 160, delay: reduce ? 0 : 240, easing: standard, fill: 'backwards' })
  }
}

/// The circle the Agent ground opens from: the menubar's Agent mode item,
/// in [ground]'s coordinates, and a radius that covers it all.
function origin(ground: HTMLElement): { x: number; y: number; r: number } {
  const g = ground.getBoundingClientRect()
  const item = document.querySelector<HTMLElement>('.lk-menubar__agent')?.getBoundingClientRect()
  const x = item ? item.left + item.width / 2 - g.left : g.width - 200
  const y = item ? item.top + item.height / 2 - g.top : 0
  const r = Math.hypot(Math.max(x, g.width - x), Math.max(y, g.height - y)) + 2
  return { x, y, r }
}

/// The Agent ground opens and its content rises in: the task columns one
/// after another, then the greeting and the prompt with a spring.
export function agentIn(ground: HTMLElement, content: HTMLElement): void {
  const reduce = reducedMotion(ground)
  if (reduce) {
    ground.animate([{ opacity: 0 }, { opacity: 1 }], { duration: FADE })
    content.animate([{ opacity: 0 }, { opacity: 1 }], { duration: FADE })
    return
  }
  const emphasized = ease(ground, '--ease-emphasized', 'cubic-bezier(0.16, 1, 0.3, 1)')
  const spring = ease(ground, '--ease-spring', 'cubic-bezier(0.2, 0.8, 0.2, 1)')
  const standard = ease(ground, '--ease-standard', 'cubic-bezier(0.2, 0.8, 0.2, 1)')
  const { x, y, r } = origin(ground)
  ground.animate([{ clipPath: `circle(0px at ${x}px ${y}px)` }, { clipPath: `circle(${r}px at ${x}px ${y}px)` }], {
    duration: 677,
    easing: emphasized,
  })
  const rise = (el: Element, delay: number, from: string, duration: number, easing: string) => {
    el.animate([{ transform: from }, { transform: 'none' }], { duration, delay, easing, fill: 'backwards' })
    el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: Math.min(duration, 300), delay, easing: standard, fill: 'backwards' })
  }
  const cols = content.querySelectorAll('.cols > .col')
  const hero = content.querySelector('.hero')
  if (cols.length || hero) {
    cols.forEach((c, i) => rise(c, 200 + i * 50, 'translateY(11px)', 340, emphasized))
    if (hero) rise(hero, 260, 'translateY(21px) scale(0.96)', 560, spring)
  } else {
    // A task open: it rises as one.
    rise(content, 200, 'translateY(11px)', 340, emphasized)
  }
}

/// The Agent content leaves together, then the ground closes back into the
/// Agent mode item; resolves when both are gone.
export async function agentOut(ground: HTMLElement, content: HTMLElement): Promise<void> {
  const reduce = reducedMotion(ground)
  if (reduce) {
    const a = content.animate([{ opacity: 1 }, { opacity: 0 }], { duration: FADE, fill: 'forwards' })
    const b = ground.animate([{ opacity: 1 }, { opacity: 0 }], { duration: FADE, fill: 'forwards' })
    await Promise.allSettled([a.finished, b.finished])
    return
  }
  const exit = ease(ground, '--ease-exit', 'cubic-bezier(0.4, 0, 1, 1)')
  const inOut = ease(ground, '--ease-in-out', 'cubic-bezier(0.65, 0, 0.35, 1)')
  const { x, y, r } = origin(ground)
  const a = content.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-7px)', opacity: 0 }], {
    duration: 120,
    easing: exit,
    fill: 'forwards',
  })
  const b = ground.animate([{ clipPath: `circle(${r}px at ${x}px ${y}px)` }, { clipPath: `circle(0px at ${x}px ${y}px)` }], {
    duration: 450,
    delay: 60,
    easing: inOut,
    fill: 'forwards',
  })
  await Promise.allSettled([a.finished, b.finished])
}
