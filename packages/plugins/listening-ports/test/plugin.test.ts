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

import { MockHost, find, l10nKeys, messageOf, texts } from "@serverbox/plugin-api/test";
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
    // The shape of what is coming, so the page does not jump when it arrives.
    expect(out.ui!.t).toBe("skeleton");
  });

  test("the hook runs the command and patches the rows in", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    // Two `store.get` first: the page opens on whichever filter the settings
    // page says is the default, and in whichever order was last chosen. Then
    // the reading, and a patch for each state it passes through — the loading
    // one is what the page shows while the command runs.
    expect(host.called()).toEqual([
      "store.get",
      "store.get",
      "server.exec",
      "ui.patch",
      "ui.patch",
    ]);
    // The whole tree, because what changed is the body — a JSON Pointer into a
    // layout this plugin also owns would be two descriptions that have to
    // agree.
    const patch = host.callsTo("ui.patch")[0]!;
    expect(patch.path).toBe("");

    const drawn = texts(screen(plugin));
    // The port is the row's title, so it stands alone. The process shares the
    // subtitle with the protocol and the address — a row that carried only a
    // process name spent a line saying "—" whenever reading it needed root.
    expect(drawn).toContain("22");
    expect(drawn).toContain("6379");
    expect(drawn.some((t) => t.includes("sshd"))).toBe(true);
    // The count is a translated sentence with the number as an argument, so
    // the key is what the tree carries — the app substitutes.
    const keys = l10nKeys(screen(plugin));
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

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter("h-42"));

    expect(host.callsTo("server.exec")[0]!.req.server).toBe(
      "h-42" as ServerHandle,
    );
  });

  /// A machine with neither command is a different answer from one with
  /// nothing listening, and the page has to say which.
  test("a machine with neither command says so", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: "fmt=none\n" });
    restore = host.install();
    const plugin = await load();

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    // `errNoTool` is the sentence that names both commands and what to install
    // instead — the half that makes it a message rather than a diagnosis.
    expect(l10nKeys(screen(plugin))).toContain("l10n.errNoTool");
  });

  /// A refused or failed command is a page that says so and offers the way
  /// out, not one that stays on "Reading…" for ever — and not one that shows
  /// the user a JavaScript error, which is a fact about this code rather than
  /// about their machine.
  test("a command that failed is drawn as a failure with a way out", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    const node = screen(plugin);
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

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook({ kind: "enter", contribution: "ports", servers: [] });

    expect(host.callsTo("server.exec")).toHaveLength(0);
    // And the page says which of the two empty states it is in.
    expect(l10nKeys(screen(plugin))).toContain("l10n.errNoServer");
  });
});

describe("the controls", () => {
  /// Tapped through the tree rather than by sending a message: with a closure
  /// as the handler there is no message to write by hand, and a test that
  /// wrote one proved the handler worked and said nothing about whether
  /// anything on screen sends it.
  test("reload runs the command again and redraws", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());
    const before = host.callsTo("server.exec").length;

    await plugin.onEvent({ msg: messageOf(screen(plugin), "l10n.reload") });

    // The command runs inside the call the tap started — the host drives an
    // instance only while it is in one — so there is nothing to wait for here.
    expect(host.callsTo("server.exec").length).toBe(before + 1);
    expect(texts(screen(plugin))).toContain("22");
  });

  /// Filtering is a local decision about a reading already in hand, so it
  /// answers a tree rather than going back to the machine.
  test("the exposed filter runs no command", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());
    const before = host.callsTo("server.exec").length;
    await plugin.onEvent({ msg: messageOf(screen(plugin), "l10n.filterAll") });

    expect(host.callsTo("server.exec")).toHaveLength(before);
    const drawn = texts(screen(plugin));
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

    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());
    const tree = screen(plugin);

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
    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());
    expect(l10nKeys(screen(plugin))).not.toContain("l10n.searchHint");
    restore();

    const many = host12();
    restore = many.install();
    plugin = await load();
    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());
    expect(l10nKeys(screen(plugin))).toContain("l10n.searchHint");
  });

  test("it matches a port by prefix, a process and an address", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    // "800" finds 8000..8009 and not 8010 or 8011 — which is what somebody
    // typing three digits means.
    // Read from the tree each time, as a tap does: every draw is a new tree
    // with new tokens in it, and the app taps what is on screen.
    await plugin.onEvent({
      msg: messageOf(screen(plugin), "l10n.searchHint", "change"),
      value: "800",
    });
    const byPort = texts(screen(plugin));
    expect(byPort).toContain("8000");
    expect(byPort).not.toContain("8010");

    await plugin.onEvent({
      msg: messageOf(screen(plugin), "l10n.searchHint", "change"),
      value: "svc7",
    });
    const byProcess = texts(screen(plugin));
    expect(byProcess).toContain("8007");
    expect(byProcess).not.toContain("8006");
  });

  test("a search that finds nothing says so and offers the way back", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    await plugin.onEvent({
      msg: messageOf(screen(plugin), "l10n.searchHint", "change"),
      value: "nothing-like-this",
    });

    const keys = l10nKeys(screen(plugin));
    expect(keys).toContain("l10n.emptySearchTitle");
    expect(keys).toContain("l10n.clear");
  });

  test("the order is by port, or by process, and is remembered", async () => {
    const host = host12();
    restore = host.install();
    const plugin = await load();
    // The host always opens a surface before it hooks it.
    plugin.open({ kind: "page", id: "ports" });
    await plugin.onHook(enter());

    await plugin.onEvent({ msg: messageOf(screen(plugin), "l10n.sortPort") });

    expect(l10nKeys(screen(plugin))).toContain("l10n.sortProcess");
    expect(host.value("global", "sortBy")).toBe("process");
  });
});

