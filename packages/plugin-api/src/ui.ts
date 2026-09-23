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
  | "flexible"
  | "align"
  | "wrap"
  | "stack"
  | "positioned"
  | "padding"
  | "sized"
  | "scroll"
  | "list"
  | "spacer"
  | "divider"
  | "refresh"
  | "dismiss"
  | "tabs"
  | "grid"
  | "reorder"
  | "container"
  | "aspect"
  | "constrained"
  | "opacity"
  | "clip"
  // content and controls
  | "card"
  | "tile"
  | "summary"
  | "kv"
  | "expand"
  | "percent"
  | "line_chart"
  | "bar_chart"
  | "pie_chart"
  | "banner"
  | "badge"
  | "tooltip"
  | "skeleton"
  | "btn"
  | "input"
  | "toggle"
  | "checkbox"
  | "segmented"
  | "dropdown"
  | "slider"
  | "chip"
  | "menu"
  | "table"
  | "progress"
  | "tag"
  | "text"
  | "rich"
  | "span"
  | "image"
  | "icon";

/**
 * How emphatic something is.
 *
 * A name rather than a colour: the app picks from its own theme, so a card
 * stays readable in dark mode and a plugin cannot ship an unreadable one.
 */
export type Tone = "normal" | "muted" | "success" | "warning" | "danger";

/**
 * Where children sit along the axis a {@link row} or {@link column} runs in —
 * Flutter's `MainAxisAlignment`, by name.
 *
 * Asking for one makes the row or column *fill* its axis, because there is
 * nothing to distribute otherwise.
 */
export type Main = "start" | "center" | "end" | "between" | "around" | "evenly";

/** Where children sit across that axis — `CrossAxisAlignment`, by name. */
export type Cross = "start" | "center" | "end" | "stretch";

/**
 * A corner or an edge, in reading order.
 *
 * `start` is the left in English and the right in Arabic, which is why these
 * are not called `left` and `right`.
 */
export type At =
  | "topStart"
  | "top"
  | "topEnd"
  | "start"
  | "center"
  | "end"
  | "bottomStart"
  | "bottom"
  | "bottomEnd";

/**
 * How large a piece of text is, by what it *is* rather than in points.
 *
 * `md` is body text and the default. `xl` is the figure a {@link summary}
 * draws, so a heading built by hand lands on the same size as the app's own.
 * Named for `tone`'s reason: a plugin naming a point size would be shipping a
 * page that stops matching the app the moment the app's own scale moves.
 */
export type TextSize = "xs" | "sm" | "md" | "lg" | "xl";

export type Weight = "normal" | "medium" | "bold";

/** Padding, as `all` or as any of the four sides. A side wins over `all`. */
export interface Sides {
  all?: number;
  /** The leading edge — left in English, right in Arabic. */
  l?: number;
  t?: number;
  /** The trailing edge. */
  r?: number;
  b?: number;
}

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

/**
 * What happens when this is tapped: a **function**, or a message to switch on.
 *
 * ```ts
 * onTap(btn("Reload"), () => ref.invalidate(jobs))   // a closure
 * onTap(tile({ title }), { m: "open", path })        // a message
 * ```
 *
 * A function is kept by the SDK and crosses as a token — see `callback` in
 * `surface.ts`. It is the shape to reach for: a plugin that writes closures
 * never has a handler and a control disagree about what a message means, which
 * is the bug this replaced.
 */
export function onTap<T extends Node>(n: T, handler: EventHandler): T;
export function onTap<T extends Node>(n: T, msg: unknown): T;
export function onTap<T extends Node>(n: T, msg: unknown): T {
  return on(n, "tap", asMessage(msg));
}

/**
 * What a control hands back when it fires.
 *
 * `value` is the control's own — the text in a box, the state of a switch, the
 * chosen option. A tap has none.
 *
 * Declared as an overload on each `on*` so an arrow function's parameter is
 * typed: with a bare `unknown` the parameter is implicitly `any` and every
 * plugin has to annotate it.
 */
export type EventHandler = (value?: unknown) => void | Promise<void>;

/**
 * A function becomes a token; anything else crosses as it is.
 *
 * Set by `surface()`, because `ui.ts` cannot depend on the reactive layer
 * without every plugin that only draws paying for it.
 */
let toMessage: ((fn: (value?: unknown) => void | Promise<void>) => unknown) | null = null;

