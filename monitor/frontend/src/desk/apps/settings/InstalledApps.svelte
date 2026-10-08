<script lang="ts">
  /// Apps an admin installs on this server's agent (`api::apps`): upload a
  /// package, approve what it asks for, remove it. Approving and removing ask
  /// the admin's password. A change reaches this desk's launchpad at once;
  /// other desks see it when they next start.

  import { AppIcon, Badge, Button, Group, Row } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import type { InstalledApp } from '../../../types'
  import type { IconTone } from '../../lk/AppIcon.svelte'
  import ReauthDialog from './ReauthDialog.svelte'

  interface Props {
    /// Adds what changed to this desk.
    onchange: () => Promise<void>
  }

  const { onchange }: Props = $props()

  let apps = $state<InstalledApp[]>([])
  let error = $state('')
  let busy = $state(false)
  let fileInput = $state<HTMLInputElement | null>(null)
  let asking = $state<{ kind: 'approve' | 'remove'; app: InstalledApp } | null>(null)

  async function load() {
    try {
      apps = (await api.listApps()).apps
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  $effect(() => {
    void load()
  })

  function titleOf(app: InstalledApp): string {
    const t = app.manifest.title
    return typeof t === 'string' ? t : (t.en ?? app.id)
  }

  function permissionText(p: string): string {
    if (p === 'notifications') return $LL.settingsPermNotifications()
    if (p === 'background') return $LL.settingsPermBackground()
    return p
  }

  function refusal(e: unknown): string {
    if (e instanceof ApiError) {
      const body = e.body as { error?: string; path?: string } | undefined
      const reason = [body?.error ?? e.message, body?.path].filter(Boolean).join(' ')
      return $LL.settingsAppRefused({ reason })
    }
    return e instanceof Error ? e.message : String(e)
  }

  async function install(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file) return
    busy = true
    error = ''
    try {
      await api.installApp(file)
      await load()
    } catch (e) {
      error = refusal(e)
    } finally {
      busy = false
    }
  }

  async function confirm(password: string) {
    if (!asking) return
    const { kind, app } = asking
    if (kind === 'approve') await api.approveApp(app.id, app.sha256, app.manifest.permissions, password)
    else await api.removeApp(app.id, password)
    await load()
    await onchange()
  }

  const message = $derived.by(() => {
    if (!asking) return ''
    const name = titleOf(asking.app)
    if (asking.kind === 'remove') return $LL.settingsAppRemoveMessage({ name })
    const asks = asking.app.manifest.permissions.map(permissionText)
    const what = asks.length ? $LL.settingsAppApproveMessage({ name, permissions: asks.join(', ') }) : $LL.settingsAppApproveBare({ name })
    return `${what} ${$LL.settingsAppApproveRisk()}`
  })
</script>

<Group title={$LL.settingsInstalledApps()}>
  {#each apps as app (app.id)}
    {@const title = titleOf(app)}
    <Row label={title} sub="{app.version} · {app.sha256.slice(0, 12)} · {app.manifest.permissions.map(permissionText).join(', ') || $LL.settingsAppNoPermissions()}">
      {#snippet leading()}<AppIcon glyph={app.manifest.glyph} tone={app.manifest.tone as IconTone} size={26} />{/snippet}
      {#if !app.approved_permissions}
        <Badge tone="warning" dot>{$LL.settingsAppWaiting()}</Badge>
        <Button size="sm" variant="tinted" onclick={() => (asking = { kind: 'approve', app })}>{$LL.settingsAppApprove()}</Button>
      {/if}
      <Button size="sm" variant="ghost" onclick={() => (asking = { kind: 'remove', app })}>{$LL.settingsAppRemove()}</Button>
    </Row>
  {/each}
  <Row label={$LL.settingsInstallApp()} sub={error || undefined}>
    <input bind:this={fileInput} type="file" class="hidden" accept=".fsba,application/gzip" onchange={install} />
    <Button size="sm" icon="upload" disabled={busy} onclick={() => fileInput?.click()}>{$LL.settingsInstallAppButton()}</Button>
  </Row>
</Group>

<ReauthDialog open={asking !== null} {message} onconfirm={confirm} onclose={() => (asking = null)} />
