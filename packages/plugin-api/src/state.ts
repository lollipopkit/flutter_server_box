/**
 * State that tracks itself: read a value and you depend on it.
 *
 * ```ts
 * const query = state("");
 * const jobs = resource(async () => read(server.value));
 *
 * export const { open, onEvent, dispose } = surface(() =>
 *   jobs.when({
 *     loading: () => skeleton(),
 *     error: (e) => notice({ title: l10n("readFailed"), detail: `${e}` }),
 *     // Reading `query.value` in here is what subscribes to it. Nothing is
 *     // declared, and nothing can be forgotten.
 *     data: (list) => card(rows(list)),
 *   }),
 * );
 * ```
 *
 * **Why reads rather than declarations.** The first version of this was
 * Riverpod's shape — `ref.watch(p)` — because that is what the app itself is
 * written in. It works, and it costs a `ref` parameter threaded through every
 * function that draws anything: the three plugins here ended up passing one to
 * `rowFor`, `emptyFor`, `settingsView`, `field`. None of that says anything
 * about the plugin. Tracking the read says the same thing and says it once.
 *
 * **Per instance for free.** The host loads one JavaScript instance per
 * surface, so a module-level `state()` is already that surface's own — there is
 * no container to scope it to and none here.
 *
 * The one rule: **tracking is synchronous.** What a computation reads *before*
 * its first `await` is what it depends on, which is the rule Solid and Svelte
 * have too. A `resource` that needs a value should read it at the top.
 *
 * **What it costs.** A tracked read is two `Set.add`s: about 40ns, measured at
 * 200 reads per build — 8µs against the 9µs the same build spends *making the
 * nodes* and the 12µs the diff and the JSON take after it, before any of it
 * reaches the app. It is not where a plugin's time goes, and it replaced
 * `ref.watch`, which did the same two adds plus a map lookup.
 */

// --------------------------------------------------------------- the graph

/** Something that can be read and depended on. */
interface Source {
  readonly subscribers: Set<Computation>;
}

/** Something that re-runs when what it read has changed. */
interface Computation {
  /** What it read last time, so a re-run can unsubscribe from the rest. */
  sources: Set<Source>;
  /** Told that something it read has moved. */
  invalidate(): void;
}

/** The computation whose reads are being recorded, if any. */
let current: Computation | null = null;

/** Records that whatever is running now depends on [source]. */
function tracked(source: Source): void {
  const running = current;
  if (running === null) return;
  running.sources.add(source);
  source.subscribers.add(running);
}

/** Runs [fn] with its reads recorded into [into]. */
function record<T>(into: Computation, fn: () => T): T {
  // Cleared first: a computation that stopped reading something must stop
  // being woken by it, or a branch nobody draws any more keeps the page
  // redrawing.
  for (const source of into.sources) source.subscribers.delete(into);
  into.sources.clear();

  const outer = current;
  current = into;
  try {
    return fn();
  } finally {
    current = outer;
  }
}

/** Wakes everything that read [source], and forgets them. */
function notify(source: Source): void {
  if (source.subscribers.size === 0) return;
  // A copy, because a computation that re-runs while this is walking would
  // otherwise be added to and removed from the set being iterated.
  const woken = [...source.subscribers];
  source.subscribers.clear();
  for (const one of woken) {
    one.sources.delete(source);
    one.invalidate();
  }
}

// -------------------------------------------------------------- the values

export interface State<T> {
  /** Reading it *is* subscribing to it. */
  get value(): T;
  set value(next: T);
  /** `count.update((n) => n + 1)`, which reads without subscribing. */
  update(fn: (previous: T) => T): void;
  /** Reads without subscribing — for a handler, which is not a build. */
  peek(): T;
}

/**
 * A value the plugin sets.
 *
 * The equivalent of a field on the module, with the difference that matters:
 * changing it redraws what read it, and nothing else. Setting it to what it
 * already holds is not a change (`Object.is`) — a poll answering the same
 * number every three seconds would otherwise redraw the page every three
 * seconds.
 */
export function state<T>(initial: T): State<T> {
  const source: Source = { subscribers: new Set() };
  let held = initial;
  return {
    get value() {
      tracked(source);
      return held;
    },
    set value(next: T) {
      if (Object.is(held, next)) return;
      held = next;
      notify(source);
    },
    update(fn) {
      this.value = fn(held);
    },
    peek: () => held,
  };
}

