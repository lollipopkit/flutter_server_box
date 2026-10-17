<script lang="ts">
  /// The machine's reverse proxies (`/proxy`): nginx, Caddy and Traefik,
  /// each installed or not, and its sites. ServerBox's sites of a server are
  /// changed here, the whole list at once, with sudo's password
  /// (`SudoConfirm`); sites written elsewhere are shown. A deployed web app's
  /// port is offered as the address to send to.

  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Dialog, Group, Icon, IconButton, Input, Row, Select, SidebarItem, SidebarSection, Spinner, Switch } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { errorText } from '../../../lib/errorText'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import { pick } from '../../../components/stack/text'
  import type { ProxyServerId, ProxySite, ProxyView, StackJob, WafView } from '../../../types'
  import { nameFor, withSite, withoutSite } from './model'
  import WafPanel from './WafPanel.svelte'

  const NAMES: Record<ProxyServerId, string> = { nginx: 'nginx', caddy: 'Caddy', traefik: 'Traefik' }

  let view = $state<ProxyView | null>(null)
  let waf = $state<WafView | null>(null)
  let selected = $state<ProxyServerId>('caddy')
  let error = $state('')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  let pending = $state<{ title: string; body: string; run: (sudo: string) => Promise<void> } | null>(null)
  let draft = $state<ProxySite | null>(null)
  let replacing = $state<string | null>(null)
  let domainsText = $state('')
  let acmeEmail = $state('')
  /// Deployed web apps, as addresses to send to.
  let apps = $state<{ label: string; url: string }[]>([])
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const [v, w] = await Promise.all([api.getProxy(), api.getWaf().catch(() => null)])
      if (stale(serverId)) return
      view = v
      waf = w
      if (v.job?.state === 'running') job = v.job
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  async function loadApps(serverId = servers.currentId) {
    try {
      const { apps: list } = await api.listStacks()
      if (stale(serverId)) return
      apps = list
        .filter((a) => a.stack?.state === 'installed' && a.manifest.web)
        .flatMap((a) => {
          const port = a.stack?.settings?.[a.manifest.web!.port]
          return typeof port === 'number' ? [{ label: pick(a.manifest.title, $locale), url: `http://127.0.0.1:${port}` }] : []
        })
    } catch {
      // No web apps to offer: an address is typed instead.
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
    void loadApps()
  })

  const current = $derived(view?.servers.find((s) => s.server === selected))
  const own = $derived(current?.sites.filter((s) => s.managed) ?? [])
  const others = $derived(current?.sites.filter((s) => !s.managed) ?? [])

  function refusal(body: Record<string, unknown> & { error?: string }): string | undefined {
    const map: Record<string, () => string> = {
      refused: () => $LL.proxyRefused({ detail: String(body.detail ?? '') }),
      invalidName: $LL.proxyInvalidName,
      invalidDomain: $LL.proxyInvalidDomain,
      invalidUpstream: $LL.proxyInvalidUpstream,
      needsCertificate: $LL.proxyNeedsCertificate,
      needsResolver: $LL.proxyNeedsResolver,
      duplicate: $LL.proxyDuplicate,
      wafNotSet: $LL.wafNotSet,
      notWritable: $LL.proxyNotWritable,
    }
    return body.error ? map[body.error]?.() : undefined
  }

  function save(sites: ProxySite[], title: string, body: string) {
    pending = {
      title,
      body,
      run: async (sudo) => {
        const v = await api.setProxySites(selected, sites, sudo)
        view = { ...v, job: view?.job ?? null }
        draft = null
      },
    }
  }

  function edit(site: ProxySite | null) {
    replacing = site?.name ?? null
    draft = site ? { ...site } : { name: '', domains: [], upstream: apps[0]?.url ?? 'http://127.0.0.1:', tls: selected === 'caddy', managed: true }
    domainsText = site?.domains.join(', ') ?? ''
  }

  function submit() {
    if (!draft) return
    const domains = domainsText.split(/[\s,]+/).map((d) => d.trim().toLowerCase()).filter(Boolean)
    const site: ProxySite = { ...draft, domains, name: draft.name || nameFor(domains[0] ?? ''), managed: true }
    save(withSite(current?.sites ?? [], site, replacing), $LL.proxySaveTitle({ server: NAMES[selected] }), $LL.proxySaveBody({ domains: domains.join(', '), upstream: site.upstream }))
  }

  function install() {
    pending = {
      title: $LL.proxyInstallTitle({ server: NAMES[selected] }),
      body: $LL.proxyInstallBody({ server: NAMES[selected] }),
      run: async (sudo) => {
        job = await api.installProxy(selected, acmeEmail.trim(), sudo)
      },
    }
  }
