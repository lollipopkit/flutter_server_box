/// How the desk is drawn, as `lkui` hands it to an app
/// (`info.theme`, then each `theme` event): its mode, and the tokens of the
/// theme the account installed (empty for the design system's own).
export interface DeskTheme {
  dark: boolean
  tokens?: Record<string, string>
}

const applied = new WeakMap<HTMLElement, string[]>()

/// Draws [root] (the element with the `lk` class, `<body>` by default) the
/// way the desk is drawn: the mode on `<html>`, as the tokens key on it, and
/// the theme's tokens on [root], where they win over the defaults. Call it
/// with `info.theme` and again on every `theme` event.
export function applyTheme(theme: DeskTheme, root: HTMLElement = document.body) {
  document.documentElement.dataset.theme = theme.dark ? 'dark' : 'light'
  root.classList.add('lk')
  for (const name of applied.get(root) ?? []) root.style.removeProperty(name)
  const tokens = Object.entries(theme.tokens ?? {}).filter(([name]) => name.startsWith('--'))
  for (const [name, value] of tokens) root.style.setProperty(name, value)
  applied.set(
    root,
    tokens.map(([name]) => name),
  )
}
