/**
 * The plugin against the mock host: descending, coming back up, and where it
 * remembers you were.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost } from "@serverbox/plugin-api/test";
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

function texts(node: Node): string[] {
  const out: string[] = [];
  const walk = (n: Node) => {
    if (n.t === "text" && typeof n.p?.value === "string") out.push(n.p.value);
    for (const c of n.c ?? []) walk(c);
  };
  walk(node);
  return out;
}

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
    expect(drawn.some((t) => t.includes("in /"))).toBe(true);
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
    expect(texts(patches[0]!.node)).toContain("Measuring…");
  });

  /// `df` is what turns "31G in /var" into something that means anything.
  test("shows the filesystem behind the directory", async () => {
    const host = hostWith();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    expect(texts(lastDrawn(host)).some((t) => t.includes("/ 49G"))).toBe(true);
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
    expect(texts(lastDrawn(host)).some((t) => t.includes("no exec"))).toBe(
      true,
    );
  });
});
