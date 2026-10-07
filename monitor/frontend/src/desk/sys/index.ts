/// `sys`: everything an app may use of the desk (see `docs/dev/desk-sys.md`).
/// An app imports from here, from `lk` (the lollipopkit Design System) and
/// from shared code outside `desk/`; never from the shell.

export { defineApp, feature, access, type AppManifest, type AppSpec, type Localized, type Opens } from './manifest'
export { registerApp } from './register'
export {
  useWindow,
  OPEN,
  type OpenPath,
  type AppHandler,
  useMenus,
  useDockMenu,
  useIntents,
  useLifecycle,
  type WindowHandle,
  type PaneControls,
  type LifecycleState,
  type Lifecycle,
  type AppMenu,
  type AppIconChrome,
  type AppNotice,
  type AppStorage,
  type Intent,
  type OpenOptions,
  type MenuEntry,
} from './window.svelte'
export { default as AppToolbar } from './AppToolbar.svelte'
export { default as SplitView } from './SplitView.svelte'
export { default as WindowFooter } from './WindowFooter.svelte'
export { systemPrefs, TEXT_SCALE, type SystemPrefsValue, type RefreshSeconds, type Density, type TextSize, type StartApp } from './systemPrefs.svelte'
