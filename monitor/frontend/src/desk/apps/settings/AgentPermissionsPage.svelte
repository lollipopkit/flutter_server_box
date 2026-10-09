<script lang="ts">
  /// How the commands Agent mode's tasks run are approved
  /// (`/agent/permissions`), a page over Settings → Agent: the mode new
  /// tasks start in and whether Allow all may be picked, the command rules
  /// (allow, ask, deny), and the auto mode judge's rules. An
  /// admin edits them; anyone else reads them.

  import { Button, Group, Row, SegmentedControl, Spinner, Switch, Textarea } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type AutoModeRules, type PermissionMode, type PermissionsView } from '../../../lib/agentApi'
  import { ApiError } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)

  let loading = $state(true)
  let saving = $state(false)
  let saved = $state(false)
  let error = $state<string | null>(null)
  let view = $state<PermissionsView | null>(null)

  let mode = $state<PermissionMode>('manual')
  let disableBypass = $state(false)
  let allow = $state('')
  let ask = $state('')
  let deny = $state('')
  const AUTO = ['environment', 'allow', 'soft_deny', 'hard_deny'] as const
  type AutoKey = (typeof AUTO)[number]
  let auto = $state<Record<AutoKey, string>>({ environment: '', allow: '', soft_deny: '', hard_deny: '' })
  let shown = $state<AutoKey | null>(null)

  const lines = (t: string) =>
    t
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean)

  function fill(v: PermissionsView) {
    view = v
    const p = v.permissions
    mode = p.defaultMode
    disableBypass = p.disableBypass
    allow = p.rules.allow.join('\n')
    ask = p.rules.ask.join('\n')
    deny = p.rules.deny.join('\n')
    for (const k of AUTO) auto[k] = (p.autoMode[k] ?? []).join('\n')
  }

  async function load() {
    const entry = servers.current
    if (!entry) return
    loading = true
    error = null
    try {
      fill(await agentApi.permissions(entry))
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  async function save() {
    const entry = servers.current
    if (!entry || saving) return
    saving = true
    saved = false
    error = null
    const autoMode: AutoModeRules = {}
    // Empty is the built-in list.
    for (const k of AUTO) if (lines(auto[k]).length) autoMode[k] = lines(auto[k])
    try {
      fill(await agentApi.savePermissions(entry, { defaultMode: mode, disableBypass, rules: { allow: lines(allow), ask: lines(ask), deny: lines(deny) }, autoMode }))
      saved = true
      setTimeout(() => (saved = false), 1500)
    } catch (e) {
      error = e instanceof ApiError ? ((e.body?.reason as string | undefined) ?? e.message) : String(e)
    } finally {
      saving = false
    }
  }

  const modeNote = $derived(
    mode === 'auto' ? $LL.settingsAgentModeAutoNote() : mode === 'bypass' ? $LL.settingsAgentModeBypassNote() : $LL.settingsAgentModeManualNote(),
  )
  const autoLabel = (k: AutoKey) =>
    ({
      environment: $LL.settingsAgentAutoEnvironment(),
      allow: $LL.settingsAgentAutoAllow(),
      soft_deny: $LL.settingsAgentAutoSoftDeny(),
      hard_deny: $LL.settingsAgentAutoHardDeny(),
    })[k]
</script>

<SettingsPage title={$LL.settingsAgentPermissions()} back={onback} description={$LL.settingsAgentPermissionsAbout()}>
  {#snippet actions()}
    {#if saving}<Spinner size="sm" />{:else if saved}<span class="text-[12px] text-(--text-tertiary)">{$LL.settingsAgentSaved()}</span>{/if}
    {#if admin && !loading}
      <Button variant="primary" size="sm" icon="save" disabled={saving} onclick={save}>{$LL.save()}</Button>
    {/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else if view}
    {#if error}<p class="px-[2px] text-[13px] break-all text-(--color-danger)">{error}</p>{/if}
    {#if !admin}<p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.settingsAgentAdminOnly()}</p>{/if}

    <Group>
      <Row label={$LL.settingsAgentMode()} sub={modeNote}>
        <SegmentedControl
          size="sm"
          value={mode}
          disabled={!admin}
          onchange={(v) => (mode = v as PermissionMode)}
          options={[
            { value: 'manual', label: $LL.settingsAgentModeManual() },
            { value: 'auto', label: $LL.settingsAgentModeAuto() },
            { value: 'bypass', label: $LL.settingsAgentModeBypass(), disabled: disableBypass },
          ]}
        />
      </Row>
      <Row label={$LL.settingsAgentDisableBypass()} sub={$LL.settingsAgentDisableBypassSub()}>
        <Switch
          label={$LL.settingsAgentDisableBypass()}
          checked={disableBypass}
          disabled={!admin}
          onchange={(v) => {
            disableBypass = v
            if (v && mode === 'bypass') mode = 'manual'
          }}
        />
      </Row>
    </Group>
    <p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.settingsAgentDangerAlwaysAsks()}</p>

    <Group title={$LL.settingsAgentRules()}>
      <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
        <Textarea label={$LL.settingsAgentRulesDeny()} mono rows={3} disabled={!admin} placeholder="rm -rf *" bind:value={deny} />
        <Textarea label={$LL.settingsAgentRulesAsk()} mono rows={3} disabled={!admin} placeholder="systemctl stop *" bind:value={ask} />
        <Textarea label={$LL.settingsAgentRulesAllow()} mono rows={3} disabled={!admin} placeholder="systemctl restart nginx" bind:value={allow} />
        <span class="text-[12px] text-(--text-tertiary) [text-wrap:pretty]">{$LL.settingsAgentRulesHint()}</span>
      </div>
    </Group>

    <Group title={$LL.settingsAgentAutoRules()}>
      <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
        <span class="text-[12px] text-(--text-tertiary) [text-wrap:pretty]">{$LL.settingsAgentAutoHint()}</span>
        {#each AUTO as k (k)}
          <div class="flex flex-col gap-[5px]">
            <Textarea label={autoLabel(k)} rows={2} disabled={!admin} placeholder={$LL.settingsAgentAutoBuiltIn()} bind:value={auto[k]} />
            <div>
              <Button variant="ghost" size="sm" icon={shown === k ? 'expand_less' : 'expand_more'} onclick={() => (shown = shown === k ? null : k)}>
                {$LL.settingsAgentAutoShowDefaults({ n: view.defaults[k].length })}
              </Button>
            </div>
            {#if shown === k}
              <ul class="flex flex-col gap-[5px] rounded-(--radius-sm) bg-(--surface-card) px-[11px] py-[9px] text-[12px] text-(--text-secondary)">
                {#each view.defaults[k] as d, i (i)}<li class="[text-wrap:pretty]">{d}</li>{/each}
              </ul>
            {/if}
          </div>
        {/each}
      </div>
    </Group>
  {/if}
</SettingsPage>