/** @internal Called by `surface()`. */
export function installCallbacks(
  fn: (handler: (value?: unknown) => void | Promise<void>) => unknown,
): void {
  toMessage = fn;
}

function asMessage(msg: unknown): unknown {
  if (typeof msg !== "function") return msg;
  if (toMessage === null) {
    throw new Error(
      "a function handler needs `surface()` — export it with " +
        "`export const { open, onEvent } = surface(build)`",
    );
  }
  return toMessage(msg as (value?: unknown) => void | Promise<void>);
}

/**
 * The second gesture a row has: "what else can I do with this".
 *
 * Honoured on any node, like {@link onTap}. On a phone it is how a list row
 * offers anything beyond its one obvious action.
 */
export function onLongPress<T extends Node>(n: T, handler: EventHandler): T;
export function onLongPress<T extends Node>(n: T, msg: unknown): T;
export function onLongPress<T extends Node>(n: T, msg: unknown): T {
  return on(n, "long_press", asMessage(msg));
}

/** Fires as the value changes, with the current value alongside the message. */
export function onChange<T extends Node>(n: T, handler: EventHandler): T;
export function onChange<T extends Node>(n: T, msg: unknown): T;
export function onChange<T extends Node>(n: T, msg: unknown): T {
  return on(n, "change", asMessage(msg));
}

/** Sets `tone` on a node that has one. */
export function tone<T extends Node>(n: T, t: Tone): T {
  return { ...n, p: { ...(n.p ?? {}), tone: t } };
}

// ---------------------------------------------------------------- layout

export const column = (
  children: Node[],
  p?: { spacing?: number; main?: Main; cross?: Cross },
): Node => node("column", p, children);

export const row = (
  children: Node[],
  p?: { spacing?: number; main?: Main; cross?: Cross },
): Node => node("row", p, children);

/**
 * Takes exactly its share of the remaining space, in a {@link row} or a
 * {@link column}.
 *
 * Anywhere else it is the child alone: an `Expanded` outside a flex throws at
 * layout time and takes the whole surface with it, so the app degrades it
 * instead.
 */
export const expanded = (child: Node, flex?: number): Node =>
  node("expanded", flex === undefined ? undefined : { flex }, [child]);

/** Takes *at most* its share — the difference from {@link expanded}. */
export const flexible = (child: Node, flex?: number): Node =>
  node("flexible", flex === undefined ? undefined : { flex }, [child]);

/** Puts a child somewhere in the space its parent gave it. */
export const align = (child: Node, at: At = "center"): Node =>
  node("align", { at }, [child]);

/** {@link align} at the middle, which is most of what it is used for. */
export const center = (child: Node): Node => align(child, "center");

/**
 * A row that starts a new line when it runs out of width.
 *
 * What a set of tags needs: a `row` of them overflows into a striped bar the
 * moment one machine has more labels than another.
 */
export const wrap = (
  children: Node[],
  p?: { spacing?: number; run?: number },
): Node => node("wrap", p, children);

/**
 * Children drawn over one another, sized by the first.
 *
 * For a badge on a corner, a label over a chart. Position the ones after the
 * first with {@link positioned}; anywhere else `positioned` is the child alone.
 */
export const stack = (children: Node[]): Node => node("stack", undefined, children);

export const positioned = (
  child: Node,
  p: { l?: number; t?: number; r?: number; b?: number; width?: number; height?: number },
): Node => node("positioned", p, [child]);

/** `padding(13, x)` for all four sides, or `padding({t: 13}, x)` for one. */
export const padding = (edges: number | Sides, child: Node): Node =>
  node("padding", typeof edges === "number" ? { all: edges } : { ...edges }, [child]);

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

/**
 * One row of a list, drawn the way the app draws its own.
 *
 * Reach for this before assembling a row out of {@link row} and {@link text}.
 * A page is usually a list of things with a name, a detail under it and a
 * reading on the right, and hand-building that gives every plugin a slightly
 * different rhythm from the app and from every other plugin. This is the app's
 * dense `ListTile`: a leading icon, a title, a subtitle, and a trailing node.
 *
 * Put a run of these inside one {@link card} rather than a card each — a card
 * per fact is what makes a page of five rows fill a window.
 *
 * `icon` names one of the fixed set (see {@link Icon}); an unknown name draws
 * nothing rather than failing the row.
 */
