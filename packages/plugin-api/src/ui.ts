/**
 * The widget vocabulary. PLUGINS.md section 5.1.
 *
 * A plugin returns a tree; the app builds Flutter widgets from it and lets
 * Flutter's element tree do the diffing. What is here is the builder for that
 * tree, so a plugin author writes `column([...])` rather than JSON.
 *
 * Every type name and every property is permanent, in the same way the host
 * interface is: a published plugin draws through these, and a renamed property
 * is a card that silently stops showing a value. Adding is free; changing is
 * not.
 */

/**
 * A property that follows a named value instead of holding one.
 *
 * The app builds such a leaf as a `ValueListenableBuilder` over a notifier it
 * keeps per slot. A tick that answers `values` instead of `ui` then sets those
 * notifiers, and nothing above the bound leaves is rebuilt at all — no widget
 * walk, no element walk, only the leaf's own RenderObject marked dirty.
 *
 * This is what a Flutter author writes by hand for a value that changes on a
 * timer, rather than calling `setState` on the page.
 */
export interface Binding {
  $: string;
}

/** A property that may hold a value or follow one. */
export type Bindable = string | Binding;

/** Follows the named slot. See {@link Binding}. */
export const bind = (slot: string): Binding => ({ $: slot });

/** One node of the tree. */
export interface Node {
  /** Type name, from the vocabulary below. */
  t: NodeType;

  /**
   * The revision of this subtree, assigned by {@link frame}.
   *
   * A node the app already has this revision of arrives as `{t, k, v}` and the
   * app reuses the Widget it built last time, which is what lets Flutter skip
   * the subtree. Never written by hand.
   */
  v?: number;

  /**
   * Marks this as "you already have this subtree", rather than a node.
   *
   * Written by {@link frame}, never by hand. It is here because the two are
   * otherwise indistinguishable: a `spacer` carries no properties and no
   * children either, so `{t, v}` would mean both "a spacer" and "reuse what
   * you have" — and the app would answer the second by reporting a revision it
   * has never seen.
   */
  s?: 1;

  /**
   * A key that is stable across rebuilds, mapped to a Flutter `ValueKey`.
   *
   * An input control with one keeps its focus and cursor between trees. This is
   * not a nicety: without it, typing in a field on a surface that ticks loses
   * the caret once a second.
   */
  k?: string;

  /** Properties. */
  p?: Record<string, unknown>;

  /** Children. */
  c?: Node[];

  /**
   * Event name to the message handed back to `onEvent` unchanged.
   *
   * The host never reads the message, which is what lets a plugin put a tagged
   * object here and switch on it.
   */
  on?: Record<string, unknown>;
}

export type NodeType =
  // layout
  | "column"
  | "row"
  | "expanded"
  | "padding"
  | "sized"
  | "scroll"
  | "list"
  | "spacer"
  | "divider"
  // content and controls
  | "card"
  | "kv"
  | "expand"
  | "percent"
  | "line_chart"
  | "bar_chart"
  | "btn"
  | "input"
  | "table"
  | "progress"
  | "tag"
  | "text"
  | "icon";

/**
 * How emphatic something is.
 *
 * A name rather than a colour: the app picks from its own theme, so a card
 * stays readable in dark mode and a plugin cannot ship an unreadable one.
 */
export type Tone = "normal" | "muted" | "success" | "warning" | "danger";

/** One line or one set of bars. */
export interface Series {
  label: string;
  values: number[];
  unit?: string;
}

function node(t: NodeType, p?: Record<string, unknown>, c?: Node[]): Node {
  const n: Node = { t };
  if (p && Object.keys(p).length > 0) n.p = p;
  if (c && c.length > 0) n.c = c;
  return n;
}

/**
 * Attaches a stable key.
 *
 * Required on anything the user types into, and on repeated rows so a rebuild
 * does not confuse two of them.
 */
export function key<T extends Node>(n: T, k: string): T {
  return { ...n, k };
}

/** Attaches a message to an event. */
export function on<T extends Node>(n: T, event: string, msg: unknown): T {
  return { ...n, on: { ...(n.on ?? {}), [event]: msg } };
}

export function onTap<T extends Node>(n: T, msg: unknown): T {
  return on(n, "tap", msg);
}