export interface Computed<T> {
  get value(): T;
  peek(): T;
}

/**
 * A value worked out from others, recomputed when one of them moves.
 *
 * Lazy: the body runs when something reads it rather than when a dependency
 * changes, so a derived value nothing is drawing costs nothing.
 */
export function computed<T>(fn: () => T): Computed<T> {
  const source: Source = { subscribers: new Set() };
  let held: T;
  let stale = true;
  const self: Computation = {
    sources: new Set(),
    invalidate() {
      if (stale) return;
      stale = true;
      notify(source);
    },
  };
  const read = (): T => {
    if (stale) {
      held = record(self, fn);
      stale = false;
    }
    return held as T;
  };
  return {
    get value() {
      tracked(source);
      return read();
    },
    peek: read,
  };
}

/**
 * Runs [fn] now, and again whenever what it read has changed.
 *
 * For the things that are not a value: clearing a selection when the server
 * moves, telling the app something. Returns a function that stops it.
 */
export function effect(fn: () => void): () => void {
  let alive = true;
  const self: Computation = {
    sources: new Set(),
    invalidate() {
      if (alive) record(self, fn);
    },
  };
  record(self, fn);
  return () => {
    alive = false;
    for (const source of self.sources) source.subscribers.delete(self);
    self.sources.clear();
  };
}

// --------------------------------------------------------- the async value

export type AsyncValue<T> =
  | { readonly state: "loading"; readonly previous?: T }
  | { readonly state: "data"; readonly value: T }
  | { readonly state: "error"; readonly error: unknown };

/**
 * The three states of something being fetched, as one value.
 *
 * `loading` carries what it had before where there is something — a refresh
 * that blanks the page it is refreshing is a page that flickers every time.
 */
export const asyncValue = {
  loading: <T>(previous?: T): AsyncValue<T> =>
    previous === undefined ? { state: "loading" } : { state: "loading", previous },
  data: <T>(value: T): AsyncValue<T> => ({ state: "data", value }),
  error: <T>(error: unknown): AsyncValue<T> => ({ state: "error", error }),
};

/** Draws one of the three. The only way to read an {@link AsyncValue} safely. */
export function when<T, R>(
  value: AsyncValue<T>,
  cases: {
    loading: (previous?: T) => R;
    error: (error: unknown) => R;
    data: (value: T) => R;
  },
): R {
  switch (value.state) {
    case "loading":
      return cases.loading(value.previous);
    case "error":
      return cases.error(value.error);
    case "data":
      return cases.data(value.value);
  }
}

export interface Resource<T> {
  /** The three states. Reading this subscribes to them. */
  get value(): AsyncValue<T>;
  peek(): AsyncValue<T>;
  /** Draws one of the three. `r.when({...})` is `when(r.value, {...})`. */
  when<R>(cases: {
    loading: (previous?: T) => R;
    error: (error: unknown) => R;
    data: (value: T) => R;
  }): R;
  /** Runs the body again, **keeping what is on screen** until it answers. */
  reload(): void;
}

/**
 * Every fetch a call must finish before it answers. `surface()` waits for
 * these.
 *
 * **Not every fetch.** A `resource` marked `background` is left out — see
 * {@link ResourceOptions.background} — because the host runs one call at a time
 * per instance, so a call that waits for a four-minute command is an instance
 * that cannot be told to stop it.
 */
const inflight = new Set<Promise<unknown>>();

/** How many are outstanding, for the host's call-driven model. */
export function pending(): number {
  return inflight.size;
}

/** Waits for what is outstanding, and for whatever those start in turn. */
export async function settleAll(rounds = 8): Promise<void> {
  for (let round = 0; round < rounds && inflight.size > 0; round++) {
    await Promise.allSettled([...inflight]);
  }
}

