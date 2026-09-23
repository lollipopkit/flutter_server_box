/**
 * The plugin against the mock host: descending, coming back up, and where it
 * remembers you were.
 */

import { afterEach, describe, expect, test } from "bun:test";

import {
  MockHost,
  find,
  l10nKeys,
  messageOf,
  taps,
  texts,
} from "@serverbox/plugin-api/test";
import type { HookEvent, Node, Plugin, ServerHandle } from "@serverbox/plugin-api";
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

/// The separator `l10n(key, ...args)` puts between the two, so a label with a
/// count in it can be named here the way the tree carries it.
const SEP = "\u001F";

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


/**
 * Opens the page the way the app does, and lets the measurement land.
 *
 * Three calls, because the app makes three. `open` draws, `onHook` is where a
 * plugin starts collecting — and the scan is a `background` resource, so the
 * hook answers with `Measuring…` rather than holding the instance for the
 * length of a `du`. The reading arrives on the next call into the plugin,
 * which in the app is the tick the surface fires as soon as the answer is in
 * (`PluginSurfaceView._onHostAnswered`).
 *
 * A test that stops after `onHook` is looking at the loading state, which is a
 * true picture of that moment and not of the page.
 */
async function enterPage(plugin: Plugin, event: HookEvent = enter) {
  plugin.open!({ kind: "page", id: event.contribution } as never);
  await plugin.onHook!(event);
  await plugin.tick!();
}

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
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    // The form is drawn by the hook, not by `open`: a promise left running when
    // a call returns does not progress, so the waiting belongs in the call that
    // always follows — see `onHook`.
    await plugin.onHook({ ...enter, contribution: "prefs", servers: [] });

    const shown = texts(screen(plugin, "settings", "prefs"));
    expect(shown).toContain("/var");
    expect(shown).toContain("node_modules .cache");
    expect(shown).toContain("64");
    expect(l10nKeys(screen(plugin, "settings", "prefs"))).toContain("l10n.prefsReset");
  });

  /// **Rejected rather than ignored.** An unusable path used to be dropped when
  /// it was read back, which means the user is looking at a value they believe
  /// is in effect and is not.
  test("a path that is not one is refused, with the reason and the text kept", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    await tap(plugin, "/", {
      kind: "settings",
      id: "prefs",
      event: "change",
      value: "not a path",
    });

    expect(host.value("global", "startAt")).toBeUndefined();
    const drawn = screen(plugin, "settings", "prefs");
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
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    await tap(plugin, "0", {
      kind: "settings",
      id: "prefs",
      event: "change",
      value: "1.5",
    });

    expect(host.value("global", "hideBelowMib")).toBeUndefined();
    expect(l10nKeys(screen(plugin, "settings", "prefs"))).toContain("l10n.prefsErrNumber");
  });

  test("a good value is stored, and clears what was said about the last one", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    await tap(plugin, "/", {
      kind: "settings",
      id: "prefs",
      event: "change",
      value: "nope",
    });
    await tap(plugin, "/", {
      kind: "settings",
      id: "prefs",
      event: "change",
      value: "/srv",
    });

    expect(host.value("global", "startAt")).toBe("/srv");
    expect(l10nKeys(screen(plugin, "settings", "prefs"))).not.toContain("l10n.prefsErrPath");
  });

  /// Empty is how a text field says "back to the default", and the default
  /// belongs to the build — so it is cleared rather than written down.
  test("emptying a field clears it rather than storing a default", async () => {
    const host = new MockHost({ global: { startAt: "/var" } });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "settings", id: "prefs" });
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    await tap(plugin, "/", {
      kind: "settings",
      id: "prefs",
      event: "change",
      value: "  ",
    });

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
    // And hooks it, which is the call the store reads the form needs get
    // to finish in — the host drives an instance only while it is inside one.
    await plugin.onHook({ kind: "enter", contribution: "prefs", servers: [] });
    await tap(plugin, "l10n.prefsReset", { kind: "settings", id: "prefs" });

    for (const key of ["startAt", "skipNames", "hideBelowMib", "crossFilesystems"]) {
      expect(host.value("global", key)).toBeUndefined();
    }
  });
});

describe("what the filters leave", () => {
  test("a skipped name and a small directory are left out, and counted", async () => {
    const host = new MockHost({
      // Started where the listing is: this is about the filters, and
      // descending has its own tests.
      global: { skipNames: "cache", hideBelowMib: "16", startAt: "/var" },
    }).exec(command("/var"), { stdout: VAR });
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);

    const shown = texts(screen(plugin));
    // `/var/cache` is skipped by name; `/var/log` is 1 GiB and stays.
    expect(shown).not.toContain("cache");
    expect(shown).toContain("log");
    // And the page says something was taken, rather than quietly being short.
    expect(l10nKeys(screen(plugin))).toContain("l10n.hiddenByFilter");
  });

  test("with no filters set, nothing is hidden and nothing is said", async () => {
    const host = new MockHost({ global: { startAt: "/var" } }).exec(
      command("/var"),
      { stdout: VAR },
    );
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);

    expect(texts(screen(plugin))).toContain("cache");
    expect(l10nKeys(screen(plugin))).not.toContain("l10n.hiddenByFilter");
  });
});

