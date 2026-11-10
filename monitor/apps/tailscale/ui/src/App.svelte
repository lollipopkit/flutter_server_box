<script lang="ts">
  /// Tailscale on this machine: installed and running or not, signed in
  /// (with an auth key, or by opening the URL a sign-in waits on; a control
  /// server of one's own, Headscale, too), then a page each, chosen in the
  /// window's sidebar: this device, its peers (reached directly or through a
  /// relay, ping), the exit node, and the network settings (routes, DNS,
  /// SSH). Changes are jobs run as root after the desk's sudo dialog; the
  /// auth key goes to the backend once.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import Input from '$lk/Input.svelte'
  import Row from '$lk/Row.svelte'
  import Select from '$lk/Select.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import Switch from '$lk/Switch.svelte'
  import { DeskError, formatBytes, translator, type SudoAsk } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { Pages } from '$common/pages.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'
  import { type Draft, type Peer, type Status, changes, draftOf } from './model'

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let view = $state<Status | null>(null)
  let error = $state('')
  let loginServer = $state('')
  let hostname = $state('')
  let authKey = $state('')
  let draft = $state<Draft | null>(null)
  let saved = $state<Draft | null>(null)
  let pings = $state<Record<string, string>>({})
  const job = new JobRun()

  const pages = new Pages(['device', 'peers', 'exit', 'network'] as const, 'device')
  const page = $derived(pages.current)

  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const own: Record<string, string> = {
      notInstallable: 'notInstallable',
      daemonStopped: 'daemonStopped',
      lanCut: 'lanCut',
      exitNodeConflict: 'exitNodeConflict',
      notExitNode: 'notExitNode',
      invalidRoute: 'invalidRoute',
      invalidHostname: 'invalidHostname',
      invalidServer: 'invalidServer',
      invalidAuthKey: 'invalidAuthKey',
    }
    return own[e.detail ?? ''] ? t(own[e.detail!]) : e.detail || e.message
  }

  async function load() {
    try {
      const v = await desk.call<Status>('view')
      view = v
      if (v.prefs) {
        const d = draftOf(v, v.prefs)
        if (!draft || JSON.stringify(draft) === JSON.stringify(saved)) draft = { ...d }
        saved = d
      }
      error = ''
    } catch (e) {
      error = said(e)
    }
  }

  // A sign-in waiting on its URL: read again until it is opened.
  $effect(() => {
    if (!job.running || view?.state === 'Running') return
    const timer = setInterval(() => void load(), 2000)
    return () => clearInterval(timer)
  })

  const signedIn = $derived(!!view?.state && !['NeedsLogin', 'NoState'].includes(view.state))
  const exitNodes = $derived(view?.peers.filter((p) => p.exitNodeOption) ?? [])
  const changed = $derived(draft && saved ? changes(saved, draft) : {})
  const anyChange = $derived(Object.keys(changed).length > 0)

  async function run(fn: string, args: Record<string, unknown>, sudo: SudoAsk) {
    const done = await job.start(fn, args, sudo, said)
    if (fn === 'set' && job.status === 'succeeded') draft = null
    void done
    void load()
  }

  function signIn() {
    const key = authKey.trim()
    authKey = ''
    void run(
      'login',
      { loginServer: loginServer.trim() || null, hostname: hostname.trim() || null, authKey: key || null },
      { title: t('loginTitle'), body: key ? t('loginKeyBody') : t('loginUrlBody') },
    )
  }

  async function ping(p: Peer) {
    const ip = p.ips.find((i) => !i.includes(':')) ?? p.ips[0]
    if (!ip) return
    pings = { ...pings, [p.id]: '…' }
    try {
      const r = await desk.call<{ ok: boolean; output: string }>('ping', { ip })
      pings = { ...pings, [p.id]: r.output.split('\n').filter(Boolean).at(-1) ?? '' }
    } catch (e) {
      pings = { ...pings, [p.id]: said(e) }
    }
  }

  const stateTone = (s: string | null) => (s === 'Running' ? 'success' : s === 'Stopped' ? 'warning' : 'neutral')

  $effect(() => {
    const titles = { device: t('thisDevice'), peers: t('peers'), exit: t('exitNode'), network: t('network') }
    void desk.toolbar({ title: paged ? titles[page] : undefined, actions: [{ id: 'refresh', label: t('refresh'), icon: 'refresh' }] })
  })

  // The pages exist once there is a tailnet to show; before that the window
  // is the one step it waits on.
  const paged = $derived(!!view?.version && !!view.daemon && signedIn)
  $effect(() => {
    pages.draw(
      paged
        ? [
            {
              items: [
                { id: 'device', label: t('thisDevice'), icon: 'computer' },
                { id: 'peers', label: t('peers'), icon: 'lan', trailing: String(view?.peers.length ?? 0) },
                { id: 'exit', label: t('exitNode'), icon: 'output' },
                { id: 'network', label: t('network'), icon: 'tune' },
              ],
            },
          ]
        : [],
    )
  })

  const saveSettings = () =>
    void run('set', { settings: changed, lanCutOk: false }, { title: t('saveTitle'), body: draft?.exitNode ? t('saveExitBody') : t('saveBody') })
  desk.on('action', ({ id }) => id === 'refresh' && void load())

  void job.resume(said).then(() => load())
  void load()