export const tile = (t: {
  title: Bindable;
  subtitle?: Bindable;
  icon?: string;
  trailing?: Node;
  /**
   * Whether this row is one of the chosen ones.
   *
   * Drawn the way the app draws its own selected rows, which is the point of
   * having it here: a plugin that expressed a selection by swapping an icon
   * asked the reader to notice one grey glyph turning into another, and a list
   * of five picked rows looked the same as a list of five unpicked ones.
   */
  selected?: boolean;
}): Node =>
  node(
    "tile",
    {
      title: t.title,
      ...(t.subtitle === undefined ? {} : { subtitle: t.subtitle }),
      ...(t.icon === undefined ? {} : { icon: t.icon }),
      ...(t.selected ? { selected: true } : {}),
    },
    t.trailing ? [t.trailing] : undefined,
  );

/**
 * The block at the top of a page: what the page answers, in one reading.
 *
 * `value` is the figure — large, and the first thing read. `label` says what
 * it counts, `detail` qualifies it, and `actions` sit on the right. Separated
 * from the list below it by its own weight rather than by a divider, so a page
 * has two levels instead of one.
 */
export const summary = (s: {
  value: Bindable;
  label?: Bindable;
  detail?: Bindable;
  actions?: Node[];
}): Node =>
  node(
    "summary",
    {
      value: s.value,
      ...(s.label === undefined ? {} : { label: s.label }),
      ...(s.detail === undefined ? {} : { detail: s.detail }),
    },
    s.actions,
  );

/** A label and a value on one line — the app's `KvRow`. */
export const kv = (k: string, v: Bindable): Node => node("kv", { k, v });

/** A tile that opens. `title` is the collapsed line. */
export const expand = (title: Node, children: Node[]): Node =>
  node("expand", { title }, children);

/** `value` is 0..1. */
export const percent = (value: number | Binding, label: string): Node =>
  node("percent", { value, label });

/**
 * A reading over time, drawn the way the app draws its own history.
 *
 * No x axis: the values are a series with no labels for them, and an axis of
 * indices says nothing. Several series are drawn together with a legend under
 * them; the unit comes from the first.
 */
export const lineChart = (series: Series[], p?: { height?: number }): Node =>
  node("line_chart", { series, ...p });

/** The same, as bars — grouped by index when there is more than one series. */
export const barChart = (series: Series[], p?: { height?: number }): Node =>
  node("bar_chart", { series, ...p });

/**
 * Parts of one whole, which is the question a bar chart cannot answer.
 *
 * The values are taken as given: what a share is *of* is the plugin's
 * business, and normalising here would draw a full circle for a disk that is
 * half empty.
 */
export const pieChart = (slices: { label: string; value: number }[]): Node =>
  node("pie_chart", { slices });

/**
 * Something the page has to say about itself: a warning, an error, a note.
 *
 * A block rather than a toast, because it is a *state* — this connection has no
 * `cron`, that directory could not be read — and a toast is gone in three
 * seconds. `tone` colours it; an `action` is a button on the right.
 */
export const banner = (
  text: Bindable,
  p?: { icon?: string; action?: Node },
): Node =>
  node("banner", { text, ...(p?.icon === undefined ? {} : { icon: p.icon }) },
    p?.action ? [p.action] : undefined);

/** A count or a dot on the corner of something. */
export const badge = (child: Node, p?: { label?: string; dot?: boolean }): Node =>
  node("badge", p, [child]);

/** What a control is for, in words — for the ones an icon cannot say. */
export const tooltip = (child: Node, message: string): Node =>
  node("tooltip", { message }, [child]);

/**
 * The shape of what is coming, while it is being fetched.
 *
 * A page that shows a spinner in the middle and then jumps to a full list moves
 * everything the eye had settled on.
 */
export const skeleton = (rows = 3): Node => node("skeleton", { rows });

/**
 * A box with a background, a border and a corner.
 *
 * **Colours are still names**: `bg` and `border` take a {@link Tone} or
 * `card`/`surface`, and what those look like is the theme's. A tone as a
 * background is drawn faint, the way a tag is — asking for `danger` gets a
 * danger-coloured block, not a red rectangle with unreadable text on it.
 */
export const container = (
  child: Node,
  p: {
    bg?: Tone | "card" | "surface";
    border?: Tone | "card" | "surface";
    borderWidth?: number;
    radius?: number;
  } & Sides,
): Node => node("container", { ...p }, [child]);

