<script lang="ts">
  /// The machine's reverse proxies: nginx, Caddy and Traefik, each installed
  /// or not, and its sites. ServerBox's sites of a server are changed here,
  /// the whole list at once, as root after the desk's sudo dialog; sites
  /// written elsewhere are shown. A deployed web app's port is offered as the
  /// address to send to. nginx's and Traefik's sites can sit behind the
  /// firewall (`WafPanel`).

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Dialog from '$lk/Dialog.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import IconButton from '$lk/IconButton.svelte'
  import Input from '$lk/Input.svelte'
  import Row from '$lk/Row.svelte'
  import SegmentedControl from '$lk/SegmentedControl.svelte'
  import Select from '$lk/Select.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import Switch from '$lk/Switch.svelte'
  import { DeskError, translator } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'
  import { type Firewall, type Proxies, type ServerId, type Site, nameFor, withSite, withoutSite } from './model'
  import WafPanel from './WafPanel.svelte'

  const NAMES: Record<ServerId, string> = { nginx: 'nginx', caddy: 'Caddy', traefik: 'Traefik' }

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let view = $state<Proxies | null>(null)
  let waf = $state<Firewall | null>(null)
  let selected = $state<ServerId>('caddy')
  let error = $state('')
  let draft = $state<Site | null>(null)
  let replacing = $state<string | null>(null)
  let domainsText = $state('')
  let acmeEmail = $state('')
  let apps = $state<{ label: string; url: string }[]>([])
  const job = new JobRun()

  /// The backend's refusal in words. Its message is the code, and for some
  /// what goes with it on the next line (the server's words, the site).
  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const [code, rest] = (e.detail ?? '').split('\n', 2)
    if (code === 'refused') return t('refused', { detail: rest ?? '' })
    const own: Record<string, string> = {
      invalidName: 'invalidName',
      invalidDomain: 'invalidDomain',
      invalidUpstream: 'invalidUpstream',
      needsCertificate: 'needsCertificate',
      needsResolver: 'needsResolver',
      duplicate: 'duplicate',
      wafNotSet: 'wafNotSet',
      notWritable: 'notWritable',
    }
    if (own[code]) return code === 'wafNotSet' ? t('wafNotSet') : t(own[code])
    return e.detail || e.message
  }

  async function load() {
    try {
      const [v, w] = await Promise.all([desk.call<Proxies>('view'), desk.call<Firewall>('waf').catch(() => null)])
      view = v
      waf = w
      error = ''
    } catch (e) {
      error = said(e)
    }
  }

  async function loadApps() {
    try {
      const list = await desk.call<{ title: [string, string][]; url: string }[]>('webApps')
      apps = list.map((a) => {
        const titles = Object.fromEntries(a.title)
        return { label: titles[locale] ?? titles[locale.split('-')[0]] ?? titles.en ?? a.url, url: a.url }
      })
    } catch {
      // No web apps to offer: an address is typed instead.
    }
  }

  const current = $derived(view?.servers.find((s) => s.server === selected))
  const own = $derived(current?.sites.filter((s) => s.managed) ?? [])
  const others = $derived(current?.sites.filter((s) => !s.managed) ?? [])

  async function save(sites: Site[], title: string, body: string) {
    try {
      view = await desk.call<Proxies>('setSites', { server: selected, sites }, { sudo: { title, body } })
      draft = null
      error = ''
    } catch (e) {
      if (e instanceof DeskError && e.message === 'declined') return
      error = said(e)
    }
  }

  function edit(site: Site | null) {
    replacing = site?.name ?? null
    draft = site
      ? { ...site }
      : { name: '', domains: [], upstream: apps[0]?.url ?? 'http://127.0.0.1:', tls: selected === 'caddy', cert: null, key: null, maxBodyMb: null, waf: false, managed: true }
    domainsText = site?.domains.join(', ') ?? ''
  }

  function submit() {
    if (!draft) return
    const domains = domainsText.split(/[\s,]+/).map((d) => d.trim().toLowerCase()).filter(Boolean)
    const site: Site = { ...draft, domains, name: draft.name || nameFor(domains[0] ?? ''), managed: true }
    void save(withSite(current?.sites ?? [], site, replacing), t('saveTitle', { server: NAMES[selected] }), t('saveBody', { domains: domains.join(', '), upstream: site.upstream }))
  }

  async function install() {
    await job.start('install', { server: selected, acmeEmail: acmeEmail.trim() || null }, { title: t('installTitle', { server: NAMES[selected] }), body: t('installBody', { server: NAMES[selected] }) }, said)
    void load()
  }

  async function installWaf() {
    await job.start('installWaf', { server: selected }, { title: t('wafInstallTitle'), body: selected === 'nginx' ? t('wafInstallNginx') : t('wafInstallTraefik') }, said)
    void load()
  }

  $effect(() => {
    void desk.toolbar({
      title: NAMES[selected],
      actions: [
        ...(current?.installed && current.writable ? [{ id: 'add', label: t('addSite'), icon: 'add' }] : []),
        { id: 'refresh', label: t('refresh'), icon: 'refresh' },
      ],
    })
  })
  desk.on('action', ({ id }) => (id === 'add' ? edit(null) : id === 'refresh' ? void load() : undefined))

  void job.resume(said).then(() => load())
  void load()
  void loadApps()
</script>

