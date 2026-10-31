# The desk (the panel's web desktop)

The panel is a macOS-style desktop: a lock screen to choose a server, then that server's desk (menubar, dock, Apps, windows, Spotlight, notification centre). Every feature is an app in a window. Agent side: `monitor/src/api/desk.rs`. **Details of each piece (web apps, packages, themes, Agent mode, the guide, the shell): `docs/dev/desk.md`**; the app framework's design: `docs/dev/desk-sys.md`.

## Layout

- `DeskRoot.svelte`: the lock screen (`lock/`) over one server's `Desk.svelte`, keyed by server id + token. Switching servers unmounts the desk; locking keeps it.
- `sys/`: **the app framework, the only way an app reaches the desk**: `defineApp`, `useWindow()` (state, title, open, notify, storage), `useMenus()`, `useLifecycle()`, `useIntents()`, `AppToolbar`, `SplitView`, `WindowFooter`, `PageStack`. ESLint enforces it: an app imports `sys`, `lk` and code outside `desk/`, never the shell or another app (Settings alone may use `useDeskPrefs()`, `prefs.svelte`, `themes.svelte`, `shell/Wallpaper`).
- `apps/<name>/`: **its `manifest.ts` (`defineApp`) is the app's only registration**; adding an app is adding its directory. Ids are `<publisher>.<name>` (the panel's own `serverbox.<name>`).
- `deskState.svelte.ts` (`Desk`, `useDesk()` for the shell only), `windows.svelte.ts` + `geometry.ts` (pure, `tests/deskWindows.test.ts`), `window/Window.svelte` (the chrome), `session.svelte.ts` (revision CAS), `prefs.svelte.ts` (per account), `shellPrefs.svelte.ts` (per browser), `storage.ts`, `deskApi.ts`.
- `shell/`: menubar, dock, Apps, Control Centre, notifications, Spotlight, context menu. `webapps/`: installed apps in sandboxed iframes and their bridge. `agent/`: Agent mode, a desk mode rather than an app. `guide/`: the first-run guide.
- `lk/`: the design system; the whole page is drawn in it. `desk.css`: window placement and animation.

## Design system: lollipopkit (`lk/`)

**Apps build their UI from `lk` and nothing else**; values are the design system's, never invented. Installed apps get it as an interface (`/desk-app/desk.css`), never the code: classes and tokens are a contract with them (`docs/dev/desk-sys.md`, UI).

- Tokens on `.lk` (`--color-accent`, `--surface-*`, `--text-*`, `--space-*` odd scale, `--radius-*`, `--dur-*`/`--ease-*`); dark via `data-theme="dark"` on `<html>`. Components are listed in `lk/index.ts`.
- One seed (berry `#730c37`, no accent picker); Figtree 13px, JetBrains Mono for paths (`lk-mono`), tabular figures (`lk-num`); flat cards; one 0.5px hairline; glass only for chrome over the wallpaper; list selection solid accent, sidebar selection soft accent; section headings `lk-caps`; sentence case, no emoji; empty state = one glyph + at most two words.
- **Tab motion wherever a view is one of N peers**: one indicator glides (`lk/Indicator.svelte`), the incoming view fades in (`use:viewIn`), no slide; tabs grow in and shrink out. Sidebar navigation does not slide.
- Icons: Material Symbols Rounded names only (no lucide, no hand-drawn SVG).
- The window draws the 52px title bar (floating over the scrolling content) and the inset sidebar; an app fills them with `sys.AppToolbar` and `sys.SplitView`. A view starting with a `DataTable` sets `flush`. Lists are `DataTable`s with the selection's actions in `sys.WindowFooter`.
- Never name where the design system was authored, in code or commits: it is "the lollipopkit Design System".

## Rules

- **A hidden window is not drawn but keeps running**; with background running off it unmounts after 5 s and restores itself from `appState`. Work done only for the eye stops while `useLifecycle().state` is `background`.
- An app's first element is `sys.AppToolbar` (no title at its first view; `title` + `back` inside it). Per-window state worth a reload goes in `useWindow().setAppState(...)` (≤16 KiB JSON, never secrets); a view's title in `setTitle`.
- **A window body is a size container**: container variants (`@md:`, `@3xl:`), never viewport breakpoints; no `h-screen`/`100vh`. `position: fixed` is relative to the window. Wide windows: forms `pane-form` (640), reading `pane-reading` (720), boards `pane-board` (1280), tables fill; the sidebar never grows.
- **Pages inside an app go through `sys.PageStack`** (`key`, `depth`, optional `back`/`forward` swipes). In a window it is the scrolling body: each page scrolls by itself, and a page gone back to returns to where it was left, also once its fetched content arrives. Never offer a swipe that ends something.
- **Tabs and split panes** (manifest `panes: true`): `window/PaneHost.svelte` runs the app once per pane with its own `useWindow()`; panes stay mounted (hidden `visibility` + `inert`), so key what outlives a mount by pane id. More windows of an app: `useWindow().openWindow(appState)`.
- Going to another app: `useWindow().open(appId, { appState })` or `{ intent }`, never a shared module-level slot.
- Pages are per server; a late answer is dropped through `useScope()` (`lib/scope.svelte.ts`). Requests go through `lib/api.ts`'s `fetchFor`; a failure shown is `errorText(e)`, never an English fallback. Timers over every server go through `lib/eachServer.ts`.
- Preferences: per browser `lib/displayPrefs.svelte.ts` (every time through `fmtDate`, every size through `fmtBytes`), `sys.systemPrefs`, `shellPrefs`; per account `prefs.svelte.ts` and each app's own `storage`.
- New shell text goes into `en` and `zh-CN` as `desk*` keys; the other locales are filled in one pass (every locale must have every key).
- Check a change with `npx svelte-check`, `npx eslint <files> --max-warnings 0`, `npx vitest run <tests>`.
