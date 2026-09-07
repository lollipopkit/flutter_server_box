/**
 * The mock host, driven by a whole plugin.
 *
 * PLUGINS.md 5.3: a plugin's logic runs here with no QuickJS and no app, so
 * this is also the shape a plugin author's own tests take.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost, find, l10nKeys, pathOf } from "../src/test.ts";
import type { Node } from "../src/index.ts";

const PIN = "aa11bb22cc33dd44ee55ff660011223344556677889900aabbccddeeff001122";

let restore: () => void;

function mount(host: MockHost) {
  restore = host.install();
}

afterEach(() => restore?.());

/** Re-imported per test, so module-level state does not leak between them. */
async function loadPlugin() {
  return await import(`../test/example.plugin.ts?${Math.random()}`);
}

describe("a plugin against the mock host", () => {
  test("reads config, calls the host, and draws what came back", async () => {
    const host = new MockHost({ config: { server: "h-1" } }).exec("uptime -p", {
      stdout: "up 3 days\n",
    });
    mount(host);

    const p = await loadPlugin();
    const { ui } = await p.open({ kind: "card", id: "x" });

    expect(host.called()).toContain("server.exec");
    expect(JSON.stringify(ui)).toContain("up 3 days");
    // And what it learned was written down, so a later instance starts warm.
    expect(host.value("server", "uptime")).toBe("up 3 days");
  });

  /// A host that could not do the thing is an answer the plugin handles, not a
  /// crash.
  test("a host failure becomes something the card can say", async () => {
    const host = new MockHost({ config: { server: "h-1" } }); // no exec scripted
    mount(host);

    const p = await loadPlugin();
    const { ui } = await p.open({ kind: "card", id: "x" });

    expect(l10nKeys(ui as Node)).toContain("l10n.example.failed");
    expect(host.logs.map(([lvl]) => lvl)).toContain("warn");
  });

  test("a message survives the round trip and reaches the right branch", async () => {
    const host = new MockHost({ config: { server: "h-1" }, server: { uptime: "up 1 day" } })
      .exec("uptime -p", { stdout: "up 3 days\n" });
    mount(host);

    const p = await loadPlugin();
    const { ui } = await p.open({ kind: "card", id: "x" });

    const wipe = find(ui as Node, "wipe");
    expect(wipe).toBeDefined();
    await p.onEvent(wipe!.on!.tap);

    expect(host.value("server", "uptime")).toBeUndefined();
  });

  /// Module-level state is where a plugin keeps things between calls, so a
  /// test that shares it between cases is a test that passes for the wrong
  /// reason. `loadPlugin` re-imports to avoid that.
  test("state persists within an instance and a fresh one starts clean", async () => {
    const host = new MockHost({ config: { server: "h-1" } }).exec("uptime -p", {
      stdout: "up 3 days\n",
    });
    mount(host);

    const first = await loadPlugin();
    await first.open({ kind: "card", id: "x" });
    // Nothing configured now, so `refresh` cannot overwrite what it holds.
    host.route("GET", "/unused", {});
    const kept = await first.onEvent({ m: "refresh" });
    expect(JSON.stringify(kept.ui)).toContain("up 3 days");

    const second = await loadPlugin();
    const fresh = await second.open({ kind: "card", id: "x" });
    expect(JSON.stringify(fresh.ui)).toContain("up 3 days");
    // The second module read nothing from the first: it called the host again.
    expect(host.callsTo("server.exec").length).toBe(3);
  });
});

describe("the mock refuses what the real host refuses", () => {
  test("a request with no reviewed certificate is not sent", async () => {
    const host = new MockHost().get("/redfish/v1/", { ok: true });
    mount(host);
    await expect(sb.http.fetch({ url: "https://10.0.0.9/redfish/v1/" })).rejects.toThrow(
      /no reviewed certificate/,
    );
  });

  test("a pinned request goes through", async () => {
    const host = new MockHost().get("/redfish/v1/", { ok: true });
    mount(host);
    const r = await sb.http.fetch({ url: "https://10.0.0.9/redfish/v1/", pinSha256: PIN });
    expect(JSON.parse(r.body)).toEqual({ ok: true });
    expect(host.requests()).toEqual(["GET /redfish/v1/"]);
  });

  /// What makes accepting any certificate safe for the review step is that
  /// nothing is sent.
  test("a certificate probe that carries anything is refused", async () => {
    mount(new MockHost().route("GET", "/", { cert: { sha256: PIN } }));
    await expect(
      sb.http.fetch({ url: "https://10.0.0.9/", probeCert: true, body: "pw=hunter2" }),
    ).rejects.toThrow(/sends nothing/);
  });

  test("a certificate probe answers the fingerprint", async () => {
    mount(new MockHost().route("GET", "/", { cert: { sha256: PIN, subject: "CN=bmc" } }));
    const r = await sb.http.fetch({ url: "https://10.0.0.9/", probeCert: true });
    expect(r.cert?.sha256).toBe(PIN);
    expect(r.cert?.subject).toBe("CN=bmc");
    expect(r.cert?.expired).toBe(false);
  });

  test("a permission the manifest did not ask for throws by name", async () => {
    mount(new MockHost({ denied: ["ui.dialog"] }));
    await expect(sb.ui.prompt({ title: "t" })).rejects.toMatchObject({
      name: "PermissionDenied",
    });
    // And one that was asked for still works.
    await expect(sb.ui.toast("hi")).resolves.toBeUndefined();
  });
});

describe("scripting", () => {
  test("a route replaces, and routeOnce answers once", async () => {
    const host = new MockHost().get("/x", { n: 1 });
    mount(host);
    const read = async () =>
      JSON.parse((await sb.http.fetch({ url: `https://h/x`, pinSha256: PIN })).body);

    expect(await read()).toEqual({ n: 1 });
    host.routeOnce("GET", "/x", { body: JSON.stringify({ n: 2 }) });
    expect(await read()).toEqual({ n: 2 });
    expect(await read()).toEqual({ n: 1 });
  });

  /// Nothing scripted is a user who walked away, which is the safe reading for
  /// a dialog that can power off a machine.
  test("an unscripted dialog counts as cancelled", async () => {
    mount(new MockHost());
    expect((await sb.ui.prompt({ title: "power off?" })).cancelled).toBe(true);
  });

  test("store list is prefixed and sorted", async () => {
    mount(new MockHost({ global: { "cred/b": "1", "cred/a": "2", other: "3" } }));
    expect(await sb.store.list("global", "cred/")).toEqual(["cred/a", "cred/b"]);
  });
});

describe("helpers", () => {
  test("pathOf drops the origin", () => {
    expect(pathOf("https://10.0.0.9:8443/redfish/v1/?x=1")).toBe("/redfish/v1/?x=1");
    expect(pathOf("https://10.0.0.9")).toBe("/");
    expect(pathOf("/already/a/path")).toBe("/already/a/path");
  });

  test("find walks depth first and answers undefined for a miss", () => {
    const tree: Node = { t: "card", c: [{ t: "row", c: [{ t: "btn", k: "go" }] }] };
    expect(find(tree, "go")?.t).toBe("btn");
    expect(find(tree, "nope")).toBeUndefined();
  });
});
