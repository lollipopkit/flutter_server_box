/**
 * What a plugin exports. PLUGINS.md section 4.2.
 *
 * Every export may be `async`; the host awaits the returned promise. A plugin
 * implements the ones it needs and omits the rest — `open` alone is a card, and
 * `statusCmd` plus `parse` alone is a status plugin with no UI at all.
 */

import type { ServerHandle, ServerSummary } from "./host.ts";
// The same five names a widget is toned with, for the same reason: a plugin's
// row has to look like the app's own in both themes.
import type { Node, Tone } from "./ui.ts";

/** Where a plugin is being shown. */
export type SurfaceKind =
  /** A page behind a button in the server function bar. */
  | "page"
  /** A card on the server detail page. */
  | "card"
  /** A tab on the home page. Not bound to a server. */
  | "tab"
  /** A section of the settings page. */
  | "settings";

export interface Surface {
  kind: SurfaceKind;
  /** The contribution id from the manifest, so a plugin offering two cards can tell them apart. */
  id: string;
  server?: ServerHandle;
}

export interface InitCtx {
  /** The server this instance is bound to, absent for a global surface. */
  server?: ServerHandle;
  /** BCP-47, so a plugin can format a number the way the app does. */
  locale: string;
}

export type ServerEventKind =
  | "connected"
  | "disconnected"
  /**
   * The server is gone. Anything this plugin stored against it goes with it,
   * which the host does — a plugin does not have to clean up after itself.
   */
  | "deleted";

export interface ServerEvent {
  kind: ServerEventKind;
  server: ServerHandle;
}

/**
 * Why the host is telling the plugin about a surface.
 *
 * One value, because the host sends one. A `leave` would have nothing to do
 * here — a surface's instance is unloaded when it goes, taking the plugin's
 * state with it — and a `refresh` waits for a surface that has a pull to
 * refresh. Both are easy to add; declaring them before anything sends them
 * would describe an interface that does not exist, which is a plugin passing
 * its own tests and failing on a device.
 */
export type HookKind =
  /** It is being shown. Fired once per mount, after `init` and `open`. */
  "enter";

/**
 * A surface being entered, and which machines it is about.
 *
 * **The host says the scope; the plugin decides what to load.** A card is
 * about the machine it is bound to, a page about the one it was opened from,
 * a tab about the whole fleet — so the same hook arrives with one server or
 * with all of them, and how much work that is worth is the plugin's call.
 *
 * This is what makes a reading lazy. Nothing here is on a timer: a plugin that
 * collects in `onHook` collects when somebody looks, where one that collects
 * in `tick` pays for every machine whether or not anybody is reading. Use
 * `tick` for a value that changes while you watch it and this for one that
 * does not.
 */
export interface HookEvent {
  kind: HookKind;

  /** Which of the plugin's contributions is being entered, by its manifest id. */
  contribution: string;

  /**
   * The machines in scope, and never more than the plugin may know about.
   *
   * One entry — the surface's own server — unless the manifest asked for
   * `server.list` and the user granted it, which is what a fleet-wide surface
   * needs. Without that grant a tab's hook still arrives, carrying only the
   * server it is bound to or nothing at all; the host does not hand over the
   * list because the payload happens to have room for it.
   *
   * Empty for a surface bound to no machine, such as a settings page.
   */
  servers: ServerSummary[];
}

/** What `open`, `onEvent` and `tick` answer with. */
export interface UiOutput {
  /**
   * Omitted from `tick` means "nothing changed, keep the last tree"; omitted
   * from `open` means "this surface has nothing to show".
   *
   * Pass it through `frame()` so unchanged subtrees are pruned.
   */
  ui?: Node;

  /**
   * New values for the slots the tree bound with `bind()`.
   *
   * A tick that answers these and no `ui` costs nothing above the bound leaves:
   * the app sets a notifier per slot, so no widget is rebuilt and no element is
   * walked. For a card whose shape is fixed and whose numbers move, this is the
   * whole of a refresh — a few hundred bytes instead of the tree.
   */
  values?: Record<string, unknown>;
}

/** One field the editor should mark as wrong. */
export interface ConfigError {
  /** Absent when it is about the form as a whole rather than one field. */
  key?: string;
  message: string;
}

export interface ValidateOutput {
  errors: ConfigError[];
}

export interface ConfigOption {
  value: string;
  label: string;
}

export interface OptionsOutput {
  options: ConfigOption[];
}

/** What `statusCmd` is asked about. The host asks about nothing else. */
export type Platform = "linux" | "bsd" | "windows";

export interface StatusCmdCtx {
  platform: Platform;
}

