<script lang="ts">
  import { fmtDate } from '../../lib/format'
  import Spinner from '../lk/Spinner.svelte'
  import OsIcon from '../../components/OsIcon.svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { ApiError, loginTo, testConnection } from '../../lib/api'
  import { normalizeAgentUrl } from '../../lib/agentUrl'
  import { capabilitiesStore } from '../../lib/capabilities.svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers, type ServerEntry } from '../../lib/servers.svelte'
  import AppIcon from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Icon from '../lk/Icon.svelte'
  import Input from '../lk/Input.svelte'

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
  const time = $derived(fmtDate(now, { hour: '2-digit', minute: '2-digit' }, $locale))
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

<!-- The design system's lock screen: the wallpaper, the time large over it,
     the servers to choose from, and a glass card to sign in or connect. -->
<div class="lk desk-root fixed inset-0 z-[200000] overflow-hidden" style:background="var(--wallpaper)" role="main">
  <div class="relative flex h-full flex-col items-center overflow-y-auto px-4 pb-10 pt-[11vh]">
    <p class="text-[17px] font-medium text-(--text-secondary)">{date}</p>
    <p class="lk-num text-[55px] font-extrabold leading-[1.1] tracking-[-0.02em]">{time}</p>

    <div class="mt-[7vh] flex w-full max-w-xl flex-wrap justify-center gap-[13px]">
      {#each servers.list as s (s.id)}
        {@const caps = capabilitiesStore.byServer[s.id]}
        {@const chosenHere = chosen === s.id && !connecting}
        <div class="group relative">
          <button class="server" aria-pressed={chosenHere} onclick={() => choose(s.id)}>
            <span class="avatar">
              {#if caps?.platform}
                <OsIcon platform={caps.platform} size={30} />
              {:else}
                <Icon name="dns" size={30} fill />
              {/if}
            </span>
            <span class="w-full truncate text-center text-[13px] font-semibold">{name(s)}</span>
          </button>
          {#if !servers.servedByAgent}
            <button
              class="remove"
              aria-label={$LL.removeServer()}
              title={$LL.removeServer()}
              onclick={() => {
                servers.remove(s.id)
                if (chosen === s.id) chosen = servers.list[0]?.id ?? null
                if (servers.empty) connecting = true
              }}
            >
              <Icon name="close" size={13} weight={600} />
            </button>
          {/if}
        </div>
      {/each}
      {#if !servers.servedByAgent}
        <button
          class="server"
          aria-pressed={connecting}
          onclick={() => {
            connecting = true
            error = ''
          }}
        >
          <span class="avatar add"><Icon name="add" size={30} /></span>
          <span class="text-[13px] font-semibold">{$LL.deskConnectServer()}</span>
        </button>
      {/if}
    </div>

    <div class="card mt-[27px] w-full max-w-[320px]">
      {#if connecting}
        <form class="flex flex-col gap-[13px]" onsubmit={connect}>
          <Input label={$LL.serverUrlLabel()} placeholder="https://host:3770" bind:value={url} required />
          <Button type="submit" variant="primary" block disabled={busy}>
            {#if busy}<Spinner size="sm" />{/if}
            {$LL.deskConnect()}
          </Button>
        </form>
      {:else if entry}
        <form class="flex flex-col gap-[13px]" onsubmit={signIn}>
          <div class="flex items-center gap-[11px]">
            <AppIcon glyph="dns" tone="berry" size={34} />
            <div class="min-w-0">
              <div class="truncate text-[15px] font-semibold">{name(entry)}</div>
              <div class="truncate text-[12px] text-(--text-tertiary)">
                {entry.token ? $LL.deskSignedInAs({ user: entry.username ?? '' }) : entry.url}
              </div>
            </div>
          </div>
          {#if entry.token}
            <Button type="submit" variant="primary" block iconRight="arrow_forward">{$LL.deskUnlock()}</Button>
          {:else}
            <Input aria-label={$LL.username()} placeholder={$LL.username()} autocomplete="username" bind:value={username} required />
            <Input
              aria-label={$LL.password()}
              placeholder={$LL.password()}
              type="password"
              autocomplete="current-password"
              bind:value={password}
              required
            />
            <Button type="submit" variant="primary" block disabled={busy}>
              {#if busy}<Spinner size="sm" />{/if}
              {$LL.signIn()}
            </Button>
          {/if}
        </form>
      {/if}
      {#if error}
        <p class="mt-[11px] flex items-center gap-[5px] text-[12px] text-(--color-danger)">
          <Icon name="error" size={16} />{error}
        </p>
      {/if}
    </div>
  </div>
</div>

<style>
  .server {
    display: flex;
    width: 104px;
    flex-direction: column;
    align-items: center;
    gap: var(--space-7);
    padding: var(--space-9) var(--space-5);
    border: 0;
    border-radius: var(--radius-card);
    background: none;
    color: var(--text-primary);
    cursor: default;
    transition:
      background-color var(--dur-fast),
      transform var(--dur-slow) var(--ease-spring-bouncy);
  }
  .server:hover {
    background: var(--fill-hover);
  }
  .server:active {
    transform: scale(0.96);
  }
  .server[aria-pressed='true'] {
    background: var(--fill-press);
  }
  .server:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
  .avatar {
    display: grid;
    width: 64px;
    height: 64px;
    place-items: center;
    border-radius: 50%;
    background: var(--glass-tile);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow: var(--shadow-popover), inset 0 0 0 0.5px var(--border-glass);
    color: var(--color-accent-text);
  }
  .server[aria-pressed='true'] .avatar {
    box-shadow:
      0 0 0 2px var(--color-accent),
      var(--shadow-popover);
  }
  .avatar.add {
    background: transparent;
    box-shadow: inset 0 0 0 1.5px var(--border-strong);
    color: var(--text-secondary);
  }
  .remove {
    position: absolute;
    top: 2px;
    right: 14px;
    display: none;
    width: 20px;
    height: 20px;
    place-items: center;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: var(--surface-raised);
    box-shadow: var(--shadow-thumb);
    color: var(--text-secondary);
  }
  .group:hover .remove,
  .remove:focus-visible {
    display: grid;
  }
  .card {
    padding: var(--space-17);
    border-radius: var(--radius-panel);
    background: var(--glass-panel);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow:
      var(--shadow-window),
      inset 0 0 0 0.5px var(--border-glass);
    animation: lk-pop-in var(--dur-window) var(--ease-spring-bouncy);
  }
</style>
