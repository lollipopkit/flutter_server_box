/**
 * Write ServerBox plugins in TypeScript or JavaScript.
 *
 * A plugin is one ES module. It holds its own state, asks the app for the
 * things it cannot do itself through the global `sb` object, and answers with a
 * tree of widgets the app draws. It never sees a credential, a server id, or
 * anything outside what its manifest asked for and the user agreed to.
 *
 * ```ts
 * import { card, kv, btn, onTap, type Plugin, type UiOutput } from "@serverbox/plugin-api";
 *
 * let count = 0;
 *
 * export function open(): UiOutput {
 *   return { ui: view() };
 * }
 *
 * export function onEvent(): UiOutput {
 *   count++;
 *   return { ui: view() };
 * }
 *
 * const view = () =>
 *   card([kv("Taps", String(count)), onTap(btn("Again"), { m: "again" })]);
 * ```
 *
 * The whole of that runs in `bun test` against `MockHost` from
 * `@serverbox/plugin-api/test` — no QuickJS, no app, no build step.
 */

export * from "./host.ts";
export * from "./plugin.ts";
export * from "./ui.ts";
export * from "./frame.ts";
export * from "./shell.ts";

/**
 * The host ABI this SDK is written against.
 *
 * Goes into `manifest.json`'s `abi`. The app refuses a plugin whose number is
 * higher than its own, and the index keeps several versions of a plugin so an
 * older app still finds one it can run.
 */
export const ABI_VERSION = 1;
