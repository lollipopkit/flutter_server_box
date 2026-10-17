<script lang="ts">
  /// One server's web application firewall: installed or not, its mode,
  /// paranoia level and the rules left out, and what it detected and
  /// refused lately, each rule leavable out from there. Every change runs as
  /// root after the desk's sudo dialog.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Group from '$lk/Group.svelte'
  import Input from '$lk/Input.svelte'
  import Row from '$lk/Row.svelte'
  import SegmentedControl from '$lk/SegmentedControl.svelte'
  import Select from '$lk/Select.svelte'
  import type { Translate } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import type { ServerId, ServerWaf, WafEvent, WafSettings } from './model'

  interface Props {
    t: Translate
    server: ServerId
    waf: ServerWaf
    crs: string | null
    /// Busy: a job runs.
    busy: boolean
    install: () => void
    said: (e: unknown) => string
    onchanged: () => void
  }

  const { t, server, waf, crs, busy, install, said, onchanged }: Props = $props()

  let draft = $state<WafSettings>({ mode: 'detect', paranoia: 1, exclusions: [] })
  let exclusionsText = $state('')
  let events = $state<WafEvent[] | null>(null)
  let error = $state('')

  $effect(() => {
    const s = waf.settings ?? { mode: 'detect', paranoia: 1, exclusions: [] }
    draft = { ...s }
    exclusionsText = s.exclusions.join(', ')
  })

  async function save(settings: WafSettings) {
    error = ''
    try {
      await desk.call('setWaf', { server, settings }, {
        sudo: { title: t('wafSaveTitle'), body: settings.mode === 'block' ? t('wafSaveBlock') : settings.mode === 'detect' ? t('wafSaveDetect') : t('wafSaveOff') },
      })
      onchanged()
    } catch (e) {
      error = said(e)
    }
  }

  function submit() {
    const exclusions = exclusionsText.split(/[\s,]+/).map((x) => Number(x)).filter((n) => Number.isInteger(n) && n > 0)
    void save({ ...draft, exclusions })
  }

  function leaveOut(id: string) {
    const n = Number(id)
    if (!Number.isInteger(n) || draft.exclusions.includes(n)) return
    void save({ ...draft, exclusions: [...(waf.settings?.exclusions ?? []), n] })
  }

  async function readEvents() {
    error = ''
    try {
      events = await desk.call<WafEvent[]>('wafEvents', { server }, { sudo: { title: t('wafEvents'), body: t('wafEventsBody') } })
    } catch (e) {
      error = said(e)
    }
  }
</script>

<Group title={t('wafTitle')}>
  {#if !waf.ready}
    <Row label={t('wafNotReady')} sub={waf.installable ? undefined : t('wafNotInstallable')}>
      {#if waf.installable}<Button size="sm" icon="download" disabled={busy} onclick={install}>{t('wafInstall')}</Button>{/if}
    </Row>
  {:else}
    <Row label={t('wafRules')} value={`OWASP CRS ${crs ?? ''}`} />
    <div class="trail wrap pad">
      <SegmentedControl
        label={t('wafMode')}
        options={[
          { value: 'off', label: t('wafOff') },
          { value: 'detect', label: t('wafDetect') },
          { value: 'block', label: t('wafBlock') },
        ]}
        value={draft.mode}
        onchange={(m) => (draft.mode = m)}
      />
      <Select label={t('wafParanoia')} options={[1, 2, 3, 4].map((n) => ({ value: n, label: String(n) }))} bind:value={draft.paranoia} />
    </div>
    <div class="trail wrap pad">
      <Input class="grow" label={t('wafExclusions')} mono placeholder="942100, 920350" bind:value={exclusionsText} />
      <Button variant="primary" onclick={submit}>{t('wafSave')}</Button>
    </div>
    <p class="pad hint">{waf.settings ? t('wafSitesNote') : t('wafFirstSave')}</p>
    {#if error}<p class="pad danger">{error}</p>{/if}
    {#if waf.settings}
      <Row label={t('wafEvents')}>
        <Button size="sm" variant="secondary" onclick={() => void readEvents()}>{t('wafRead')}</Button>
      </Row>
      {#each events ?? [] as e, i (i)}
        <div class="event">
          <div class="trail wrap">
            <Badge tone={e.status === 403 ? 'danger' : 'warning'}>{e.status === 403 ? t('wafRefused') : t('wafDetected')}</Badge>
            <span class="lk-mono">{e.method} {e.host}{e.uri}</span>
            <span class="hint">{e.client} · {e.time}</span>
          </div>
          {#each e.rules as [id, message] (id)}
            <div class="trail">
              <span class="lk-mono">{id}</span><span class="grow">{message}</span>
              {#if !waf.settings?.exclusions.includes(Number(id))}
                <Button size="sm" variant="ghost" onclick={() => leaveOut(id)}>{t('wafLeaveOut')}</Button>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        {#if events}<p class="pad hint">{t('wafNoEvents')}</p>{/if}
      {/each}
    {/if}
  {/if}
</Group>

<style>
  .event {
    display: flex;
    flex-direction: column;
    gap: 5px;
    border-top: 0.5px solid var(--border-hairline);
    padding: 9px 13px;
    font-size: 12px;
    word-break: break-all;
  }
</style>
