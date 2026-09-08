/**
 * The plugin against the mock host: descending, coming back up, and where it
 * remembers you were.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost, l10nKeys, texts } from "@serverbox/plugin-api/test";
import type { HookEvent, Node, ServerHandle } from "@serverbox/plugin-api";
import { command } from "../src/scan.ts";

const VAR = `df
/dev/vda1 51475068 48901120 1934564 97% /
du
4096	/var/cache
32948124	/var/lib
1048576	/var/log
34041852	/var
`;

const ROOT = `df
/dev/vda1 51475068 48901120 1934564 97% /
du
34041852	/var
8388608	/usr
51475068	/
`;

let restore: () => void;
afterEach(() => restore?.());

async function load() {
  return await import(`../src/plugin.ts?${Math.random()}`);
}

const enter: HookEvent = {
  kind: "enter",
  contribution: "usage",
  servers: [{ server: "h-1" as ServerHandle, name: "web" }],
};


/** The tree of the last patch, which is what is on screen. */
function lastDrawn(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}

function hostWith() {
  return new MockHost()
    .exec(command("/"), { stdout: ROOT })
    .exec(command("/var"), { stdout: VAR });
}

describe("the first level", () => {
  test("starts at the root when nothing is remembered", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    expect(host.callsTo("server.exec")[0]!.req.script).toBe(command("/"));
    const drawn = texts(lastDrawn(host));
    // The path is the eyebrow and the total is the figure, so they are two
    // strings rather than one sentence.
    expect(drawn).toContain("/");
    expect(drawn).toContain("var");
    expect(drawn).toContain("usr");
  });

  /// A level can take a minute, and a page that shows nothing for a minute
  /// reads as a page that did nothing.
  test("draws before it measures", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    const patches = host.callsTo("ui.patch");
    expect(patches.length).toBeGreaterThanOrEqual(2);
    expect(l10nKeys(patches[0]!.node)).toContain("l10n.measuring");
  });

  /// `df` is what turns "31G in /var" into something that means anything.
  test("shows the filesystem behind the directory", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    // A translated sentence with both figures as arguments, so the tree
    // carries the key and the app substitutes.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.filesystem");
  });
});

describe("descending", () => {
  test("a tap measures the child, not the whole tree again", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "open", path: "/var" });

    expect(host.callsTo("server.exec").map((c) => c.req.script)).toEqual([
      command("/"),
      command("/var"),
    ]);
    const drawn = texts(lastDrawn(host));
    expect(drawn).toContain("lib");
    expect(drawn).toContain("log");
  });

  test("up goes to the parent, and the root offers no up", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "open", path: "/var" });
    const before = host.callsTo("server.exec").length;

    await plugin.onEvent({ m: "up" });
    expect(host.callsTo("server.exec")).toHaveLength(before + 1);

    // At the root there is nowhere to go, so nothing is asked.
    await plugin.onEvent({ m: "up" });
    expect(host.callsTo("server.exec")).toHaveLength(before + 1);
  });
});

