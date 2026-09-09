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

/** Lets everything already queued run, including the store reads a draw waits on. */
const flush = () => new Promise((r) => setTimeout(r, 0));

const enter: HookEvent = {
  kind: "enter",
  contribution: "usage",
  servers: [{ server: "h-1" as ServerHandle, name: "web" }],
};


describe("the settings form", () => {
  /// The first plugin surface with a form rather than a switch, which is what
  /// PLUGINS.md 5 asked for before opening this to anybody else: several
  /// fields, values that can be wrong, and a way back to the defaults.
  test("it draws every field, from the store", async () => {
    const host = new MockHost({
      global: {
        startAt: "/var",
        skipNames: "node_modules .cache",
        hideBelowMib: "64",
      },
    });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    // The form is drawn by the hook, not by `open`: a promise left running when
    // a call returns does not progress, so the waiting belongs in the call that
    // always follows — see `onHook`.
    await plugin.onHook({ ...enter, contribution: "prefs", servers: [] });

    const shown = texts(lastDrawn(host));
    expect(shown).toContain("/var");
    expect(shown).toContain("node_modules .cache");
    expect(shown).toContain("64");
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.prefsReset");
  });

  /// **Rejected rather than ignored.** An unusable path used to be dropped when
  /// it was read back, which means the user is looking at a value they believe
  /// is in effect and is not.
  test("a path that is not one is refused, with the reason and the text kept", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    await plugin.onEvent({ msg: { m: "setStartAt" }, value: "not a path" });

    expect(host.value("global", "startAt")).toBeUndefined();
    const drawn = lastDrawn(host);
    expect(l10nKeys(drawn)).toContain("l10n.prefsErrPath");
    // What they typed is still there to be corrected. Redrawing the stored
    // value under somebody being told their input is wrong takes away the
    // thing they need to fix.
    expect(texts(drawn)).toContain("not a path");
  });

  test("a size that is not a whole number is refused", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    await plugin.onEvent({ msg: { m: "setHideBelow" }, value: "1.5" });

    expect(host.value("global", "hideBelowMib")).toBeUndefined();
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.prefsErrNumber");
  });

  test("a good value is stored, and clears what was said about the last one", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    await plugin.onEvent({ msg: { m: "setStartAt" }, value: "nope" });
    await plugin.onEvent({ msg: { m: "setStartAt" }, value: "/srv" });

    expect(host.value("global", "startAt")).toBe("/srv");
    expect(l10nKeys(lastDrawn(host))).not.toContain("l10n.prefsErrPath");
  });

  /// Empty is how a text field says "back to the default", and the default
  /// belongs to the build — so it is cleared rather than written down.
  test("emptying a field clears it rather than storing a default", async () => {
    const host = new MockHost({ global: { startAt: "/var" } });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    await plugin.onEvent({ msg: { m: "setStartAt" }, value: "  " });

    expect(host.value("global", "startAt")).toBeUndefined();
  });

  test("reset clears every key the form owns", async () => {
    const host = new MockHost({
      global: {
        startAt: "/var",
        skipNames: "x",
        hideBelowMib: "64",
        crossFilesystems: "1",
      },
    });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    await plugin.onEvent({ msg: { m: "resetPrefs" }, value: undefined });

    for (const key of ["startAt", "skipNames", "hideBelowMib", "crossFilesystems"]) {
      expect(host.value("global", key)).toBeUndefined();
    }
  });
});

describe("what the filters leave", () => {
  test("a skipped name and a small directory are left out, and counted", async () => {
    const host = new MockHost({
      global: { skipNames: "cache", hideBelowMib: "16" },
    }).exec(command("/var"), { stdout: VAR });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "page", id: "usage" });
    await plugin.onHook({ ...enter, servers: enter.servers });
    await plugin.onEvent({ msg: { m: "open", path: "/var" }, value: undefined });

    const shown = texts(lastDrawn(host));
    // `/var/cache` is skipped by name; `/var/log` is 1 GiB and stays.
    expect(shown).not.toContain("cache");
    expect(shown).toContain("log");
    // And the page says something was taken, rather than quietly being short.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.hiddenByFilter");
  });

  test("with no filters set, nothing is hidden and nothing is said", async () => {
    const host = new MockHost().exec(command("/var"), { stdout: VAR });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "page", id: "usage" });
    await plugin.onHook({ ...enter, servers: enter.servers });
    await plugin.onEvent({ msg: { m: "open", path: "/var" }, value: undefined });

    expect(texts(lastDrawn(host))).toContain("cache");
    expect(l10nKeys(lastDrawn(host))).not.toContain("l10n.hiddenByFilter");
  });
});

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
    await plugin.onEvent({ msg: { m: "open", path: "/var" } });

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
    await plugin.onEvent({ msg: { m: "open", path: "/var" } });
    const before = host.callsTo("server.exec").length;

    await plugin.onEvent({ msg: { m: "up" } });
    expect(host.callsTo("server.exec")).toHaveLength(before + 1);

    // At the root there is nowhere to go, so nothing is asked.
    await plugin.onEvent({ msg: { m: "up" } });
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

    await plugin.onEvent({ msg: { m: "select" } });
    // The same tap that descended a moment ago now picks, and measures
    // nothing: descending while picking would take the selection out of sight
    // of the person who made it.
    await plugin.onEvent({ msg: { m: "pick", path: "/var" } });

    expect(host.callsTo("server.exec")).toHaveLength(before);
    const out = await plugin.onEvent({ msg: { m: "pick", path: "/usr" } });
    expect(l10nKeys(out.ui!)).toContain("l10n.delete");
  });

  test("nothing is removed until the dialog is answered", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", path: "/var" } });
    // Cancelled, which is the default this mock gives when nothing is scripted
    // — and the point: a delete that ran anyway would be unrecoverable.
    host.answerPrompt({ cancelled: true });
    await plugin.onEvent({ msg: { m: "delete" } });

    expect(
      host.callsTo("server.exec").some((c) => c.req.script.includes("rm")),
    ).toBe(false);
  });

  test("what it removes is quoted, and the options are ended", async () => {
    const host = hostWith().confirmNext();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", path: "/var" } });
    await plugin.onEvent({ msg: { m: "delete" } });

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

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", path: "/var" } });
    await plugin.onEvent({ msg: { m: "delete" } });

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

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", path: "/var" } });
    await plugin.onEvent({ msg: { m: "cancelSelect" } });
    await plugin.onEvent({ msg: { m: "open", path: "/var" } });

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
    await plugin.onEvent({ msg: { m: "open", path: "/var" } });

    expect(host.value("server", "lastPath")).toBe("/var");
  });

  test("and comes back to it", async () => {
    const host = hostWith();
    restore = host.install();
    const first = await load();
    await first.onHook(enter);
    await first.onEvent({ msg: { m: "open", path: "/var" } });

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
    await plugin.onEvent({ msg: { m: "open", path: "/var" } });

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

    const out = await plugin.onEvent({ msg: { m: "sort" } });
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
