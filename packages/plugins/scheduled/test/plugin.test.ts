/**
 * The plugin against the mock host, and mostly the write.
 *
 * The read is the same shape as the other two plugins here. What is new is a
 * change to the machine: it is confirmed before it happens, it is
 * compare-and-swap, and a refusal means reload rather than retry.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost, l10nKeys, texts } from "@serverbox/plugin-api/test";
import type { HookEvent, Node, ServerHandle } from "@serverbox/plugin-api";
import {
  READ_COMMAND,
  added,
  edited,
  removed,
  toggled,
  writeCommand,
} from "../src/schedule.ts";

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

function lastDrawn(host: MockHost): Node {
  const patches = host.callsTo("ui.patch");
  return patches[patches.length - 1]!.node;
}

describe("the fleet tab", () => {
  const fleetEnter = (
    ...servers: [string, string][]
  ): HookEvent => ({
    kind: "enter",
    contribution: "fleet",
    servers: servers.map(([server, name]) => ({
      server: server as ServerHandle,
      name,
    })),
  });

  /// A tab is not bound to a server, which is why this one asks for
  /// `server.list` — the fleet is its whole subject.
  test("it reads every machine and totals them", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "tab", id: "fleet" });
    await plugin.onHook(fleetEnter(["h-1", "web"], ["h-2", "db"]));

    const shown = texts(lastDrawn(host));
    expect(shown).toContain("web");
    expect(shown).toContain("db");
    // One enabled job and one timer per machine, twice.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.fleetCount");
    expect(host.called().filter((c) => c === "server.exec")).toHaveLength(2);
  });

  /// **Serial, and drawn after each answer.** Twenty machines must not mean
  /// twenty connections opening because somebody looked at a tab, and a slow
  /// one at the end should cost a row that says so rather than a blank page.
  test("it draws as answers land rather than at the end", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "tab", id: "fleet" });
    await plugin.onHook(fleetEnter(["h-1", "web"], ["h-2", "db"]));

    // One before anything was asked, then one per machine.
    expect(host.callsTo("ui.patch")).toHaveLength(3);
  });

  test("a machine that will not answer is a row, not the page", async () => {
    // Only `h-1` is scripted; the exec for `h-2` rejects.
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "tab", id: "fleet" });
    await plugin.onHook(fleetEnter(["h-1", "web"], ["h-2", "db"]));

    // Both rows are there; the totals only count what answered.
    const shown = texts(lastDrawn(host));
    expect(shown).toContain("web");
    expect(shown).toContain("db");
  });

  test("tapping a row opens that server", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    plugin.open({ kind: "tab", id: "fleet" });
    await plugin.onHook(fleetEnter(["h-1", "web"]));
    await plugin.onEvent({ msg: { m: "openServer", server: "h-1" }, value: undefined });

    expect(host.called()).toContain("nav.openServer");
  });

  test("no servers is a state with something to say", async () => {
    const host = new MockHost();
    restore = host.install();
    const plugin = await load();

    const out = plugin.open({ kind: "tab", id: "fleet" });
    await plugin.onHook(fleetEnter());

    expect(l10nKeys(out.ui!)).toContain("l10n.fleetEmptyTitle");
    expect(host.called().filter((c) => c === "server.exec")).toHaveLength(0);
  });
});

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
    // The breakdown is a translated sentence with the counts as arguments, so
    // what the tree carries is the key — the app substitutes when it draws.
    // `breakdownOff` here because one of the fixture's jobs is disabled; the
    // plain `breakdown` is the same sentence without that count.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.breakdownOff");
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
    await plugin.onEvent({ msg: { m: "toggle", line: 1 } });

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
    await plugin.onEvent({ msg: { m: "toggle", line: 1 } });

    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    expect(scripts).toHaveLength(2);
    // The fingerprint it read is what it says it is replacing.
    expect(scripts[1]).toContain(`!= '${SUM}'`);
    // And the row is off now, without another read.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.tagOff");
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
    await plugin.onEvent({ msg: { m: "toggle", line: 1 } });

    const scripts = host.callsTo("server.exec").map((c) => c.req.script);
    // read · write · read. Never a second write against a fingerprint that is
    // already known to be stale.
    expect(scripts).toEqual([READ_COMMAND, WRITE_OFF, READ_COMMAND]);
    expect(
      host.callsTo("ui.patch").some((p) =>
        l10nKeys(p.node).includes("l10n.conflict"),
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
    await plugin.onEvent({ msg: { m: "toggle", line: 1 } });

    const drawn = texts(lastDrawn(host));
    expect(drawn.some((t) => t.includes("no crontab for you"))).toBe(true);
    // Still on, because the write did not happen.
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.tagOn");
  });

  test("a line that is not a job is not toggled", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();

    await plugin.onHook(enter);
    // `MAILTO=root` is line 0 and is not a job.
    await plugin.onEvent({ msg: { m: "toggle", line: 0 } });

    expect(host.callsTo("ui.prompt")).toHaveLength(0);
    expect(host.callsTo("server.exec")).toHaveLength(1);
  });
});

describe("adding and editing", () => {
  const base = () =>
    new MockHost().exec(READ_COMMAND, { stdout: READ });

  test("a new job is appended and the whole file is written", async () => {
    const write = writeCommand(
      added(LINES, { when: "@daily", command: "/opt/new.sh" }),
      SUM,
    );
    const host = base()
      .exec(write, { stdout: "ok\n999 44\n" })
      .answerPrompt({ values: { when: "@daily", command: "/opt/new.sh" } });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "add" } });

    expect(host.callsTo("server.exec").map((c) => c.req.script)).toEqual([
      READ_COMMAND,
      write,
    ]);
  });

  test("an edit replaces that line and leaves the others", async () => {
    const write = writeCommand(
      edited(LINES, 1, { when: "0 4 * * *", command: "/opt/backup.sh" }),
      SUM,
    );
    const host = base()
      .exec(write, { stdout: "ok\n999 44\n" })
      .answerPrompt({
        values: { when: "0 4 * * *", command: "/opt/backup.sh" },
      });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "edit", line: 1 } });

    expect(host.callsTo("server.exec")[1]!.req.script).toBe(write);
  });

  /// `crontab` accepts a line it cannot parse and simply never runs it, so
  /// this dialog is the only moment anybody finds out.
  test("a schedule crontab would not run is refused before it is written", async () => {
    const host = base().answerPrompt({
      values: { when: "every day at three", command: "/opt/new.sh" },
    });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "add" } });

    expect(host.callsTo("server.exec")).toHaveLength(1);
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.errBadSchedule");
  });

  test("a job with no command is refused too", async () => {
    const host = base().answerPrompt({
      values: { when: "@daily", command: "  " },
    });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "add" } });

    expect(host.callsTo("server.exec")).toHaveLength(1);
    expect(l10nKeys(lastDrawn(host))).toContain("l10n.errNoCommand");
  });

  test("cancelling writes nothing", async () => {
    const host = base().answerPrompt({ cancelled: true });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "add" } });

    expect(host.callsTo("server.exec")).toHaveLength(1);
  });
});

describe("removing jobs", () => {
  test("every picked line goes in one write", async () => {
    // One write and not one per job: the second compare-and-swap would meet
    // the fingerprint the first had just changed.
    const write = writeCommand(removed(LINES, [1, 2]), SUM);
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .exec(write, { stdout: "ok\n999 44\n" })
      .confirmNext();
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", line: 1 } });
    await plugin.onEvent({ msg: { m: "pick", line: 2 } });
    await plugin.onEvent({ msg: { m: "remove" } });

    expect(host.callsTo("server.exec").map((c) => c.req.script)).toEqual([
      READ_COMMAND,
      write,
    ]);
  });

  test("nothing is removed until the dialog is answered", async () => {
    const host = new MockHost()
      .exec(READ_COMMAND, { stdout: READ })
      .answerPrompt({ cancelled: true });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "select" } });
    await plugin.onEvent({ msg: { m: "pick", line: 1 } });
    await plugin.onEvent({ msg: { m: "remove" } });

    expect(host.callsTo("server.exec")).toHaveLength(1);
  });

  test("picking changes what a tap on a row means", async () => {
    const host = new MockHost().exec(READ_COMMAND, { stdout: READ });
    restore = host.install();
    const plugin = await load();
    await plugin.onHook(enter);

    await plugin.onEvent({ msg: { m: "select" } });
    const out = await plugin.onEvent({ msg: { m: "pick", line: 1 } });

    // No dialog and no write: the same tap that opened the editor a moment ago
    // now picks.
    expect(host.callsTo("ui.prompt")).toHaveLength(0);
    expect(l10nKeys(out.ui!)).toContain("l10n.remove");
  });
});
