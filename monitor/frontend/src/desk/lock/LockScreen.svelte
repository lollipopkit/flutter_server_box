<script lang="ts">
  import { ArrowRight, CircleAlert, Plus, Server, X } from '@lucide/svelte'
  import { Spinner } from '@serverbox/webui'
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

<div class="desk-root fixed inset-0 z-[200000] overflow-hidden font-body" role="main">
  <div class="absolute inset-0 scale-110 blur-2xl">
    <Wallpaper preset="nightfall" url={null} fit="cover" />
  </div>
  <div class="absolute inset-0 bg-black/25"></div>

  <div class="relative flex h-full flex-col items-center overflow-y-auto px-4 pb-10 pt-[12vh] text-white">
    <p class="text-[0.95rem] font-medium opacity-90">{date}</p>
    <p class="font-display text-7xl font-bold tracking-tight tabular-nums sm:text-8xl">{time}</p>

    <div class="mt-[8vh] flex w-full max-w-xl flex-wrap justify-center gap-4">
      {#each servers.list as s (s.id)}
        {@const caps = capabilitiesStore.byServer[s.id]}
        <div class="group relative">
          <button
            class="flex w-28 flex-col items-center gap-2 rounded-2xl p-3 transition-colors hover:bg-white/10"
            class:bg-white-15={chosen === s.id && !connecting}
            onclick={() => choose(s.id)}
            aria-pressed={chosen === s.id && !connecting}
          >
            <span
              class="grid h-16 w-16 place-items-center rounded-full bg-white/20 shadow-lg ring-white/80 backdrop-blur"
              class:ring-2={chosen === s.id && !connecting}
            >
              {#if caps?.platform}
                <OsIcon platform={caps.platform} class="h-8 w-8" />
              {:else}
                <Server class="h-8 w-8" />
              {/if}
            </span>
            <span class="w-full truncate text-center text-sm font-medium drop-shadow">{name(s)}</span>
          </button>
          {#if !servers.servedByAgent}
            <button
              class="absolute right-1 top-1 hidden h-5 w-5 place-items-center rounded-full bg-black/40 group-hover:grid"
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
          class="flex w-28 flex-col items-center gap-2 rounded-2xl p-3 transition-colors hover:bg-white/10"
          onclick={() => {
            connecting = true
            error = ''
          }}
          aria-pressed={connecting}
        >
          <span class="grid h-16 w-16 place-items-center rounded-full border-2 border-dashed border-white/60" class:border-white={connecting}>
            <Plus class="h-7 w-7" />
          </span>
          <span class="text-sm font-medium drop-shadow">{$LL.deskConnectServer()}</span>
        </button>
      {/if}
    </div>

    <div class="mt-8 w-full max-w-xs">
      {#if connecting}
        <form class="space-y-2" onsubmit={connect}>
          <input
            class="w-full rounded-full bg-white/20 px-4 py-2 text-sm text-white outline-none backdrop-blur placeholder:text-white/60 focus:bg-white/25"
            placeholder="https://host:3770"
            bind:value={url}
            aria-label={$LL.serverUrlLabel()}
            required
          />
          <button
            class="flex w-full items-center justify-center gap-2 rounded-full bg-white/25 py-2 text-sm font-semibold backdrop-blur hover:bg-white/35 disabled:opacity-50"
            disabled={busy}
          >
            {#if busy}<Spinner size="sm" />{/if}
            {$LL.deskConnect()}
          </button>
        </form>
      {:else if entry}
        <form class="space-y-2" onsubmit={signIn}>
          {#if entry.token}
            <p class="text-center text-sm opacity-80">{$LL.deskSignedInAs({ user: entry.username ?? '' })}</p>
            <button
              class="flex w-full items-center justify-center gap-2 rounded-full bg-white/25 py-2 text-sm font-semibold backdrop-blur hover:bg-white/35"
            >
              {$LL.deskUnlock()}
              <ArrowRight class="h-4 w-4" />
            </button>
          {:else}
            <input
              class="w-full rounded-full bg-white/20 px-4 py-2 text-sm text-white outline-none backdrop-blur placeholder:text-white/60 focus:bg-white/25"
              placeholder={$LL.username()}
              autocomplete="username"
              bind:value={username}
              aria-label={$LL.username()}
              required
            />
            <div class="relative">
              <input
                class="w-full rounded-full bg-white/20 py-2 pl-4 pr-10 text-sm text-white outline-none backdrop-blur placeholder:text-white/60 focus:bg-white/25"
                type="password"
                placeholder={$LL.password()}
                autocomplete="current-password"
                bind:value={password}
                aria-label={$LL.password()}
                required
              />
              <button
                class="absolute right-1 top-1 grid h-7 w-7 place-items-center rounded-full bg-white/25 hover:bg-white/40 disabled:opacity-50"
                aria-label={$LL.signIn()}
                disabled={busy}
              >
                {#if busy}<Spinner size="sm" />{:else}<ArrowRight class="h-4 w-4" />{/if}
              </button>
            </div>
          {/if}
        </form>
      {/if}
      {#if error}
        <p class="mt-3 flex items-center justify-center gap-1.5 text-center text-sm text-red-200">
          <CircleAlert class="h-4 w-4 shrink-0" />{error}
        </p>
      {/if}
    </div>
  </div>
</div>

<style>
  .bg-white-15 {
    background: rgb(255 255 255 / 0.15);
  }
</style>
