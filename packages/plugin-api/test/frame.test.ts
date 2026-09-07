/**
 * Pruning, which is the whole of the tick-time cost.
 *
 * A wrong answer here is a card that stops updating, so these assert both
 * directions: what is pruned really did not change, and what changed is really
 * sent.
 */

import { beforeEach, describe, expect, test } from "bun:test";

import {
  bind,
  btn,
  card,
  column,
  frame,
  kv,
  list,
  onTap,
  resetFrame,
  spacer,
  text,
  type Node,
} from "../src/index.ts";

beforeEach(() => resetFrame());

/** A node the app already has: type, key and revision, nothing else. */
function isStub(n: Node): boolean {
  return n.c === undefined && n.p === undefined && n.on === undefined;
}

/** Every node in the tree, depth first. */
function all(n: Node): Node[] {
  return [n, ...(n.c ?? []).flatMap(all)];
}

const view = (cpu: string, mem: string) =>
  card([column([kv("CPU", cpu), kv("Mem", mem), btn("Refresh")])]);

describe("the first frame", () => {
  test("carries everything, because the app has nothing", () => {
    const sent = frame(view("12%", "40%"));
    expect(all(sent).some(isStub)).toBe(false);
    expect(JSON.stringify(sent)).toContain("12%");
    expect(JSON.stringify(sent)).toContain("Refresh");
  });

  test("every node gets a revision", () => {
    const sent = frame(view("12%", "40%"));
    expect(all(sent).every((n) => typeof n.v === "number")).toBe(true);
  });
});

describe("a frame where nothing changed", () => {
  test("collapses to the root stub", () => {
    frame(view("12%", "40%"));
    const sent = frame(view("12%", "40%"));

    expect(isStub(sent)).toBe(true);
    expect(sent.t).toBe("card");
    expect(sent.c).toBeUndefined();
    // Small enough to be worth stating: this is what a tick costs on the wire
    // when a card is idle.
    expect(JSON.stringify(sent).length).toBeLessThan(40);
  });

  test("keeps the same revision, so the app reuses its Widget", () => {
    const first = frame(view("12%", "40%"));
    const second = frame(view("12%", "40%"));
    expect(second.v).toBe(first.v);
  });
});

describe("a frame where one leaf changed", () => {
  test("sends the path to it and stubs its siblings", () => {
    frame(view("12%", "40%"));
    const sent = frame(view("38%", "40%"));

    // The root and the column are on the path, so they carry children.
    expect(isStub(sent)).toBe(false);
    const col = sent.c![0]!;
    expect(col.t).toBe("column");
    const [cpu, mem, refresh] = col.c!;

    expect(isStub(cpu!)).toBe(false);
    expect(cpu!.p!.v).toBe("38%");
    expect(isStub(mem!)).toBe(true);
    expect(isStub(refresh!)).toBe(true);
  });

  /// The app compares by revision. A parent whose child changed must get a new
  /// one, or the app reuses a Widget whose children are stale.
  test("every node on the path gets a new revision", () => {
    const first = frame(view("12%", "40%"));
    const second = frame(view("38%", "40%"));

    expect(second.v).not.toBe(first.v);
    expect(second.c![0]!.v).not.toBe(first.c![0]!.v);
    // And the sibling that did not change keeps its own.
    expect(second.c![0]!.c![1]!.v).toBe(first.c![0]!.c![1]!.v);
  });

  test("and the frame after it collapses again", () => {
    frame(view("12%", "40%"));
    frame(view("38%", "40%"));
    expect(isStub(frame(view("38%", "40%")))).toBe(true);
  });
});

