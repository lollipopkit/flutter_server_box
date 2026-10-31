<script lang="ts">
  /// Backups of this monitor's settings to a WebDAV folder
  /// (`/monitor-backup*`): where they go, the passphrase they are encrypted
  /// with, how the last one went, and restoring one. Saving, the passphrase
  /// and restoring ask the account's password again.

  import { onDestroy } from 'svelte'
  import { Badge, Button, Checkbox, Dialog, Group, Input, Row, Spinner, Switch } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { DATE_TIME, fmtBytes, fmtDate } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { MonitorBackupFile, MonitorBackupView } from '../../../types'
  import { monitorBackupErrorText } from './monitorBackupText'

  const { stale } = useScope()

  let view = $state<MonitorBackupView | null>(null)
  const errText = (e: unknown) => monitorBackupErrorText(e, $LL, view?.max_bytes)
  let loadError = $state<string | null>(null)

  // The folder form.
  let url = $state('')
  let username = $state('')
  /// Empty keeps the saved password, unless [forget].
  let password = $state('')
  /// Remove the saved password on the next save.
  let forget = $state(false)
  let allowInsecure = $state(false)
  let enabled = $state(true)
  let keep = $state('10')
  let formError = $state<string | null>(null)
  let tested = $state<string | null>(null)
  let testing = $state(false)
  let saved = $state(false)

  let backups = $state<MonitorBackupFile[] | null>(null)
  let listError = $state<string | null>(null)
  let listing = $state(false)

  /// What the password dialog is for.
  let asking = $state<null | { message: string; run: (password: string) => Promise<void> }>(null)

  // The passphrase dialog.
  let keyOpen = $state(false)
  let passphrase = $state('')
  let passphraseAgain = $state('')

  // Restoring.
  let restoring = $state<MonitorBackupFile | null>(null)
  let restorePassphrase = $state('')
  let restoreError = $state<string | null>(null)

  let timer: ReturnType<typeof setInterval> | undefined
  onDestroy(() => clearInterval(timer))

  const plainHttp = $derived(/^http:\/\//i.test(url.trim()))
  const passphraseShort = $derived(passphrase.length > 0 && [...passphrase].length < (view?.min_passphrase ?? 12))
  const passphraseMismatch = $derived(passphraseAgain.length > 0 && passphrase !== passphraseAgain)

  function fill(v: MonitorBackupView) {
    view = v
    url = v.url ?? ''
    username = v.username ?? ''
    password = ''
    forget = false
    allowInsecure = v.allow_insecure
    enabled = v.enabled
    keep = String(v.keep)
  }

  async function load() {
    const serverId = servers.currentId
    loadError = null
    try {
      const v = await api.getMonitorBackup()
      if (stale(serverId)) return
      fill(v)
      if (v.running) follow()
      if (v.configured) void list()
    } catch (e) {
      if (!stale(serverId)) loadError = errText(e)
    }
  }

  $effect(() => {
    void servers.currentId
    view = null
    backups = null
    if (servers.authenticated) void load()
  })

  function target() {
    const secret = password ? { password } : forget ? { password: '' } : {}
    return { url: url.trim(), username: username.trim(), allow_insecure: allowInsecure, ...secret }
  }

  /// Runs [change] behind the password dialog: a refusal of the change itself
  /// (not of the password) closes the dialog and is said in the form.
  function behindPassword(message: string, change: (own: string) => Promise<void>) {
    asking = {
      message,
      run: async (own) => {
        try {
          await change(own)
        } catch (e) {
          if (e instanceof ApiError && e.status !== 401 && e.status !== 403 && e.status !== 429) {
            formError = errText(e)
            return
          }
          throw e
        }
      },
    }
  }

  async function test() {
    testing = true
    tested = null
    formError = null
    try {
      const probe = await api.testMonitorBackup(target())
      tested = probe.missing ? $LL.monitorBackupTestMissing() : $LL.monitorBackupTestOk({ count: probe.backups })
    } catch (e) {
      formError = errText(e)
    } finally {
      testing = false
    }
  }

  function save() {
    formError = null
    saved = false
    behindPassword($LL.monitorBackupSaveReauth(), async (own) => {
      fill(await api.saveMonitorBackup({ ...target(), enabled, keep: Number(keep) }, own))
      saved = true
      void list()
    })
  }

  function setKey() {
    const chosen = passphrase
    keyOpen = false
    formError = null
    behindPassword($LL.monitorBackupKeyReauth(), async (own) => {
      fill(await api.setMonitorBackupKey(chosen, own))
      passphrase = ''
      passphraseAgain = ''
      follow()
    })
  }

  async function runNow() {
    try {
      view = await api.runMonitorBackup()
      follow()
    } catch (e) {
      formError = errText(e)
    }
  }

  /// Asks again while a backup runs, then lists the folder.
  function follow() {
    clearInterval(timer)
    const serverId = servers.currentId
    let seen = 0
    timer = setInterval(async () => {
      try {
        const v = await api.getMonitorBackup()
        if (stale(serverId)) return clearInterval(timer)
        view = v
        // The loop may not have picked it up yet on the first ask.
        if (!v.running && ++seen > 1) {
          clearInterval(timer)
          void list()
        }
      } catch {
        clearInterval(timer)
      }
    }, 1500)
  }

  async function list() {
    const serverId = servers.currentId
    listing = true
    listError = null
    try {
      const found = (await api.listMonitorBackups()).backups
      if (!stale(serverId)) backups = found
    } catch (e) {
      if (!stale(serverId)) listError = errText(e)
    } finally {
      listing = false
    }
  }

  function restore() {
    const file = restoring
    const chosen = restorePassphrase
    if (!file) return
    restoring = null
    asking = {
      message: $LL.monitorBackupRestoreReauth({ when: when(file.created_at) }),
      run: async (own) => {
        try {
          const done = await api.restoreMonitorBackup(file.name, chosen, own)
          restorePassphrase = ''
          // The password is the backup's now: this session is over. The
          // sign-in screen says what happened.
          const next = done.restart ? $LL.monitorBackupRestoredRestarting() : $LL.monitorBackupRestoredRestart()
          servers.logout(servers.currentId, undefined, `${next} ${$LL.monitorBackupRestoredSignIn()}`)
        } catch (e) {
          // A wrong passphrase is the passphrase's to retype, not the password's.
          if (e instanceof ApiError && e.status !== 401 && e.status !== 403 && e.status !== 429) {
            restoring = file
            restoreError = errText(e)
            return
          }
          throw e
        }
      },
    }
  }

  function when(iso: string): string {
    return fmtDate(new Date(iso), DATE_TIME, $locale)
  }
</script>

<SettingsPage title={$LL.monitorBackupTitle()} description={$LL.monitorBackupDescription()}>
  {#if loadError}
    <p class="text-[13px] text-(--color-danger)" role="alert">{loadError}</p>
  {:else if !view}
    <div class="flex justify-center py-[27px]"><Spinner /></div>
  {:else}
    <Group title={$LL.monitorBackupFolder()}>
      <div class="flex flex-col gap-[11px] py-[11px]">
        <Input id="backup-url" label={$LL.monitorBackupUrl()} hint={$LL.monitorBackupUrlHint()} placeholder="https://dav.example.com/serverbox/this-server/" mono bind:value={url} />
        <div class="flex flex-wrap gap-[11px]">
          <Input id="backup-user" class="min-w-[180px] flex-1" label={$LL.monitorBackupUsername()} autocomplete="off" bind:value={username} />
          <Input
            id="backup-password"
            class="min-w-[180px] flex-1"
            type="password"
            autocomplete="new-password"
            label={$LL.monitorBackupPassword()}
            placeholder={view.has_password && !forget ? $LL.monitorBackupPasswordSaved() : ''}
            bind:value={password}
          />
        </div>
        {#if view.has_password && !password}
          <Checkbox label={$LL.monitorBackupForgetPassword()} bind:checked={forget} />
        {/if}
      </div>
      {#if plainHttp}
        <Row label={$LL.monitorBackupAllowInsecure()} sub={$LL.monitorBackupAllowInsecureHint()}>
          <Switch label={$LL.monitorBackupAllowInsecure()} bind:checked={allowInsecure} />
        </Row>
      {/if}
      <Row label={$LL.monitorBackupKeep()} sub={$LL.monitorBackupKeepHint()}>
        <Input id="backup-keep" class="w-[90px]" type="number" min="1" max="100" bind:value={keep} />
      </Row>
      <Row label={$LL.monitorBackupEnabled()} sub={$LL.monitorBackupEnabledHint()}>
        <Switch label={$LL.monitorBackupEnabled()} bind:checked={enabled} />
      </Row>
      <div class="flex flex-wrap items-center justify-end gap-[9px] py-[11px]">
        {#if tested}<span class="mr-auto text-[13px] text-(--color-success)">{tested}</span>{/if}
        {#if saved}<span class="mr-auto text-[13px] text-(--color-success)">{$LL.monitorBackupSaved()}</span>{/if}
        <Button variant="secondary" size="sm" disabled={!url.trim() || testing} onclick={() => void test()}>
          {#if testing}<Spinner size={14} />{/if}
          {$LL.monitorBackupTest()}
        </Button>
        <Button size="sm" disabled={!url.trim()} onclick={save}>{$LL.save()}</Button>
      </div>
      {#if formError}<p class="pb-[11px] text-[13px] text-(--color-danger)" role="alert">{formError}</p>{/if}
    </Group>

    {#if view.configured}
      <Group title={$LL.monitorBackupKey()}>
        <Row
          label={view.key_id ? $LL.monitorBackupKeySet() : $LL.monitorBackupKeyMissing()}
          sub={view.key_id ? $LL.monitorBackupKeySetHint({ id: view.key_id }) : $LL.monitorBackupKeyMissingHint()}
        >
          <Button size="sm" variant={view.key_id ? 'secondary' : 'primary'} onclick={() => (keyOpen = true)}>
            {view.key_id ? $LL.monitorBackupKeyChange() : $LL.monitorBackupKeySetAction()}
          </Button>
        </Row>
      </Group>

      <Group title={$LL.monitorBackupStatus()}>
        <Row
          label={view.running ? $LL.monitorBackupRunning() : view.last_backup_at ? $LL.monitorBackupLast({ when: when(view.last_backup_at) }) : $LL.monitorBackupNone()}
          sub={!view.enabled ? $LL.monitorBackupOff() : view.last_error ? errText(view.last_error) : $LL.monitorBackupSchedule()}
        >
          <div class="flex items-center gap-[7px]">
            {#if view.last_error && view.enabled}<Badge tone="danger">{$LL.monitorBackupFailed()}</Badge>{/if}
            <Button size="sm" variant="secondary" icon="backup" disabled={!view.key_id || !view.enabled || view.running} onclick={() => void runNow()}>
              {#if view.running}<Spinner size={14} />{/if}
              {$LL.monitorBackupRunNow()}
            </Button>
          </div>
        </Row>
      </Group>

      <Group title={$LL.monitorBackupList()}>
        {#if listing && !backups}
          <div class="flex justify-center py-[13px]"><Spinner size={18} /></div>
        {:else if backups && backups.length === 0}
          <p class="py-[11px] text-[13px] text-(--text-secondary)">{$LL.monitorBackupListEmpty()}</p>
        {:else if backups}
          {#each backups as b (b.name)}
            <Row label={when(b.created_at)} sub={`${fmtBytes(b.size)} · ${b.key_id}`}>
              <div class="flex items-center gap-[7px]">
                {#if !b.own}
                  <Badge tone="accent">{$LL.monitorBackupOtherServer()}</Badge>
                {:else if !b.current_key}
                  <Badge tone="neutral">{$LL.monitorBackupOlderKey()}</Badge>
                {/if}
                <Button size="sm" variant="secondary" onclick={() => ((restoring = b), (restoreError = null))}>{$LL.monitorBackupRestore()}</Button>
              </div>
            </Row>
          {/each}
        {/if}
        {#if listError}<p class="py-[11px] text-[13px] text-(--color-danger)" role="alert">{listError}</p>{/if}
      </Group>
    {/if}
  {/if}
</SettingsPage>

<Dialog open={keyOpen} wide title={view?.key_id ? $LL.monitorBackupKeyChange() : $LL.monitorBackupKeySetAction()} onclose={() => (keyOpen = false)}>
  <form id="backup-key-form" class="space-y-[13px]" onsubmit={(e) => (e.preventDefault(), setKey())}>
    <p class="text-[13px] text-(--text-secondary)">{$LL.monitorBackupKeyBody()}</p>
    <p class="text-[13px] font-medium text-(--color-warning)">{$LL.monitorBackupKeyWarning()}</p>
    <Input
      id="backup-passphrase"
      label={$LL.monitorBackupPassphrase()}
      type="password"
      autocomplete="new-password"
      error={passphraseShort ? $LL.monitorBackupPassphraseShort({ min: view?.min_passphrase ?? 12 }) : undefined}
      bind:value={passphrase}
    />
    <Input
      id="backup-passphrase-again"
      label={$LL.monitorBackupPassphraseAgain()}
      type="password"
      autocomplete="new-password"
      error={passphraseMismatch ? $LL.monitorBackupPassphraseMismatch() : undefined}
      bind:value={passphraseAgain}
    />
  </form>
  {#snippet actions()}
    <Button variant="secondary" type="button" onclick={() => (keyOpen = false)}>{$LL.cancel()}</Button>
    <Button type="submit" form="backup-key-form" disabled={!passphrase || passphraseShort || passphrase !== passphraseAgain}>{$LL.monitorBackupKeySave()}</Button>
  {/snippet}
</Dialog>

<Dialog open={restoring !== null} wide title={$LL.monitorBackupRestoreTitle()} onclose={() => (restoring = null)}>
  <form id="backup-restore-form" class="space-y-[13px]" onsubmit={(e) => (e.preventDefault(), restore())}>
    <p class="text-[13px] text-(--text-secondary)">{$LL.monitorBackupRestoreBody({ when: restoring ? when(restoring.created_at) : '' })}</p>
    <p class="text-[13px] font-medium text-(--color-warning)">{$LL.monitorBackupRestoreWarning()}</p>
    <Input id="backup-restore-passphrase" label={$LL.monitorBackupPassphrase()} type="password" autocomplete="off" bind:value={restorePassphrase} />
    {#if restoreError}<p class="text-[13px] text-(--color-danger)" role="alert">{restoreError}</p>{/if}
  </form>
  {#snippet actions()}
    <Button variant="secondary" type="button" onclick={() => (restoring = null)}>{$LL.cancel()}</Button>
    <Button type="submit" form="backup-restore-form" variant="destructive" disabled={!restorePassphrase}>{$LL.monitorBackupRestore()}</Button>
  {/snippet}
</Dialog>

<ReauthDialog
  open={asking !== null}
  message={asking?.message}
  onconfirm={async (own) => {
    await asking?.run(own)
  }}
  onclose={() => (asking = null)}
/>