describe("the card", () => {
  /// The same reading, in a glance, on the server's detail page. It exists to
  /// put a port reachable from outside in front of somebody who was not looking
  /// for one — so what it shows is the count and those, and nothing else.
  test("it summarises and names only what is exposed", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "card", id: "summary" });
    await plugin.onHook({ ...enter(), contribution: "summary" });

    const shown = texts(screen(plugin, "card", "summary"));
    // Two listeners, one of them on 0.0.0.0.
    expect(shown).toContain("22");
    expect(shown).not.toContain("6379");
    expect(l10nKeys(screen(plugin, "card", "summary"))).toContain(
      "l10n.exposedCount",
    );
  });

  /// A card is one of several on that page, and every one of them ticking would
  /// be `ss` on every server every few seconds. The detail page hands cards an
  /// interval; this plugin exports no `tick`, which is what declines it.
  test("it collects once and does not tick", async () => {
    const host = new MockHost().exec(COMMAND, { stdout: SS });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "card", id: "summary" });
    await plugin.onHook({ ...enter(), contribution: "summary" });

    expect(host.called().filter((c) => c === "server.exec")).toHaveLength(1);
    expect(plugin.tick).toBeUndefined();
  });

  test("nothing reachable says so instead of listing a lock", async () => {
    const local = `fmt=ss
tcp   LISTEN 0 511  127.0.0.1:6379 0.0.0.0:* users:(("redis-server",pid=9,fd=6))
`;
    const host = new MockHost().exec(COMMAND, { stdout: local });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "card", id: "summary" });
    await plugin.onHook({ ...enter(), contribution: "summary" });

    const card = screen(plugin, "card", "summary");
    expect(l10nKeys(card)).toContain("l10n.exposedNone");
    expect(texts(card)).not.toContain("6379");
  });

  /// Compact rather than a notice with a retry: a failure on a card is not the
  /// detail page's subject, and the plugin's own page is where the retry is.
  test("a failure is one muted line", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "card", id: "summary" });
    await plugin.onHook({ ...enter(), contribution: "summary" });

    const keys = l10nKeys(screen(plugin, "card", "summary"));
    expect(keys.some((k) => k.startsWith("l10n.err"))).toBeTrue();
    expect(keys).not.toContain("l10n.retry");
  });
});

/** The tree of the last patch, for when the patch itself is the subject. */
function lastPatch(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}

/**
 * The whole tree as it stands.
 *
 * A patch carries a *diff* — every unchanged subtree is a stub — so reading one
 * says what changed rather than what is on screen. `open` draws in full against
 * the state the plugin already holds, which is what a test wants to assert on.
 */
function screen(
  plugin: { open: (s: { kind: string; id: string }) => { ui?: Node } },
  kind = "page",
  id = "ports",
): Node {
  return plugin.open({ kind, id }).ui!;
}
