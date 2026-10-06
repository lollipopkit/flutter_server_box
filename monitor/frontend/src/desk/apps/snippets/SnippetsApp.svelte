<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import { Pencil, Play, Plus, RefreshCw, Trash2 } from '@lucide/svelte'
  import SnippetForm, {
    snippetFormState,
    type SnippetFormState,
  } from './SnippetForm.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import { useWindow } from '../../deskState.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { snippetPlanRefusalText, snippetRefusalText } from '../../../lib/snippetRefusal'
  import { snippetRun } from '../../../lib/snippetRun.svelte'
  import { untrack } from 'svelte'
  import type { Snippet, SnippetsView } from '../../../types'

  /// The snippet library saved on the agent, and the one screen that runs one.
  ///
  /// Running hands the script to the terminal rather than executing it here:
  /// the agent's `/snippets/plan` answers what a shell should be *typed*, and
  /// the terminal is the only page with a shell. So Run expands the script,
  /// leaves it in `snippetRun` and opens the terminal, which types it once its
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
      snippetRun.queue(snippet.name, plan.steps)
      opened = null
      win.open('terminal')
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
    <IconButton label={$LL.snippetAdd()} onclick={() => openForm(null)}>
      <Plus class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</AppToolbar>

<main class="mx-auto max-w-3xl space-y-3 px-4 py-4 @3xl:px-6">
  {#if error}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if actionError}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</p>
    </Card>
  {/if}

  {#if notice}
    <Card class="p-3">
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card class="grid place-items-center p-8"><Spinner class="h-5 w-5" /></Card>
  {:else if view}
    {#if snippets.length === 0}
      <Card class="p-4">
        <p class="text-sm text-muted-fg">{$LL.snippetEmpty()}</p>
      </Card>
    {:else}
      <!-- One snippet per card: what it is called and what it would type. Its
           three actions are in the dialog the card opens, so a Run press is
           never the thing nearest the cursor. -->
      <ul class="space-y-2">
        {#each snippets as snippet (snippet.id)}
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl border border-line bg-surface px-3 py-2.5 text-left transition-colors hover:bg-soft/40"
              onclick={() => open(snippet)}
            >
              <span class="min-w-0 flex-1">
                <span class="flex flex-wrap items-baseline gap-2">
                  <span class="truncate text-[0.85rem] font-medium text-fg-strong">{snippet.name}</span>
                  {#each snippet.tags as tag (tag)}
                    <Badge tone="neutral">{tag}</Badge>
                  {/each}
                </span>
                <span class="mt-0.5 block truncate font-mono text-xs text-muted-fg">{snippet.script}</span>
              </span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}

    <!-- What a snippet is and what pressing Run does, in one place: the list
         is the only screen either is visible from, and the answer to "what
         happens" is not on this page at all. -->
    <p class="px-1 text-[0.7rem] text-muted-fg">{$LL.snippetRunNote()}</p>

    {#if busy}
      <div class="flex items-center gap-2 px-1 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

<!-- One snippet: what is stored, and the three things that may be done with it.
     Its own dialog rather than buttons on the row, so the script is on screen
     before it is run — a Run press is the one action here that cannot be taken
     back, and it is not the one nearest the cursor. -->
{#if opened && editing === undefined}
  <Modal open title={opened.name} onclose={() => (opened = null)}>
    <div class="space-y-4">
      {#if opened.tags.length > 0}
        <div class="flex flex-wrap gap-1.5">
          {#each opened.tags as tag (tag)}
            <Badge tone="neutral">{tag}</Badge>
          {/each}
        </div>
      {/if}

      {#if opened.note}
        <p class="text-sm text-muted-fg">{opened.note}</p>
      {/if}

      <pre
        class="max-h-64 overflow-auto rounded-md border border-line bg-soft/40 px-3 py-2 font-mono text-xs whitespace-pre-wrap break-all text-fg">{opened.script}</pre>

      {#if removing}
        <Card class="space-y-2">
          <p class="text-sm text-fg">{$LL.snippetDeleteConfirm({ name: opened.name })}</p>
          <div class="flex justify-end gap-2">
            <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
            <Button disabled={busy} onclick={() => void remove()}>{$LL.snippetDelete()}</Button>
          </div>
        </Card>
      {:else}
        <div class="flex flex-wrap items-center gap-2">
          <Button disabled={planning || busy} onclick={() => void run(opened!)}>
            {#if planning}<Spinner class="w-4 h-4" />{:else}<Play class="w-4 h-4" />{/if}
            {$LL.snippetRun()}
          </Button>
          <Button variant="secondary" onclick={() => openForm(opened!)}>
            <Pencil class="w-4 h-4" />
            {$LL.snippetEdit()}
          </Button>
          <Button variant="secondary" onclick={() => (removing = true)}>
            <Trash2 class="w-4 h-4" />
            {$LL.snippetDelete()}
          </Button>
        </div>
        {#if runError}
          <p class="text-sm text-danger whitespace-pre-wrap break-all">{runError}</p>
        {/if}
      {/if}
    </div>
  </Modal>
{/if}

{#if editing !== undefined}
  <Modal
    open
    title={editing ? $LL.snippetEdit() : $LL.snippetAdd()}
    onclose={() => (editing = undefined)}
  >
    <SnippetForm
      snippet={editing ?? undefined}
      fields={formState}
      onsaved={(snippet) => void submit(snippet, editing ?? null)}
      oncancel={() => (editing = undefined)}
    />
  </Modal>
{/if}
