<script lang="ts">
  /// Tailscale on this machine (`/tailscale`): installed and running or not,
  /// signed in (with an auth key, or by opening the URL a sign-in waits on;
  /// a control server of one's own, Headscale, too), this device, its peers
  /// (reached directly or through a relay, ping), and its settings: exit
  /// node, routes, DNS, SSH. Changes are jobs run as root after sudo's
  /// password (`SudoConfirm`); the auth key goes to the agent once.

  import { AppToolbar } from '../../sys'
  import { Badge, Button, Card, Group, Icon, IconButton, Input, Row, Select, Spinner, Switch } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { errorText } from '../../../lib/errorText'
  import { fmtBytes } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { StackJob, TailscaleAction, TailscalePeer, TailscaleView } from '../../../types'
  import { type Draft, changes, draftOf } from './model'

  let view = $state<TailscaleView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  let pending = $state<{ title: string; body: string; action: TailscaleAction } | null>(null)
  let loginServer = $state('')
  let hostname = $state('')
  let authKey = $state('')
  let draft = $state<Draft | null>(null)
  let saved = $state<Draft | null>(null)
  let pings = $state<Record<string, string>>({})
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const v = await api.getTailscale()
      if (stale(serverId)) return
      view = v
      if (v.job?.state === 'running') job = v.job
      if (v.prefs) {
        const d = draftOf(v, v.prefs)
        if (!draft || JSON.stringify(draft) === JSON.stringify(saved)) draft = { ...d }
        saved = d
      }
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  // A sign-in waiting on its URL: read again until it is opened.
  $effect(() => {
    if (!running || view?.state === 'Running') return
    const t = setInterval(() => void load(), 2000)
    return () => clearInterval(t)
  })

  const signedIn = $derived(!!view?.state && !['NeedsLogin', 'NoState'].includes(view.state))
  const exitNodes = $derived(view?.peers.filter((p) => p.exitNodeOption) ?? [])
  const changed = $derived(draft && saved ? changes(saved, draft) : {})
  const anyChange = $derived(Object.keys(changed).length > 0)

  function refusal(body: Record<string, unknown> & { error?: string }): string | undefined {
    const map: Record<string, () => string> = {
      notInstallable: $LL.tailscaleNotInstallable,
      daemonStopped: $LL.tailscaleDaemonStopped,
      lanCut: $LL.tailscaleLanCut,
      exitNodeConflict: $LL.tailscaleExitNodeConflict,
      notExitNode: $LL.tailscaleNotExitNode,
      invalidRoute: $LL.tailscaleInvalidRoute,
      invalidHostname: $LL.tailscaleInvalidHostname,
      invalidServer: $LL.tailscaleInvalidServer,
      invalidAuthKey: $LL.tailscaleInvalidAuthKey,
    }
    return body.error ? map[body.error]?.() : undefined
  }

  function ask(action: TailscaleAction) {
    const words: Record<TailscaleAction['action'], [string, string]> = {
      install: [$LL.tailscaleInstallTitle(), $LL.tailscaleInstallBody()],
      startDaemon: [$LL.tailscaleStartTitle(), $LL.tailscaleStartBody()],
      login: [$LL.tailscaleLoginTitle(), authKey.trim() ? $LL.tailscaleLoginKeyBody() : $LL.tailscaleLoginUrlBody()],
      logout: [$LL.tailscaleLogoutTitle(), $LL.tailscaleLogoutBody()],
      connect: [$LL.tailscaleConnectTitle(), $LL.tailscaleConnectBody()],
      disconnect: [$LL.tailscaleDisconnectTitle(), $LL.tailscaleDisconnectBody()],
      set: [$LL.tailscaleSaveTitle(), draft?.exitNode ? $LL.tailscaleSaveExitBody() : $LL.tailscaleSaveBody()],
    }
    const [title, body] = words[action.action]
    pending = { title, body, action }
  }

  async function ping(p: TailscalePeer) {
    const ip = p.ips.find((i) => !i.includes(':')) ?? p.ips[0]
    if (!ip) return
    pings = { ...pings, [p.id]: '…' }
    try {
      const r = await api.tailscalePing(ip)
      pings = { ...pings, [p.id]: r.output.split('\n').filter(Boolean).at(-1) ?? '' }
    } catch (e) {
      pings = { ...pings, [p.id]: errorText(e) }
    }
  }

  const stateTone = (s: string | null) => (s === 'Running' ? 'success' : s === 'Stopped' ? 'warning' : 'neutral')