describe("picking and deleting", () => {
  test("picking changes what a tap on a row means", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);
    const before = host.callsTo("server.exec").length;

    await plugin.onEvent({ m: "select" });
    // The same tap that descended a moment ago now picks, and measures
    // nothing: descending while picking would take the selection out of sight
    // of the person who made it.
    await plugin.onEvent({ m: "pick", path: "/var" });

    expect(host.callsTo("server.exec")).toHaveLength(before);
    const out = await plugin.onEvent({ m: "pick", path: "/usr" });
    expect(l10nKeys(out.ui!)).toContain("l10n.delete");
  });

  test("nothing is removed until the dialog is answered", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ m: "select" });
    await plugin.onEvent({ m: "pick", path: "/var" });
    // Cancelled, which is the default this mock gives when nothing is scripted
    // — and the point: a delete that ran anyway would be unrecoverable.
    host.answerPrompt({ cancelled: true });
    await plugin.onEvent({ m: "delete" });

    expect(
      host.callsTo("server.exec").some((c) => c.req.script.includes("rm")),
    ).toBe(false);
  });

  test("what it removes is quoted, and the options are ended", async () => {
    const host = hostWith().confirmNext();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ m: "select" });
    await plugin.onEvent({ m: "pick", path: "/var" });
    await plugin.onEvent({ m: "delete" });

    const rm = host
      .callsTo("server.exec")
      .map((c) => c.req.script)
      .find((s) => s.startsWith("rm"));
    // `--` because a directory called `-rf` is a legal directory name, and it
    // arrives here out of a listing this plugin asked the server for.
    expect(rm).toBe("rm -rf -- '/var'");
  });

  test("the level is measured again rather than adjusted", async () => {
    const host = hostWith().confirmNext().exec("rm -rf -- '/var'", {});
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ m: "select" });
    await plugin.onEvent({ m: "pick", path: "/var" });
    await plugin.onEvent({ m: "delete" });

    // What `rm` actually removed is a question for the machine, and every
    // other row's share of the total moved with it.
    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    expect(scripts[scripts.length - 1]).toBe(command("/"));
    // And the selection is over: it described rows that no longer exist.
    expect(texts(lastDrawn(host)).some((t) => t.includes("Delete"))).toBe(false);
  });

  test("descending clears the selection", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ m: "select" });
    await plugin.onEvent({ m: "pick", path: "/var" });
    await plugin.onEvent({ m: "cancelSelect" });
    await plugin.onEvent({ m: "open", path: "/var" });

    // A selection is about what is in front of you; carried down it would mean
    // a delete that removes something off screen.
    expect(texts(lastDrawn(host)).some((t) => t.includes("Delete"))).toBe(false);
  });
});

describe("where it left you", () => {
  /// Per server, because "the big directory" is a property of the machine and
  /// not of the person looking at it.
  test("remembers the directory against the server", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "open", path: "/var" });

    expect(host.value("server", "lastPath")).toBe("/var");
  });

  test("and comes back to it", async () => {
    const host = hostWith();
    restore = host.install();
    const first = await load();
    await first.onHook(enter);
    await first.onEvent({ m: "open", path: "/var" });

    // A fresh instance, as a second visit is.
    const again = await load();
    await again.onHook(enter);

    const asked = host.callsTo("server.exec").map((c) => c.req.script);
    expect(asked[asked.length - 1]).toBe(command("/var"));
  });

  /// A directory measured but never confirmed should not be where the next
  /// visit starts.
  test("a level that failed is not remembered", async () => {
    const host = new MockHost().exec(command("/"), { stdout: ROOT });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "open", path: "/var" });

    expect(host.value("server", "lastPath")).toBe("/");
    // The failure is drawn, with the two ways off it — and without the
    // JavaScript error, which is a fact about this code rather than about the
    // user's machine.
    const keys = l10nKeys(lastDrawn(host));
    expect(keys).toContain("l10n.errTitle");
    expect(keys).toContain("l10n.retry");
    expect(keys).toContain("l10n.up");
    // And never the JavaScript error, which is a fact about this code rather
    // than about the user's machine.
    expect(texts(lastDrawn(host)).some((t) => t.includes("no exec"))).toBe(
      false,
    );
  });
});

describe("the order and what is missing", () => {
  const DENIED = `df
/dev/vda1 51475068 48901120 1934564 97% /
du
du: cannot read directory '/root': Permission denied
8192	/usr
34041852	/var
51475068	/
`;

  test("largest first by default, and by name when asked", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    const first = () =>
      texts(lastDrawn(host)).filter((t) => t === "var" || t === "usr");

    expect(first()[0]).toBe("var");

    const out = await plugin.onEvent({ m: "sort" });
    const names = texts(out.ui!).filter((t) => t === "var" || t === "usr");
    expect(names[0]).toBe("usr");
    // Remembered: the order somebody chose is a preference, not a property of
    // the directory they were in.
    expect(host.value("global", "sortBy")).toBe("name");
  });

  /// The measurement is short by whatever is in them and nothing else on the
  /// page says so.
  test("directories that could not be read are reported", async () => {
    const host = new MockHost().exec(command("/"), { stdout: DENIED });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    expect(l10nKeys(lastDrawn(host))).toContain("l10n.unreadableOne");
  });

  test("a clean reading says nothing about it", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    const keys = l10nKeys(lastDrawn(host));
    expect(keys).not.toContain("l10n.unreadableOne");
    expect(keys).not.toContain("l10n.unreadable");
  });
});
