<script lang="ts">
  /// The skills Agent mode's tasks may load (`/agent/skills`), a page over
  /// Settings → Agent: installed from a GitHub repository as `npx skills add`
  /// takes it, each switched on or off, or removed.

  import { Button, Group, IconButton, Input, Row, Spinner, Switch } from '../../lk'
  import { errorText } from '../../../lib/errorText'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type AgentSkill } from '../../../lib/agentApi'
  import { ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let loading = $state(true)
  let busy = $state(false)
  let error = $state<string | null>(null)
  let skills = $state<AgentSkill[]>([])
  let source = $state('')

  function reason(e: unknown): string {
    if (e instanceof ApiError) {
      const code = e.body?.error as string | undefined
      if (code === 'noSkill') return $LL.settingsAgentSkillsNone()
      if (code === 'tooMany') return $LL.settingsAgentSkillsTooMany()
      if (code === 'invalidSource') return $LL.settingsAgentSkillsBadSource()
      return (e.body?.reason as string | undefined) ?? e.message
    }
    return errorText(e)
  }

  async function run(f: () => Promise<{ skills: AgentSkill[] }>): Promise<boolean> {
    busy = true
    error = null
    try {
      skills = (await f()).skills
      return true
    } catch (e) {
      error = reason(e)
      return false
    } finally {
      busy = false
      loading = false
    }
  }

  $effect(() => {
    void servers.currentId
    const entry = servers.current
    if (entry) void run(() => agentApi.skills(entry))
  })

  async function install() {
    const entry = servers.current
    if (!entry || !source.trim()) return
    if (await run(() => agentApi.installSkill(entry, source.trim()))) source = ''
  }
</script>

<SettingsPage title={$LL.settingsAgentSkills()} back={onback} description={$LL.settingsAgentSkillsAbout()}>
  {#snippet actions()}
    {#if busy && !loading}<Spinner size="sm" />{/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    {#if error}<p class="px-[2px] text-[13px] break-all text-(--color-danger)">{error}</p>{/if}
    <Group>
      {#each skills as s (s.dir)}
        <Row label={s.name} sub={[s.description, s.source].filter(Boolean).join(' · ')}>
          <span class="flex items-center gap-[9px]">
            <Switch
              label={$LL.settingsAgentSkillsEnabled()}
              checked={s.enabled}
              disabled={busy}
              onchange={(on) => {
                const entry = servers.current
                if (entry) void run(() => agentApi.setSkill(entry, s.dir, on))
              }}
            />
            <IconButton
              size="sm"
              icon="delete"
              label={$LL.settingsAgentSkillsRemove()}
              disabled={busy}
              onclick={() => {
                const entry = servers.current
                if (entry) void run(() => agentApi.removeSkill(entry, s.dir))
              }}
            />
          </span>
        </Row>
      {:else}
        <p class="px-[13px] py-[13px] text-[13px] text-(--text-tertiary)">{$LL.settingsAgentSkillsEmpty()}</p>
      {/each}
    </Group>
    <Group title={$LL.settingsAgentSkillsInstall()}>
      <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
        <Input
          label={$LL.settingsAgentSkillsSource()}
          mono
          placeholder="anthropics/skills"
          hint={$LL.settingsAgentSkillsSourceHint()}
          bind:value={source}
          onkeydown={(e: KeyboardEvent) => {
            if (e.key === 'Enter') void install()
          }}
        />
        <div>
          <Button variant="primary" icon="download" disabled={busy || !source.trim()} onclick={install}>{$LL.settingsAgentSkillsInstall()}</Button>
        </div>
      </div>
    </Group>
  {/if}
</SettingsPage>
