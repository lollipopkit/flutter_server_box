<script lang="ts">
  import { ArrowRight, CircleAlert, Plus, Server, X } from '@lucide/svelte'
  import { Button, Input, Spinner } from '@serverbox/webui'
  import OsIcon from '../../components/OsIcon.svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { ApiError, loginTo, testConnection } from '../../lib/api'
  import { normalizeAgentUrl } from '../../lib/agentUrl'
  import { capabilitiesStore } from '../../lib/capabilities.svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers, type ServerEntry } from '../../lib/servers.svelte'
  import Wallpaper from '../shell/Wallpaper.svelte'

  interface Props {
    /// [serverId] is signed in: show its desk.
    onunlock: (serverId: string) => void
  }

  const { onunlock }: Props = $props()

  /// The server chosen on this screen; the one last used to start with.
  let chosen = $state<string | null>(servers.current?.id ?? null)
  let connecting = $state(servers.empty && !servers.servedByAgent)
  let username = $state('')
  let password = $state('')
  let url = $state('')
  let busy = $state(false)
  let error = $state('')

  const entry = $derived(servers.list.find((s) => s.id === chosen))

  // A chosen server's name and icon, when it can be asked.
  $effect(() => {
    for (const s of servers.list) if (s.token) void capabilitiesStore.ensure(s.id)
  })

  let now = $state(new Date())
  $effect(() => {
    const t = setInterval(() => (now = new Date()), 10_000)
    return () => clearInterval(t)
  })
  const time = $derived(new Intl.DateTimeFormat($locale, { hour: '2-digit', minute: '2-digit' }).format(now))
  const date = $derived(new Intl.DateTimeFormat($locale, { weekday: 'long', month: 'long', day: 'numeric' }).format(now))

  function name(s: ServerEntry): string {
    return serverNames.byServer[s.id] ?? (s.id === 'local' ? $LL.thisServer() : displayName(s))
  }

  function choose(id: string) {
    chosen = id
    connecting = false
    error = ''
    password = ''
    username = servers.list.find((s) => s.id === id)?.username ?? ''
  }

  async function signIn(e: SubmitEvent) {
    e.preventDefault()
    if (!entry) return
    if (entry.token) {
      onunlock(entry.id)
      return
    }
    busy = true
    error = ''
    try {
      const res = await loginTo(entry.url, { username: username.trim(), password })
      servers.setSession(entry.id, res.token, username.trim())
      password = ''
      onunlock(entry.id)
    } catch (err) {
      error = err instanceof ApiError ? err.message : $LL.deskSignInFailed()
    } finally {
      busy = false
    }
  }

  async function connect(e: SubmitEvent) {
    e.preventDefault()
    error = ''
    let normalized: string
    try {
      normalized = normalizeAgentUrl(url)
    } catch (err) {
      error = err instanceof Error ? err.message : $LL.deskBadUrl()
      return
    }
    busy = true
    const reachable = await testConnection(normalized)
    busy = false
    if (!reachable) {
      error = $LL.deskUnreachable()
      return
    }
    servers.add(normalized)
    url = ''
    choose(servers.currentId)
  }
</script>

<!-- After ClawBox's sign-in: the wallpaper on one side, the form on the
     other, a large title over it. -->
