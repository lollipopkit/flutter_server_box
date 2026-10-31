<script lang="ts">
  /// Ubuntu Pro: the client installed or not, the machine attached to a
  /// subscription or not (a token from the Pro dashboard), the contract, the
  /// services each on or off, Livepatch's state. Every change is a job run
  /// as root after the desk's sudo dialog; the token goes to the backend
  /// once and is not kept here.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import Input from '$lk/Input.svelte'
  import Row from '$lk/Row.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import Switch from '$lk/Switch.svelte'
  import { DeskError, formatDate, translator, type SudoAsk } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { Pages } from '$common/pages.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'

  interface Service {
    name: string
    description: string
    available: boolean
    entitled: boolean | null
    status: string | null
    statusDetails: string | null
  }
  interface Pro {
    ubuntu: boolean
    release: string | null
    client: string | null
    attached: boolean
    account: string | null
    contract: string | null
    expires: string | null
    techSupport: string | null
    services: Service[]
    livepatch: { kernel: string | null; state: string | null; version: string | null; supported: string | null } | null
  }

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let view = $state<Pro | null>(null)
  let error = $state('')
  let token = $state('')
  let autoEnable = $state(false)
  const job = new JobRun()

  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const own: Record<string, string> = {
      notUbuntu: 'notUbuntu',
      noClient: 'noClient',
      attached: 'alreadyAttached',
      notAttached: 'notAttached',
      notEntitled: 'notEntitled',
      invalidToken: 'invalidToken',
    }
    return own[e.detail ?? ''] ? t(own[e.detail!]) : e.detail || e.message
  }

  async function load() {
    try {
      view = await desk.call<Pro>('view')
      error = ''
    } catch (e) {
      error = said(e)
    }
  }

  const shown = $derived(view?.services.filter((s) => s.available || s.entitled) ?? [])

  async function run(fn: string, args: Record<string, unknown>, sudo: SudoAsk) {
    await job.start(fn, args, sudo, said)
    void load()
  }

  function attach() {
    const value = token.trim()
    // Not kept on the page once it is on its way.
    token = ''
    void run('attach', { token: value, autoEnable }, { title: t('attachTitle'), body: autoEnable ? t('attachAutoBody') : t('attachBody') })
  }

  function toggle(s: Service, on: boolean) {
    void (on
      ? run('enable', { service: s.name }, { title: t('enableTitle', { service: s.name }), body: t('enableBody') })
      : run('disable', { service: s.name }, { title: t('disableTitle', { service: s.name }), body: t('disableBody') }))
  }

  const statusTone = (s: string | null) => (s === 'enabled' ? 'success' : s === 'warning' ? 'warning' : 'neutral')

  /// The subscription, its services and Livepatch, chosen in the window's
  /// sidebar once the client is here.
  const pages = new Pages(['subscription', 'services', 'livepatch'] as const, 'subscription')
  const paged = $derived(!!view?.ubuntu && !!view.client)
  const page = $derived(pages.current === 'livepatch' && !view?.livepatch ? 'subscription' : pages.current)
  const titles = $derived({ subscription: t('subscription'), services: t('services'), livepatch: 'Livepatch' })

  $effect(() => {
    if (!view || !paged) return pages.draw([])
    const on = view.services.filter((s) => s.status === 'enabled' || s.status === 'warning').length
    pages.draw([
      {
        items: [
          { id: 'subscription', label: titles.subscription, icon: 'verified_user' },
          { id: 'services', label: titles.services, icon: 'tune', trailing: view.attached ? String(on) : undefined },
          ...(view.livepatch ? [{ id: 'livepatch', label: titles.livepatch, icon: 'healing' }] : []),
        ],
      },
    ])
  })

  $effect(() => {
    void desk.toolbar({ title: paged ? titles[page] : undefined, actions: [{ id: 'refresh', label: t('refresh'), icon: 'refresh' }] })
  })
  desk.on('action', ({ id }) => id === 'refresh' && void load())

  void job.resume(said).then(() => load())
  void load()
