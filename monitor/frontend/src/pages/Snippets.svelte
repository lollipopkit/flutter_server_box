<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import { Pencil, Play, Plus, RefreshCw, Trash2 } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import SnippetForm, {
    snippetFormState,
    type SnippetFormState,
  } from '../components/SnippetForm.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { api, ApiError } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { layout } from '../lib/layout.svelte'
  import { servers } from '../lib/servers.svelte'
  import { snippetPlanRefusalText, snippetRefusalText } from '../lib/snippetRefusal'
  import { snippetRun } from '../lib/snippetRun.svelte'
  import { untrack } from 'svelte'
  import type { Snippet, SnippetsView } from '../types'

  /// The snippet library saved on the agent, and the one screen that runs one.
  ///
  /// Running hands the script to the terminal rather than executing it here:
  /// the agent's `/snippets/plan` answers what a shell should be *typed*, and
  /// the terminal is the only thing on this page that has a shell. So Run
  /// expands the script, leaves it in `snippetRun` and opens the terminal,
  /// which types it once its session is up.
  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

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

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  const caps = $derived(capabilitiesStore.byServer[servers.currentId]?.remote_access)
  /// Whether this agent answers `/snippets` at all. The tab is only drawn for an
  /// agent that does, so a page reached with this false is one reached from a
  /// cached capability — worth explaining rather than showing a failed request.
  const served = $derived(caps?.snippets !== false)

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
    // Only the machine on screen re-runs this, and only when it serves the
    // library: a request to an agent without the endpoint would answer 404 and
    // be drawn as a failure of this page rather than as an agent too old for it.
    const serverId = servers.currentId
    if (!served) return
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
      actionError = snippetRefusalText(e instanceof Error ? e.message : String(e))
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
    planning = true
    runError = ''
    try {
      const plan = await api.planSnippet(snippet.script)
      snippetRun.queue(snippet.name, plan.steps)
      opened = null
      layout.navigate('terminal')
    } catch (e) {
      runError = e instanceof ApiError ? planRefusalText(e) : e instanceof Error ? e.message : String(e)
    } finally {
      planning = false
    }
  }

  /// `/plan`'s refusal read off the `ApiError`.
  ///
  /// From the body rather than the message: `request()` builds the message out
  /// of the `error` code alone, and this refusal carries the placeholder it
  /// could not answer as a second field (`{error, key}`). A save's refusals are
  /// one code and one sentence, which is why the other helper here needs only
  /// the message. An `error` code this build does not know is shown as sent.
  function planRefusalText(error: ApiError): string {
    const body = error.body as { error?: unknown; key?: unknown } | undefined
    if (typeof body?.error !== 'string') return error.message
    return snippetPlanRefusalText(body.error, typeof body.key === 'string' ? body.key : '')
  }

  const snippets = $derived(view?.snippets ?? [])

  function subtitle(): string | undefined {
    return $LL.snippetSubtitle({ count: snippets.length })
  }
</script>

<PageHeader
  title={$LL.snippets()}
  subtitle={view ? subtitle() : undefined}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="snippets" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.snippetAdd()} onclick={() => openForm(null)} disabled={!served}>
      <Plus class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading || !served}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if !served}
    <Card>
      <p class="text-sm text-muted-fg">{$LL.snippetUnavailable()}</p>
    </Card>
  {:else}
    {#if error}
      <Card class="border-danger/40 bg-danger/5">
        <p class="text-sm text-danger">{error}</p>
      </Card>
    {/if}

    {#if actionError}
      <Card class="border-danger/40 bg-danger/5">
        <p class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</p>
      </Card>
    {/if}

    {#if notice}
      <Card>
        <p class="text-sm text-muted-fg">{notice}</p>
      </Card>
    {/if}

    {#if loading && !view}
      <Card><Spinner class="w-5 h-5" /></Card>
    {:else if view}
      {#if snippets.length === 0}
        <Card>
          <p class="text-sm text-muted-fg">{$LL.snippetEmpty()}</p>
        </Card>
      {:else}
        <Card class="divide-y divide-line p-0">
          {#each snippets as snippet (snippet.id)}
            <button
              class="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-soft/40"
              onclick={() => open(snippet)}
            >
              <span class="min-w-0 flex-1">
                <span class="flex flex-wrap items-baseline gap-2">
                  <span class="truncate text-sm font-medium text-fg-strong">{snippet.name}</span>
                  {#each snippet.tags as tag (tag)}
                    <Badge tone="neutral">{tag}</Badge>
                  {/each}
                </span>
                <span class="block truncate font-mono text-xs text-muted-fg">{snippet.script}</span>
              </span>
            </button>
          {/each}
        </Card>
      {/if}

      <!-- What a snippet is and what pressing Run does, in one place: the list
           is the only screen either is visible from, and the answer to "what
           happens" is not on this page at all. -->
      <p class="text-xs text-muted-fg">{$LL.snippetRunNote()}</p>

      {#if busy}
        <div class="flex items-center gap-2 text-xs text-muted-fg">
          <Spinner size="sm" />
        </div>
      {/if}
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