describe("what counts as changed", () => {
  test("a different event message does", () => {
    frame(card([onTap(btn("Go"), { m: "a" })]));
    const sent = frame(card([onTap(btn("Go"), { m: "b" })]));
    expect(isStub(sent)).toBe(false);
  });

  test("a different child count does, and nothing under it is stubbed", () => {
    frame(card([text("a"), text("b")]));
    const sent = frame(card([text("a")]));
    expect(all(sent).some(isStub)).toBe(false);
  });

  test("a different type at the same position does", () => {
    frame(card([text("a")]));
    const sent = frame(card([spacer()]));
    expect(sent.c![0]!.t).toBe("spacer");
  });

  test("a key appearing or changing does", () => {
    frame(card([text("a")]));
    const sent = frame(card([{ ...text("a"), k: "row" }]));
    expect(isStub(sent)).toBe(false);
    expect(sent.c![0]!.k).toBe("row");
  });

  /// Numbers inside a chart's series are ordinary property values; a deep
  /// comparison is what keeps a chart from being resent unchanged.
  test("a nested value does, and an equal nested value does not", () => {
    const series = (values: number[]) => card([{ t: "line_chart" as const, p: { series: [{ label: "cpu", values }] } }]);
    frame(series([1, 2, 3]));
    expect(isStub(frame(series([1, 2, 3])))).toBe(true);
    expect(isStub(frame(series([1, 2, 4])))).toBe(false);
  });

  /// A sensor that reads `NaN` twice running has not changed, and `===` says
  /// otherwise.
  test("NaN twice running does not", () => {
    const t = (v: number) => card([{ t: "percent" as const, p: { value: v, label: "x" } }]);
    frame(t(NaN));
    expect(isStub(frame(t(NaN)))).toBe(true);
  });
});

describe("resetting", () => {
  test("sends everything again", () => {
    frame(view("12%", "40%"));
    resetFrame();
    expect(all(frame(view("12%", "40%"))).some(isStub)).toBe(false);
  });

  test("the `full` option does the same inline", () => {
    frame(view("12%", "40%"));
    const sent = frame(view("12%", "40%"), { full: true });
    expect(all(sent).some(isStub)).toBe(false);
  });
});

describe("bindings", () => {
  /// A bound leaf's property is the slot name, not the value, so the tree does
  /// not change when the value does — which is the point: the tick answers
  /// `values` and nothing is rebuilt above the leaf.
  test("a bound tree stays identical while its values move", () => {
    const bound = () => card([column([kv("CPU", bind("cpu")), kv("Mem", bind("mem"))])]);
    frame(bound());
    expect(isStub(frame(bound()))).toBe(true);
    expect(JSON.stringify(bound())).toContain('"$":"cpu"');
  });
});

describe("lists", () => {
  test("a plain list carries its rows", () => {
    const rows = [1, 2, 3].map((i) => ({ ...text(`row ${i}`), k: `r${i}` }));
    const sent = frame(card([list(rows)]));
    expect(sent.c![0]!.c).toHaveLength(3);
    expect(sent.c![0]!.p).toBeUndefined();
  });

  /// Flutter's list is lazy; a window says how many rows there are without
  /// carrying them.
  test("a windowed list declares the count and where its rows start", () => {
    const rows = [0, 1].map((i) => ({ ...text(`row ${i}`), k: `r${i}` }));
    const sent = frame(card([list(rows, { count: 500, from: 0 })]));
    expect(sent.c![0]!.p).toEqual({ count: 500, from: 0 });
  });

  test("a row that changed is sent and its neighbours are not", () => {
    const rows = (second: string) =>
      card([list([
        { ...text("row 0"), k: "r0" },
        { ...text(second), k: "r1" },
        { ...text("row 2"), k: "r2" },
      ])]);
    frame(rows("row 1"));
    const sent = frame(rows("changed"));

    const [a, b, c] = sent.c![0]!.c!;
    expect(isStub(a!)).toBe(true);
    expect(b!.p!.value).toBe("changed");
    expect(isStub(c!)).toBe(true);
  });
});

describe("the shape the app relies on", () => {
  /// The app resolves a stub against the Widget at the same position, so an
  /// unchanged sibling must keep its slot rather than being dropped.
  test("a stub keeps its position among its siblings", () => {
    frame(card([text("a"), text("b"), text("c")]));
    const sent = frame(card([text("a"), text("changed"), text("c")]));
    expect(sent.c).toHaveLength(3);
    expect(sent.c!.map(isStub)).toEqual([true, false, true]);
  });

  test("a stub carries its key so a reorder is visible", () => {
    frame(card([{ ...text("a"), k: "x" }, { ...text("b"), k: "y" }]));
    const sent = frame(card([{ ...text("a"), k: "x" }, { ...text("changed"), k: "y" }]));
    expect(sent.c![0]!.k).toBe("x");
  });

  test("pruning never mutates the tree the plugin built", () => {
    const built = view("12%", "40%");
    const before = JSON.stringify(built);
    frame(built);
    frame(built);
    expect(JSON.stringify(built)).toBe(before);
  });
});
