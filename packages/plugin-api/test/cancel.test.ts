/**
 * Giving up on a command, and saying honestly what that did.
 *
 * The thing being held here is not that a cancel works — it is that a plugin
 * can tell the two outcomes apart. Over SSH the channel carries a signal and
 * the command really stops; over a monitor agent one HTTP request carries the
 * whole run, so abandoning it leaves the command walking a filesystem with
 * nobody reading its output. A plugin that says "stopped" over the second case
 * has told somebody their server is idle when it is not, and nothing else in
 * the app would ever correct it.
 */

import { describe, expect, test } from "bun:test";

import { MockHost } from "../src/test.ts";
import { classify, reason } from "../src/index.ts";
import type { ServerHandle } from "../src/index.ts";

const SERVER = "h:one" as ServerHandle;
const SCAN = "du -x -d 1 /";

/**
 * Starts a run and catches its failure straight away.
 *
 * The `catch` has to be attached before the cancel, or the rejection is
 * unhandled for a turn and the test runner reports it as a failure of its own.
 * A plugin does not have this problem — it `await`s the call — but a test that
 * starts one and goes off to press a button does.
 */
function start(key: string): Promise<unknown> {
  return sb.server
    .exec({ server: SERVER, script: SCAN, cancelKey: key })
    .then(() => new Error("it answered instead of being stopped"))
    .catch((e: unknown) => e);
}

describe("sb.server.cancel", () => {
  test("stops a run that carries the key, and says how many", async () => {
    const host = new MockHost().execWaits(SCAN);
    const restore = host.install();
    try {
      const running = start("scan");

      const answer = await sb.server.cancel({ key: "scan" });

      expect(answer.stopped).toBe(1);
      expect(await running).toMatchObject({ kind: "cancelled" });
    } finally {
      restore();
    }
  });

  /// One key covers several machines on purpose: a fleet-wide surface asks
  /// twenty servers the same question, and stopping is stopping all of them.
  test("one key stops every run carrying it", async () => {
    const host = new MockHost().execWaits(SCAN);
    const restore = host.install();
    try {
      const first = start("scan");
      const second = start("scan");

      expect((await sb.server.cancel({ key: "scan" })).stopped).toBe(2);

      expect(await first).toMatchObject({ kind: "cancelled" });
      expect(await second).toMatchObject({ kind: "cancelled" });
    } finally {
      restore();
    }
  });

  /// Not a failure. A Stop pressed as the answer came back names nothing, and
  /// the page is already showing the result.
  test("a key nothing is running under answers zero", async () => {
    const host = new MockHost();
    const restore = host.install();
    try {
      expect(await sb.server.cancel({ key: "scan" })).toEqual({ stopped: 0 });
    } finally {
      restore();
    }
  });

  /// Stopping a command is part of running one, so the same grant covers both
  /// — and a plugin denied `server.exec` is refused here in the same way,
  /// rather than being handed a call that quietly does nothing.
  test("it needs the same permission running one does", async () => {
    const host = new MockHost({ denied: ["server.exec"] });
    const restore = host.install();
    try {
      await expect(sb.server.cancel({ key: "scan" })).rejects.toMatchObject({
        name: "PermissionDenied",
      });
    } finally {
      restore();
    }
  });
});

describe("what the plugin is told", () => {
  test("a structured refusal keeps the permission", () => {
    const denied = Object.assign(new Error("wording may change"), {
      name: "PermissionDenied",
      kind: "denied",
      operation: "sb.server.exec",
      permission: "server.exec",
    });

    expect(classify(denied)).toEqual({
      kind: "denied",
      permission: "server.exec",
    });

    expect(
      classify(
        Object.assign(new Error("wording may change"), {
          kind: "bad_request",
          operation: "sb.server.exec",
        }),
      ),
    ).toEqual({ kind: "bad_request" });
  });

  test("an SSH run really stopped", async () => {
    const host = new MockHost().execWaits(SCAN, "stopped");
    const restore = host.install();
    try {
      const running = start("scan");
      await sb.server.cancel({ key: "scan" });

      const e = await running;
      expect(classify(e)).toEqual({ kind: "cancelled", remote: "stopped" });
      expect(reason(e, "…")).toBe("Stopped.");
    } finally {
      restore();
    }
  });

  /// The case the whole distinction exists for.
  test("an agent run is still going", async () => {
    const host = new MockHost().execWaits(SCAN, "running");
    const restore = host.install();
    try {
      const running = start("scan");
      await sb.server.cancel({ key: "scan" });

      const e = await running;
      expect(classify(e)).toEqual({ kind: "cancelled", remote: "running" });
      expect(reason(e, "…")).toContain("still running on the server");
    } finally {
      restore();
    }
  });

  /// A timeout is the same mechanism — the app stops waiting — so it carries
  /// the same answer, and a plugin that handles one handles the other.
  test("a timeout carries it too", () => {
    const timedOut = Object.assign(new Error("took too long"), {
      name: "HostError",
      kind: "timeout",
      remote: "running",
    });

    expect(classify(timedOut)).toEqual({ kind: "timeout", remote: "running" });
    expect(reason(timedOut, "…")).toContain("still running there");
  });

  /// A failure with no answer to give must not read as one of the two: absent
  /// is its own state, and `remote === "stopped"` has to mean the host said so.
  test("a failure that is not a stop carries nothing", () => {
    const io = Object.assign(new Error("no route to host"), {
      name: "HostError",
      kind: "io",
    });

    expect(classify(io)).toEqual({ kind: "io" });
    expect("remote" in classify(io)).toBe(false);
  });

  /// The host is what decides, so a value it did not send is not one to carry
  /// through: an `Error` a plugin built itself, or one from an older app.
  test("a remote the host did not send is dropped", () => {
    const odd = Object.assign(new Error("stopped"), {
      name: "HostError",
      kind: "cancelled",
      remote: "probably",
    });

    expect(classify(odd)).toEqual({ kind: "cancelled" });
  });
});
