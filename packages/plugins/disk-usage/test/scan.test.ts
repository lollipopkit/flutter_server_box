/**
 * The command this builds and the two commands' output it reads.
 *
 * The command half has a security property in it and is tested against a real
 * shell: the path comes back out of a listing the *server* produced, so a
 * directory called `; rm -rf ~` — a legal directory name — reaches this code
 * as data and must leave it as data.
 */

import { describe, expect, test } from "bun:test";
import { command, humanBytes, parentOf, parse } from "../src/scan.ts";

const RAW = `df
/dev/vda1     51475068 48901120   1934564  97% /
du
4096	/var/cache
32948124	/var/lib
1048576	/var/log
34041852	/var
`;

describe("the command", () => {
  test("asks df and du about the same directory, one level deep", () => {
    const cmd = command("/var");
    expect(cmd).toContain("df -kP '/var'");
    expect(cmd).toContain("du -x -d 1 -k '/var'");
  });

  /// `-x` is what keeps `du /` off every network mount on the machine, and
  /// what makes descending into a mount point a separate question rather than
  /// a number already counted above it.
  test("stays on one filesystem", () => {
    expect(command("/")).toContain("-x");
  });

  /// The line that matters. Asserted by running a real shell, because the
  /// question is what `sh` does with the string and not what this file thinks
  /// it produces.
  test("a directory named like a command is data", async () => {
    const marker = "/tmp/sb-du-quote-probe";
    await Bun.spawn(["sh", "-c", `rm -f ${marker}`]).exited;

    // `du` will fail on this path, which is fine and is the point: it fails
    // rather than running the thing embedded in the name.
    const cmd = command(`/tmp/; touch ${marker}`);
    await Bun.spawn(["sh", "-c", cmd]).exited;

    expect(await Bun.file(marker).exists()).toBe(false);
  });

  /// Not a substitute for quoting — a weaker check for the values that are
  /// safe but wrong. A path with a newline in it cannot be read back out of a
  /// line-oriented command's output.
  test("a path a line-oriented command cannot answer about is refused", () => {
    expect(() => command("/var/two\nlines")).toThrow();
    expect(() => command("")).toThrow();
  });
});

describe("parsing", () => {
  const scan = parse("/var", RAW);

  test("the row for the directory itself is the total, not a child", () => {
    expect(scan.totalBytes).toBe(34041852 * 1024);
    expect(scan.children.map((c) => c.name)).not.toContain("var");
  });

  test("largest first, because that is the whole question", () => {
    expect(scan.children.map((c) => c.name)).toEqual([
      "lib",
      "log",
      "cache",
    ]);
  });

  /// `df` is what turns "31G in /var" into something that means anything.
  test("the filesystem's own numbers come across", () => {
    expect(scan.filesystem).toEqual({
      usedBytes: 48901120 * 1024,
      sizeBytes: 51475068 * 1024,
    });
  });

  test("a machine whose df said nothing still reports du", () => {
    const only = parse("/var", "du\n100\t/var/log\n200\t/var\n");
    expect(only.filesystem).toBeUndefined();
    expect(only.children).toHaveLength(1);
  });

  /// A path may contain spaces, so the size comes off the front rather than
  /// the line being split into columns.
  test("a directory with a space in its name is one row", () => {
    const spaced = parse("/srv", "du\n4096\t/srv/my backups\n8192\t/srv\n");
    expect(spaced.children[0]).toMatchObject({
      name: "my backups",
      path: "/srv/my backups",
    });
  });

  /// `-d 1` should not produce one, but a `du` that ignores it would put a
  /// grandchild at the wrong level rather than under its own parent.
  test("a grandchild is skipped rather than shown at this level", () => {
    const deep = parse(
      "/var",
      "du\n10\t/var/log/nginx\n20\t/var/log\n30\t/var\n",
    );
    expect(deep.children.map((c) => c.path)).toEqual(["/var/log"]);
  });

  test("the root's children are one component, not two", () => {
    const root = parse("/", "du\n10\t/var/log\n20\t/var\n30\t/\n");
    expect(root.children.map((c) => c.name)).toEqual(["var"]);
    expect(root.totalBytes).toBe(30 * 1024);
  });

  test("a line that is not a row costs a line, not the reading", () => {
    const noisy = parse("/var", "du\ndu: cannot read directory\n40\t/var\n");
    expect(noisy.totalBytes).toBe(40 * 1024);
  });
});

describe("moving around", () => {
  test("up from a directory is its parent, and the root has none", () => {
    expect(parentOf("/var/log")).toBe("/var");
    expect(parentOf("/var")).toBe("/");
    expect(parentOf("/")).toBeNull();
    expect(parentOf("/var/log/")).toBe("/var");
  });
});

describe("reading a size", () => {
  /// Binary units, because `du -k` counts kibibytes and so does `df` — a
  /// plugin dividing by 1000 would disagree with the machine it is describing.
  test("agrees with df on the same machine", () => {
    expect(humanBytes(1024)).toBe("1.0K");
    expect(humanBytes(1024 * 1024)).toBe("1.0M");
    expect(humanBytes(1024 ** 3)).toBe("1.0G");
  });

  /// One decimal below ten and none above: `47G` rather than `47.0G`, which is
  /// a digit of noise on the number people compare.
  test("drops the decimal once it stops carrying information", () => {
    expect(humanBytes(9.4 * 1024 ** 3)).toBe("9.4G");
    expect(humanBytes(47 * 1024 ** 3)).toBe("47G");
    expect(humanBytes(512)).toBe("512B");
  });
});
