/// The messages between the desk and an installed app's frame
/// (`docs/dev/desk-sys.md`). Every message carries `sbm: 1`.
///
/// The desk posts `{ sbm, event: 'connect' }` with a `MessagePort` to the
/// frame's first page; everything after goes over that port (a page the
/// frame navigates to later has none).
/// Frame → desk: a call, `{ sbm, id, call, args }`, answered by
/// `{ sbm, re: id, ok: true, value }` or `{ sbm, re: id, ok: false, error,
/// message? }` (`error` a code, `message` the backend's words).
/// Desk → frame: an event, `{ sbm, event, data }`.

export const PROTOCOL = 1

/// How the desk is drawn (`hello`'s `theme`, the `theme` event): its mode,
/// and the CSS custom properties of the theme the account installed, to set
/// on the app's `.lk` root (`applyTheme` in `ui.ts`). Empty for
/// the design system's own; absent from a desk before themes.
export interface AppTheme {
  dark: boolean
  tokens?: Record<string, string>
}

export interface Call {
  sbm: 1
  id: number
  call: string
  args?: unknown
}

export type Reply = { sbm: 1; re: number; ok: true; value?: unknown } | { sbm: 1; re: number; ok: false; error: string; message?: string }

/// What the desk's own dialog says before a call or job runs as root: the
/// desk asks for sudo's password itself (or uses one remembered), so the app
/// never sees it. Plain text; the desk names the app above it.
export interface SudoAsk {
  title: string
  body: string
  /// Typed back first, for a change that loses data.
  confirmWord?: string
}

/// A backend job as the agent reports it (`GET /apps/{id}/jobs`).
export interface JobView {
  id: number
  function: string
  state: 'running' | 'succeeded' | 'failed' | 'cancelled'
  lines: { seq: number; text: string }[]
  /// The next line's sequence number.
  next: number
  /// Once ended well: the function's value.
  value?: unknown
  /// Once ended otherwise: its code and words.
  error?: { error: string; message?: string }
}

export interface Event {
  sbm: 1
  event: string
  data?: unknown
}

/// A toolbar button or menu row the app describes; the desk draws it and
/// sends `action` with its id when used.
export interface ActionItem {
  id: string
  label: string
  icon?: string
  shortcut?: string
  checked?: boolean
  disabled?: boolean
  danger?: boolean
  separator?: boolean
}

export interface MenuDescription {
  label: string
  items: ActionItem[]
}

export interface ToolbarDescription {
  title?: string
  subtitle?: string
  actions?: ActionItem[]
}

export function isCall(data: unknown): data is Call {
  const d = data as Partial<Call> | null
  return !!d && d.sbm === PROTOCOL && typeof d.id === 'number' && Number.isSafeInteger(d.id) && typeof d.call === 'string'
}
