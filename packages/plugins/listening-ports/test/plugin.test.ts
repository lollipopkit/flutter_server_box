/**
 * The plugin against the mock host: the half that is a conversation with the
 * app rather than a parser.
 *
 * What is worth checking here is the shape PLUGINS.md 4.4 argues for and this
 * is the first plugin to use — the reading is collected in `onHook`, not in
 * `open` and not on a tick, so a slow machine costs a spinner rather than a
 * blank window held open.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost, find } from "@serverbox/plugin-api/test";
import type { HookEvent, Node, ServerHandle } from "@serverbox/plugin-api";
import { COMMAND } from "../src/parse.ts";

const SS = `fmt=ss
tcp   LISTEN 0 4096 0.0.0.0:22    0.0.0.0:* users:(("sshd",pid=1,fd=3))
tcp   LISTEN 0 511  127.0.0.1:6379 0.0.0.0:* users:(("redis-server",pid=9,fd=6))
`;

let restore: () => void;
afterEach(() => restore?.());

/** Re-imported per test, so module-level state does not leak between them. */
async function load() {
  return await import(`../src/plugin.ts?${Math.random()}`);
}

function enter(server = "h-1"): HookEvent {
  return {
    kind: "enter",
    contribution: "ports",
    servers: [{ server: server as ServerHandle, name: "web" }],
  };
}

/** Every `text` value in a tree, so an assertion names what is on screen. */
function texts(node: Node): string[] {
  const out: string[] = [];
  const walk = (n: Node) => {
    if (n.t === "text" && typeof n.p?.value === "string") out.push(n.p.value);
    for (const c of n.c ?? []) walk(c);
  };
  walk(node);
  return out;
}

describe("the collection", () => {
  test("open draws immediately and runs nothing", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    const out = plugin.open({ kind: "page", id: "ports" });

    // The point of collecting in the hook: `open` holds the surface until it
    // answers, and this is a command on a machine that may be asleep.
    expect(host.called()).toEqual([]);
    expect(texts(out.ui!)).toContain("Reading…");
  });

  test("the hook runs the command and patches the rows in", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    expect(host.called()).toEqual(["server.exec", "ui.patch"]);
    // The whole tree, because what changed is the body — a JSON Pointer into a
    // layout this plugin also owns would be two descriptions that have to
    // agree.
    const patch = host.callsTo("ui.patch")[0]!;
    expect(patch.path).toBe("");

    const drawn = texts(patch.node);
    expect(drawn).toContain("22");
    expect(drawn).toContain("sshd");
    expect(drawn).toContain("6379");
    expect(drawn.some((t) => t.includes("2 listening"))).toBe(true);
    // The one thing this list is opened to find out.
    expect(drawn.some((t) => t.includes("1 reachable from outside"))).toBe(true);
  });

  /// The hook is the only place the server handle comes from — a page is
  /// bound to one machine and `open` is not told which.
  test("it runs against the server the hook named", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter("h-42"));

    expect(host.callsTo("server.exec")[0]!.req.server).toBe("h-42");
  });

  /// A machine with neither command is a different answer from one with
  /// nothing listening, and the page has to say which.
  test("a machine with neither command says so", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: "fmt=none\n" });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());

    const drawn = texts(host.callsTo("ui.patch")[0]!.node);
    expect(drawn.some((t) => t.includes("neither ss nor netstat"))).toBe(true);
  });

  /// A refused or failed command is a page that says so, not one that stays on
  /// "Reading…" for ever.
  test("a command that failed is drawn as a failure", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());

    const drawn = texts(host.callsTo("ui.patch")[0]!.node);
    expect(drawn.some((t) => t.includes("no exec scripted"))).toBe(true);
  });

  test("a hook naming no server does not run a command", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook({ kind: "enter", contribution: "ports", servers: [] });

    expect(host.callsTo("server.exec")).toHaveLength(0);
    expect(host.callsTo("ui.patch")).toHaveLength(1);
  });
});

describe("the controls", () => {
  test("reload draws before it runs, so the tap is visible", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());
    await plugin.onEvent({ m: "reload" });

    // patch(rows) · exec · patch("Reading…") · exec · patch(rows): the middle
    // patch is the point — on a machine that takes seconds the button has to
    // have done something.
    expect(host.called()).toEqual([
      "server.exec",
      "ui.patch",
      "ui.patch",
      "server.exec",
      "ui.patch",
    ]);
  });

  /// Filtering is a local decision about a reading already in hand, so it
  /// answers a tree rather than going back to the machine.
  test("the exposed filter runs no command", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());
    const before = host.callsTo("server.exec").length;
    const out = await plugin.onEvent({ m: "exposed" });

    expect(host.callsTo("server.exec")).toHaveLength(before);
    const drawn = texts(out.ui!);
    expect(drawn).toContain("22");
    expect(drawn).not.toContain("6379");
  });
});

describe("the rows", () => {
  /// Keyed by what makes a listener itself, so the renderer keeps a row's
  /// element across a reload rather than rebuilding the list.
  test("each row carries a key that survives a reload", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());
    const tree = host.callsTo("ui.patch")[0]!.node;

    expect(find(tree, "tcp:0.0.0.0:22")).toBeDefined();
    expect(find(tree, "tcp:127.0.0.1:6379")).toBeDefined();
  });
});