<main class="page">
  {#if view}
    <SegmentedControl
      label={t('title')}
      options={view.servers.map((s) => ({ value: s.server, label: NAMES[s.server] }))}
      value={selected}
      onchange={(v) => (selected = v as ServerId)}
    />
  {/if}
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog {t} status={job.status} title={job.running ? t('installing') : job.status === 'succeeded' ? t('done') : t('failed')} lines={job.lines} oncancel={() => job.cancel()} />
  {/if}

  {#if !view}
    {#if !error}<div class="center"><Spinner /></div>{/if}
  {:else if current}
    <Group>
      <Row label={NAMES[current.server]} sub={current.version ?? undefined}>
        <Badge tone={current.active ? 'success' : current.installed ? 'warning' : 'neutral'}>
          {current.active ? t('running') : current.installed ? t('stopped') : t('notInstalled')}
        </Badge>
      </Row>
      {#if view.listening.length}
        <Row label={t('portsInUse')} value={view.listening.join(', ')} />
      {/if}
    </Group>
    {#if !current.installed}
      <Card>
        <div class="intro">
          <p>{t('installNote', { server: NAMES[current.server] })}</p>
          {#if current.server === 'traefik'}
            <Input label={t('acmeEmail')} placeholder="ops@example.com" bind:value={acmeEmail} hint={t('acmeHint')} />
          {/if}
          <Button variant="primary" icon="download" disabled={job.running} onclick={() => void install()}>{t('install')}</Button>
        </div>
      </Card>
    {:else if !current.writable}
      <Card><p class="note"><Icon name="info" size={17} /><span>{t('notWritable')}</span></p></Card>
    {/if}

    {#if current.installed}
      <Group title={t('ownSites')}>
        {#each own as s (s.name)}
          <Row label={s.domains.join(', ')} mono sub={`→ ${s.upstream}`}>
            <span class="trail">
              {#if s.tls}<Badge tone="success">HTTPS</Badge>{/if}
              {#if s.waf}<Badge tone="success">WAF</Badge>{/if}
              <IconButton icon="edit" label={t('edit')} onclick={() => edit(s)} />
              <IconButton
                icon="delete"
                label={t('remove')}
                onclick={() => void save(withoutSite(current.sites, s.name), t('removeTitle', { domains: s.domains.join(', ') }), t('removeBody'))}
              />
            </span>
          </Row>
        {:else}
          <p class="pad hint">{t('noOwnSites')}</p>
        {/each}
      </Group>
      {#if waf && current.server !== 'caddy'}
        <WafPanel
          {t}
          server={current.server}
          waf={current.server === 'nginx' ? waf.nginx : waf.traefik}
          crs={waf.crs}
          busy={job.running}
          install={() => void installWaf()}
          {said}
          onchanged={() => void load()}
        />
      {/if}
      {#if others.length}
        <Group title={t('otherSites')}>
          {#each others as s (s.name + s.domains.join())}
            <Row label={s.domains.join(', ')} mono sub={s.upstream ? `→ ${s.upstream}` : undefined}>
              {#if s.tls}<Badge>HTTPS</Badge>{/if}
            </Row>
          {/each}
        </Group>
      {/if}
    {/if}
  {/if}
</main>

{#if draft}
  <Dialog open title={replacing ? t('edit') : t('addSite')} onclose={() => (draft = null)}>
    <div class="intro">
      <Input label={t('domains')} mono placeholder="app.example.com" bind:value={domainsText} hint={t('domainsHint')} />
      {#if apps.length}
        <Select
          label={t('deployedApp')}
          options={[{ value: '', label: t('typeAddress') }, ...apps.map((a) => ({ value: a.url, label: `${a.label} · ${a.url}` }))]}
          value={apps.some((a) => a.url === draft?.upstream) ? draft.upstream : ''}
          onchange={(e: Event) => {
            const v = (e.currentTarget as HTMLSelectElement).value
            if (v && draft) draft.upstream = v
          }}
        />
      {/if}
      <Input label={t('upstream')} mono placeholder="http://127.0.0.1:8080" bind:value={draft.upstream} />
      <div class="trail">
        <Switch label="HTTPS" bind:checked={draft.tls} />
        <span>HTTPS</span>
      </div>
      {#if selected !== 'caddy'}
        <div class="trail">
          <Switch label={t('wafSiteToggle')} checked={draft.waf} onchange={(on) => draft && (draft.waf = on)} />
          <span>{t('wafSiteToggle')}</span>
        </div>
      {/if}
      {#if draft.tls && selected === 'nginx'}
        <Input label={t('cert')} mono placeholder="/etc/ssl/certs/app.pem" value={draft.cert ?? ''} oninput={(e: Event) => draft && (draft.cert = (e.currentTarget as HTMLInputElement).value || null)} />
        <Input label={t('key')} mono placeholder="/etc/ssl/private/app.key" value={draft.key ?? ''} oninput={(e: Event) => draft && (draft.key = (e.currentTarget as HTMLInputElement).value || null)} />
      {:else if draft.tls && selected === 'caddy'}
        <p class="hint">{t('caddyTls')}</p>
      {:else if draft.tls && selected === 'traefik' && !current?.tlsResolver}
        <p class="danger">{t('needsResolver')}</p>
      {/if}
    </div>
    {#snippet actions()}
      <Button variant="primary" block disabled={!domainsText.trim() || !draft?.upstream.trim()} onclick={submit}>{t('save')}</Button>
      <Button variant="secondary" block onclick={() => (draft = null)}>{t('cancel')}</Button>
    {/snippet}
  </Dialog>
{/if}
