/**
 * Sending only what changed.
 *
 * Flutter's `Element.updateChild` has one fast path that matters here
 * (`framework.dart`): when the new widget compares equal to the old one it
 * returns immediately, without calling `update()`. The whole subtree is then
 * skipped — no rebuild, no layout, no paint. `Widget` does not override `==`,
 * so that comparison is identity.
 *
 * A tree rebuilt from scratch every tick never hits it: every widget is a new
 * object, so the framework walks the whole tree to discover that nothing moved.
 *
 * So each node carries a revision. A node whose revision the app already has is
 * sent as `{t, k, v, s: 1}` with no properties and no children, and the app
 * hands back the Widget instance it built last time — which is what makes the
 * fast path fire. `s` is what separates that from a node with no content of
 * its own; see {@link stub}.
 *
 * The author writes none of this. {@link frame} diffs against the tree it sent
 * last time and assigns the revisions itself.
 */

import type { Node } from "./ui.ts";

/** The full tree as last sent, with its revisions. */
let previous: Node | null = null;

/** Rises whenever any subtree changes. Any value that differs would do. */
let revision = 0;

/**
 * Prepares a tree for the app, pruning what has not changed.
 *
 * Call it on every tree returned from `open`, `onEvent` or `tick`:
 *
 * ```ts
 * export function tick(): UiOutput {
 *   return { ui: frame(view()) };
 * }
 * ```
 *
 * `full` is what to send when the app cannot have the previous tree — the first
 * frame of a surface, and after anything that discarded it.
 */
export function frame(tree: Node, opts?: { full?: boolean }): Node {
  if (opts?.full) previous = null;
  const { kept, sent } = walk(tree, previous);
  previous = kept;
  return sent;
}

/**
 * Forgets what the app has, so the next {@link frame} sends everything.
 *
 * The host discards a surface's tree when a call threw, because a plugin that
 * failed halfway may have counted a frame the app never applied. Anything doing
 * the same on the plugin's side calls this.
 */
export function resetFrame(): void {
  previous = null;
}

interface Walked {
  /** The full node, carrying the revision, kept for the next comparison. */
  kept: Node;
  /** What goes to the app: pruned where nothing changed. */
  sent: Node;
  /**
   * Whether anything in this subtree moved.
   *
   * Carried rather than inferred from `sent`'s shape. A stub and a node type
   * that simply has no content — `spacer`, `divider` — look the same from
   * outside, so reading the shape made a `spacer` replacing a `text` count as
   * unchanged, and the parent stubbed itself over a subtree that had.
   */
  changed: boolean;
}

function walk(next: Node, prev: Node | null): Walked {
  if (prev && shallowSame(next, prev)) {
    const nextChildren = next.c ?? [];
    const prevChildren = prev.c ?? [];
    if (nextChildren.length === prevChildren.length) {
      const walked = nextChildren.map((child, i) => walk(child, prevChildren[i]!));
      // Unchanged all the way down, and the app already has this revision, so
      // the whole subtree collapses to three fields.
      if (walked.every((w) => !w.changed)) {
        return { kept: prev, sent: stub(prev), changed: false };
      }
      // The node itself did not change, but something below it did. Its own
      // revision has to move too: the app compares by revision, and reusing the
      // old one would have it reuse a Widget whose children are stale.
      const v = ++revision;
      const kept: Node = { ...next, v, c: walked.map((w) => w.kept) };
      const sent: Node = { ...next, v, c: walked.map((w) => w.sent) };
      return { kept, sent, changed: true };
    }
  }

  const v = ++revision;
  const children = (next.c ?? []).map((child) => walk(child, null));
  const kept: Node = { ...next, v };
  const sent: Node = { ...next, v };
  if (children.length > 0) {
    kept.c = children.map((c) => c.kept);
    sent.c = children.map((c) => c.sent);
  }
  return { kept, sent, changed: true };
}

/**
 * A node reduced to "you already have this".
 *
 * `s` is what separates it from a node that simply has no content. A `spacer`
 * carries no properties and no children, so without the marker `{t, v}` would
 * mean both things — and the app, told to reuse a revision it has never seen,
 * would report that rather than draw the spacer.
 */
function stub(prev: Node): Node {
  const n: Node = { t: prev.t, s: 1 };
  if (prev.v !== undefined) n.v = prev.v;
  if (prev.k !== undefined) n.k = prev.k;
  return n;
}

/** Everything about a node except its children. */
function shallowSame(a: Node, b: Node): boolean {
  return a.t === b.t && a.k === b.k && same(a.p, b.p) && same(a.on, b.on);
}

/**
 * Structural equality, over what a node's properties can hold.
 *
 * Deep comparison rather than a hash: the tree is walked either way, and a hash
 * would trade an exact answer for a collision that shows up as a card which
 * stopped updating.
 */
function same(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null || a === undefined || b === undefined) return false;

  if (Array.isArray(a)) {
    if (!Array.isArray(b) || a.length !== b.length) return false;
    return a.every((v, i) => same(v, b[i]));
  }
  if (typeof a === "object") {
    if (typeof b !== "object" || Array.isArray(b)) return false;
    const ka = Object.keys(a as object);
    const kb = Object.keys(b as object);
    if (ka.length !== kb.length) return false;
    return ka.every((k) =>
      Object.hasOwn(b as object, k)
        ? same((a as Record<string, unknown>)[k], (b as Record<string, unknown>)[k])
        : false,
    );
  }
  // NaN, which `===` says differs from itself. A reading that is not a number
  // twice running has not changed.
  return a !== a && b !== b;
}
