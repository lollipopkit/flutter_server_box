# The desk (the panel's web desktop)

The panel is a macOS-style desktop: a lock screen to choose a server, then that server's desk — menubar, dock, launchpad, windows, Spotlight, notification centre, desk icons. Everything the panel does is an app in a window. Agent side: `monitor/src/api/desk.rs` (`/desk*`, see `monitor/CLAUDE.md`).

## Layout

- `DeskRoot.svelte` — lock screen (`lock/LockScreen.svelte`) over one server's `Desk.svelte`, keyed by server id + token. Switching servers unmounts the desk (its agent keeps its windows); locking keeps it.
- `deskState.svelte.ts` — `Desk`: windows, prefs, notifications, the shell's open panel/menu/Spotlight. `useDesk()` is for the shell only; **an app uses `useWindow()` and nothing else of the desk** (the one exception: Settings' Appearance section uses `useDeskAppearance()`).
- `windows.svelte.ts` (state, no DOM) + `geometry.ts` (pure) — tested in `tests/deskWindows.test.ts`. `window/Window.svelte` is the chrome (pointer events: drag, 8 edges, snap to halves/top, double-click zoom).
- `session.svelte.ts` (window session, revision CAS, the focused tab wins), `prefs.svelte.ts`, `notifications.svelte.ts`, `storage.ts` (`AgentStorage` when the agent lists `desk`, `BrowserStorage` otherwise), `deskApi.ts` (always to an explicit `ServerEntry`).
- `shell/` — Menubar, Dock, Launchpad, ControlCenter, NotificationCenter, CalendarPanel, Spotlight, Banner, ContextMenu, DeskIcons, Wallpaper, AppIcon.
- `apps.ts` — **the only list of apps** (id, title, icon, tint, availability, instances, sizes, lazy `load`). `apps/<id>/` holds each app.
- `ui/` — what apps are built from: `AppToolbar`, `SplitView` (sidebar + content, the sidebar folds below `@3xl`), `SourceGroup` (`boxed` for Settings-style cards)/`SourceItem` (sidebar rows), `Section` (titled card, count, actions), `Segmented` (a few views or values), `StatusPill` (ACTIVE/EXITED-style state).
- `desk.css` — the palette (`--glass` light surface, `--ink` text and borders; dark swaps them), the shared kit's `--sb-*` tokens set from it inside `.desk-root` (so `bg`, `surface`, `fg`, `line`, `soft`, `primary`, `Button`, `IconButton` follow the mode and the accent), and `desk-*` classes in `@layer components`. Shell parts use these, never raw colours.

## Look: Bloom (after ClawBox, `/Users/lk/proj/claw-box/webui`, reference only)

The design is called Bloom (after its default wallpaper): soft blooms of colour, a berry accent, opaque sheets.


- Windows and panels are opaque sheets (white / black), hairline borders, soft shadows, large radii; the menubar and dock are frosted glass over the wallpaper.
- The accent (default berry `#8b2252`) marks what is chosen: a tint plus a tinted border (`desk-chosen`), never a solid black fill. A primary `Button` is the accent.
- App icons are one glyph on a neutral tile (`AppIcon`), no colours per app.
- Panels open over the dock (launchpad, Spotlight centred; control centre, notifications, calendar at the right) with `PanelHead`: a capitalised eyebrow, a bold title, a rule.
- In apps: content as `Section` cards (radius 24, bold 18px titles, a count circle), state as `StatusPill`, choices as `Segmented`, actions as bordered `IconButton`s in the `AppToolbar`.

## Rules

- **Minimised windows are hidden, never unmounted**; windows are keyed by id. An app keeps its state and sockets while open.
- **A window body is a size container.** Apps use container variants (`@md:`, `@3xl:`), never viewport breakpoints (`sm:`, `md:`, `lg:`): a narrow window on a wide screen must lay out narrow.
- No `min-h-screen`, `h-screen`, `100vh`/`dvh` inside an app: the window is the screen. Use `h-full`/`min-h-full`.
- `position: fixed` inside an app is relative to its window (the window's `backdrop-filter` makes it the containing block): a `Modal` is a sheet over its window, which is intended, and scrolls inside it when taller.
- An app never imports `layout`, `Sidebar`, `PageHeader` or `FeatureTabs` (being deleted). Its first element is `ui/AppToolbar.svelte` (no title at the app's first view — the window shows it; `title` + `back` for a view inside the app).
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