/** Fires as the value changes, with the current value alongside the message. */
export function onChange<T extends Node>(n: T, msg: unknown): T {
  return on(n, "change", msg);
}

/** Sets `tone` on a node that has one. */
export function tone<T extends Node>(n: T, t: Tone): T {
  return { ...n, p: { ...(n.p ?? {}), tone: t } };
}

// ---------------------------------------------------------------- layout

export const column = (children: Node[], p?: { spacing?: number }): Node =>
  node("column", p, children);

export const row = (children: Node[], p?: { spacing?: number }): Node =>
  node("row", p, children);

export const expanded = (child: Node): Node => node("expanded", undefined, [child]);

export const padding = (all: number, child: Node): Node => node("padding", { all }, [child]);

export const sized = (child: Node, p: { width?: number; height?: number }): Node =>
  node("sized", p, [child]);

export const scroll = (children: Node[]): Node => node("scroll", undefined, children);

/**
 * A long list, rendered lazily.
 *
 * Flutter's list is lazy by design — `ListView.builder` only builds what is on
 * screen — and a materialised array throws that away. So a list may describe
 * more rows than it carries: `count` is how many there are, `from` is the index
 * of the first row supplied, and the app asks the plugin's `listWindow` export
 * for the rest as the user scrolls.
 *
 * Send a window a few screens tall. The app requests more without blocking the
 * scroll, showing a placeholder until the answer arrives, so a slow plugin
 * costs a blank row rather than a stuck list.
 *
 * With neither `count` nor `from`, the rows given are the whole list — which is
 * right up to a few dozen and wrong at several hundred.
 *
 * Rows need keys. Without one, reordering makes Flutter match a row against
 * whatever now sits at its index, which throws away that row's element and
 * everything it held.
 */
export const list = (rows: Node[], window?: { count?: number; from?: number }): Node =>
  node("list", window ? { count: window.count ?? rows.length, from: window.from ?? 0 } : undefined, rows);

export const spacer = (): Node => node("spacer");

export const divider = (): Node => node("divider");

// -------------------------------------------------------------- controls

export const card = (children: Node[]): Node => node("card", undefined, children);

/** A label and a value on one line — the app's `KvRow`. */
export const kv = (k: string, v: Bindable): Node => node("kv", { k, v });

/** A tile that opens. `title` is the collapsed line. */
export const expand = (title: Node, children: Node[]): Node =>
  node("expand", { title }, children);

/** `value` is 0..1. */
export const percent = (value: number | Binding, label: string): Node =>
  node("percent", { value, label });

export const lineChart = (series: Series[]): Node => node("line_chart", { series });

export const barChart = (series: Series[]): Node => node("bar_chart", { series });

export const btn = (label: string): Node => node("btn", { label });

export const input = (value: string, p?: { hint?: string; secret?: boolean }): Node =>
  node("input", { value, ...p });

export const table = (header: string[], rows: string[][]): Node =>
  node("table", { header, rows });

/** Determinate when `value` is given, spinning when it is not. */
export const progress = (value?: number | Binding): Node =>
  value === undefined ? node("progress") : node("progress", { value });

export const tag = (label: Bindable): Node => node("tag", { label });

export const text = (value: Bindable): Node => node("text", { value });

export const icon = (name: string): Node => node("icon", { name });

// ------------------------------------------------------------------ l10n

/**
 * A localised string, resolved by the app against `l10n/<locale>.json`.
 *
 * Anything starting `l10n.` is looked up; everything else is shown as typed. So
 * a plugin that ships no translations still works, and one that does needs no
 * API for it.
 */
export function l10n(key: string, ...args: string[]): string {
  if (args.length === 0) return `l10n.${key}`;
  // The whole sentence stays in the translation file and only the values
  // cross. A plugin assembling a sentence out of fragments is the thing that
  // cannot be translated, so there is no interpolation node.
  return [`l10n.${key}`, ...args.map((a) => a.split(L10N_ARG_SEP).join(""))].join(L10N_ARG_SEP);
}

/**
 * The separator between a key and its arguments.
 *
 * A control character rather than something typeable: an argument is a machine
 * name or a `ResetType`, and a plugin must not be able to break its own
 * formatting by containing the separator. {@link l10n} drops it anyway.
 */
export const L10N_ARG_SEP = "\u001F";
