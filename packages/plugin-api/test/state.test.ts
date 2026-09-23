/**
 * State that tracks itself, and a surface that redraws from it.
 *
 * What these hold is the promise the whole layer makes: **a plugin that changes
 * its state does not have to remember to redraw**, and does not have to declare
 * what it reads either. Every one of the three plugins here used to end each
 * handler with `return { ui: view() }`, and forgetting it is exactly what a
 * dead control looks like — the plugin handled the tap, moved its state, and
 * answered with nothing.
 *
 * The host is driven the way it really drives a plugin: `open`, then `onEvent`
 * with whatever message the tree carried, then `tick`.
 */

import { afterEach, describe, expect, test } from "bun:test";

import { MockHost, texts } from "../src/test.ts";
import {
  computed,
  effect,
  family,
  resource,
  state,
  surface,
  tracker,
} from "../src/index.ts";
import { column, kv, onTap, tag, text, type Node } from "../src/ui.ts";

let restore: (() => void) | null = null;
const stops: Array<() => void> = [];

afterEach(() => {
  restore?.();
  restore = null;
  for (const stop of stops.splice(0)) stop();
});

const SURFACE = { kind: "page", id: "p" };

/** The message a node carries, for a test to send back the way the host does. */
function tapOf(tree: Node, at = 0): unknown {
  const found: unknown[] = [];
  const walk = (n: Node) => {
    if (n.on?.["tap"] !== undefined) found.push(n.on["tap"]);
    for (const c of n.c ?? []) walk(c);
  };
  walk(tree);
  return found[at];
}

/** Keeps an effect alive for one test. */
function until(stop: () => void): void {
  stops.push(stop);
}

describe("tracking", () => {
  test("a computed follows what it read", () => {
    const count = state(1);
    const doubled = computed(() => count.value * 2);

    expect(doubled.value).toBe(2);
    count.value = 21;
    expect(doubled.value).toBe(42);
  });

  /// Lazy, so a derived value nothing is drawing costs nothing — and a chain
  /// of them does not recompute on every keystroke somewhere else.
  test("a computed body runs when it is read, not when its input moves", () => {
    let runs = 0;
    const count = state(0);
    const doubled = computed(() => {
      runs++;
      return count.value * 2;
    });

    expect(runs).toBe(0);
    expect(doubled.value).toBe(0);
    expect(runs).toBe(1);

    count.value = 1;
    expect(runs).toBe(1);
    expect(doubled.value).toBe(2);
    expect(runs).toBe(2);
  });

  /// A poll answering the same number every three seconds would otherwise
  /// redraw the page every three seconds.
  test("setting a value to what it already holds is not a change", () => {
    const count = state(1);
    let runs = 0;
    until(
      effect(() => {
        count.value;
        runs++;
      }),
    );

    count.value = 1;
    expect(runs).toBe(1);
    count.value = 2;
    expect(runs).toBe(2);
  });

  /// The one thing an explicit `ref.watch` made obvious and this has to get
  /// right by itself: a branch that stopped being drawn stops waking the build.
  test("what a computation stops reading stops waking it", () => {
    const which = state(true);
    const a = state("a");
    const b = state("b");
    let runs = 0;
    until(
      effect(() => {
        runs++;
        which.value ? a.value : b.value;
      }),
    );

    expect(runs).toBe(1);
    // Not read on the last run, so not a dependency.
    b.value = "b2";
    expect(runs).toBe(1);
    a.value = "a2";
    expect(runs).toBe(2);
  });

  /// **One computation per surface, not one per draw.** A fresh one each time
  /// would subscribe again to everything it read, and the previous one is only
  /// dropped when something notifies — so a page that drew twenty times without
  /// changing held twenty subscriptions to every value, and the next change
  /// woke all twenty.
  test("re-running a tracker replaces what it was subscribed to", () => {
    const count = state(0);
    let runs = 0;
    const t = tracker(() => runs++);

    for (let i = 0; i < 5; i++) t.run(() => count.value);

    count.value = 1;
    expect(runs).toBe(1);
    t.dispose();
  });

  test("a family is one value per argument", () => {
    const perServer = family((id: string) => state(`idle:${id}`));

    perServer("a").value = "busy:a";

    expect(perServer("a").value).toBe("busy:a");
    expect(perServer("b").value).toBe("idle:b");
    // The same argument is the same value, not a new one each call.
    expect(perServer("a")).toBe(perServer("a"));
  });

  /// `peek` is what a handler uses: it is not a build, and subscribing from
  /// one would tie the page to something nobody drew.
  test("peek reads without subscribing", () => {
    const count = state(0);
    let runs = 0;
    until(
      effect(() => {
        count.peek();
        runs++;
      }),
    );

    count.value = 1;
    expect(runs).toBe(1);
  });
});