/** The tree of the last patch, for when the patch itself is the subject. */
function lastDrawn(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}

/**
 * The whole tree as it stands.
 *
 * A patch carries a *diff* — every unchanged subtree is a stub — so reading one
 * says what changed rather than what is on screen. `open` draws in full against
 * the state the plugin already holds.
 */
function screen(plugin: Plugin, kind = "page", id = "usage"): Node {
  const out = plugin.open!({ kind, id } as never) as { ui?: Node };
  return out.ui!;
}

/**
 * Taps the thing labelled [label], the way the app does.
 *
 * A handler is a closure, so what crosses is a token the SDK made: there is no
 * message to write by hand, and a test that wrote one would be speaking a
 * protocol the plugin does not.
 */
async function tap(
  plugin: Plugin,
  label: string,
  opts: { kind?: string; id?: string; value?: unknown; event?: string } = {},
) {
  const tree = screen(plugin, opts.kind ?? "page", opts.id ?? "usage");
  const event = opts.event ?? "tap";
  const msg = messageOf(tree, label, event);
  expect(msg, `nothing labelled ${label} answers ${event}`).toBeDefined();
  const out = await plugin.onEvent!({ msg, value: opts.value });
  // And what the tap *started* — a measurement is a fetch the handler does not
  // wait for, so the answer to the tap is the loading state and the reading
  // lands on the next call in. The app is driving the whole time; a test has
  // to say so. See `enterPage`.
  await new Promise((done) => setTimeout(done, 0));
  await plugin.tick!();
  return out;
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

    await enterPage(plugin);

    expect(host.callsTo("server.exec")[0]!.req.script).toBe(command("/"));
    const drawn = texts(screen(plugin));
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

    await enterPage(plugin);

    // The measuring state is what the page shows while the command runs, and
    // the reading replaces it. Both are patches: the first says the tap did
    // something, the second answers it.
    const patches = host.callsTo("ui.patch");
    expect(patches.length).toBeGreaterThanOrEqual(2);
    expect(
      patches.some((p) => l10nKeys(p.node).includes("l10n.measuring")),
    ).toBe(true);
  });

  /// `df` is what turns "31G in /var" into something that means anything.
  test("shows the filesystem behind the directory", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);

    // A translated sentence with both figures as arguments, so the tree
    // carries the key and the app substitutes.
    expect(l10nKeys(screen(plugin))).toContain("l10n.filesystem");
  });
});

describe("descending", () => {
  test("a tap measures the child, not the whole tree again", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");

    expect(host.callsTo("server.exec").map((c) => c.req.script)).toEqual([
      command("/"),
      command("/var"),
    ]);
    const drawn = texts(screen(plugin));
    expect(drawn).toContain("lib");
    expect(drawn).toContain("log");
  });

  test("up goes to the parent, and the root offers no up", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");
    const before = host.callsTo("server.exec").length;

    await tap(plugin, "↑");
    expect(host.callsTo("server.exec")).toHaveLength(before + 1);

    // At the root there is nowhere to go, so the control is not there —
    // rather than there and doing nothing, which is a button that lies.
    expect(messageOf(screen(plugin), "↑")).toBeUndefined();
  });
});

describe("picking and deleting", () => {
  test("picking changes what a tap on a row means", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await enterPage(plugin);
    const before = host.callsTo("server.exec").length;

    await tap(plugin, "l10n.select");
    // The same tap that descended a moment ago now picks, and measures
    // nothing: descending while picking would take the selection out of sight
    // of the person who made it.
    await tap(plugin, "var");

    expect(host.callsTo("server.exec")).toHaveLength(before);
    await tap(plugin, "usr");
    expect(
      l10nKeys(screen(plugin)).some((k) => k.startsWith("l10n.delete")),
    ).toBe(true);

    // A row that picks and does not say it is picked is a count with nothing
    // behind it. The tint carries it — the app's own selected row — with the
    // icon as the affordance beside it.
    expect(JSON.stringify(find(screen(plugin), "/var|true|true"))).toContain(
      '"selected":true',
    );
  });

  test("nothing is removed until the dialog is answered", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await enterPage(plugin);

    await tap(plugin, "l10n.select");
    await tap(plugin, "var");
    // Cancelled, which is the default this mock gives when nothing is scripted
    // — and the point: a delete that ran anyway would be unrecoverable.
    host.answerPrompt({ cancelled: true });
    await tap(plugin, "l10n.delete" + SEP + "1");

    expect(
      host.callsTo("server.exec").some((c) => c.req.script.includes("rm")),
    ).toBe(false);
  });

  test("what it removes is quoted, and the options are ended", async () => {
    const host = hostWith().confirmNext();
    restore = host.install();
    const plugin = await load();
    await enterPage(plugin);

    await tap(plugin, "l10n.select");
    await tap(plugin, "var");
    await tap(plugin, "l10n.delete" + SEP + "1");

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
    await enterPage(plugin);

    await tap(plugin, "l10n.select");
    await tap(plugin, "var");
    await tap(plugin, "l10n.delete" + SEP + "1");

    // What `rm` actually removed is a question for the machine, and every
    // other row's share of the total moved with it.
    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    expect(scripts[scripts.length - 1]).toBe(command("/"));
    // And the selection is over: it described rows that no longer exist.
    expect(texts(screen(plugin)).some((t) => t.includes("Delete"))).toBe(false);
  });

  test("descending clears the selection", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();
    await enterPage(plugin);

    await tap(plugin, "l10n.select");
    await tap(plugin, "var");
    await tap(plugin, "l10n.cancel");
    await tap(plugin, "var");

    // A selection is about what is in front of you; carried down it would mean
    // a delete that removes something off screen.
    expect(texts(screen(plugin)).some((t) => t.includes("Delete"))).toBe(false);
  });
});

