/**
 * A whole plugin, small enough to read.
 *
 * It exists so the SDK's own tests exercise the thing plugin authors actually
 * write: module-level state, `sb` calls, a widget tree, and a message that has
 * to survive the round trip through the host.
 */

import {
  btn,
  card,
  column,
  key,
  kv,
  l10n,
  onTap,
  text,
  tone,
  type Plugin,
  type Surface,
  type UiOutput,
} from "../src/index.ts";

type Msg = { m: "refresh" } | { m: "wipe" };

let uptime: string | null = null;
let failure: string | null = null;

export async function init(): Promise<void> {
  uptime = await sb.store.get("server", "uptime");
}

export async function open(_surface: Surface): Promise<UiOutput> {
  await refresh();
  return { ui: view() };
}

export async function onEvent(msg: unknown): Promise<UiOutput> {
  const m = msg as Msg;
  if (m.m === "refresh") await refresh();
  if (m.m === "wipe") {
    await sb.store.set("server", "uptime", null);
    uptime = null;
  }
  return { ui: view() };
}

async function refresh(): Promise<void> {
  const server = sb.config.get("server");
  if (!server) {
    failure = "unconfigured";
    return;
  }
  try {
    const r = await sb.server.exec({ server: server as never, script: "uptime -p" });
    uptime = r.stdout.trim();
    failure = null;
    await sb.store.set("server", "uptime", uptime);
  } catch (e) {
    // A host that could not do the thing is an answer, not a death.
    failure = (e as { kind?: string }).kind ?? "unknown";
    sb.log.warn(`uptime unavailable: ${failure}`);
  }
}

function view() {
  const rows = [
    failure
      ? tone(text(l10n("example.failed", failure)), "danger")
      : kv("Uptime", uptime ?? "—"),
    key(onTap(btn(l10n("example.refresh")), { m: "refresh" }), "refresh"),
    key(onTap(btn(l10n("example.wipe")), { m: "wipe" }), "wipe"),
  ];
  return card([column(rows)]);
}

// Checked against the interface without being an instance of it: a plugin is a
// module, so this only asserts the export signatures.
export const _typecheck = { init, open, onEvent } satisfies Plugin;