</script>

<main class="page">
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog {t} status={job.status} title={job.running ? t('working') : job.status === 'succeeded' ? t('done') : t('failed')} lines={job.lines} oncancel={() => job.cancel()} />
  {/if}

  {#if !view}
    {#if !error}<div class="center"><Spinner /></div>{/if}
  {:else if !view.ubuntu}
    <Card><p class="note"><Icon name="info" size={17} /><span>{t('notUbuntu')}</span></p></Card>
  {:else if !view.client}
    <Card>
      <div class="intro">
        <p>{t('noClient')}</p>
        <Button variant="primary" icon="download" disabled={job.running} onclick={() => void run('installClient', {}, { title: t('installTitle'), body: t('installBody') })}>{t('installClient')}</Button>
      </div>
    </Card>
  {:else if page === 'subscription'}
    <Group>
      <Row label={t('subscription')}>
        <Badge tone={view.attached ? 'success' : 'neutral'}>{view.attached ? t('attached') : t('unattached')}</Badge>
      </Row>
      {#if view.attached}
        {#if view.contract}<Row label={t('contract')} value={view.contract} />{/if}
        {#if view.account}<Row label={t('account')} value={view.account} />{/if}
        {#if view.expires}<Row label={t('expires')} value={formatDate(view.expires, locale)} />{/if}
        {#if view.techSupport}<Row label={t('support')} value={view.techSupport} />{/if}
      {/if}
      <Row label={t('release')} value={`Ubuntu ${view.release ?? ''} · pro ${view.client}`} />
    </Group>
    {#if !view.attached}
      <Group title={t('attach')}>
        <div class="intro pad">
          <Input label={t('token')} type="password" autocomplete="off" mono bind:value={token} hint={t('tokenHint')} />
          <div class="trail">
            <Switch label={t('autoEnable')} bind:checked={autoEnable} />
            <span>{t('autoEnable')}</span>
          </div>
          <Button variant="primary" disabled={job.running || !token.trim()} onclick={attach}>{t('attach')}</Button>
        </div>
      </Group>
    {/if}
    {#if view.attached}
      <Group>
        <Row label={t('detach')} sub={t('detachNote')}>
          <Button size="sm" variant="destructive" disabled={job.running} onclick={() => void run('detach', {}, { title: t('detachTitle'), body: t('detachBody'), confirmWord: 'detach' })}>{t('detach')}</Button>
        </Row>
      </Group>
    {/if}
  {:else if page === 'services'}
    <Group>
      {#each shown as s (s.name)}
        <Row label={s.name} sub={s.statusDetails || s.description}>
          {#if view.attached}
            {#if s.entitled === false}
              <Badge>{t('notEntitledBadge')}</Badge>
            {:else}
              <span class="trail">
                {#if s.status && s.status !== 'enabled' && s.status !== 'disabled'}<Badge tone={statusTone(s.status)}>{s.status}</Badge>{/if}
                <Switch label={s.name} checked={s.status === 'enabled' || s.status === 'warning'} disabled={job.running} onchange={(on) => toggle(s, on)} />
              </span>
            {/if}
          {/if}
        </Row>
      {/each}
      {#if !view.attached}<p class="pad hint">{t('servicesNote')}</p>{/if}
    </Group>
  {:else if view.livepatch}
    <Group>
      <Row label={t('livepatchState')} value={view.livepatch.state ?? '—'} />
      {#if view.livepatch.kernel}<Row label={t('livepatchKernel')} value={view.livepatch.kernel} mono />{/if}
      {#if view.livepatch.version}<Row label={t('livepatchVersion')} value={view.livepatch.version} mono />{/if}
      {#if view.livepatch.supported}<Row label={t('livepatchSupport')} value={view.livepatch.supported} />{/if}
    </Group>
  {/if}
</main>
