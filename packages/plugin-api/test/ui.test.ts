import { describe, expect, test } from "bun:test";

import {
  L10N_ARG_SEP,
  btn,
  card,
  column,
  input,
  key,
  kv,
  l10n,
  onChange,
  onTap,
  spacer,
  text,
  tone,
  type Node,
} from "../src/index.ts";

describe("the tree", () => {
  test("serialises without its empty parts", () => {
    // Every node crosses FFI on every tick; a page of two hundred is mostly
    // keys otherwise.
    expect(JSON.stringify(column([text("hi"), spacer()]))).toBe(
      '{"t":"column","c":[{"t":"text","p":{"value":"hi"}},{"t":"spacer"}]}',
    );
  });

  test("carries a message verbatim", () => {
    // The host never reads it, which is what lets a plugin use a tagged object.
    const n = onTap(btn("Start"), { m: "power", intent: "restart" });
    expect(n.on).toEqual({ tap: { m: "power", intent: "restart" } });
  });

  test("keeps a key and leaves it out when unset", () => {
    expect(key(input("web"), "search").k).toBe("search");
    expect(input("web").k).toBeUndefined();
  });

  test("round-trips through JSON unchanged", () => {
    const n = card([kv("CPU", "12%"), tone(onTap(btn("Start"), { m: "go" }), "danger")]);
    expect(JSON.parse(JSON.stringify(n)) as Node).toEqual(n);
  });

  test("builders do not mutate what they are given", () => {
    const base = btn("Start");
    const tapped = onTap(base, { m: "go" });
    expect(base.on).toBeUndefined();
    expect(tapped.on).toBeDefined();
  });

  test("two events can hang off one node", () => {
    const n = onChange(onTap(input(""), { m: "submit" }), { m: "typed" });
    expect(Object.keys(n.on ?? {}).sort()).toEqual(["change", "tap"]);
  });
});

describe("l10n", () => {
  test("prefixes a key and leaves a literal alone", () => {
    expect(l10n("bmc.power_on")).toBe("l10n.bmc.power_on");
    expect(text("12%").p?.value).toBe("12%");
  });

  test("arguments follow the key, separated", () => {
    expect(l10n("bmc.power_confirm", "ForceRestart")).toBe(
      `l10n.bmc.power_confirm${L10N_ARG_SEP}ForceRestart`,
    );
  });

  /// A plugin must not be able to break its own formatting by passing a value
  /// that contains the separator.
  test("a separator inside an argument is dropped", () => {
    const out = l10n("k", `a${L10N_ARG_SEP}b`);
    expect(out.split(L10N_ARG_SEP)).toEqual(["l10n.k", "ab"]);
  });
});