</script>

{#snippet toggle(key: 'exitNodeAllowLan' | 'acceptRoutes' | 'acceptDns' | 'ssh' | 'shieldsUp' | 'advertiseExitNode', label: string)}
  {#if draft}
    <div class="trail">
      <Switch {label} bind:checked={draft[key]} />
      <span>{label}</span>
    </div>
  {/if}
{/snippet}

<!-- One Save for the settings of both pages: a change on one is kept while
     the other is shown. -->
{#snippet save()}
  <div class="trail">
    <Button variant="primary" disabled={job.running || !anyChange} onclick={saveSettings}>{t('save')}</Button>
  </div>
{/snippet}

<main class="page">
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog
      {t}
      status={job.status}
      title={job.running ? t('working') : job.status === 'succeeded' ? t('done') : t('failed')}
      lines={job.lines}
      oncancel={view?.authUrl ? () => job.cancel() : undefined}
    />
  {/if}

  {#if !view}
    {#if !error}<div class="center"><Spinner /></div>{/if}
  {:else if !view.version}
    <Card>
      <div class="intro">
        <p>{view.installable ? t('notInstalled') : t('notInstallable')}</p>
        {#if view.installable}<Button variant="primary" icon="download" disabled={job.running} onclick={() => void run('install', {}, { title: t('installTitle'), body: t('installBody') })}>{t('install')}</Button>{/if}
      </div>
    </Card>
  {:else if !view.daemon}
    <Card>
      <div class="intro">
        <p>{t('daemonStopped')}</p>
        <Button variant="primary" disabled={job.running} onclick={() => void run('startDaemon', {}, { title: t('startTitle'), body: t('startBody') })}>{t('start')}</Button>
      </div>
    </Card>
  {:else if !signedIn}
    {#if view.authUrl}
      <Card>
        <div class="intro">
          <p>{t('openToSignIn')}</p>
          <a
            class="lk-mono link"
            href={view.authUrl}
            onclick={(e) => {
              e.preventDefault()
              void desk.openUrl(view!.authUrl!)
            }}>{view.authUrl}</a
          >
        </div>
      </Card>
    {/if}
    <Group title={t('signIn')}>
      <div class="intro pad">
        <Input label={t('server')} mono placeholder="https://controlplane.tailscale.com" bind:value={loginServer} hint={t('serverHint')} />
        <Input label={t('hostname')} mono placeholder={view.name ?? ''} bind:value={hostname} />
        <Input label={t('authKey')} type="password" autocomplete="off" mono bind:value={authKey} hint={t('authKeyHint')} />
        <Button variant="primary" disabled={job.running} onclick={signIn}>{t('signIn')}</Button>
      </div>
    </Group>
  {:else if page === 'device'}
    <Group>
      <Row label={view.name ?? '—'} sub={view.dnsName ?? undefined}>
        <span class="trail">
          <Badge tone={stateTone(view.state)}>{view.state === 'Running' ? t('connected') : view.state === 'Stopped' ? t('disconnected') : view.state}</Badge>
          {#if view.state === 'Running'}
            <Button size="sm" variant="secondary" disabled={job.running} onclick={() => void run('disconnect', {}, { title: t('disconnectTitle'), body: t('disconnectBody') })}>{t('disconnect')}</Button>
          {:else}
            <Button size="sm" variant="primary" disabled={job.running} onclick={() => void run('connect', {}, { title: t('connectTitle'), body: t('connectBody') })}>{t('connect')}</Button>
          {/if}
        </span>
      </Row>
      {#if view.ips.length}<Row label={t('addresses')} value={view.ips.join(', ')} mono />{/if}
      {#if view.tailnet}<Row label={t('tailnet')} value={view.tailnet} />{/if}
      {#if view.user}<Row label={t('user')} value={view.user} />{/if}
      {#if view.prefs?.controlUrl}<Row label={t('server')} value={view.prefs.controlUrl} mono />{/if}
      <Row label="Tailscale" value={view.version} mono>
        <Button size="sm" variant="ghost" disabled={job.running} onclick={() => void run('logout', {}, { title: t('logoutTitle'), body: t('logoutBody') })}>{t('logout')}</Button>
      </Row>
    </Group>
    {#if view.health.length}
      <Card>
        {#each view.health as h (h)}<p class="note"><Icon name="warning" size={15} /><span>{h}</span></p>{/each}
      </Card>
    {/if}
  {:else if page === 'peers'}
    <Group>
      {#each view.peers as p (p.id)}
        <Row label={p.name} sub={[p.ips.join(', '), p.os, p.direct ? t('direct', { addr: p.direct }) : p.relay ? t('relay', { relay: p.relay }) : '', pings[p.id]].filter(Boolean).join(' · ')}>
          <span class="trail wrap">
            {#if p.exitNode}<Badge tone="accent">{t('exitNodeInUse')}</Badge>{:else if p.exitNodeOption}<Badge>{t('offersExitNode')}</Badge>{/if}
            {#if p.routes.length}<Badge>{p.routes.join(', ')}</Badge>{/if}
            <span class="lk-num hint">↓{formatBytes(p.rxBytes)} ↑{formatBytes(p.txBytes)}</span>
            <Badge tone={p.online ? 'success' : 'neutral'}>{p.online ? t('online') : t('offline')}</Badge>
            {#if p.online}<Button size="sm" variant="ghost" onclick={() => void ping(p)}>Ping</Button>{/if}
          </span>
        </Row>
      {:else}
        <p class="pad hint">{t('noPeers')}</p>
      {/each}
    </Group>
  {:else if draft && page === 'exit'}
    <Group>
      <div class="intro pad">
        <Select
          label={t('exitNode')}
          options={[{ value: '', label: t('noExitNode') }, ...exitNodes.map((p) => ({ value: p.id, label: `${p.name} · ${p.ips[0] ?? ''}` }))]}
          bind:value={draft.exitNode}
        />
        {@render toggle('exitNodeAllowLan', t('allowLan'))}
        {#if draft.exitNode && !draft.exitNodeAllowLan}<p class="danger">{t('lanCut')}</p>{/if}
      </div>
    </Group>
    <Group>
      <div class="intro pad">
        {@render toggle('advertiseExitNode', t('advertiseExitNode'))}
      </div>
    </Group>
    {@render save()}
  {:else if draft && page === 'network'}
    <Group>
      <div class="intro pad">
        {@render toggle('acceptRoutes', t('acceptRoutes'))}
        {@render toggle('acceptDns', t('acceptDns'))}
        {@render toggle('ssh', t('ssh'))}
        {@render toggle('shieldsUp', t('shieldsUp'))}
      </div>
    </Group>
    <Group>
      <div class="intro pad">
        <Input label={t('hostname')} mono bind:value={draft.hostname} />
        <Input label={t('routes')} mono placeholder="192.168.1.0/24" bind:value={draft.advertiseRoutes} hint={t('routesHint')} />
      </div>
    </Group>
    {@render save()}
  {/if}
</main>
