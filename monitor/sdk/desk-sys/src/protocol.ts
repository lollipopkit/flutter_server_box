/// The messages between the desk and an installed app's frame
/// (`docs/dev/desk-sys.md`). Every message carries `sbm: 1`.
///
/// The desk posts `{ sbm, event: 'connect' }` with a `MessagePort` to the
/// frame's first page; everything after goes over that port (a page the
/// frame navigates to later has none).
/// Frame → desk: a call, `{ sbm, id, call, args }`, answered by
/// `{ sbm, re: id, ok: true, value }` or `{ sbm, re: id, ok: false, error }`.
/// Desk → frame: an event, `{ sbm, event, data }`.

export const PROTOCOL = 1

export interface Call {
  sbm: 1
  id: number
  call: string
  args?: unknown
}

export type Reply = { sbm: 1; re: number; ok: true; value?: unknown } | { sbm: 1; re: number; ok: false; error: string }

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
