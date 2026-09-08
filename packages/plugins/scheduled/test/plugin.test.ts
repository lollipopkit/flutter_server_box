/**
 * The plugin against the mock host, and mostly the write.
 *
 * The read is the same shape as the other two plugins here. What is new is a
 * change to the machine: it is confirmed before it happens, it is
 * compare-and-swap, and a refusal means reload rather than retry.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost } from "@serverbox/plugin-api/test";
import type { HookEvent, Node, ServerHandle } from "@serverbox/plugin-api";
import { READ_COMMAND, toggled, writeCommand } from "../src/schedule.ts";

const LINES = [
  "MAILTO=root",
  "0 3 * * * /opt/backup.sh",
  "#30 4 * * 0 /opt/weekly.sh",
];

const SUM = "2917190459 218";

const READ = `cron
${LINES.join("\n")}
cronsum
${SUM}
hascron
yes
timers
Mon 2026-09-08 06:00:00 UTC 8h left Sun 2026-09-07 06:00:00 UTC 15h ago logrotate.timer logrotate.service
`;

let restore: () => void;
afterEach(() => restore?.());

async function load() {
  return await import(`../src/plugin.ts?${Math.random()}`);
}

const enter: HookEvent = {
  kind: "enter",
  contribution: "scheduled",
  servers: [{ server: "h-1" as ServerHandle, name: "web" }],
};

/**
 * Every word on screen, out of both the nodes that carry one.
 *
 * `tag` puts its word in `label` and `text` in `value`, and "on"/"off" is a
 * tag — so a walker that only looked at `text` would report a row as having no
 * state at all.
 */
function texts(node: Node): string[] {
  const out: string[] = [];
  const walk = (n: Node) => {
    for (const prop of ["value", "label"]) {
      const v = n.p?.[prop];
      if (typeof v === "string") out.push(v);
    }
    for (const c of n.c ?? []) walk(c);
  };
  walk(node);
  return out;
}

function lastDrawn(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}

/** The write this plugin would send to turn line 1 off. */
const WRITE_OFF = writeCommand(toggled(LINES, 1), SUM);

describe("reading", () => {
  test("draws the jobs and the timers together", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);

    const drawn = texts(lastDrawn(host));
    expect(drawn).toContain("/opt/backup.sh");
    expect(drawn).toContain("logrotate.timer");
    expect(drawn.some((t) => t.includes("2 cron"))).toBe(true);
    // `MAILTO=root` is a setting, not a job.
    expect(drawn).not.toContain("MAILTO=root");
  });
});

describe("turning a job off", () => {
  // A change to a machine is asked about before it happens, and the question
  // names the command rather than the line number.
  test("asks first, and does nothing if the answer is no", async () => {
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .exec(WRITE_OFF, { stdout: "ok\n111 22\n" })
      .answerPrompt({ cancelled: true });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "toggle", line: 1 });

    expect(host.callsTo("ui.prompt")).toHaveLength(1);
    expect(host.callsTo("ui.prompt")[0]!.spec.message).toContain(
      "/opt/backup.sh",
    );
    // One exec: the read. Nothing was written.
    expect(host.callsTo("server.exec")).toHaveLength(1);
  });

  test("writes the whole file back when the answer is yes", async () => {
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .exec(WRITE_OFF, { stdout: "ok\n111 22\n" })
      .confirmNext();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "toggle", line: 1 });

    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    expect(scripts).toHaveLength(2);
    // The fingerprint it read is what it says it is replacing.
    expect(scripts[1]).toContain(`!= '${SUM}'`);
    // And the row is off now, without another read.
    expect(texts(lastDrawn(host))).toContain("off");
  });

  // The reason compare-and-swap is here: a crontab is the only copy, and
  // another client or a person over ssh may have edited it.
  test("a refusal reloads rather than retrying", async () => {
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .exec(WRITE_OFF, { stdout: "conflict\n" })
      .confirmNext();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "toggle", line: 1 });

    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    // read · write · read. Never a second write against a fingerprint that is
    // already known to be stale.
    expect(scripts).toEqual([READ_COMMAND, WRITE_OFF, READ_COMMAND]);
    expect(
      host.callsTo("ui.patch").some((p) =>
        texts(p.node).some((t) => t.includes("changed on the server")),
      ),
    ).toBe(true);
  });

  test("a write that failed says so and leaves the list alone", async () => {
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .exec(WRITE_OFF, { stdout: "crontab: no crontab for you\nfailed\n" })
      .confirmNext();
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    await plugin.onEvent({ m: "toggle", line: 1 });

    const drawn = texts(lastDrawn(host));
    expect(drawn.some((t) => t.includes("no crontab for you"))).toBe(true);
    // Still on, because the write did not happen.
    expect(drawn).toContain("on");
  });

  test("a line that is not a job is not toggled", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    // `MAILTO=root` is line 0 and is not a job.
    await plugin.onEvent({ m: "toggle", line: 0 });

    expect(host.callsTo("ui.prompt")).toHaveLength(0);
    expect(host.callsTo("server.exec")).toHaveLength(1);
  });
});
