/**
 * The exports the host calls, written for you.
 *
 * ```ts
 * export const { open, onEvent, tick, dispose } = surface((ref) => view(ref));
 * ```
 *
 * What that buys, in the order it matters:
 *
 * - **The build runs again by itself** when a provider it watched changes.
 *   Every handler in every plugin here ended with `return { ui: view() }`, and
 *   forgetting it is precisely what a dead control looks like: the plugin
 *   handled the event, changed its state, and answered with nothing.
 * - **A handler is a closure.** `onTap(btn("Run"), () => refresh())`. The SDK
 *   keeps the function and sends the host a token in its place, so a plugin
 *   never writes a `switch` over message shapes. Messages still work — they are
 *   what actually crosses — and a plugin mixing both is fine.
 * - **A change that lands while nothing is on screen is dropped**, not queued.
 *   `sb.ui.patch` answers `no_surface` and that is the honest end of it.
 */

import { frame, resetFrame } from "./frame.ts";
import { pending, settleAll, tracker } from "./state.ts";
import { installCallbacks, type Node } from "./ui.ts";

/** Which surface is being built. */
export interface BuildCtx {
  /** `page`, `card`, `tab` or `settings`. */
  kind: string;
  /** The contribution id from the manifest. */
  id: string;
}

export interface SurfaceOptions {
  /**
   * What to do on the app's refresh interval. Absent means nothing — a page
   * that has nothing to poll should not be polled.
   *
   * Reloading a resource is the common one: `onTick: () => jobs.reload()`.
   */
  onTick?: () => void | Promise<void>;
  /** Called when the surface goes away. */
  onDispose?: () => void;
}

/** A function attached to a node, or a message the plugin will switch on. */
export type Handler = unknown | ((value?: unknown) => void | Promise<void>);

interface Registered {
  fn: (value?: unknown) => void | Promise<void>;
  generation: number;
}

/** The token a callback crosses as. Nothing else may produce this shape. */
interface CallbackMessage {
  __cb: number;
}

const registry = new Map<number, Registered>();
let nextToken = 1;
let generation = 0;

// So `onTap(btn(...), () => ...)` works the moment this module is loaded, and
// throws a sentence rather than a type error when it is not.
installCallbacks(callback);

/**
 * How many builds' callbacks stay reachable.
 *
 * **A tap lands on the tree that is on screen, which is not the newest one.**
 * A page settles by drawing several times — the loading state, then the
 * reading — and a tick draws again every few seconds, so by the time a tap
 * crosses, the tree it came from may be a few builds behind. Two was not
 * enough: opening a page and tapping what it first drew already missed.
 *
 * Eight is generous and still bounded; past that a token is from a tree nobody
 * has seen for a while, and ignoring it is better than acting on a row that has
 * since moved.
 */
const keepGenerations = 8;

/**
 * A callback as a message.
 *
 * The token is what crosses; the function stays here. See [keepGenerations]
 * for how long one is answerable.
 */
export function callback(fn: (value?: unknown) => void | Promise<void>): unknown {
  const token = nextToken++;
  registry.set(token, { fn, generation });
  return { __cb: token } satisfies CallbackMessage;
}

function isCallback(msg: unknown): msg is CallbackMessage {
  return typeof msg === "object" && msg !== null && "__cb" in msg;
}

function sweep(): void {
  generation++;
  for (const [token, one] of registry) {
    if (one.generation < generation - keepGenerations) registry.delete(token);
  }
}

/**
 * Builds the surface, redraws it when its state moves, and answers the host.
 *
 * The build is a pure function of the providers it watches: it may run at any
 * time, and anything it does besides returning a tree happens more often than
 * the author expects.
 */