/** A status plugin's command. PLUGINS.md section 9. */
export interface StatusCmd {
  /** A shell command, run on the server the way a custom command is. */
  cmd: string;
  /**
   * How this plugin splits its own output, when it runs several probes in one
   * command.
   *
   * The host does not read it — the separator between *commands* is the
   * host's. It is here so that a plugin needing one has somewhere to say what
   * it used, instead of putting it in the command text.
   */
  sep?: string;
}

export interface StatusParseCtx {
  /** What the command printed, byte for byte. */
  text: string;
}

export interface StatusItem {
  label: string;
  value: string;
  /**
   * 0..1, drawn as a bar beside the value. Omit where the reading is not a
   * proportion — a temperature, a count.
   *
   * A value outside the range is dropped by the host rather than clamped: a
   * bar at 100% because a plugin divided by the wrong thing is a wrong reading
   * shown confidently.
   */
  percent?: number;
  tone?: Tone;
}

/**
 * What `parse` answers with.
 *
 * Checked by the host, and trimmed wherever it can be: at most 64 items, at
 * most 200 characters of a label or a value, a row with nothing on either side
 * dropped. Only a document that is not this shape at all is refused — the whole
 * cost of a bad status plugin should be a wrong row, not a card that will not
 * draw.
 */
export interface StatusResult {
  /** The card's heading. Falls back to the plugin's name when empty. */
  title?: string;
  items: StatusItem[];
  /** Shown under the readings, for what a row cannot say — "3 of 20 sensors unreadable". */
  note?: string;
}

/**
 * The shape of a plugin module.
 *
 * Not something to implement — a plugin is a module, not a class. It is here so
 * a plugin can write `satisfies Plugin` and have its export signatures checked.
 *
 * **Every export is called with exactly one argument**, the host's input parsed
 * from JSON. That is why the ones below that need more than one value take an
 * object. The multi-parameter signatures still written that way — `onEvent`,
 * `listWindow`, `configOptions`, `tool` — are the ones the host does not call
 * yet; their shape is settled with the renderer (PLUGINS.md section 10 step 5),
 * and until then this interface describes an intent rather than a contract.
 * `init`, `open`, `onHook`, `onServerEvent`, `validateConfig`, `statusCmd` and
 * `parse`
 * are the calls that exist, and each takes one object.
 */
export interface Plugin {
  /** Once, after the instance exists and before any surface is shown. */
  init?(ctx: InitCtx): void | Promise<void>;

  /** A surface is being shown. The tree this answers with is the whole of it. */
  open?(surface: Surface): UiOutput | Promise<UiOutput>;

  /**
   * The user did something.
   *
   * `msg` is whatever the plugin attached to the event; `value` is the
   * control's current value, for the ones that have one.
   */
  onEvent?(msg: unknown, value?: unknown): UiOutput | Promise<UiOutput>;

  /** The shared refresh interval, and only while a surface is visible. */
  tick?(): UiOutput | Promise<UiOutput>;

  /**
   * More rows for a `list` that declared a `count` larger than it carried.
   *
   * Called as the user scrolls, so it must answer without doing anything slow;
   * the app shows a placeholder until it does.
   */
  listWindow?(key: string, from: number, count: number): Node[] | Promise<Node[]>;

  onServerEvent?(event: ServerEvent): void | Promise<void>;

  /**
   * A surface was entered. See {@link HookEvent}.
   *
   * Answers nothing: a plugin that has something new to draw sends it with
   * `sb.ui.patch`, which is what lets a slow collection fill the page in as it
   * lands rather than holding it blank until every machine has answered.
   */
  onHook?(event: HookEvent): void | Promise<void>;

  /** Called before the editor saves, with the form as typed. */
  validateConfig?(cfg: Record<string, string>): ValidateOutput | Promise<ValidateOutput>;

  /**
   * The choices for a `select` config field whose `options_from` names `key`.
   *
   * For picking one of something the plugin itself stores, which no manifest
   * can enumerate.
   */
  configOptions?(key: string): OptionsOutput | Promise<OptionsOutput>;

  /** A tool the AI agent may call, by the name the manifest declared. */
  tool?(name: string, args: unknown): unknown | Promise<unknown>;

  /**
   * The instance is going away.
   *
   * Where a session on a device that allows few of them is ended. Nothing else
   * gives it back before it times out.
   */
  dispose?(): void | Promise<void>;

  // ---- status plugins (section 9). Neither needs a surface.

  /**
   * The command to run on the server.
   *
   * Asked once per platform the manifest named, and again whenever the
   * plugin's configuration changes. The host runs it — bounded by a timeout
   * and a size cap, and shown to the user — so the manifest must ask for
   * `server.exec` to contribute status at all.
   */
  statusCmd?(ctx: StatusCmdCtx): StatusCmd | Promise<StatusCmd>;

  /** That command's output, as readings the app draws with its own widgets. */
  parse?(ctx: StatusParseCtx): StatusResult | Promise<StatusResult>;
}
