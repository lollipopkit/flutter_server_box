<script lang="ts">
  import Spinner from '../../lk/Spinner.svelte'
  import { AppToolbar, useWindow } from '../../sys'
  import { Badge, Button, Card, Dialog, Icon, IconButton } from '../../lk'
  import SnippetForm, {
    snippetFormState,
    type SnippetFormState,
  } from './SnippetForm.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { snippetPlanRefusalText, snippetRefusalText } from '../../../lib/snippetRefusal'
  import { TYPE_SNIPPET } from '../../../lib/snippetIntent'
  import { untrack } from 'svelte'
  import type { Snippet, SnippetsView } from '../../../types'

  /// The snippet library saved on the agent, and the one screen that runs one.
  ///
  /// Running hands the script to the terminal rather than executing it here:
  /// the agent's `/snippets/plan` answers what a shell should be *typed*, and
  /// the terminal is the only page with a shell. So Run expands the script,
  /// opens a terminal with it as an intent (`lib/snippetIntent`), which types it once its
  /// session is up.
  const win = useWindow()

  let view = $state<SnippetsView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after a write lands and cleared by the next one. Worth saying because
  /// the set it names has been replaced under the list still on screen.
  let notice = $state('')
  /// What went wrong with a write, the agent's own code where it sent one.
  let actionError = $state('')
  /// Why the snippet on screen cannot be expanded, from `/plan` rather than
  /// from the save — a different question asked of the same dialog, so it has
  /// its own place to be shown.
  let runError = $state('')
  /// The snippet whose detail is open, the snippet the form is about
  /// (`undefined` for a new one), and whether the open one is being removed.
  let opened = $state<Snippet | null>(null)
  let editing = $state<Snippet | null | undefined>(undefined)
  let formState = $state<SnippetFormState>(snippetFormState())
  let removing = $state(false)
  let planning = $state(false)

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getSnippets()
      if (stale(serverId)) return
      view = next
      // The open snippet is replaced by the fresh one with the same id, so the
      // dialog shows what the save just produced — and closes by itself where
      // the snippet is gone.
      if (opened) {
        opened = next.snippets.find((snippet) => snippet.id === opened?.id) ?? null
        if (!opened) removing = false
      }
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// A write replaces the whole library, because that is what the endpoint
  /// takes: the order is part of what is stored, so there is no smaller
  /// expression for a move, and an add, a change and a removal are the same
  /// request with a different list.
  async function save(snippets: Snippet[], done: string) {
    busy = true
    notice = ''
    actionError = ''
    try {
      view = await api.updateSnippets(snippets)
      notice = done
      return true
    } catch (e) {
      // A refusal made before anything was stored, as its own code.
      actionError = snippetRefusalText(e)
      return false
    } finally {
      busy = false
    }
  }

  async function submit(snippet: Snippet, original: Snippet | null) {
    const snippets = view?.snippets ?? []
    // Matched by id, which is a snippet's identity: matching by position would
    // replace whichever snippet a rename had pushed out of the way.
    const next = original
      ? snippets.map((entry) => (entry.id === original.id ? snippet : entry))
      : [...snippets, snippet]
    // The dialog stays open on a refusal so the field that caused it is still
    // there to be corrected.
    if (await save(next, $LL.snippetDoneSaved({ name: snippet.name }))) editing = undefined
  }

  async function remove() {
    const snippet = opened
    if (!snippet) return
    const next = (view?.snippets ?? []).filter((entry) => entry.id !== snippet.id)
    if (await save(next, $LL.snippetDoneDeleted({ name: snippet.name }))) {
      opened = null
      removing = false
    }
  }

  function open(snippet: Snippet) {
    opened = snippet
    removing = false
    actionError = ''
    runError = ''
  }

  function openForm(snippet: Snippet | null) {
    formState = snippetFormState(snippet ?? undefined)
    editing = snippet
    actionError = ''
  }

  /// Expands the script and hands it to the terminal.
  ///
  /// The expansion is asked of the agent for the same reason the app asks the
  /// shared crate for it: what `${ctrl+c}` sends is one definition, and a
  /// second reading of the script here would be free to disagree with it.
  ///
  /// Nothing is executed by this: a snippet becomes a command only once a shell
  /// has run it, and what is queued is what a keyboard would have typed.
  async function run(snippet: Snippet) {
    // The queue is global and the terminal types into whichever server is on
    // screen, so a plan that answers after a switch belongs to neither.
    const serverId = servers.currentId
    planning = true
    runError = ''
    try {
      const plan = await api.planSnippet(snippet.script)
      if (stale(serverId)) return
      // A terminal of its own: the script goes to the shell this opens and
      // to no other terminal already on the desk.
      const terminal = win.open('terminal', {
        newWindow: true,
        intent: { action: TYPE_SNIPPET, data: { name: snippet.name, steps: plan.steps } },
      })
      if (!terminal) {
        runError = $LL.snippetNoTerminal()
        return
      }
      opened = null
    } catch (e) {
      if (stale(serverId)) return
      runError = snippetPlanRefusalText(e)
    } finally {
      planning = false
    }
  }

  const snippets = $derived(view?.snippets ?? [])

  function subtitle(): string | undefined {
    return $LL.snippetSubtitle({ count: snippets.length })
  }