export function surface(
  build: (ctx: BuildCtx) => Node,
  options: SurfaceOptions = {},
) {
  let current: BuildCtx | null = null;
  let showing = false;
  /** A rebuild is already queued, so a burst of changes is one redraw. */
  let queued = false;
  /**
   * Whether the host is inside a call right now.
   *
   * While it is, the redraws belong to that call: the states on the way out go
   * as patches from [finish] and the last one is the answer — one round trip
   * instead of two. **It has to cover the whole call, not just the handler.**
   * A queued redraw is a microtask, and every `await` in here is a chance for
   * it to run first, take the tree, and leave the answer empty.
   */
  let answering = false;

  /// One computation for the surface's whole life, re-run per draw — see
  /// `tracker`. A new one per draw would leave the old ones subscribed until
  /// something changed.
  const reads = tracker(() => onChange());

  const draw = (full: boolean): Node => {
    sweep();
    const ctx = current!;
    // **Recorded, so the reads are the subscription.** Whatever the build
    // touched — a `state`, a `resource`, a `computed` — wakes it when it
    // moves, and a branch it stopped drawing stops waking it.
    const tree = reads.run(() => build(ctx));
    return frame(tree, { full });
  };

  function onChange(): void {
    if (queued || current === null) return;
    queued = true;
    // A microtask, so a handler that moves three values redraws once.
    void Promise.resolve().then(push);
  }

  const push = async () => {
    // The call in progress will carry it.
    if (answering) return;
    // Already drained into a call's answer while this was waiting its turn —
    // pushing again would send the same tree twice, and the first of the two
    // would be the *older* one.
    if (!queued) return;
    queued = false;
    // Nothing has been drawn yet, so there is no surface to build against.
    if (current === null) return;

    // **Built even when nothing is showing.** A build is what creates the
    // providers and starts their fetches, so skipping it stops the plugin
    // working rather than only stopping it drawing — one refused patch used to
    // leave a page that never read anything again.
    const tree = draw(false);
    if (!showing) return;
    try {
      await sb.ui.patch({ path: "", node: tree });
    } catch (error) {
      // `no_surface`: nothing is showing this instance. Not an error — a
      // plugin whose page was closed mid-fetch has nowhere to put the answer,
      // and the next `open` sends a full tree anyway.
      if ((error as { kind?: unknown } | null)?.kind === "no_surface") {
        showing = false;
        return;
      }
      throw error;
    }
  };

  /**
   * The tree the call in progress will answer with, once it is known.
   *
   * A redraw is either *the answer* or a state on the way to one, and which it
   * is turns on whether anything is still outstanding after it — a build is
   * what starts a fetch, so that cannot be known before drawing.
   */
  let answer: Node | null = null;

  /**
   * Waits for what the call started, sending each state it passes through.
   *
   * **The host drives an instance only while it is inside a call.** A fetch a
   * handler started and did not wait for does not progress once the call
   * returns — it stops, and the page sits on its loading state until something
   * else happens to call in. So every entry point finishes here.
   *
   * The states along the way go out as patches (the "measuring" line, which is
   * what says the tap did something); the last one is the call's answer.
   */
  const finish = async (
    { answers, rounds = 8 }: { answers: boolean; rounds?: number },
  ): Promise<void> => {
    for (let round = 0; round < rounds; round++) {
      if (queued) {
        queued = false;
        const tree = draw(false);
        // The last state is the call's answer — except where the caller has no
        // answer to give: `onHook` returns nothing, so its final tree has to go
        // out as a patch or it goes nowhere at all.
        if (answers && pending() === 0) {
          answer = tree;
          return;
        }
        answer = null;
        if (showing) {
          try {
            await sb.ui.patch({ path: "", node: tree });
          } catch (error) {
            if ((error as { kind?: unknown } | null)?.kind === "no_surface") {
              showing = false;
            } else {
              throw error;
            }
          }
        }
      }
      // **Both, not just what is outstanding.** An answer that arrives while
      // this is awaiting `sb.ui.patch` queues a rebuild and empties the
      // pending set in the same breath, and returning there left that rebuild
      // to nobody: `push` declines while a call is in progress, and
      // `onChange` does not re-arm a `queued` that is already set. It cost the
      // reading about one run in three, and looked like a page that stayed on
      // its loading state for no reason.
      if (!queued && pending() === 0) return;
      await settleAll(1);
    }
  };

  /**
   * Ends a call, leaving nothing undrawn.
   *
   * A rebuild queued but not taken by the call — because it ran out of rounds
   * — is one `push` refused while `answering` was true. Re-arming it here is
   * what makes that a patch a moment later rather than a tree nobody sends.
   */
  const endCall = (): void => {
    answering = false;
    if (queued) void Promise.resolve().then(push);
  };

  /** Whatever the call ended on, as its answer. */
  const drain = (): { ui?: Node } => {
    if (answer !== null) {
      const tree = answer;
      answer = null;
      return { ui: tree };
    }
    if (!queued) return {};
    queued = false;
    return { ui: draw(false) };
  };

  return {
    open(s: { kind: string; id: string }) {
      current = { kind: s.kind, id: s.id };
      showing = true;
      // The app has nothing of this surface's tree, whatever this plugin sent
      // for the last one.
      resetFrame();
      return { ui: draw(true) };
    },

    async onEvent(event: { msg?: unknown; value?: unknown }) {
      const msg = event?.msg;
      answering = true;
      try {
        if (isCallback(msg)) {
          const one = registry.get(msg.__cb);
          // A token from a tree older than the two generations kept, which is
          // a tap on something long gone. Ignored rather than throwing: the
          // user pressed a button that is no longer there.
          if (one) await one.fn(event.value);
        }
        await finish({ answers: true });
        return drain();
      } finally {
        endCall();
      }
    },

    /**
     * The refresh interval, and **where a background reading lands**.
     *
     * It runs `finish` even for a surface with no `onTick`, which is not
     * pointless: the host delivers an outstanding host call's answer only
     * while it is inside a call, so a `resource` marked `background` — a scan
     * no call may wait for — has this as the thing that picks it up. A surface
     * with nothing to poll and nothing outstanding still answers with nothing.
     */
    async tick() {
      answering = true;
      try {
        await options.onTick?.();
        await finish({ answers: true });
        return drain();
      } finally {
        endCall();
      }
    },

    /**
     * Waits for everything outstanding, and sends what it produced.
     *
     * **Call this from `onHook`.** The host drives an instance only while it is
     * inside a call, so a fetch started while drawing `open` does not progress
     * until something calls in again — and `onHook` is the call that always
     * follows. Without it a page opens on its loading state and stays there
     * until the user touches something.
     */
    async settle(rounds = 8) {
      answering = true;
      try {
        await finish({ answers: false, rounds });
      } finally {
        endCall();
      }
    },

    dispose() {
      showing = false;
      reads.dispose();
      registry.clear();
      options.onDispose?.();
    },
  };
}