<div class="desk-root fixed inset-0 z-[200000] flex bg-bg font-body text-fg" role="main">
  <aside class="relative hidden w-[55%] overflow-hidden border-r border-line md:block">
    <Wallpaper preset="bloom" url={null} fit="cover" />
    <p class="lock-brand absolute left-8 top-8 text-xs font-semibold uppercase tracking-[0.14em]">ServerBox</p>
    <div class="absolute bottom-10 left-8">
      <p class="text-6xl font-bold tracking-tight tabular-nums">{time}</p>
      <p class="mt-1 text-[0.95rem] font-medium text-muted-fg">{date}</p>
    </div>
  </aside>

  <div class="flex flex-1 flex-col overflow-y-auto bg-soft px-6 py-10 sm:px-8">
    <div class="my-auto w-full max-w-xl">
      <h1 class="text-4xl font-bold leading-tight tracking-tight text-fg-strong sm:text-5xl">
        {connecting ? $LL.deskConnectServer() : entry?.token ? $LL.deskUnlock() : $LL.signIn()}
      </h1>
      <p class="mt-1 truncate text-3xl font-bold leading-tight tracking-tight text-fg-strong sm:text-4xl">
        {connecting ? $LL.deskServers() : entry ? name(entry) : ''}
      </p>

      <div class="mt-6 flex flex-wrap gap-2">
        {#each servers.list as s (s.id)}
          {@const caps = capabilitiesStore.byServer[s.id]}
          {@const chosenHere = chosen === s.id && !connecting}
          <div class="group relative">
            <button
              class="flex max-w-56 items-center gap-2 rounded-xl border bg-surface py-1.5 pl-2 pr-3 text-sm font-medium transition-colors hover:border-fg/25"
              class:border-line={!chosenHere}
              class:lock-chosen={chosenHere}
              onclick={() => choose(s.id)}
              aria-pressed={chosenHere}
            >
              <span class="grid h-7 w-7 shrink-0 place-items-center rounded-lg border border-line bg-soft">
                {#if caps?.platform}
                  <OsIcon platform={caps.platform} class="h-4 w-4" />
                {:else}
                  <Server class="h-4 w-4" />
                {/if}
              </span>
              <span class="truncate">{name(s)}</span>
            </button>
            {#if !servers.servedByAgent}
              <button
                class="absolute -right-1.5 -top-1.5 hidden h-5 w-5 place-items-center rounded-full border border-line bg-surface text-muted-fg group-hover:grid"
                aria-label={$LL.removeServer()}
                title={$LL.removeServer()}
                onclick={() => {
                  servers.remove(s.id)
                  if (chosen === s.id) chosen = servers.list[0]?.id ?? null
                  if (servers.empty) connecting = true
                }}
              >
                <X class="h-3 w-3" />
              </button>
            {/if}
          </div>
        {/each}
        {#if !servers.servedByAgent}
          <button
            class="flex items-center gap-2 rounded-xl border border-dashed py-1.5 pl-2 pr-3 text-sm font-medium transition-colors hover:border-fg/40"
            class:border-line={!connecting}
            class:lock-chosen={connecting}
            onclick={() => {
              connecting = true
              error = ''
            }}
            aria-pressed={connecting}
          >
            <span class="grid h-7 w-7 place-items-center rounded-lg"><Plus class="h-4 w-4" /></span>
            {$LL.deskConnectServer()}
          </button>
        {/if}
      </div>

      <div class="mt-6">
        {#if connecting}
          <form class="flex flex-col gap-4" onsubmit={connect}>
            <label class="block text-sm">
              <span class="mb-1.5 block">{$LL.serverUrlLabel()}</span>
              <Input placeholder="https://host:3770" bind:value={url} required />
            </label>
            <div class="flex justify-end">
              <Button size="sm" disabled={busy}>
                {#if busy}<Spinner size="sm" />{/if}
                {$LL.deskConnect()}
              </Button>
            </div>
          </form>
        {:else if entry}
          <form class="flex flex-col gap-4" onsubmit={signIn}>
            {#if entry.token}
              <p class="text-sm text-muted-fg">{$LL.deskSignedInAs({ user: entry.username ?? '' })}</p>
              <div class="flex justify-end">
                <Button size="sm" class="gap-1.5">
                  {$LL.deskUnlock()}
                  <ArrowRight class="h-4 w-4" />
                </Button>
              </div>
            {:else}
              <div class="grid gap-4 sm:grid-cols-2">
                <label class="block text-sm">
                  <span class="mb-1.5 block">{$LL.username()}</span>
                  <Input autocomplete="username" bind:value={username} required />
                </label>
                <label class="block text-sm">
                  <span class="mb-1.5 block">{$LL.password()}</span>
                  <Input type="password" autocomplete="current-password" bind:value={password} required />
                </label>
              </div>
              <div class="flex justify-end">
                <Button size="sm" class="gap-1.5" disabled={busy}>
                  {#if busy}<Spinner size="sm" />{/if}
                  {$LL.signIn()}
                </Button>
              </div>
            {/if}
          </form>
        {/if}
        {#if error}
          <p class="mt-3 flex items-center gap-1.5 text-sm text-danger">
            <CircleAlert class="h-4 w-4 shrink-0" />{error}
          </p>
        {/if}
      </div>
    </div>
  </div>
</div>

<style>
  /* The accent, lifted towards the text colour so it reads on either ground. */
  .lock-brand {
    color: color-mix(in srgb, var(--desk-accent) 75%, hsl(var(--ink)));
  }
  .lock-chosen {
    border-color: color-mix(in srgb, var(--desk-accent) 40%, transparent);
    background: color-mix(in srgb, var(--desk-accent) 12%, transparent);
  }
</style>