</script>

<AppToolbar>
  {#snippet actions()}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<main class="pane-form space-y-[13px] pb-[21px] pt-[5px]">
  {#if error}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{error}</p></Card>
  {/if}
  {#if job}
    {#key job.id}
      <StackProgress
        {job}
        title={job.state === 'running' ? $LL.tailscaleWorking() : job.state === 'succeeded' ? $LL.tailscaleDone() : $LL.tailscaleFailed()}
        read={(since) => api.tailscaleJob(since)}
        stop={view?.authUrl ? () => api.tailscaleCancel() : null}
        ondone={(done) => {
          // Kept on screen: a failure says why.
          job = done
          void load()
        }}
      />
    {/key}
  {/if}

  {#if !view}
    {#if !error}<div class="grid place-items-center py-[55px]"><Spinner /></div>{/if}
  {:else if !view.version}
    <Card class="space-y-[11px] text-[13px]">
      <p class="text-(--text-secondary)">{view.installable ? $LL.tailscaleNotInstalled() : $LL.tailscaleNotInstallable()}</p>
      {#if view.installable}<Button variant="primary" icon="download" disabled={running} onclick={() => ask({ action: 'install' })}>{$LL.tailscaleInstall()}</Button>{/if}
    </Card>
  {:else if !view.daemon}
    <Card class="space-y-[11px] text-[13px]">
      <p class="text-(--text-secondary)">{$LL.tailscaleDaemonStopped()}</p>
      <Button variant="primary" disabled={running} onclick={() => ask({ action: 'startDaemon' })}>{$LL.tailscaleStart()}</Button>
    </Card>
  {:else if !signedIn}
    {#if view.authUrl}
      <Card class="space-y-[9px] text-[13px]">
        <p>{$LL.tailscaleOpenToSignIn()}</p>
        <a class="lk-mono break-all text-(--color-accent) underline" href={view.authUrl} target="_blank" rel="noreferrer noopener">{view.authUrl}</a>
      </Card>
    {/if}
    <Group title={$LL.tailscaleSignIn()}>
      <div class="space-y-[11px] px-[13px] py-[11px]">
        <Input label={$LL.tailscaleServer()} mono placeholder="https://controlplane.tailscale.com" bind:value={loginServer} hint={$LL.tailscaleServerHint()} />
        <Input label={$LL.tailscaleHostname()} mono placeholder={view.name ?? ''} bind:value={hostname} />
        <Input label={$LL.tailscaleAuthKey()} type="password" autocomplete="off" mono bind:value={authKey} hint={$LL.tailscaleAuthKeyHint()} />
        <Button
          variant="primary"
          disabled={running}
          onclick={() => ask({ action: 'login', loginServer: loginServer.trim() || undefined, hostname: hostname.trim() || undefined })}
        >{$LL.tailscaleSignIn()}</Button>
      </div>
    </Group>
  {:else}
    <Group>
      <Row label={view.name ?? '—'} sub={view.dnsName ?? undefined}>
        <Badge tone={stateTone(view.state)}>{view.state === 'Running' ? $LL.tailscaleConnected() : view.state === 'Stopped' ? $LL.tailscaleDisconnected() : view.state}</Badge>
        {#if view.state === 'Running'}
          <Button size="sm" variant="secondary" disabled={running} onclick={() => ask({ action: 'disconnect' })}>{$LL.tailscaleDisconnect()}</Button>
        {:else}
          <Button size="sm" variant="primary" disabled={running} onclick={() => ask({ action: 'connect' })}>{$LL.tailscaleConnect()}</Button>
        {/if}
      </Row>
      {#if view.ips.length}<Row label={$LL.tailscaleAddresses()} value={view.ips.join(', ')} mono />{/if}
      {#if view.tailnet}<Row label={$LL.tailscaleTailnet()} value={view.tailnet} />{/if}
      {#if view.user}<Row label={$LL.tailscaleUser()} value={view.user} />{/if}
      {#if view.prefs?.controlUrl}<Row label={$LL.tailscaleServer()} value={view.prefs.controlUrl} mono />{/if}
      <Row label="Tailscale" value={view.version} mono>
        <Button size="sm" variant="ghost" disabled={running} onclick={() => ask({ action: 'logout' })}>{$LL.tailscaleLogout()}</Button>
      </Row>
    </Group>
    {#if view.health.length}
      <Card class="space-y-[5px] text-[12px] text-(--text-secondary)">
        {#each view.health as h (h)}<p class="flex items-start gap-[7px]"><Icon name="warning" size={15} />{h}</p>{/each}
      </Card>
    {/if}

    {#if draft}
      <Group title={$LL.tailscaleSettings()}>
        <div class="space-y-[11px] px-[13px] py-[11px]">
          <Select
            label={$LL.tailscaleExitNode()}
            options={[{ value: '', label: $LL.tailscaleNoExitNode() }, ...exitNodes.map((p) => ({ value: p.id, label: `${p.name} · ${p.ips[0] ?? ''}` }))]}
            bind:value={draft.exitNode}
          />
          {#each [
            ['exitNodeAllowLan', $LL.tailscaleAllowLan()],
            ['acceptRoutes', $LL.tailscaleAcceptRoutes()],
            ['acceptDns', $LL.tailscaleAcceptDns()],
            ['ssh', $LL.tailscaleSsh()],
            ['shieldsUp', $LL.tailscaleShieldsUp()],
            ['advertiseExitNode', $LL.tailscaleAdvertiseExitNode()],
          ] as [key, label] (key)}
            <div class="flex items-center gap-[9px] text-[13px]">
              <Switch {label} bind:checked={draft[key as 'ssh']} />
              <span>{label}</span>
            </div>
          {/each}
          <Input label={$LL.tailscaleHostname()} mono bind:value={draft.hostname} />
          <Input label={$LL.tailscaleRoutes()} mono placeholder="192.168.1.0/24" bind:value={draft.advertiseRoutes} hint={$LL.tailscaleRoutesHint()} />
          {#if draft.exitNode && !draft.exitNodeAllowLan}<p class="text-[12px] text-(--color-danger)">{$LL.tailscaleLanCut()}</p>{/if}
          <Button variant="primary" disabled={running || !anyChange} onclick={() => ask({ action: 'set', settings: changed })}>{$LL.tailscaleSave()}</Button>
        </div>
      </Group>
    {/if}

    <Group title={$LL.tailscalePeers()}>
      {#each view.peers as p (p.id)}
        <Row label={p.name} sub={[p.ips.join(', '), p.os, p.direct ? $LL.tailscaleDirect({ addr: p.direct }) : p.relay ? $LL.tailscaleRelay({ relay: p.relay }) : '', pings[p.id]].filter(Boolean).join(' · ')}>
          {#if p.exitNode}<Badge tone="accent">{$LL.tailscaleExitNodeInUse()}</Badge>{:else if p.exitNodeOption}<Badge>{$LL.tailscaleOffersExitNode()}</Badge>{/if}
          {#if p.routes.length}<Badge>{p.routes.join(', ')}</Badge>{/if}
          <span class="lk-num text-[12px] text-(--text-tertiary)">↓{fmtBytes(p.rxBytes)} ↑{fmtBytes(p.txBytes)}</span>
          <Badge tone={p.online ? 'success' : 'neutral'}>{p.online ? $LL.tailscaleOnline() : $LL.tailscaleOffline()}</Badge>
          {#if p.online}<Button size="sm" variant="ghost" onclick={() => void ping(p)}>Ping</Button>{/if}
        </Row>
      {:else}
        <p class="px-[13px] py-[11px] text-[13px] text-(--text-tertiary)">{$LL.tailscaleNoPeers()}</p>
      {/each}
    </Group>
  {/if}
</main>

<SudoConfirm
  open={pending !== null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  run={async (sudo) => {
    const action = pending!.action
    job = await api.tailscaleAct(action, sudo, action.action === 'login' ? authKey.trim() : undefined)
    if (action.action === 'login') authKey = ''
    if (action.action === 'set') draft = null
  }}
  {refusal}
  onclose={() => {
    pending = null
    void load()
  }}
/>
