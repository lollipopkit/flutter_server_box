/**
 * The two commands' output, and the compare-and-swap that writes one of them
 * back.
 *
 * The crontab body is verbatim from a real one: it has the prose comments, the
 * `MAILTO=`, the commented-out job and the `@reboot` line that a parser
 * written against a tidy sample gets wrong.
 */

import { describe, expect, test } from "bun:test";
import {
  parse,
  parseCronLine,
  parseTimer,
  parseWrite,
  toggled,
  writeCommand,
} from "../src/schedule.ts";

const RAW = `cron
# Edit this file to introduce tasks to be run by cron.
MAILTO=root
PATH=/usr/local/bin:/usr/bin:/bin

0 3 * * * /opt/backup.sh --full
*/5 * * * * /usr/bin/check-health >> /var/log/health.log 2>&1
#30 4 * * 0 /opt/weekly-report.sh
@reboot /opt/warm-cache.sh
cronsum
2917190459 218
hascron
yes
timers
Mon 2026-09-08 06:00:00 UTC 8h left      Sun 2026-09-07 06:00:00 UTC 15h ago      logrotate.timer              logrotate.service
Mon 2026-09-08 00:00:00 UTC 2h left      n/a                                 n/a  certbot.timer                certbot.service
`;

describe("reading a crontab", () => {
  const s = parse(RAW);

  test("prose and settings are not jobs", () => {
    expect(s.jobs.map((j) => j.command)).toEqual([
      "/opt/backup.sh --full",
      "/usr/bin/check-health >> /var/log/health.log 2>&1",
      "/opt/weekly-report.sh",
      "/opt/warm-cache.sh",
    ]);
  });

  // A commented-out job is a job — that is how this plugin turns one off, and
  // how most people do it by hand.
  test("a commented-out job is a job that is off", () => {
    const off = s.jobs.filter((j) => j.disabled);
    expect(off).toHaveLength(1);
    expect(off[0]!.command).toBe("/opt/weekly-report.sh");
    expect(off[0]!.when).toBe("30 4 * * 0");
  });

  test("the schedule is the five fields, and the rest is the command", () => {
    const check = s.jobs.find((j) => j.command.startsWith("/usr/bin/check"))!;
    expect(check.when).toBe("*/5 * * * *");
  });

  test("@reboot and friends have no five fields", () => {
    const boot = s.jobs.find((j) => j.when.startsWith("@"))!;
    expect(boot.when).toBe("@reboot");
    expect(boot.command).toBe("/opt/warm-cache.sh");
  });

  // Verbatim, because a write puts the whole file back and anything this
  // parser did not understand has to survive that.
  test("every line is kept, understood or not", () => {
    expect(s.cronLines).toContain("MAILTO=root");
    expect(s.cronLines[0]).toBe(
      "# Edit this file to introduce tasks to be run by cron.",
    );
  });

  test("a line's index is what an edit names it by", () => {
    const backup = s.jobs.find((j) => j.command.startsWith("/opt/backup"))!;
    expect(s.cronLines[backup.line]).toContain("/opt/backup.sh");
  });

  test("the fingerprint is what the next write has to match", () => {
    expect(s.fingerprint).toBe("2917190459 218");
    expect(s.hasCron).toBe(true);
  });

  // A machine with no `crontab` at all is a different answer from one with an
  // empty crontab, and the page says so differently.
  test("no crontab command is told apart from an empty crontab", () => {
    const none = parse("cron\ncronsum\n4294967295 0\nhascron\ntimers\n");
    expect(none.hasCron).toBe(false);
    expect(none.jobs).toEqual([]);
  });
});

describe("a comment that is only a comment", () => {
  test("prose with five words in it is not a job", () => {
    expect(parseCronLine("# run this every day at three", 0)).toBeNull();
    expect(parseCronLine("# see also /opt/backup.sh for the full one", 0))
      .toBeNull();
  });

  test("but a real schedule behind a hash is", () => {
    const job = parseCronLine("# 0 3 * * * /opt/backup.sh", 0);
    expect(job).toMatchObject({ when: "0 3 * * *", disabled: true });
  });

  test("an assignment is a setting, commented or not", () => {
    expect(parseCronLine("MAILTO=root", 0)).toBeNull();
    expect(parseCronLine("#MAILTO=root", 0)).toBeNull();
  });
});

