import { describe, expect, test } from "bun:test";

import { parse, statusCmd } from "./status.plugin.ts";

describe("a status plugin", () => {
  test("answers a command for the platforms it knows", () => {
    expect(statusCmd({ platform: "linux" }).cmd).toContain("zpool list");
    expect(statusCmd({ platform: "bsd" }).cmd).toContain("zpool list");
    // The manifest names the platforms, so the host never asks about this one.
    // Throwing is what a plugin can do about being asked anyway; the host
    // reports it as a failed call rather than running something.
    expect(() => statusCmd({ platform: "windows" })).toThrow();
  });

  test("turns what the command printed into readings", () => {
    const out = parse({
      text: "tank\t1000000000000\t330000000000\tONLINE\nold\t200\t199\tDEGRADED\n",
    });

    expect(out.title).toBe("ZFS");
    expect(out.items).toHaveLength(2);
    const [tank, old] = out.items;
    expect(tank).toMatchObject({
      label: "tank",
      value: "307.3G / 931.3G",
      tone: "success",
    });
    expect(tank?.percent).toBeCloseTo(0.33, 5);
    expect(old?.tone).toBe("danger");
    expect(out.note).toBeUndefined();
  });

  // A diagnostic on stdout costs that row, not the card. `zpool` prints one on
  // some failures and it arrives in the same stream as the pools.
  test("a line it cannot read costs a row and says so", () => {
    const out = parse({
      text: "tank\t1000\t330\tONLINE\ncannot open 'gone': no such pool\n",
    });

    expect(out.items).toHaveLength(1);
    expect(out.note).toBe("1 pool(s) unreadable");
  });

  test("no output is no readings, not a failure", () => {
    expect(parse({ text: "" }).items).toEqual([]);
    expect(parse({ text: "\n\n" }).items).toEqual([]);
  });

  // A pool of size 0 would make `percent` infinite or NaN. The host drops a
  // percent outside 0..1, but a plugin that hands one over has already decided
  // to show a bar it cannot fill.
  test("a pool with no size is not a division", () => {
    const out = parse({ text: "empty\t0\t0\tONLINE\n" });
    expect(out.items).toEqual([]);
    expect(out.note).toBe("1 pool(s) unreadable");
  });
});
