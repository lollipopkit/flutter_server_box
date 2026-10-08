/// How an installed app looks like the desk around it, with no UI code of
/// its own: the desk serves its design system to the frame (`_desk/desk.css`,
/// the `lk-*` classes, the tokens and their fonts), and this puts it on the
/// page and keeps it in the desk's mode and theme. The app writes markup
/// with those classes and tokens (docs/dev/desk-sys.md, "UI"); outside the
/// desk there is nothing to load, so it is the desk's to use only.

import type { AppTheme } from './protocol.js'

/// Loads the desk's stylesheet into [doc]; settles once it applied or
/// failed (an agent without it), or after [timeout] ms, so the app never
/// waits on it for good.
export function useStylesheet(url: string, doc: Document = document, timeout = 5000): Promise<void> {
  const link = doc.createElement('link')
  link.rel = 'stylesheet'
  link.href = url
  // First, so the app's own styles come after it and win.
  doc.head.prepend(link)
  return new Promise((resolve) => {
    const done = () => resolve()
    link.addEventListener('load', done, { once: true })
    link.addEventListener('error', done, { once: true })
    setTimeout(done, timeout)
  })
}

const applied = new WeakMap<HTMLElement, string[]>()

/// Draws [root] (`<body>`, which gets the `lk` class the design system is
/// scoped to) the way the desk is drawn: the mode on `<html>`, where the dark
/// tokens key on it, and the installed theme's tokens on [root], where they
/// win over the defaults. Only custom properties are set.
export function applyTheme(theme: AppTheme, root: HTMLElement = document.body) {
  root.ownerDocument.documentElement.dataset.theme = theme.dark ? 'dark' : 'light'
  root.classList.add('lk')
  for (const name of applied.get(root) ?? []) root.style.removeProperty(name)
  const tokens = Object.entries(theme.tokens ?? {}).filter(([name]) => name.startsWith('--'))
  for (const [name, value] of tokens) root.style.setProperty(name, value)
  applied.set(
    root,
    tokens.map(([name]) => name),
  )
}