describe("a resource", () => {
  test("reads as loading, then as data", async () => {
    const jobs = resource(async () => ["a", "b"]);

    expect(jobs.value.state).toBe("loading");
    await Promise.resolve();
    await Promise.resolve();

    expect(jobs.value).toEqual({ state: "data", value: ["a", "b"] });
  });

  /// A page cannot forget to clear a spinner it does not own, and a failure is
  /// a state of the value rather than a flag beside it.
  test("and as an error when the body throws", async () => {
    const jobs = resource<string[]>(async () => {
      throw new Error("exec failed");
    });

    jobs.value;
    await Promise.resolve();
    await Promise.resolve();

    expect(jobs.value.state).toBe("error");
  });

  /// Lazy: a surface that does not draw it does not run it, which is what
  /// keeps a plugin from running a command in `open`.
  test("nothing runs until something reads it", () => {
    let runs = 0;
    const jobs = resource(async () => {
      runs++;
      return 1;
    });

    expect(runs).toBe(0);
    jobs.value;
    expect(runs).toBe(1);
  });

  /// Reading a value at the top of the body is the whole of "reload when the
  /// server changes" — there is nothing else to write.
  test("it re-runs when what it read moves", async () => {
    let runs = 0;
    const which = state("a");
    const jobs = resource(async () => {
      runs++;
      return `on ${which.value}`;
    });

    jobs.value;
    await Promise.resolve();
    await Promise.resolve();
    expect(runs).toBe(1);

    which.value = "b";
    await Promise.resolve();
    await Promise.resolve();

    expect(runs).toBe(2);
    expect(jobs.value).toEqual({ state: "data", value: "on b" });
  });

  /// A refresh that blanks the page it is refreshing is a page that flickers
  /// every three seconds.
  test("a reload keeps what it is showing while it runs", async () => {
    let answer = "first";
    const jobs = resource(async () => answer);
    jobs.value;
    await Promise.resolve();
    await Promise.resolve();

    answer = "second";
    jobs.reload();

    const mid = jobs.peek();
    expect(mid.state).toBe("loading");
    expect(mid.state === "loading" ? mid.previous : null).toBe("first");
  });
});

describe("the surface", () => {
  /// The whole point. Every plugin here ended each handler with
  /// `return { ui: view() }`, and forgetting it is what a dead control is.
  test("a handler that changes state redraws without saying so", async () => {
    const host = new MockHost();
    restore = host.install();
    const count = state(0);
    const app = surface(() =>
      column([
        kv("Taps", `${count.value}`),
        onTap(tag("again"), () => count.update((n) => n + 1)),
      ]),
    );

    const first = app.open(SURFACE);
    expect(texts(first.ui)).toContain("0");

    const answer = await app.onEvent({ msg: tapOf(first.ui) });

    // Answered in the same round trip, because the handler was synchronous.
    expect(answer.ui).toBeDefined();
    expect(texts(answer.ui!)).toContain("1");
  });

  /// **What a call starts, the call finishes.** The host drives an instance
  /// only while it is inside a call, so a fetch left running when one returns
  /// does not progress — it stops, and the page sits on its loading state
  /// until something else happens to call in.
  test("a tap that starts a fetch answers with what it fetched", async () => {
    const host = new MockHost();
    restore = host.install();
    let answerText = "first";
    const jobs = resource(async () => {
      // Resolves on its own, a turn later — a host call, not something this
      // test hands back.
      await new Promise((done) => setTimeout(done, 0));
      return answerText;
    });
    const app = surface(() =>
      column([
        jobs.when({
          loading: (previous) => text(previous ?? "…"),
          error: () => text("!"),
          data: (v) => text(v),
        }),
        onTap(tag("reload"), () => jobs.reload()),
      ]),
    );

    // Opening is the same shape: the page comes up loading, and `settle` — the
    // call the hook gives it — is where the first reading lands.
    const first = app.open(SURFACE);
    expect(texts(first.ui)).toEqual(["…", "reload"]);
    await app.settle();
    const drawn = host.callsTo("ui.patch").at(-1)!.node;
    expect(texts(drawn)).toContain("first");

    answerText = "second";
    // The token off the tree that is *on screen*, which is the last patch —
    // not the one `open` drew, which the settle has already replaced.
    const replied = await app.onEvent({ msg: tapOf(drawn, 0) });

    expect(texts(replied.ui!)).toContain("second");
    // The root path, which the app reads as "replace the whole tree".
    expect(host.callsTo("ui.patch").every((p) => p.path === "")).toBe(true);
  });

  /// A tap crosses as a token, so a plugin never writes a `switch` over
  /// message shapes — and a token from a tree two generations old is a tap on
  /// something that is no longer there.
  test("a stale callback is ignored rather than thrown", async () => {
    const app = surface(() =>
      onTap(tag("x"), () => {
        throw new Error("should not run");
      }),
    );
    const first = app.open(SURFACE);
    const stale = tapOf(first.ui);

    // Past the generations kept, which is what makes it stale.
    for (let i = 0; i <= 8; i++) app.open(SURFACE);

    await expect(app.onEvent({ msg: stale })).resolves.toEqual({});
  });

  /// Nothing is showing this instance: `sb.ui.patch` answers `no_surface`, and
  /// that is the honest end of it rather than something to queue.
  test("a change with nothing on screen is dropped", async () => {
    const host = new MockHost();
    restore = host.install();
    const label = state("a");
    surface(() => text(label.value));

    label.value = "b";
    await Promise.resolve();

    expect(host.callsTo("ui.patch")).toHaveLength(0);
  });

  test("a patch failure other than no_surface reaches the caller", async () => {
    const host = new MockHost();
    restore = host.install();
    const label = state("a");
    const app = surface(() => text(label.value));
    app.open(SURFACE);
    sb.ui.patch = async () => {
      throw Object.assign(new Error("bridge failed"), {
        name: "HostError",
        kind: "io",
      });
    };
    label.value = "b";

    await expect(app.settle()).rejects.toMatchObject({ kind: "io" });
  });

  test("a tick may reload, and answers with the tree when it changed", async () => {
    const host = new MockHost();
    restore = host.install();
    const count = state(0);
    const app = surface(() => text(`${count.value}`), {
      onTick: () => count.update((n) => n + 1),
    });
    app.open(SURFACE);

    const answer = await app.tick();

    expect(texts(answer.ui!)).toEqual(["1"]);
  });

  test("a surface with nothing to poll answers a tick with nothing", async () => {
    const app = surface(() => text("static"));
    app.open(SURFACE);

    expect(await app.tick()).toEqual({});
  });
});