/** A box of a given shape, whatever width it is given. */
export const aspect = (child: Node, ratio: number): Node =>
  node("aspect", { ratio }, [child]);

export const constrained = (
  child: Node,
  p: { minWidth?: number; maxWidth?: number; minHeight?: number; maxHeight?: number },
): Node => node("constrained", p, [child]);

/** `0` is invisible and `1` is as it is. Out of range is clamped, not refused. */
export const opacity = (child: Node, value: number): Node =>
  node("opacity", { value }, [child]);

/** Rounds the corners of whatever is inside — an image, a chart, a container. */
export const clip = (
  child: Node,
  p?: { radius?: number; shape?: "rect" | "oval" },
): Node => node("clip", p, [child]);

/**
 * A paragraph with more than one style in it.
 *
 * Children are {@link span}s. A span with a tap is a link, which is the reason
 * this exists at all: a tappable *word* cannot be a row of texts, and a row of
 * texts does not wrap as a sentence either.
 */
export const rich = (spans: Node[]): Node => node("rich", undefined, spans);

/** One run inside a {@link rich}. Takes the same knobs as {@link text}. */
export const span = (
  value: string,
  p?: { size?: TextSize; weight?: Weight; mono?: boolean; tone?: Tone },
): Node => node("span", { value, ...p });

/**
 * A file the plugin shipped, from its own `assets/` directory.
 *
 * **Only that** — there is no URL form. An image fetched as it is drawn is a
 * request to somewhere every time a card is on screen, which is a tracking
 * pixel with extra steps. `.png`, `.jpg`, `.webp`, `.gif` and `.svg`, one flat
 * directory, no sub-paths.
 */
export const image = (
  asset: string,
  p?: { width?: number; height?: number; fit?: "contain" | "cover" | "fill" | "none" },
): Node => node("image", { asset, ...p });

/**
 * A list the user can put in order.
 *
 * The message carries `{from, to}`. **The app applies the move as it happens**
 * and holds it until your next tree arrives, so answer with one — the rows
 * spring back to whatever it says.
 */
export const reorder = (rows: Node[], msg: unknown): Node =>
  on(node("reorder", undefined, rows), "reorder", asMessage(msg));

/** A grid of the same thing, where a list would waste a wide window. */
export const grid = (
  children: Node[],
  p?: { columns?: number; ratio?: number; spacing?: number },
): Node => node("grid", p, children);

/**
 * `text` is the default and what most buttons should be; `filled` is for the
 * one action a page is *for*. There is no third weight on purpose — it would
 * be a decision on every button, and the app itself uses these two.
 *
 * `busy` swaps the label for a spinner **and** stops the taps, so a plugin
 * showing one cannot be asked to do the same thing twice.
 */
export const btn = (
  label: string,
  p?: { variant?: "text" | "filled"; icon?: string; busy?: boolean },
): Node => node("btn", { label, ...p });

export const input = (
  value: string,
  p?: {
    hint?: string;
    secret?: boolean;
    /** A leading icon, from the fixed set. */
    icon?: string;
    /** How many lines tall. More than one grows with what is typed. */
    lines?: number;
    /** Which keyboard a phone offers. */
    keyboard?: "text" | "number" | "url" | "email" | "multiline";
  },
): Node => node("input", { value, ...p });

/** Fires when the user presses the keyboard's return key, with the value. */
export function onSubmit<T extends Node>(n: T, handler: EventHandler): T;
export function onSubmit<T extends Node>(n: T, msg: unknown): T;
export function onSubmit<T extends Node>(n: T, msg: unknown): T {
  return on(n, "submit", asMessage(msg));
}

/**
 * A setting that is on or off.
 *
 * The label sits on the left and the switch on the right, which is how the
 * app draws its own — so a plugin's settings page reads like the pages around
 * it. `onChange` carries the new value, so a plugin never has to track which
 * way it was.
 *
 * A settings page is mostly these. Reach for {@link btn} only for something
 * that *happens* rather than something that is.
 */
export const toggle = (
  value: boolean | Binding,
  p: { label: string; hint?: string },
): Node => node("toggle", { value, ...p });

/**
 * One of several things being chosen — the sibling of {@link toggle}.
 *
 * A switch is a setting that takes effect as you touch it; a checkbox is one
 * of a set you are picking. Drawn the same way round, so a page of both reads
 * as one page.
 */