</script>

<AppToolbar title={NAMES[selected]}>
  {#snippet actions()}
    {#if current?.installed && current.writable}
      <Button size="sm" icon="add" onclick={() => edit(null)}>{$LL.proxyAddSite()}</Button>
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      {#each view?.servers ?? [] as s (s.server)}
        <SidebarItem
          label={NAMES[s.server]}
          icon={s.active ? 'check_circle' : s.installed ? 'pause_circle' : 'radio_button_unchecked'}
          active={selected === s.server}
          trailing={s.sites.length || undefined}
          onclick={() => (selected = s.server)}
        />
      {/each}
    </SidebarSection>
  {/snippet}

  <div class="mx-auto max-w-[760px] space-y-[13px] px-(--content-pad) pb-[21px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{error}</p></Card>
    {/if}
    {#if job}
      {#key job.id}
        <StackProgress
          {job}
          title={job.state === 'running' ? $LL.proxyInstalling() : job.state === 'succeeded' ? $LL.proxyDone() : $LL.proxyFailed()}
          read={(since) => api.proxyJob(since)}
          stop={null}
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
    {:else if current}
      <Group>
        <Row label={NAMES[current.server]} sub={current.version ?? undefined}>
          <Badge tone={current.active ? 'success' : current.installed ? 'warning' : 'neutral'}>
            {current.active ? $LL.proxyRunning() : current.installed ? $LL.proxyStopped() : $LL.proxyNotInstalled()}
          </Badge>
        </Row>
        {#if view.listening.length}
          <Row label={$LL.proxyPortsInUse()} value={view.listening.join(', ')} />
        {/if}
      </Group>
      {#if !current.installed}
        <Card class="space-y-[11px] text-[13px]">
          <p class="text-(--text-secondary)">{$LL.proxyInstallNote({ server: NAMES[current.server] })}</p>
          {#if current.server === 'traefik'}
            <Input label={$LL.proxyAcmeEmail()} placeholder="ops@example.com" bind:value={acmeEmail} hint={$LL.proxyAcmeHint()} />
          {/if}
          <Button variant="primary" icon="download" disabled={running} onclick={install}>{$LL.proxyInstall()}</Button>
        </Card>
      {:else if !current.writable}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)"><Icon name="info" size={17} /><p>{$LL.proxyNotWritable()}</p></Card>
      {/if}

      {#if current.installed}
        <Group title={$LL.proxyOwnSites()}>
          {#each own as s (s.name)}
            <Row label={s.domains.join(', ')} mono sub={`→ ${s.upstream}`}>
              {#if s.tls}<Badge tone="success">HTTPS</Badge>{/if}
              {#if s.waf}<Badge tone="success">WAF</Badge>{/if}
              <IconButton icon="edit" label={$LL.proxyEdit()} onclick={() => edit(s)} />
              <IconButton
                icon="delete"
                label={$LL.proxyRemove()}
                onclick={() => save(withoutSite(current.sites, s.name), $LL.proxyRemoveTitle({ domains: s.domains.join(', ') }), $LL.proxyRemoveBody())}
              />
            </Row>
          {:else}
            <p class="px-[13px] py-[11px] text-[13px] text-(--text-tertiary)">{$LL.proxyNoOwnSites()}</p>
          {/each}
        </Group>
        {#if waf && current.server !== 'caddy'}
          <WafPanel
            server={current.server}
            waf={current.server === 'nginx' ? waf.nginx : waf.traefik}
            crs={waf.crs}
            onjob={(j) => (job = j)}
            onchanged={() => void load()}
          />
        {/if}
        {#if others.length}
          <Group title={$LL.proxyOtherSites()}>
            {#each others as s (s.name + s.domains.join())}
              <Row label={s.domains.join(', ')} mono sub={s.upstream ? `→ ${s.upstream}` : undefined}>
                {#if s.tls}<Badge>HTTPS</Badge>{/if}
              </Row>
            {/each}
          </Group>
        {/if}
      {/if}
    {/if}
  </div>
</SplitView>

{#if draft}
  <Dialog open title={replacing ? $LL.proxyEdit() : $LL.proxyAddSite()} onclose={() => (draft = null)}>
    <div class="flex flex-col gap-[11px]">
      <Input label={$LL.proxyDomains()} mono placeholder="app.example.com" bind:value={domainsText} hint={$LL.proxyDomainsHint()} />
      {#if apps.length}
        <Select
          label={$LL.proxyDeployedApp()}
          options={[{ value: '', label: $LL.proxyTypeAddress() }, ...apps.map((a) => ({ value: a.url, label: `${a.label} · ${a.url}` }))]}
          value={apps.some((a) => a.url === draft?.upstream) ? draft.upstream : ''}
          onchange={(e: Event) => {
            const v = (e.currentTarget as HTMLSelectElement).value
            if (v && draft) draft.upstream = v
          }}
        />
      {/if}
      <Input label={$LL.proxyUpstream()} mono placeholder="http://127.0.0.1:8080" bind:value={draft.upstream} />
      <div class="flex items-center gap-[9px] text-[13px]">
        <Switch label="HTTPS" bind:checked={draft.tls} />
        <span>HTTPS</span>
      </div>
      {#if selected !== 'caddy'}
        <div class="flex items-center gap-[9px] text-[13px]">
          <Switch label={$LL.wafSiteToggle()} checked={draft.waf ?? false} onchange={(on) => draft && (draft.waf = on)} />
          <span>{$LL.wafSiteToggle()}</span>
        </div>
      {/if}
      {#if draft.tls && selected === 'nginx'}
        <Input label={$LL.proxyCert()} mono placeholder="/etc/ssl/certs/app.pem" value={draft.cert ?? ''} oninput={(e: Event) => draft && (draft.cert = (e.currentTarget as HTMLInputElement).value)} />
        <Input label={$LL.proxyKey()} mono placeholder="/etc/ssl/private/app.key" value={draft.key ?? ''} oninput={(e: Event) => draft && (draft.key = (e.currentTarget as HTMLInputElement).value)} />
      {:else if draft.tls && selected === 'caddy'}
        <p class="text-[12px] text-(--text-tertiary)">{$LL.proxyCaddyTls()}</p>
      {:else if draft.tls && selected === 'traefik' && !current?.tlsResolver}
        <p class="text-[12px] text-(--color-danger)">{$LL.proxyNeedsResolver()}</p>
      {/if}
      <div class="flex justify-end gap-[9px]">
        <Button variant="ghost" onclick={() => (draft = null)}>{$LL.cancel()}</Button>
        <Button variant="primary" disabled={!domainsText.trim() || !draft.upstream.trim()} onclick={submit}>{$LL.proxySave()}</Button>
      </div>
    </div>
  </Dialog>
{/if}

<SudoConfirm
  open={pending !== null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  run={(sudo) => pending!.run(sudo)}
  {refusal}
  onclose={() => {
    pending = null
    void load()
  }}
/>
