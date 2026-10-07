# The desk (the panel's web desktop)

The panel is a macOS-style desktop: a lock screen to choose a server, then that server's desk — menubar, dock, launchpad, windows, Spotlight, notification centre, desk icons. Everything the panel does is an app in a window. Agent side: `monitor/src/api/desk.rs` (`/desk*`, see `monitor/CLAUDE.md`).

## Layout

- `DeskRoot.svelte` — lock screen (`lock/LockScreen.svelte`) over one server's `Desk.svelte`, keyed by server id + token. Switching servers unmounts the desk (its agent keeps its windows); locking keeps it.
- `sys/` — **the app framework, the only way an app reaches the desk** (design and phases: `docs/dev/desk-sys.md`): `defineApp` (manifest), `registerApp`, `useWindow()` (state, title, app name/icon/badge, open, lifecycle), `useMenus()` (menubar menus; `shortcut`s run while the window is in front, `shortcuts.ts`), `useLifecycle()` (`active`/`visible`/`background`/`suspended`, `keepAlive`), `useDockMenu()`, `useWindow().notify()` and `.storage` (`appData.ts`), `AppToolbar`, `SplitView`. ESLint enforces it: an app imports `sys`, `lk` and code outside `desk/`, never the shell or another app (Settings alone may use `useDeskPrefs()`, `prefs.svelte`, `shell/Wallpaper`).
- `deskState.svelte.ts` — `Desk`: windows, prefs, notifications, each window's `WindowChrome` (`chromes`), lock/tab visibility, the shell's open panel/menu/Spotlight. `useDesk()` is for the shell only.
- `windows.svelte.ts` (state, no DOM) + `geometry.ts` (pure) — tested in `tests/deskWindows.test.ts`. `window/Window.svelte` is the chrome (pointer events: drag, 8 edges, snap to halves/top, double-click zoom).
- `session.svelte.ts` (window session, revision CAS, the focused tab wins), `prefs.svelte.ts`, `notifications.svelte.ts`, `storage.ts` (`AgentStorage` when the agent lists `desk`, `BrowserStorage` otherwise), `deskApi.ts` (always to an explicit `ServerEntry`).
- `shell/` — Menubar, Dock, Launchpad, ControlCenter, NotificationCenter, CalendarPanel, Spotlight, Banner, ContextMenu, DeskIcons, Wallpaper, AppIcon.
- `apps/<id>/` holds each app; **its `manifest.ts` (`defineApp`) is the app's only registration** (`apps/index.ts` finds them; `registry.svelte.ts` is the list the shell reads). Adding an app is adding its directory.
- `ui/` — TODO-remove shims. `lk/` — the design system (below).
- `desk.css` — window placement and animation, wallpaper light/dark; imports `lk/lk.css`.

## Design system: lollipopkit (`lk/`)

The desk follows the lollipopkit Design System exactly; `lk/` is its Svelte form. **Apps build their UI from `lk` and nothing else.**

- `lk/lk.css` — tokens (`--color-accent`, `--surface-*`, `--text-*`, `--border-hairline`, `--fill-hover`, `--space-*` odd scale 3/5/7/9/11/13/17/21/27/34/55, `--radius-*` 5/7/9/11/13/17/21/27, `--shadow-*`, `--glass-*`, `--dur-*`/`--ease-*` springs) scoped to `.lk`; dark via `data-theme="dark"` on <html> (`lib/theme.svelte.ts`). `lk-*` classes in `@layer components`. Values are the design system's; never invent one.
- Components (`lk/index.ts`): Icon (Material Symbols Rounded by name), Button (primary/secondary/tinted/ghost/destructive), IconButton, Badge, Input, Textarea, Select, Checkbox, Radio, Switch, Slider, SegmentedControl, Card (flat/raised/glass), Tooltip, Dialog, Notification, Menu, AppIcon, TrafficLights, SidebarSection, SidebarItem, ControlTile, Group + Row (settings lists).
- Rules: one seed (berry `#730c37`, no accent picker); Figtree 13px body, JetBrains Mono for paths/permissions/terminal (`lk-mono`), tabular figures (`lk-num`); flat cards (no border, no shadow; `raised` only on a tinted ground); one hairline (`--border-hairline`, 0.5px); glass only for chrome over the wallpaper; selection in lists solid accent with white text, in sidebars soft accent with a filled glyph; segmented thumb raised white, never inverted; section headings `lk-caps`; sentence case, dry copy, no emoji; empty state = one 44–56px glyph + at most two words; press = shrink and spring back.
- Icons: Material Symbols Rounded names only (no lucide in new code, no hand-drawn SVG). App icons: `AppIcon` glyph + tone from the app's manifest (an app may change them while it runs: `setIcon`).
- The window frame (`window/Window.svelte`) draws the title bar and the inset sidebar; an app puts its title/tools there with `sys.AppToolbar` and its sidebar with `sys.SplitView` (they register into `useWindow().chrome`). `ui/SourceGroup`, `SourceItem`, `Segmented`, `Section`, `StatusPill` are TODO-remove shims; use `lk` instead.
- Never name where the design system was authored, in code or commits: it is "the lollipopkit Design System".