export const checkbox = (
  value: boolean | Binding,
  p: { label: string; hint?: string },
): Node => node("checkbox", { value, ...p });

/** One choice out of a few, all of them visible. */
export interface Choice {
  value: string;
  /** Falls back to `value`, which is a machine name rather than a blank row. */
  label?: string;
  icon?: string;
}

/**
 * One of a few, all visible at once — Material's answer for a small exclusive
 * choice, which is why there is no radio group: a column of radio buttons
 * costs a row each and says the same thing.
 *
 * Past about five options it stops fitting; that is what {@link dropdown} is
 * for. `onChange` carries the chosen `value`.
 */
export const segmented = (
  value: string | Binding,
  options: Choice[],
): Node => node("segmented", { value, options });

/** One of many, in a menu. With a `label` it is a settings row. */
export const dropdown = (
  value: string | Binding,
  options: Choice[],
  p?: { label?: string; hint?: string },
): Node => node("dropdown", { value, options, ...p });

/**
 * A number in a range, where the range is the point.
 *
 * The current value is drawn beside the label, so the setting can be read
 * without touching it. `divisions` makes it step; leaving it out is continuous.
 */
export const slider = (
  value: number | Binding,
  p: { min?: number; max?: number; divisions?: number; label?: string },
): Node => node("slider", { value, ...p });

/**
 * A chip, which in Material is a *choice*.
 *
 * A row of them in a {@link wrap} is a filter bar. `onTap` carries whatever
 * message you attach; the plugin decides what selecting one means.
 */
export const chip = (
  label: Bindable,
  p?: { selected?: boolean; icon?: string },
): Node => node("chip", { label, ...p });

/**
 * The actions that do not fit on a row, behind one button.
 *
 * Each item carries its own `msg`, so a plugin reads one event rather than an
 * index it has to map back.
 */
export const menu = (
  items: (Choice & { msg?: unknown })[],
  p?: { icon?: string },
): Node => node("menu", { options: items, ...p });

/**
 * Pull to refresh, around whatever scrolls.
 *
 * The spinner turns until the plugin's **next tree**, so answer with one. A
 * plugin that answers with values alone leaves it turning until the app gives
 * up on it.
 */
export const refresh = (child: Node, msg: unknown): Node =>
  on(node("refresh", undefined, [child]), "refresh", asMessage(msg));

/**
 * A row that answers a swipe.
 *
 * **The row is not removed by the swipe** — it springs back, and the plugin's
 * next tree is what makes it disappear. Flutter's own `Dismissible` expects the
 * list to lose the row immediately, which a tree that arrives over a network
 * cannot promise. Needs a {@link key}.
 */
export const dismiss = (child: Node, msg: unknown): Node =>
  on(node("dismiss", undefined, [child]), "dismiss", asMessage(msg));

/**
 * Sections of one surface, with the app's own tab bar.
 *
 * **The index is the app's.** Switching a tab is a frame, where asking the
 * plugin first would be a visible pause on something that should feel like part
 * of the app; attach `onChange` to be told which one is showing, not to decide
 * it.
 *
 * A `tabs` needs a height to give its views: inside a page there is one, inside
 * a card there is not and it takes a screenful.
 */
export const tabs = (labels: string[], views: Node[]): Node =>
  node("tabs", { labels }, views);

export const table = (header: string[], rows: string[][]): Node =>
  node("table", { header, rows });

/** Determinate when `value` is given, spinning when it is not. */
export const progress = (value?: number | Binding): Node =>
  value === undefined ? node("progress") : node("progress", { value });

export const tag = (label: Bindable): Node => node("tag", { label });

/**
 * A run of text.
 *
 * The knobs are named rather than numeric ({@link TextSize}, {@link Weight}) —
 * the app owns what its type looks like. `mono` is the one case where the face
 * is the meaning: a command, a path, a hash, where a proportional font makes
 * two different things look alike. `max` truncates with an ellipsis, and
 * `select` makes it selectable, which is a different widget rather than a
 * property.
 */
export const text = (
  value: Bindable,
  p?: {
    size?: TextSize;
    weight?: Weight;
    mono?: boolean;
    align?: "start" | "center" | "end";
    max?: number;
    select?: boolean;
  },
): Node => node("text", { value, ...p });

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