</script>

<AppToolbar subtitle={view ? subtitle() : undefined}>
  {#snippet actions()}
    <Button size="sm" variant="tinted" icon="add" onclick={() => openForm(null)}>{$LL.snippetAdd()}</Button>
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<main class="space-y-[9px] px-(--content-pad) pb-[21px] pt-[5px]">
  {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
  {#if actionError}<Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{actionError}</p></Card>{/if}
  {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

  {#if loading && !view}
    <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
  {:else if view}
    {#if snippets.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
        <Icon name="terminal" size={48} weight={300} />
        <span class="text-[13px]">{$LL.snippetsEmptyState()}</span>
      </div>
    {:else}
      <!-- Each item opens its details before Run is available. -->
      <ul class="space-y-[7px]">
        {#each snippets as snippet (snippet.id)}
          <li>
            <Card padding="11px 13px" onclick={() => open(snippet)}>
              <div class="flex min-w-0 items-center gap-[13px]">
                <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)"><Icon name="terminal" size={18} /></span>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-[7px]">
                    <span class="truncate text-[13px] font-semibold">{snippet.name}</span>
                    {#each snippet.tags as tag (tag)}<Badge tone="neutral">{tag}</Badge>{/each}
                  </div>
                  <p class="lk-mono truncate text-[12px] text-(--text-tertiary)">{snippet.script}</p>
                </div>
              </div>
            </Card>
          </li>
        {/each}
      </ul>
    {/if}

    <!-- Run expands the script and types it into a terminal session. -->
    <p class="px-[3px] text-[12px] text-(--text-tertiary)">{$LL.snippetRunNote()}</p>
    {#if busy}<div class="flex items-center gap-[7px] px-[3px] text-[12px] text-(--text-tertiary)"><Spinner size="sm" /></div>{/if}
  {/if}
</main>

<!-- One snippet: what is stored, and the actions that use it. -->
{#if opened && editing === undefined}
  <Dialog open wide title={opened.name} onclose={() => (opened = null)}>
    {#snippet actions()}
      {#if removing}
        <Button variant="destructive" disabled={busy} onclick={() => void remove()}>{$LL.snippetDelete()}</Button>
        <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
      {:else}
        <Button variant="primary" icon="play_arrow" disabled={planning || busy} onclick={() => void run(opened!)}>{$LL.snippetRun()}</Button>
        <Button variant="secondary" icon="edit" onclick={() => openForm(opened!)}>{$LL.snippetEdit()}</Button>
        <Button variant="destructive" icon="delete" onclick={() => (removing = true)}>{$LL.snippetDelete()}</Button>
        <Button variant="secondary" onclick={() => (opened = null)}>{$LL.close()}</Button>
      {/if}
    {/snippet}
    {#if opened.tags.length > 0}<div class="flex flex-wrap gap-[7px]">{#each opened.tags as tag (tag)}<Badge tone="neutral">{tag}</Badge>{/each}</div>{/if}
    {#if removing}<p class="my-[13px] text-[13px] text-(--text-secondary)">{$LL.snippetDeleteConfirm({ name: opened.name })}</p>{/if}
    {#if opened.note}<p class="mt-[9px] text-[13px] text-(--text-secondary)">{opened.note}</p>{/if}
    <pre class="mt-[13px] max-h-64 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono whitespace-pre-wrap break-all text-[13px]">{opened.script}</pre>
    {#if planning}<div class="mt-[9px]"><Spinner class="w-4 h-4" /></div>{/if}
    {#if runError}<p class="mt-[9px] whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{runError}</p>{/if}
  </Dialog>
{/if}

{#if editing !== undefined}
  <Dialog open wide title={editing ? $LL.snippetEdit() : $LL.snippetAdd()} onclose={() => (editing = undefined)}>
    <SnippetForm
      snippet={editing ?? undefined}
      fields={formState}
      onsaved={(snippet) => void submit(snippet, editing ?? null)}
      oncancel={() => (editing = undefined)}
    />
  </Dialog>
{/if}
