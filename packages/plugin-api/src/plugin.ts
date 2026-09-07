/**
 * What a plugin exports. PLUGINS.md section 4.2.
 *
 * Every export may be `async`; the host awaits the returned promise. A plugin
 * implements the ones it needs and omits the rest — `open` alone is a card, and
 * `statusCmd` plus `parse` alone is a status plugin with no UI at all.
 */

import type { ServerHandle } from "./host.ts";
import type { Node } from "./ui.ts";

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

/** A status plugin's command, and how the host should split its output. */
export interface StatusCmd {
  cmd: string;
  sep: string;
}

/**
 * The shape of a plugin module.
 *
 * Not something to implement — a plugin is a module, not a class. It is here so
 * a plugin can write `satisfies Plugin` and have its export signatures checked.
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

  // ---- status plugins (section 9). Neither needs a surface or a permission.

  /** The command to run on the server, and its segment marker. */
  statusCmd?(platform: string): StatusCmd | Promise<StatusCmd>;

  /** That command's output, as typed counters. */
  parse?(text: string): unknown | Promise<unknown>;
}