## Rules

- **A hidden window (minimised, desk locked, tab hidden) is not drawn but keeps running**; windows are keyed by id. With background running off (Settings → Apps) its content is unmounted after 5 s (`suspended`) and mounted again when shown, so an app restores itself from `appState`, saved as it changes. Work done only for the eye (polling a chart) stops while `useLifecycle().state` is `background`.
- **A window body is a size container.** Apps use container variants (`@md:`, `@3xl:`), never viewport breakpoints (`sm:`, `md:`, `lg:`): a narrow window on a wide screen must lay out narrow.
- No `min-h-screen`, `h-screen`, `100vh`/`dvh` inside an app: the window is the screen. Use `h-full`/`min-h-full`.
- `position: fixed` inside an app is relative to its window (`.desk-window` has `contain: layout`, which makes it the containing block): a `Modal` is a sheet over its window, which is intended, and scrolls inside it when taller.
- An app never imports `layout`, `Sidebar`, `PageHeader` or `FeatureTabs` (being deleted). Its first element is `AppToolbar` from `sys` (no title at the app's first view — the window shows it; `title` + `back` for a view inside the app).
- Going to another app: `useWindow().open(appId, { appState })`. The receiving app reads `useWindow().appState` once on mount (and `$effect` on it if it should follow a second open, e.g. Files given a new path).
- Per-window state worth restoring after a reload (a path, a tab): `useWindow().setAppState(...)` — small JSON, ≤16 KiB, never secrets.
- Window title for a view inside the app: `useWindow().setTitle(...)`; `null` restores the app's name.
- Pages are per server: `servers.current` is this desk's server for the desk's whole life. The existing `stale(serverId)` guards stay.
- New shell text goes into `en` and `zh-CN` as `desk*` keys; the other locales are filled in one pass (every locale must have every key, `satisfies Translation`).
- `useDesk()`'s `menu`/`panel` are single: one context menu, one panel at a time; `Escape` closes them.

## Porting a page to an app (the recipe)

1. `git mv src/pages/X.svelte src/desk/apps/<id>/XApp.svelte` (replacing the temporary wrapper), and `git mv` the components only it uses into the same directory. Components used by several apps stay in `src/components/` and are not edited in a port.
2. Drop `Props { onback }`, `FeatureTabs`, `PageHeader`, `layout`. The page's header actions go into `AppToolbar`'s `actions`; a drill-down (detail view) gets `title` + `back`.
3. `layout.navigate('terminal')`-style jumps become `useWindow().open('terminal', …)`.
4. Breakpoints: `sm:` → `@2xl:`, `md:` → `@3xl:`, `lg:` → `@5xl:`, `xl:` → `@7xl:` (container sizes approximate the old viewport ones). Outer `max-w-* mx-auto px-4 sm:px-6 lg:px-8 py-8` becomes `mx-auto max-w-* px-4 py-4 @3xl:px-6`.
5. Its test (`src/tests/<x>.test.ts`) imports the new path and renders the app without `onback`; behaviour assertions stay.
6. Check: `npx svelte-check` (only locale gaps may remain), `npx eslint <files> --max-warnings 0`, `npx vitest run <its tests>`.