export interface ResourceOptions {
  /**
   * Whether a host call may answer without waiting for this.
   *
   * **The host runs one call at a time per instance.** A tap is a call, a tick
   * is a call, and neither is delivered while another is running — so a call
   * that waits for a four-minute `du` is four minutes in which the Stop button
   * this plugin drew cannot be pressed. It is also four minutes in which no
   * tick arrives, so nothing else on the page moves either.
   *
   * Set it for work whose length the plugin cannot bound: a scan, an archive,
   * anything a user might reasonably give up on. The page draws its loading
   * state, the call answers with it, and the reading arrives on the next tick
   * — the host polls the outstanding call whenever it is inside one, so
   * nothing is lost, only deferred by an interval.
   *
   * Leave it off for the short reads it would only make slower to show: a
   * store lookup, one `systemctl status`. Those are what waiting is for.
   */
  background?: boolean;
}

/**
 * Something fetched, as an {@link AsyncValue}.
 *
 * The page has all three states without the plugin holding a flag for any of
 * them, and **what the body reads it re-runs for**: reading `server.value` at
 * the top is the whole of "reload when the server changes".
 *
 * Lazy, like everything here: the fetch starts when something reads the value,
 * so a surface that does not draw it does not run it. That is what keeps a
 * plugin from running a command in `open`.
 */
export function resource<T>(
  load: () => Promise<T>,
  options: ResourceOptions = {},
): Resource<T> {
  const source: Source = { subscribers: new Set() };
  let held: AsyncValue<T> = asyncValue.loading<T>();
  let started = false;
  // Which run the outstanding promise belongs to. A slower earlier one
  // answering after a newer one started is dropped: the page would otherwise
  // show the previous machine's answer.
  let generation = 0;

  const run = (previous?: T) => {
    started = true;
    const mine = ++generation;
    held = asyncValue.loading(previous);
    notify(source);

    // The body's reads are recorded, which is what makes a resource re-run —
    // and only what it reads *before its first await*, because tracking is
    // synchronous.
    const running = record(self, load)
      .then((value) => {
        if (mine !== generation) return;
        held = asyncValue.data(value);
        notify(source);
      })
      .catch((error: unknown) => {
        if (mine !== generation) return;
        held = asyncValue.error<T>(error);
        notify(source);
      })
      .finally(() => {
        inflight.delete(running);
      });
    // A background one is still a promise and still runs; what it is not is
    // something a call waits for.
    if (!options.background) inflight.add(running);
  };

  const self: Computation = {
    sources: new Set(),
    invalidate() {
      // Something the body read has moved, so what it produced is stale.
      if (started) run(held.state === "data" ? held.value : undefined);
    },
  };

  const read = (): AsyncValue<T> => {
    if (!started) run();
    return held;
  };

  return {
    get value() {
      tracked(source);
      return read();
    },
    peek: read,
    when(cases) {
      tracked(source);
      return when(read(), cases);
    },
    reload() {
      run(held.state === "data" ? held.value : undefined);
    },
  };
}

/**
 * One value per argument — state keyed by something.
 *
 * The argument is the key, compared by `JSON.stringify`, so an object works as
 * long as it is data. What it is for: state per server, per path, per anything
 * the same page shows several of.
 */
export function family<A, T>(make: (arg: A) => T): (arg: A) => T {
  const made = new Map<string, T>();
  return (arg: A) => {
    const key = JSON.stringify(arg);
    const had = made.get(key);
    if (had !== undefined) return had;
    const one = make(arg);
    made.set(key, one);
    return one;
  };
}

/** A computation that can be run again. See {@link tracker}. */
export interface Tracker {
  /** Runs [fn] with its reads recorded, replacing what was recorded before. */
  run<T>(fn: () => T): T;
  /** Unsubscribes from everything. */
  dispose(): void;
}

/**
 * One re-runnable computation, calling [onChange] when what it read moves.
 *
 * **One per surface, reused for every build.** A fresh computation per draw
 * would subscribe again to everything it read, and the previous one is only
 * dropped when something *notifies* — so a page that drew twenty times without
 * changing held twenty subscriptions to each value it read, and the next change
 * woke all twenty. Reusing one is both less to hold and less to do: `run`
 * unsubscribes from what the last pass read before recording this one.
 *
 * @internal `surface()` is the only caller.
 */
export function tracker(onChange: () => void): Tracker {
  const self: Computation = { sources: new Set(), invalidate: onChange };
  return {
    run: (fn) => record(self, fn),
    dispose() {
      for (const source of self.sources) source.subscribers.delete(self);
      self.sources.clear();
    },
  };
}
