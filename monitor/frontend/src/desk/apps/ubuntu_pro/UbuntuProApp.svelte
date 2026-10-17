<script lang="ts">
  /// Ubuntu Pro (`/ubuntu-pro`): the client installed or not, the machine
  /// attached to a subscription or not (a token from the Pro dashboard),
  /// the contract, the services each enabled or disabled, Livepatch's state.
  /// Every change is a job run as root after sudo's password (`SudoConfirm`);
  /// the token goes to the agent once and is never shown again.

  import { AppToolbar } from '../../sys'
  import { Badge, Button, Card, Group, Icon, IconButton, Input, Row, Spinner, Switch } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { errorText } from '../../../lib/errorText'
  import { fmtDate } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { ProAction, ProService, ProView, StackJob } from '../../../types'

  let view = $state<ProView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  let pending = $state<{ title: string; body: string; confirmWord?: string; action: ProAction } | null>(null)
  let token = $state('')
  let autoEnable = $state(false)
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const v = await api.getUbuntuPro()
      if (stale(serverId)) return
      view = v
      if (v.job?.state === 'running') job = v.job
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  const shown = $derived(view?.services.filter((s) => s.available || s.entitled) ?? [])

  function refusal(body: Record<string, unknown> & { error?: string }): string | undefined {
    const map: Record<string, () => string> = {
      notUbuntu: $LL.ubuntuProNotUbuntu,
      noClient: $LL.ubuntuProNoClient,
      attached: $LL.ubuntuProAlreadyAttached,
      notAttached: $LL.ubuntuProNotAttached,
      notEntitled: $LL.ubuntuProNotEntitled,
      invalidToken: $LL.ubuntuProInvalidToken,
    }
    return body.error ? map[body.error]?.() : undefined
  }

  function ask(action: ProAction) {
    switch (action.action) {
      case 'installClient':
        pending = { title: $LL.ubuntuProInstallTitle(), body: $LL.ubuntuProInstallBody(), action }
        break
      case 'attach':
        pending = { title: $LL.ubuntuProAttachTitle(), body: action.autoEnable ? $LL.ubuntuProAttachAutoBody() : $LL.ubuntuProAttachBody(), action }
        break
      case 'detach':
        pending = { title: $LL.ubuntuProDetachTitle(), body: $LL.ubuntuProDetachBody(), confirmWord: 'detach', action }
        break
      case 'enable':
        pending = { title: $LL.ubuntuProEnableTitle({ service: action.service }), body: $LL.ubuntuProEnableBody(), action }
        break
      case 'disable':
        pending = { title: $LL.ubuntuProDisableTitle({ service: action.service }), body: $LL.ubuntuProDisableBody(), action }
    }
  }

  function toggle(s: ProService, on: boolean) {
    ask(on ? { action: 'enable', service: s.name } : { action: 'disable', service: s.name })
  }

  const statusTone = (s: string | null) => (s === 'enabled' ? 'success' : s === 'warning' ? 'warning' : 'neutral')
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
        title={job.state === 'running' ? $LL.ubuntuProWorking() : job.state === 'succeeded' ? $LL.ubuntuProDone() : $LL.ubuntuProFailed()}
        read={(since) => api.ubuntuProJob(since)}
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
  {:else if !view.ubuntu}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)"><Icon name="info" size={17} /><p>{$LL.ubuntuProNotUbuntu()}</p></Card>
  {:else if !view.client}
    <Card class="space-y-[11px] text-[13px]">
      <p class="text-(--text-secondary)">{$LL.ubuntuProNoClient()}</p>
      <Button variant="primary" icon="download" disabled={running} onclick={() => ask({ action: 'installClient' })}>{$LL.ubuntuProInstallClient()}</Button>
    </Card>
  {:else}
    <Group>
      <Row label={$LL.ubuntuProSubscription()}>
        <Badge tone={view.attached ? 'success' : 'neutral'}>{view.attached ? $LL.ubuntuProAttached() : $LL.ubuntuProUnattached()}</Badge>
      </Row>
      {#if view.attached}
        {#if view.contract}<Row label={$LL.ubuntuProContract()} value={view.contract} />{/if}
        {#if view.account}<Row label={$LL.ubuntuProAccount()} value={view.account} />{/if}
        {#if view.expires}<Row label={$LL.ubuntuProExpires()} value={fmtDate(new Date(view.expires), { year: 'numeric', month: 'short', day: 'numeric' })} />{/if}
        {#if view.techSupport}<Row label={$LL.ubuntuProSupport()} value={view.techSupport} />{/if}
      {/if}
      <Row label={$LL.ubuntuProRelease()} value={`Ubuntu ${view.release ?? ''} · pro ${view.client}`} />
    </Group>

    {#if !view.attached}
      <Group title={$LL.ubuntuProAttach()}>
        <div class="space-y-[11px] px-[13px] py-[11px]">
          <Input label={$LL.ubuntuProToken()} type="password" autocomplete="off" mono bind:value={token} hint={$LL.ubuntuProTokenHint()} />
          <div class="flex items-center gap-[9px] text-[13px]">
            <Switch label={$LL.ubuntuProAutoEnable()} bind:checked={autoEnable} />
            <span>{$LL.ubuntuProAutoEnable()}</span>
          </div>
          <Button variant="primary" disabled={running || !token.trim()} onclick={() => ask({ action: 'attach', autoEnable })}>{$LL.ubuntuProAttach()}</Button>
        </div>
      </Group>
    {/if}

    {#if view.livepatch}
      <Group title="Livepatch">
        <Row label={$LL.ubuntuProLivepatchState()} value={view.livepatch.state ?? '—'} />
        {#if view.livepatch.kernel}<Row label={$LL.ubuntuProLivepatchKernel()} value={view.livepatch.kernel} mono />{/if}
        {#if view.livepatch.version}<Row label={$LL.ubuntuProLivepatchVersion()} value={view.livepatch.version} mono />{/if}
        {#if view.livepatch.supported}<Row label={$LL.ubuntuProLivepatchSupport()} value={view.livepatch.supported} />{/if}
      </Group>
    {/if}

    <Group title={$LL.ubuntuProServices()}>
      {#each shown as s (s.name)}
        <Row label={s.name} sub={s.statusDetails || s.description}>
          {#if view.attached}
            {#if s.entitled === false}
              <Badge>{$LL.ubuntuProNotEntitledBadge()}</Badge>
            {:else}
              {#if s.status && s.status !== 'enabled' && s.status !== 'disabled'}<Badge tone={statusTone(s.status)}>{s.status}</Badge>{/if}
              <Switch label={s.name} checked={s.status === 'enabled' || s.status === 'warning'} disabled={running} onchange={(on) => toggle(s, on)} />
            {/if}
          {/if}
        </Row>
      {/each}
      {#if !view.attached}<p class="px-[13px] pb-[11px] text-[12px] text-(--text-tertiary)">{$LL.ubuntuProServicesNote()}</p>{/if}
    </Group>

    {#if view.attached}
      <Group>
        <Row label={$LL.ubuntuProDetach()} sub={$LL.ubuntuProDetachNote()}>
          <Button size="sm" variant="destructive" disabled={running} onclick={() => ask({ action: 'detach' })}>{$LL.ubuntuProDetach()}</Button>
        </Row>
      </Group>
    {/if}
  {/if}
</main>

<SudoConfirm
  open={pending !== null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  confirmWord={pending?.confirmWord}
  run={async (sudo) => {
    const action = pending!.action
    job = await api.ubuntuProAct(action, sudo, action.action === 'attach' ? token.trim() : undefined)
    if (action.action === 'attach') token = ''
  }}
  {refusal}
  onclose={() => {
    pending = null
    void load()
  }}
/>
