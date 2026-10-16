<script lang="ts">
  /// This agent's version, whether a newer one is out (`GET /update`), and
  /// updating it.
  ///
  /// The agent runs the installer apart from itself (`POST /update/run`,
  /// `sbm_parser::monitor_agent::start_update_script`): the upgrade restarts
  /// the agent, which ends every connection through it — a terminal it opened
  /// included — but not the update. This follows the update's log across the
  /// restart, saying so while the agent does not answer.

  import { onDestroy } from 'svelte'
  import { errorText } from '../../../lib/errorText'
  import { Badge, Button, Group, Input, Row } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { canAct } from '../../../lib/access'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { AgentUpdate, AgentUpdateRun } from '../../../types'

  /// How often the update is asked after while it runs.
  const EVERY_MS = 2000
  /// When to stop waiting for an agent that does not come back.
  const GIVE_UP_MS = 15 * 60 * 1000

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  const mayAct = $derived(canAct(caps))

  let update = $state<AgentUpdate | null>(null)
  let checking = $state(false)
  let error = $state<string | null>(null)
  let password = $state('')

  /// Following an update this page started, or found running.
  let following = $state(false)
  let starting = $state(false)
  /// The agent did not answer the last ask: restarting, most likely.
  let away = $state(false)
  let gaveUp = $state(false)
  let timer: ReturnType<typeof setInterval> | undefined
  let since = 0
  const { stale } = useScope()

  const run = $derived<AgentUpdateRun | undefined>(update?.run)

  async function load(check: boolean) {
    const serverId = servers.currentId
    checking = check
    error = null
    try {
      const read = await api.getUpdate(check)
      if (stale(serverId)) return
      update = read
      if (read.run?.state === 'running') follow()
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    } finally {
      checking = false
    }
  }

  $effect(() => {
    void servers.currentId
    stop()
    update = null
    if (servers.authenticated) void load(false)
  })

  onDestroy(stop)

  function stop() {
    if (timer) clearInterval(timer)
    timer = undefined
    following = false
  }

  function follow() {
    if (timer) return
    following = true
    away = false
    gaveUp = false
    since = Date.now()
    const serverId = servers.currentId
    timer = setInterval(() => void poll(serverId), EVERY_MS)
  }

  async function poll(serverId: string) {
    try {
      const read = await api.getUpdate()
      if (stale(serverId)) return stop()
      away = false
      update = read
      if (read.run && read.run.state !== 'running') {
        stop()
        // A new agent: what it offers may have changed with it.
        void capabilitiesStore.refresh(serverId)
      }
    } catch {
      if (stale(serverId)) return stop()
      away = true
      if (Date.now() - since > GIVE_UP_MS) {
        gaveUp = true
        stop()
      }
    }
  }

  async function start() {
    starting = true
    error = null
    try {
      const serverId = servers.currentId
      await api.startUpdate(update?.needs_password ? password : undefined)
      password = ''
      await load(false)
      if (!stale(serverId)) follow()
    } catch (e) {
      error =
        e instanceof ApiError && e.code === 'sudo_password'
          ? $LL.selfUpdateSudoRefused()
          : e instanceof ApiError
            ? e.message
            : String(e)
    } finally {
      starting = false
    }
  }
</script>

<Group title={$LL.selfUpdateTitle()}>
  <Row label={$LL.selfUpdateVersion()} value={update?.version ?? caps?.version ?? '—'} mono />
  <Row
    label={$LL.selfUpdateLatest()}
    sub={update?.error ? $LL.selfUpdateCheckFailed({ error: update.error }) : undefined}
  >
    <div class="flex items-center gap-[7px]">
      {#if update?.outdated && update.latest}
        <Badge tone="warning">{$LL.selfUpdateAvailable({ version: update.latest })}</Badge>
      {:else if update?.latest}
        <Badge tone="success">{$LL.selfUpdateUpToDate()}</Badge>
      {/if}
      <Button size="sm" variant="ghost" icon="refresh" disabled={checking || following} onclick={() => void load(true)}>
        {$LL.selfUpdateCheck()}
      </Button>
    </div>
  </Row>
  {#if following || run}
    <div class="space-y-[7px] py-[9px]">
      <p class="text-[13px]">
        {#if gaveUp}
          <span class="text-(--color-danger)">{$LL.selfUpdateNoAnswer()}</span>
        {:else if following}
          {away ? $LL.selfUpdateRestarting() : $LL.selfUpdateRunning()}
        {:else if run?.state === 'done'}
          <span class="text-(--color-success)">{$LL.selfUpdateDone({ version: update?.version ?? '' })}</span>
        {:else}
          <span class="text-(--color-danger)">{$LL.selfUpdateFailed()}</span>
        {/if}
      </p>
      {#if run?.lines.length}
        <pre class="max-h-[220px] overflow-auto rounded-[9px] bg-(--surface-control) p-[9px] text-[12px] select-text">{run.lines.join('\n')}</pre>
      {/if}
    </div>
  {/if}
  {#if update?.outdated && !following}
    {#if update.install === 'script'}
      {#if mayAct}
        {#if update.needs_password}
          <Row label={$LL.selfUpdateSudoPassword()} sub={$LL.selfUpdateSudoHint()}>
            <Input class="w-[200px]" type="password" autocomplete="off" bind:value={password} />
          </Row>
        {/if}
        <Row label={$LL.selfUpdateRun()} sub={$LL.selfUpdateRunHint()}>
          <Button
            size="sm"
            variant="primary"
            icon="system_update"
            disabled={starting || (update.needs_password && !password)}
            onclick={() => void start()}
          >
            {$LL.selfUpdateRun()}
          </Button>
        </Row>
      {:else if update.command}
        <p class="pt-[9px] text-[13px] text-(--text-secondary)">{$LL.selfUpdateNoTerminal()}</p>
        <pre class="my-[7px] overflow-x-auto rounded-[9px] bg-(--surface-control) p-[9px] text-[12px] select-all">{update.command}</pre>
      {/if}
    {:else}
      <p class="py-[9px] text-[13px] text-(--text-secondary)">
        {update.install === 'container'
          ? $LL.selfUpdateContainer()
          : update.install === 'nix'
            ? $LL.selfUpdateNix()
            : $LL.selfUpdateOther()}
      </p>
    {/if}
  {/if}
  {#if error}
    <p class="pb-[9px] text-[13px] text-(--color-danger)">{error}</p>
  {/if}
</Group>