describe("where it left you", () => {
  /// Per server, because "the big directory" is a property of the machine and
  /// not of the person looking at it.
  test("remembers the directory against the server", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");

    expect(host.value("server", "lastPath")).toBe("/var");
  });

  test("and comes back to it", async () => {
    const host = hostWith();
    restore = host.install();
    const first = await load();
    await enterPage(first);
    await tap(first, "var");

    // A fresh instance, as a second visit is.
    const again = await load();
    await enterPage(again);

    const asked = host.callsTo("server.exec").map((c) => c.req.script);
    expect(asked[asked.length - 1]).toBe(command("/var"));
  });

  /// A directory measured but never confirmed should not be where the next
  /// visit starts.
  test("a level that failed is not remembered", async () => {
    const host = new MockHost().exec(command("/"), { stdout: ROOT });
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");

    expect(host.value("server", "lastPath")).toBe("/");
    // The failure is drawn, with the two ways off it — and without the
    // JavaScript error, which is a fact about this code rather than about the
    // user's machine.
    const keys = l10nKeys(screen(plugin));
    expect(keys).toContain("l10n.errTitle");
    expect(keys).toContain("l10n.retry");
    expect(keys).toContain("l10n.up");
    // And never the JavaScript error, which is a fact about this code rather
    // than about the user's machine.
    expect(texts(screen(plugin)).some((t) => t.includes("no exec"))).toBe(
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
    await enterPage(plugin);

    const first = () =>
      texts(screen(plugin)).filter((t) => t === "var" || t === "usr");

    expect(first()[0]).toBe("var");

    await tap(plugin, "l10n.sortSize");
    const names = first();
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

    await enterPage(plugin);

    expect(l10nKeys(screen(plugin))).toContain("l10n.unreadableOne");
  });

  test("a clean reading says nothing about it", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);

    const keys = l10nKeys(screen(plugin));
    expect(keys).not.toContain("l10n.unreadableOne");
    expect(keys).not.toContain("l10n.unreadable");
  });
});

describe("stopping a scan", () => {
  /**
   * A `du` over a full disk is minutes of a machine's IO, and the decision to
   * give up on one is not a number anybody can pick before it starts. So the
   * control has to be *there while it runs* — which is the whole of what these
   * hold: the reload turns into a Stop, the Stop reaches the run, and what the
   * page then says is the one thing the plugin cannot work out for itself.
   */
  function scanning() {
    return new MockHost()
      .exec(command("/"), { stdout: ROOT })
      .execWaits(command("/var"), "stopped");
  }

  test("the reload becomes a Stop while a level is measuring", async () => {
    const host = scanning();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    // The root came back; this one hangs.
    await tap(plugin, "var");

    const keys = l10nKeys(screen(plugin));
    expect(keys).toContain("l10n.stop");
    // Not both. Reloading here would start a second `du` over a directory the
    // first is still walking.
    expect(keys).not.toContain("l10n.reload");
  });

  /// Over SSH the channel carries a signal, so the command really stopped and
  /// the page says so plainly.
  test("an SSH scan is reported as stopped", async () => {
    const host = scanning();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");
    await tap(plugin, "l10n.stop");

    expect(host.callsTo("server.cancel").map((c) => c.key)).toEqual(["scan"]);
    expect(l10nKeys(screen(plugin))).toContain("l10n.errCancelled");
  });

  /// And over a monitor agent it did not: one request carried the whole run,
  /// so `du` is still walking that filesystem. Saying "Stopped." here would
  /// tell somebody their server is idle while it is not, and nothing else in
  /// the app would ever correct it.
  test("an agent scan says the command is still running", async () => {
    const host = new MockHost()
      .exec(command("/"), { stdout: ROOT })
      .execWaits(command("/var"), "running");
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);
    await tap(plugin, "var");
    await tap(plugin, "l10n.stop");

    const keys = l10nKeys(screen(plugin));
    expect(keys).toContain("l10n.errCancelledRunning");
    expect(keys).not.toContain("l10n.errCancelled");
  });

  /// The level is measured under a key, or the Stop reaches nothing.
  test("the scan carries the key the Stop names", async () => {
    const host = scanning();
    restore = host.install();
    const plugin = await load();

    await enterPage(plugin);

    expect(host.callsTo("server.exec")[0]!.req.cancelKey).toBe("scan");
  });
});
