/// `sys`: everything an app may use of the desk (see `docs/dev/desk-sys.md`).
/// An app imports from here, from `lk` (the lollipopkit Design System) and
/// from shared code outside `desk/`; never from the shell.

export { defineApp, feature, access, type AppManifest, type AppSpec, type Localized } from './manifest'
export { registerApp } from './register'
export {
  useWindow,
  useMenus,
  useLifecycle,
  type WindowHandle,
  type LifecycleState,
  type Lifecycle,
  type AppMenu,
  type AppIconChrome,
  type MenuEntry,
} from './window.svelte'
export { default as AppToolbar } from './AppToolbar.svelte'
export { default as SplitView } from './SplitView.svelte'
