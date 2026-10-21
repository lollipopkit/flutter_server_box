<script module lang="ts">
  import type { Component } from 'svelte'

  /// Any page component, whatever props it declares.
  ///
  /// The wrapper cannot know a page's props — each one declares its own, some
  /// take an `onback` and some take none — and a component's props are
  /// contravariant, so no single concrete prop type accepts them all. `any` is
  /// the honest type here; the alternative is every page re-declaring the same
  /// shape to suit this file.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export type AnyPage = Component<any>

  /// Resolved chunks, keyed by the loader `App.svelte` passed.
  ///
  /// Module scope rather than per-instance state: the whole point is to
  /// outlive the instance, since a page is unmounted and rebuilt on every
  /// navigation. The loaders are module-level constants in `App.svelte`, so
  /// they are stable identities. A `WeakMap` and not a reactive one — nothing
  /// renders from this, it only answers "have we already got this chunk", and
  /// keying weakly means a loader that ever did go out of scope takes its entry
  /// with it rather than needing a bound.
  const resolved = new WeakMap<() => Promise<{ default: AnyPage }>, AnyPage>()
</script>

<script lang="ts">
  import { Spinner } from '@serverbox/webui'

  /// Loads a page the first time it is asked for, and keeps it after that.
  ///
  /// `App.svelte` used to import all sixteen pages statically, so every visit
  /// downloaded all of them — around 1.6 MB, half a megabyte of it gzipped,
  /// for a panel most visits only ever open a Dashboard and one other page on.
  /// The heavy *dependencies* (xterm, noVNC, IronRDP) were already split out
  /// this way; this is the same move one level up, for the pages themselves.
  ///
  /// The loader is a function rather than a promise on purpose: a promise
  /// passed in would have been started by the parent, so switching away and
  /// back before it resolved would still be showing the first page's chunk.
  interface Props {
    loader: () => Promise<{ default: AnyPage }>
    props?: Record<string, unknown>
  }

  const { loader, props = {} }: Props = $props()

  /// `null` while the chunk is in flight, which is also the state a switch
  /// back to a not-yet-loaded page starts from.
  let page = $state<AnyPage | null>(null)

  $effect(() => {
    const current = loader
    let alive = true
    const cached = resolved.get(current)
    if (cached) {
      // `App.svelte` remounts this on every page and server switch, so without
      // this a second visit to a page already fetched would flash a spinner for
      // a microtask, which is a flicker and nothing else.
      page = cached
      return
    }
    page = null
    void current()
      .then((module) => {
        resolved.set(current, module.default)
        if (alive) page = module.default
      })
      .catch((error) => {
        // A chunk that will not load is the panel and the agent disagreeing
        // about versions, which a retry cannot fix and the user cannot read
        // off a spinner. Left to the console rather than dressed up as a
        // message in thirteen languages this file does not otherwise own.
        console.error('page chunk failed to load', error)
      })
    // A page unmounted mid-load must not set state on the way out.
    return () => {
      alive = false
    }
  })
</script>

{#if page}
  <page {...props}></page>
{:else}
  <div class="flex items-center justify-center p-12">
    <Spinner />
  </div>
{/if}