describe("work a call must not wait for", () => {
  /**
   * **The host serves one call per instance at a time.** A tap is a call, a
   * tick is a call, and neither is delivered while another is running — so a
   * call that waits for a four-minute `du` is four minutes in which the Stop
   * button the plugin drew cannot be pressed, and in which nothing else on the
   * page moves either.
   *
   * `background` is how a plugin says which of its work that applies to. What
   * these hold is that such a resource still runs, still redraws, and simply
   * is not something a call waits for.
   */
  test("a call answers with the loading state rather than waiting", async () => {
    const host = new MockHost();
    restore = host.install();
    // Never settles, which is what "longer than a call may hold" means here.
    const slow = resource(() => new Promise<string>(() => {}), {
      background: true,
    });
    const app = surface(() =>
      slow.when({
        loading: () => text("measuring"),
        error: () => text("!"),
        data: (v) => text(v),
      }),
    );

    const first = app.open(SURFACE);
    expect(texts(first.ui)).toEqual(["measuring"]);

    // The call that would never return if this were waited for. Reaching the
    // line after it is the whole assertion; the tick below says the page is
    // still on its loading state rather than having been given up on.
    await app.settle();
    expect(await app.tick()).toEqual({});
  });

  /// And the ordinary kind still is: a store read is what waiting was for, and
  /// a page that flashed its loading state for one would be worse, not better.
  test("an ordinary resource is still waited for", async () => {
    const host = new MockHost();
    restore = host.install();
    const quick = resource(async () => "read");
    const app = surface(() =>
      quick.when({
        loading: () => text("…"),
        error: () => text("!"),
        data: (v) => text(v),
      }),
    );

    app.open(SURFACE);
    await app.settle();

    expect(texts(host.callsTo("ui.patch").at(-1)!.node)).toEqual(["read"]);
  });

  /// The answer is not lost, only deferred: it lands on the next call in,
  /// which is what the app's tick is for — see `PluginSurfaceView`.
  test("its answer lands on the next tick", async () => {
    const host = new MockHost();
    restore = host.install();
    let answer!: (v: string) => void;
    const slow = resource(
      () => new Promise<string>((done) => (answer = done)),
      { background: true },
    );
    const app = surface(() =>
      slow.when({
        loading: () => text("measuring"),
        error: () => text("!"),
        data: (v) => text(v),
      }),
    );

    app.open(SURFACE);
    await app.settle();

    answer("31G");
    // The app calls in; that is the whole of how the plugin sees it.
    const ticked = await app.tick();

    expect(texts(ticked.ui!)).toEqual(["31G"]);
  });
});
