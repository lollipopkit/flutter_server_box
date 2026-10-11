<script lang="ts">
  /// The machine's file shares (`/shares`): SMB (Samba) shares and NFS
  /// exports. ServerBox's own are changed here; those set up elsewhere are
  /// shown as they are. Every change is root's, asked about with sudo's
  /// password (`SudoDialog`); installing Samba or the NFS server is a job.

  import { AppToolbar, SplitView, useWindow } from '../../sys'
  import { Badge, Button, Card, Checkbox, Dialog, Group, Icon, IconButton, Input, Row, Select, SidebarItem, SidebarSection, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError, api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { DATE_TIME, fmtDate, parseTimestamp } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import type { NfsClient, NfsExport, ShareConnections, SharesView, SmbShare, StackJob } from '../../../types'
  import SudoDialog from './SudoDialog.svelte'
  import { firewallIntent, mountedFolders, shareNameOk, withExport, withShare, withoutExport, withoutShare } from './model'
  import { untrack } from 'svelte'

  type Tab = 'smb' | 'nfs'

  let tab = $state<Tab>('smb')
  let view = $state<SharesView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  /// Accounts that may be given an SMB password, when the agent lists them.
  let accounts = $state<string[]>([])
  /// The change being asked about.
  let pending = $state<{ title: string; body: string; run: (sudo: string) => Promise<void> } | null>(null)
  let smbDraft = $state<SmbShare | null>(null)
  let smbOriginal = $state<string | null>(null)
  let nfsDraft = $state<NfsExport | null>(null)
  let nfsOriginal = $state<string | null>(null)
  let passwordUser = $state('')
  let passwordFor = $state<string | null>(null)
  let newPassword = $state('')
  let newPassword2 = $state('')
  let connections = $state<ShareConnections | null>(null)
  let connectionsLocked = $state(false)
  let connectionsTried = false
  let folderOptions = $state<string[]>([])
  let foldersTried = false
  const win = useWindow()
  const folderListId = `sharing-folders-${win.id || 'detached'}`
  const canFirewall = $derived(capabilitiesStore.byServer[servers.currentId]?.features?.includes('firewall') === true)

  async function load(serverId = servers.currentId) {
    try {
      const next = await api.getShares()
      if (serverId !== servers.currentId) return
      view = next
      error = ''
      if (next.job?.state === 'running') job = next.job
      void loadFolders(serverId)
      if (!connectionsTried && (next.tools.includes('smbd') || next.tools.includes('exportfs'))) {
        connectionsTried = true
        void readConnections(serverId)
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function loadAccounts(serverId = servers.currentId) {
    try {
      const v = await api.getSystemUsers('list')
      if (serverId !== servers.currentId) return
      accounts = v.users.filter((u) => !u.system && !u.is_root).map((u) => u.name)
      passwordUser = accounts[0] ?? ''
    } catch {
      accounts = []
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      connectionsTried = false
      connectionsLocked = false
      connections = null
      foldersTried = false
      folderOptions = []
      void capabilitiesStore.ensure(serverId)
      void load(serverId)
      void loadAccounts(serverId)
    })
  })

  $effect(() => {
    const serverId = servers.currentId
    const hasStorage = capabilitiesStore.byServer[serverId]?.features?.includes('storage') === true
    if (hasStorage) void loadFolders(serverId)
  })

  const has = (tool: string) => view?.tools.includes(tool) === true

  async function loadFolders(serverId = servers.currentId) {
    if (foldersTried || capabilitiesStore.byServer[serverId]?.features?.includes('storage') !== true) return
    foldersTried = true
    try {
      const storage = await api.getStorage()
      if (serverId === servers.currentId) folderOptions = mountedFolders(storage)
    } catch {
      if (serverId === servers.currentId) folderOptions = []
    }
  }

  async function readConnections(serverId = servers.currentId, sudo = '', quiet = true): Promise<boolean> {
    try {
      const result = await api.shareConnections(sudo)
      if (serverId !== servers.currentId) return false
      connections = result
      connectionsLocked = false
      return true
    } catch (e) {
      if (serverId === servers.currentId && e instanceof ApiError && e.status === 403) connectionsLocked = true
      if (!quiet) throw e
      return false
    }
  }

  function askConnections() {
    ask($LL.sharingShowConnections(), $LL.sharingShowConnectionsBody(), async (sudo) => {
      await readConnections(servers.currentId, sudo, false)
      pending = null
    })
  }

  function refreshConnections() {
    if (connectionsLocked) askConnections()
    else void readConnections()
  }

  function allowFirewall(protocol: Tab) {
    win.open('serverbox.firewall', { intent: firewallIntent(protocol) })
  }

  function connectionSince(value: string | null): string | undefined {
    if (!value) return undefined
    const date = parseTimestamp(value)
    return Number.isNaN(date.getTime()) ? undefined : fmtDate(date, DATE_TIME)
  }

  function ask(title: string, body: string, run: (sudo: string) => Promise<void>) {
    pending = { title, body, run }
  }

  function install(nfs: boolean) {
    ask(nfs ? $LL.sharingInstallNfs() : $LL.sharingInstallSamba(), nfs ? $LL.sharingInstallNfsBody() : $LL.sharingInstallSambaBody(), async (sudo) => {
      job = await api.installShares(nfs, sudo)
      pending = null
    })
  }

  // SMB ----------------------------------------------------------------------

  function newShare() {
    smbOriginal = null
    smbDraft = {
      name: '',
      path: '/mnt/',
      comment: null,
      read_only: false,
      guest: false,
      users: [],
      time_machine: false,
      recycle: false,
      managed: true,
    }
  }

  function editShare(s: SmbShare) {
    smbOriginal = s.name
    smbDraft = { ...s, users: [...s.users] }
  }

  function saveShare() {
    const draft = smbDraft!
    const list = withShare(view!.smb, draft, smbOriginal)
    smbDraft = null
    ask($LL.sharingSave(), $LL.sharingSaveSmbBody({ name: draft.name, path: draft.path }), async (sudo) => {
      view = { ...(await api.setSmbShares(list, sudo)), job: view?.job ?? null }
      pending = null
    })
  }

  function removeShare(s: SmbShare) {
    ask($LL.sharingRemove(), $LL.sharingRemoveSmbBody({ name: s.name }), async (sudo) => {
      view = { ...(await api.setSmbShares(withoutShare(view!.smb, s.name), sudo)), job: view?.job ?? null }
      pending = null
    })
  }

  function smbAccess(s: SmbShare): string {
    return [
      s.read_only ? $LL.sharingReadOnly() : $LL.sharingReadWrite(),
      s.guest ? $LL.sharingGuest() : undefined,
      s.time_machine ? $LL.sharingTimeMachine() : undefined,
      s.recycle ? $LL.sharingRecycle() : undefined,
      s.users.length ? s.users.join(', ') : undefined,
    ]
      .filter(Boolean)
      .join(' · ')
  }

  function toggleUser(user: string, on: boolean) {
    if (!smbDraft) return
    smbDraft.users = on ? [...smbDraft.users, user] : smbDraft.users.filter((u) => u !== user)
  }

  function setPassword() {
    const user = passwordFor!
    const password = newPassword
    passwordFor = null
    ask($LL.sharingSetPassword(), $LL.sharingSetPasswordBody({ user }), async (sudo) => {
      await api.setSmbPassword(user, password, sudo)
      pending = null
      newPassword = ''
      newPassword2 = ''
    })
  }

  // NFS ----------------------------------------------------------------------

  const client = (): NfsClient => ({ host: '', read_only: false, squash: 'root', options: [] })

  function newExport() {
    nfsOriginal = null
    nfsDraft = { path: '/mnt/', clients: [client()], managed: true }
  }

  function editExport(e: NfsExport) {
    nfsOriginal = e.path
    nfsDraft = { ...e, clients: e.clients.map((c) => ({ ...c })) }
  }

  function saveExport() {
    const draft = nfsDraft!
    const list = withExport(view!.nfs, draft, nfsOriginal)
    nfsDraft = null
    ask($LL.sharingSave(), $LL.sharingSaveNfsBody({ path: draft.path }), async (sudo) => {
      view = { ...(await api.setNfsExports(list, sudo)), job: view?.job ?? null }
      pending = null
    })
  }

  function removeExport(e: NfsExport) {
    ask($LL.sharingRemove(), $LL.sharingRemoveNfsBody({ path: e.path }), async (sudo) => {
      view = { ...(await api.setNfsExports(withoutExport(view!.nfs, e.path), sudo)), job: view?.job ?? null }
      pending = null
    })
  }

  function clientText(c: NfsClient): string {
    const squash = c.squash === 'all' ? $LL.sharingSquashAll() : c.squash === 'none' ? $LL.sharingSquashNone() : $LL.sharingSquashRoot()
    return [c.read_only ? $LL.sharingReadOnly() : $LL.sharingReadWrite(), squash, ...c.options].join(' · ')
  }
</script>

{#snippet connected(rows: { label: string; sub: string | undefined }[] | undefined)}
  <Group title={$LL.sharingConnectedNow()}>
    {#if connectionsLocked}
      <Row label={$LL.sharingShowConnectionsBody()}>
        <Button size="sm" variant="secondary" onclick={askConnections}>{$LL.sharingShowConnections()}</Button>
      </Row>
    {:else if rows}
      {#each rows as r, i (`${r.label}:${i}`)}
        <Row label={r.label} sub={r.sub} mono />
      {:else}
        <Row label={$LL.sharingNobodyConnected()} />
      {/each}
      <div class="flex justify-end px-[13px] py-[9px]">
        <IconButton icon="refresh" label={$LL.refresh()} onclick={refreshConnections} />
      </div>
    {/if}
  </Group>
{/snippet}

<AppToolbar title={tab === 'smb' ? $LL.sharingSmb() : $LL.sharingNfs()}>
  {#snippet actions()}
    {#if tab === 'smb' && has('smbd')}
      <Button size="sm" icon="add" onclick={newShare}>{$LL.sharingAddShare()}</Button>
    {:else if tab === 'nfs' && has('exportfs')}
      <Button size="sm" icon="add" onclick={newExport}>{$LL.sharingAddExport()}</Button>
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      <SidebarItem label={$LL.sharingSmb()} icon="folder_shared" active={tab === 'smb'} trailing={view?.smb.length || undefined} onclick={() => (tab = 'smb')} />
      <SidebarItem label={$LL.sharingNfs()} icon="lan" active={tab === 'nfs'} trailing={view?.nfs.length || undefined} onclick={() => (tab = 'nfs')} />
    </SidebarSection>
  {/snippet}

  <div class="space-y-[13px] px-(--content-pad) pb-[21px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p>{error}</p></Card>
    {/if}
    {#if job}
      {#key job.id}
        <StackProgress
          {job}
          title={job.state === 'running' ? $LL.sharingInstalling() : job.state === 'succeeded' ? $LL.storageDone() : $LL.storageFailed()}
          read={(since) => api.sharesJob(since)}
          stop={null}
          ondone={(done) => {
            job = done
            void load()
          }}
        />
      {/key}
    {/if}

    {#if !view}
      {#if !error}<div class="flex justify-center py-12"><Spinner /></div>{/if}
    {:else if tab === 'smb'}
      {#if !has('smbd')}
        <Card class="flex items-center gap-[11px] text-[13px] text-(--text-secondary)">
          <p class="flex-1">{$LL.sharingNoSamba()}</p>
          <Button size="sm" icon="download" disabled={job?.state === 'running'} onclick={() => install(false)}>{$LL.sharingInstallSamba()}</Button>
        </Card>
      {:else}
        <Group title={$LL.sharingService()}>
          <Row label="Samba">
            <Badge tone={view.smb_active ? 'success' : 'neutral'}>{view.smb_active ? $LL.sharingRunning() : $LL.sharingStopped()}</Badge>
          </Row>
          {#if canFirewall}<Row label={$LL.sharingFirewall()}><Button size="sm" variant="secondary" onclick={() => allowFirewall('smb')}>{$LL.sharingAllowFirewall()}</Button></Row>{/if}
        </Group>
        {#each view.smb as s (s.name)}
          <Group title={s.name}>
            <Row label={s.path} sub={s.comment ?? undefined} value={smbAccess(s)} mono />
            <div class="flex items-center justify-end gap-[7px] px-[13px] py-[9px]">
              {#if s.managed}
                <Button size="sm" variant="ghost" onclick={() => removeShare(s)}>{$LL.sharingRemove()}</Button>
                <Button size="sm" variant="secondary" onclick={() => editShare(s)}>{$LL.sharingEdit()}</Button>
              {:else}
                <Badge tone="neutral">{$LL.sharingElsewhere()}</Badge>
              {/if}
            </div>
          </Group>
        {:else}
          <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)"><Icon name="folder_shared" size={48} /><p>{$LL.sharingNoShares()}</p></div>
        {/each}
        {@render connected(connections?.smb.map((c) => ({ label: `${c.share} · ${c.user ?? '—'} · ${c.machine}`, sub: connectionSince(c.since) })))}
        <Group title={$LL.sharingPasswords()}>
          <Row label={$LL.sharingPasswordsBody()}>
            <div class="flex shrink-0 gap-[7px]">
              {#if accounts.length}
                <Select value={passwordUser} options={accounts.map((a) => ({ value: a, label: a }))} onchange={(e: Event) => (passwordUser = (e.currentTarget as HTMLSelectElement).value)} aria-label={$LL.sharingAccount()} />
              {:else}
                <Input value={passwordUser} mono oninput={(e: Event) => (passwordUser = (e.currentTarget as HTMLInputElement).value)} aria-label={$LL.sharingAccount()} />
              {/if}
              <Button size="sm" variant="secondary" disabled={!passwordUser || !has('smbpasswd')} onclick={() => (passwordFor = passwordUser)}>{$LL.sharingSetPassword()}</Button>
            </div>
          </Row>
        </Group>
      {/if}
    {:else}
      {#if !has('exportfs')}
        <Card class="flex items-center gap-[11px] text-[13px] text-(--text-secondary)">
          <p class="flex-1">{$LL.sharingNoNfs()}</p>
          <Button size="sm" icon="download" disabled={job?.state === 'running'} onclick={() => install(true)}>{$LL.sharingInstallNfs()}</Button>
        </Card>
      {:else}
        <Group title={$LL.sharingService()}>
          <Row label={$LL.sharingNfsServer()}>
            <Badge tone={view.nfs_active ? 'success' : 'neutral'}>{view.nfs_active ? $LL.sharingRunning() : $LL.sharingStopped()}</Badge>
          </Row>
          {#if canFirewall}<Row label={$LL.sharingFirewall()}><Button size="sm" variant="secondary" onclick={() => allowFirewall('nfs')}>{$LL.sharingAllowFirewall()}</Button></Row>{/if}
        </Group>
        {@render connected(connections?.nfs.map((address) => ({ label: address, sub: undefined })))}
        {#each view.nfs as e (e.path + e.managed)}
          <Group title={e.path}>
            {#each e.clients as c, i (i)}
              <Row label={c.host} value={clientText(c)} mono />
            {/each}
            <div class="flex items-center justify-end gap-[7px] px-[13px] py-[9px]">
              {#if e.managed}
                <Button size="sm" variant="ghost" onclick={() => removeExport(e)}>{$LL.sharingRemove()}</Button>
                <Button size="sm" variant="secondary" onclick={() => editExport(e)}>{$LL.sharingEdit()}</Button>
              {:else}
                <Badge tone="neutral">{$LL.sharingElsewhere()}</Badge>
              {/if}
            </div>
          </Group>
        {:else}
          <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)"><Icon name="lan" size={48} /><p>{$LL.sharingNoExports()}</p></div>
        {/each}
      {/if}
    {/if}
  </div>
</SplitView>

{#if smbDraft}
  <Dialog open wide title={smbOriginal === null ? $LL.sharingAddShare() : $LL.sharingEdit()} onclose={() => (smbDraft = null)}>
    <div class="space-y-[9px] text-left">
      <datalist id={folderListId}>
        {#each folderOptions as path (path)}<option value={path}></option>{/each}
      </datalist>
      <Input label={$LL.storageName()} mono value={smbDraft.name} oninput={(e: Event) => (smbDraft!.name = (e.currentTarget as HTMLInputElement).value)} />
      <Input label={$LL.sharingFolder()} mono list={folderListId} value={smbDraft.path} hint={$LL.sharingFolderHint()} oninput={(e: Event) => (smbDraft!.path = (e.currentTarget as HTMLInputElement).value)} />
      <Input label={$LL.sharingComment()} value={smbDraft.comment ?? ''} oninput={(e: Event) => (smbDraft!.comment = (e.currentTarget as HTMLInputElement).value)} />
      <Checkbox bind:checked={smbDraft.read_only} label={$LL.sharingReadOnly()} />
      <Checkbox bind:checked={smbDraft.guest} label={$LL.sharingGuestLabel()} />
      <Checkbox bind:checked={smbDraft.time_machine} label={$LL.sharingTimeMachineOption()} />
      <Checkbox bind:checked={smbDraft.recycle} label={$LL.sharingRecycleOption()} />
      {#if accounts.length}
        <p class="text-[12px] text-(--text-tertiary)">{$LL.sharingUsersHint()}</p>
        {#each accounts as a (a)}
          <Checkbox checked={smbDraft.users.includes(a)} label={a} onchange={(e: Event) => toggleUser(a, (e.currentTarget as HTMLInputElement).checked)} />
        {/each}
      {/if}
    </div>
    {#snippet actions()}
      <Button block disabled={!shareNameOk(smbDraft!.name) || !smbDraft!.path.startsWith('/')} onclick={saveShare}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (smbDraft = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if nfsDraft}
  <Dialog open wide title={nfsOriginal === null ? $LL.sharingAddExport() : $LL.sharingEdit()} onclose={() => (nfsDraft = null)}>
    <datalist id={folderListId}>
      {#each folderOptions as path (path)}<option value={path}></option>{/each}
    </datalist>
    <div class="space-y-[9px] text-left">
      <Input label={$LL.sharingFolder()} mono list={folderListId} value={nfsDraft.path} hint={$LL.sharingFolderHint()} oninput={(e: Event) => (nfsDraft!.path = (e.currentTarget as HTMLInputElement).value)} />
      <p class="text-[12px] text-(--text-tertiary)">{$LL.sharingClientsHint()}</p>
      {#each nfsDraft.clients as c, i (i)}
        <div class="flex flex-wrap items-end gap-[7px]">
          <Input class="min-w-[160px] flex-1" label={$LL.sharingClient()} mono value={c.host} oninput={(e: Event) => (nfsDraft!.clients[i].host = (e.currentTarget as HTMLInputElement).value)} />
          <Select
            label={$LL.sharingSquash()}
            value={c.squash}
            options={[
              { value: 'root', label: $LL.sharingSquashRoot() },
              { value: 'all', label: $LL.sharingSquashAll() },
              { value: 'none', label: $LL.sharingSquashNone() },
            ]}
            onchange={(e: Event) => (nfsDraft!.clients[i].squash = (e.currentTarget as HTMLSelectElement).value as 'root')}
          />
          <Checkbox bind:checked={nfsDraft.clients[i].read_only} label={$LL.sharingReadOnly()} />
          <IconButton icon="remove" label={$LL.sharingRemove()} disabled={nfsDraft.clients.length === 1} onclick={() => (nfsDraft!.clients = nfsDraft!.clients.filter((_, j) => j !== i))} />
        </div>
      {/each}
      <Button size="sm" variant="ghost" icon="add" onclick={() => (nfsDraft!.clients = [...nfsDraft!.clients, client()])}>{$LL.sharingAddClient()}</Button>
    </div>
    {#snippet actions()}
      <Button block disabled={!nfsDraft!.path.startsWith('/') || !nfsDraft!.clients.some((c) => c.host.trim())} onclick={saveExport}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (nfsDraft = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if passwordFor}
  <Dialog open title={$LL.sharingSetPassword()} message={passwordFor} onclose={() => (passwordFor = null)}>
    <div class="space-y-[9px] text-left">
      <Input label={$LL.sharingNewPassword()} type="password" value={newPassword} oninput={(e: Event) => (newPassword = (e.currentTarget as HTMLInputElement).value)} />
      <Input
        label={$LL.sharingNewPasswordAgain()}
        type="password"
        value={newPassword2}
        error={newPassword2 && newPassword2 !== newPassword ? $LL.sharingPasswordsDiffer() : undefined}
        oninput={(e: Event) => (newPassword2 = (e.currentTarget as HTMLInputElement).value)}
      />
    </div>
    {#snippet actions()}
      <Button block disabled={!newPassword || newPassword !== newPassword2} onclick={setPassword}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (passwordFor = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

<SudoDialog open={!!pending} title={pending?.title ?? ''} body={pending?.body ?? ''} run={(sudo) => pending!.run(sudo)} onclose={() => (pending = null)} />