describe("reading systemd's timers", () => {
  const s = parse(RAW);

  test("the unit and what it starts come off the end", () => {
    expect(s.timers.map((t) => t.unit)).toEqual([
      "logrotate.timer",
      "certbot.timer",
    ]);
    expect(s.timers[0]!.activates).toBe("logrotate.service");
  });

  // The two dates are full of spaces, so the row is read from the right.
  test("the two dates are told apart", () => {
    expect(s.timers[0]!.next).toContain("2026-09-08");
    expect(s.timers[0]!.last).toContain("2026-09-07");
  });

  // "Never" is an answer, so it is shown rather than blanked.
  test("a timer that has never run says so", () => {
    expect(s.timers[1]!.last).toContain("n/a");
  });

  test("a line that is not a timer is not a row", () => {
    expect(parseTimer("NEXT LEFT LAST PASSED UNIT ACTIVATES")).toBeNull();
    expect(parseTimer("")).toBeNull();
  });
});

describe("turning one off", () => {
  const lines = [
    "0 3 * * * /opt/backup.sh",
    "  */5 * * * * /usr/bin/check",
    "#30 4 * * 0 /opt/weekly.sh",
  ];

  test("adds a hash, and takes it away again", () => {
    const off = toggled(lines, 0);
    expect(off[0]).toBe("#0 3 * * * /opt/backup.sh");
    expect(toggled(off, 0)[0]).toBe("0 3 * * * /opt/backup.sh");
  });

  test("an already-disabled line comes back on", () => {
    expect(toggled(lines, 2)[2]).toBe("30 4 * * 0 /opt/weekly.sh");
  });

  // The lines around it are the point: a write puts the whole file back.
  test("nothing else in the file moves", () => {
    const next = toggled(lines, 0);
    expect(next.slice(1)).toEqual(lines.slice(1));
    expect(next).toHaveLength(lines.length);
  });

  test("leading whitespace is kept", () => {
    expect(toggled(lines, 1)[1]).toBe("  #*/5 * * * * /usr/bin/check");
  });
});

describe("the write", () => {
  test("refuses unless the crontab still looks like what was read", () => {
    const cmd = writeCommand(["0 3 * * * /opt/backup.sh"], "2917190459 218");
    expect(cmd).toContain(`[ "$cur" != '2917190459 218' ]`);
    expect(cmd).toContain("printf 'conflict\\n'; exit 0");
  });

  // The whole file, quoted, because there is no way to edit one line of a
  // crontab and pretending otherwise loses the lines this parser did not
  // understand.
  test("sends the whole file as one quoted argument", () => {
    const cmd = writeCommand(["a", "MAILTO=root", "#b"], "1 2");
    expect(cmd).toContain("'a\nMAILTO=root\n#b'");
    expect(cmd).toContain("| crontab -");
  });

  test("a crontab with a quote in it survives quoting", async () => {
    const cmd = writeCommand([`0 3 * * * /opt/it's.sh`], "1 2");
    // What a shell makes of it, rather than what this test thinks it says.
    const printf = cmd.split("\n").find((l) => l.startsWith("printf"))!;
    const p = Bun.spawn(["sh", "-c", printf.replace("| crontab -", "").replace(/\|\|.*$/, "")], {
      stdout: "pipe",
    });
    expect(await new Response(p.stdout).text()).toBe(`0 3 * * * /opt/it's.sh\n`);
  });

  test("ok carries the fingerprint the next write will need", () => {
    expect(parseWrite("ok\n123456 789\n")).toEqual({
      at: "ok",
      fingerprint: "123456 789",
    });
  });

  // Reload, not retry: what is on the machine is not what this was edited
  // from, and writing anyway is what would lose somebody's change.
  test("conflict is told apart from failure", () => {
    expect(parseWrite("conflict\n")).toEqual({ at: "conflict" });
    expect(parseWrite("crontab: installing new crontab\nfailed\n")).toMatchObject(
      { at: "failed" },
    );
  });

  test("saying nothing at all is a failure, not a success", () => {
    expect(parseWrite("")).toMatchObject({ at: "failed" });
  });
});
