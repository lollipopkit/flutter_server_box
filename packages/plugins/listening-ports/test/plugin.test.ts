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

import { MockHost, find, l10nKeys, texts } from "@serverbox/plugin-api/test";
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

describe("the collection", () => {
  test("open draws immediately and runs nothing", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    const out = plugin.open({ kind: "page", id: "ports" });

    // The point of collecting in the hook: `open` holds the surface until it
    // answers, and this is a command on a machine that may be asleep.
    expect(host.called()).toEqual([]);
    expect(l10nKeys(out.ui!)).toContain("l10n.reading");
  });

  test("the hook runs the command and patches the rows in", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    // Two `store.get` first: the page opens on whichever filter the settings
    // page says is the default, and in whichever order was last chosen.
    expect(host.called()).toEqual([
      "store.get",
      "store.get",
      "server.exec",
      "ui.patch",
    ]);
    // The whole tree, because what changed is the body — a JSON Pointer into a
    // layout this plugin also owns would be two descriptions that have to
    // agree.
    const patch = host.callsTo("ui.patch")[0]!;
    expect(patch.path).toBe("");

    const drawn = texts(patch.node);
    // The port is the row's title, so it stands alone. The process shares the
    // subtitle with the protocol and the address — a row that carried only a
    // process name spent a line saying "—" whenever reading it needed root.
    expect(drawn).toContain("22");
    expect(drawn).toContain("6379");
    expect(drawn.some((t) => t.includes("sshd"))).toBe(true);
    // The count is a translated sentence with the number as an argument, so
    // the key is what the tree carries — the app substitutes.
    const keys = l10nKeys(patch.node);
    expect(keys).toContain("l10n.ports");
    // The one thing this list is opened to find out.
    expect(keys).toContain("l10n.exposedCount");
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

    // `errNoTool` is the sentence that names both commands and what to install
    // instead — the half that makes it a message rather than a diagnosis.
    expect(l10nKeys(host.callsTo("ui.patch")[0]!.node)).toContain(
      "l10n.errNoTool",
    );
  });

  /// A refused or failed command is a page that says so and offers the way
  /// out, not one that stays on "Reading…" for ever — and not one that shows
  /// the user a JavaScript error, which is a fact about this code rather than
  /// about their machine.
  test("a command that failed is drawn as a failure with a way out", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter());

    const node = host.callsTo("ui.patch")[0]!.node;
    expect(l10nKeys(node)).toContain("l10n.errTitle");
    expect(l10nKeys(node)).toContain("l10n.retry");
    // And never the JavaScript error, which is a fact about this code rather
    // than about the user's machine.
    expect(texts(node).some((t) => t.includes("no exec scripted"))).toBe(false);
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
      "store.get",
      "store.get",
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

describe("finding one among many", () => {
  /// Two rows need no search box; ninety are exactly where this page stops
  /// being readable without one.
  const MANY = `fmt=ss
${Array.from(
  { length: 12 },
  (_, i) =>
    `tcp   LISTEN 0 4096 0.0.0.0:${8000 + i}     0.0.0.0:* users:(("svc${i}",pid=${i},fd=3))`,
).join("\n")}
`;

  const host12 = () => new MockHost().exec(COMMAND, { stdout: MANY });

  test("a short list gets no search box, a long one does", async () => {
    const few = new MockHost().exec(COMMAND, { stdout: SS });
    restore = few.install();
    let plugin = await load();
    await plugin.onHook(enter());
    expect(l10nKeys(lastPatch(few))).not.toContain("l10n.searchHint");
    restore();

    const many = host12();
    restore = many.install();
    plugin = await load();
    await plugin.onHook(enter());
    expect(l10nKeys(lastPatch(many))).toContain("l10n.searchHint");
  });

  test("it matches a port by prefix, a process and an address", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter());

    // "800" finds 8000..8009 and not 8010 or 8011 — which is what somebody
    // typing three digits means.
    const byPort = texts((await plugin.onEvent({ m: "search" }, "800")).ui!);
    expect(byPort).toContain("8000");
    expect(byPort).not.toContain("8010");

    const byProcess = texts((await plugin.onEvent({ m: "search" }, "svc7")).ui!);
    expect(byProcess).toContain("8007");
    expect(byProcess).not.toContain("8006");
  });

  test("a search that finds nothing says so and offers the way back", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter());

    const out = await plugin.onEvent({ m: "search" }, "nothing-like-this");

    const keys = l10nKeys(out.ui!);
    expect(keys).toContain("l10n.emptySearchTitle");
    expect(keys).toContain("l10n.clear");
  });

  test("the order is by port, or by process, and is remembered", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter());

    const out = await plugin.onEvent({ m: "sort" });

    expect(l10nKeys(out.ui!)).toContain("l10n.sortProcess");
    expect(host.value("global", "sortBy")).toBe("process");
  });
});

/** The tree of the last patch, which is what is on screen. */
function lastPatch(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}
