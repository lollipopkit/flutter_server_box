<script lang="ts">
  /// The machine's kernels: the one running, the installed ones and which
  /// GRUB boots, the series the machine follows and the archive's others,
  /// other versions of the running flavour. Every change is a job run as
  /// root after the desk's sudo dialog; a kernel runs after a restart, which
  /// the desk's own dialog does.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import IconButton from '$lk/IconButton.svelte'
  import Row from '$lk/Row.svelte'
  import Select from '$lk/Select.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import { DeskError, translator, type SudoAsk } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { Pages } from '$common/pages.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'

  interface Kernel {
    release: string
    package: string
    version: string
    running: boolean
    default: boolean
    next: boolean
    neededBy: string | null
  }
  interface Kernels {
    supported: boolean
    running: string
    installed: Kernel[]
    pinned: string | null
    series: { package: string; version: string; installed: string | null }[]
    versions: { package: string; release: string; version: string }[]
    rebootRequired: boolean
  }

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let view = $state<Kernels | null>(null)
  let error = $state('')
  let version = $state('')
  const job = new JobRun()

  /// The backend's refusal in words: its own codes, else what it said.
  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const own: Record<string, string> = {
      unsupported: 'unsupported',
      notOffered: 'notOffered',
      installed: 'alreadyInstalled',
      unknownKernel: 'unknown',
      running: 'removeRunning',
      booted: 'removeBooted',
      lastKernel: 'removeLast',
      neededBySeries: 'removeNeeded',
    }
    return own[e.detail ?? ''] ? t(own[e.detail!]) : e.detail || e.message
  }

  async function load() {
    try {
      const v = await desk.call<Kernels>('view')
      view = v
      if (!v.versions.some((o) => o.package === version)) version = v.versions[0]?.package ?? ''
      error = ''
    } catch (e) {
      error = said(e)
    }
  }

  const booted = $derived(view?.installed.find((k) => k.default))
  const next = $derived(view?.installed.find((k) => k.next))
  /// What a restart would change: another kernel booted than the one running.
  const restartBoots = $derived(next ?? booted)
  const restartNeeded = $derived(!!view && (view.rebootRequired || (!!restartBoots && !restartBoots.running)))

  function removable(k: Kernel): boolean {
    return !k.running && !k.default && !k.next && !k.neededBy && (view?.installed.length ?? 0) > 1
  }

  async function run(fn: string, args: Record<string, unknown>, sudo: SudoAsk) {
    await job.start(fn, args, sudo, said)
    void load()
  }

  const install = (p: string) => run('install', { package: p }, { title: t('installTitle', { package: p }), body: t('installBody') })
  const remove = (r: string) => run('remove', { release: r }, { title: t('removeTitle', { release: r }), body: t('removeBody'), confirmWord: r })
  const boot = (r: string, once: boolean) =>
    run('boot', { release: r, once }, { title: once ? t('bootOnceTitle', { release: r }) : t('bootTitle', { release: r }), body: once ? t('bootOnceBody') : t('bootBody') })
  const bootNewest = () => run('bootNewest', {}, { title: t('bootNewestTitle'), body: t('bootNewestBody') })

  /// The kernels here and what boots, and the ones to install, chosen in the
  /// window's sidebar; the second only where kernels are managed here.
  const pages = new Pages(['installed', 'available'] as const, 'installed')
  const available = $derived(!!view?.supported && (view.series.length > 0 || view.versions.length > 0))
  const page = $derived(available ? pages.current : 'installed')

  $effect(() => {
    pages.draw(
      view
        ? [
            {
              items: [
                { id: 'installed', label: t('installed'), icon: 'memory', trailing: String(view.installed.length) },
                ...(available ? [{ id: 'available', label: t('available'), icon: 'download' }] : []),
              ],
            },
          ]
        : [],
    )
  })

  $effect(() => {
    void desk.toolbar({ title: view ? (page === 'installed' ? t('installed') : t('available')) : undefined, actions: [{ id: 'refresh', label: t('refresh'), icon: 'refresh' }] })
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
  {:else}
    {#if page === 'installed'}
      {#if !view.supported}
        <Card><p class="note"><Icon name="info" size={17} /><span>{t('unsupported')}</span></p></Card>
      {/if}
      <Group>
        <Row label={t('running')} value={view.running} mono />
        <Row label={t('boots')} value={booted?.release ?? '—'} mono sub={view.pinned ? t('pinned') : t('newest')}>
          {#if view.pinned && view.supported}
            <Button size="sm" variant="secondary" disabled={job.running} onclick={() => void bootNewest()}>{t('bootNewest')}</Button>
          {/if}
        </Row>
        {#if next}
          <Row label={t('nextBoot')} value={next.release} mono />
        {/if}
      </Group>
      {#if restartNeeded}
        <Card>
          <div class="trail wrap">
            <Icon name="restart_alt" size={17} />
            <p class="grow">{restartBoots && !restartBoots.running ? t('restartToBoot', { release: restartBoots.release }) : t('restartRequired')}</p>
            <Button size="sm" variant="primary" onclick={() => void desk.power('reboot')}>{t('reboot')}…</Button>
          </div>
        </Card>
      {/if}

      <Group title={t('installed')}>
        {#each view.installed as k (k.release)}
          <Row label={k.release} mono sub={`${k.package} ${k.version}`}>
            <span class="trail wrap">
              {#if k.running}<Badge tone="success">{t('badgeRunning')}</Badge>{/if}
              {#if k.default}<Badge tone="accent">{t('badgeDefault')}</Badge>{/if}
              {#if k.next}<Badge tone="warning">{t('badgeNext')}</Badge>{/if}
              {#if view.supported}
                {#if !k.default || view.pinned === null}
                  <Button size="sm" variant="ghost" disabled={job.running} onclick={() => void boot(k.release, false)}>{t('boot')}</Button>
                {/if}
                {#if !k.next && !k.running}
                  <Button size="sm" variant="ghost" disabled={job.running} onclick={() => void boot(k.release, true)}>{t('bootOnce')}</Button>
                {/if}
                {#if removable(k)}
                  <IconButton icon="delete" label={t('remove')} disabled={job.running} onclick={() => void remove(k.release)} />
                {/if}
              {/if}
            </span>
          </Row>
        {/each}
      </Group>
    {:else}
      {#if view.supported && view.series.length}
        <Group title={t('series')}>
          {#each view.series as s (s.package)}
            <Row label={s.package} mono sub={s.installed ? (s.installed === s.version ? s.version : `${s.installed} → ${s.version}`) : s.version}>
              <span class="trail">
                {#if s.installed}<Badge tone="success">{t('followed')}</Badge>{/if}
                {#if s.installed !== s.version}
                  <Button size="sm" variant="ghost" disabled={job.running} onclick={() => void install(s.package)}>{s.installed ? t('update') : t('install')}</Button>
                {/if}
              </span>
            </Row>
          {/each}
        </Group>
      {/if}

      {#if view.supported && view.versions.length}
        <Group title={t('versions')}>
          <div class="trail wrap pad">
            <Select class="grow" label={t('version')} options={view.versions.map((o) => ({ value: o.package, label: `${o.release} · ${o.version}` }))} bind:value={version} />
            <Button variant="primary" icon="download" disabled={job.running || !version} onclick={() => void install(version)}>{t('install')}</Button>
          </div>
          <p class="pad hint">{t('versionsNote')}</p>
        </Group>
      {/if}
    {/if}
  {/if}
</main>
