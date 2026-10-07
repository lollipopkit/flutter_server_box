<script lang="ts">
  import { Button, Card, Input, Select } from '../../lk/index'
  import { prettyFingerprint } from '../../../lib/bmc'
  import { pveDraft } from '../../../lib/virt'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { PveAuthKind, PveConfigInput, PveConfigView } from '../../../types'

  /// How this agent reaches the Proxmox VE API of its host. A secret is never
  /// shown: empty keeps the stored one. The certificate is not entered here:
  /// the page shows the one the API presents and an admin trusts it there.
  interface Props {
    current: PveConfigView | null
    busy: boolean
    onsaved: (config: PveConfigInput) => void
    oncancel: () => void
  }

  const { current, busy, onsaved, oncancel }: Props = $props()

  // Seeded once from what the dialog opened on.
  const initial = (() => pveDraft(current))()
  let addr = $state(initial.addr)
  let auth = $state<PveAuthKind>(initial.auth)
  let username = $state(initial.username ?? 'root@pam')
  let password = $state('')
  let tokenId = $state(initial.token_id ?? '')
  let tokenSecret = $state('')
  let pin = $state(initial.cert_sha256)

  /// A pin belongs to the address it was confirmed for.
  function changeAddr(next: string) {
    addr = next
    if (next.trim() !== (current?.addr ?? '')) pin = null
  }

  function submit(e: SubmitEvent) {
    e.preventDefault()
    onsaved({
      addr: addr.trim(),
      auth,
      username: auth === 'password' ? username.trim() : current?.username ?? null,
      password: password === '' ? null : password,
      token_id: auth === 'token' ? tokenId.trim() : current?.token_id ?? null,
      token_secret: tokenSecret === '' ? null : tokenSecret,
      cert_sha256: pin,
    })
  }
</script>

<form class="space-y-[13px]" onsubmit={submit}>
  <Input
    id="pve-addr"
    label={$LL.pveAddr()}
    hint={$LL.pveAddrHint()}
    value={addr}
    oninput={(e: Event) => changeAddr((e.currentTarget as HTMLInputElement).value)}
    placeholder="https://127.0.0.1:8006"
  />

  <Select
    id="pve-auth"
    label={$LL.pveAuth()}
    class="w-full"
    bind:value={auth}
    options={[
      { value: 'token', label: $LL.pveAuthToken() },
      { value: 'password', label: $LL.pveAuthPassword() },
    ]}
  />

  {#if auth === 'token'}
    <div class="grid gap-[13px] @2xl:grid-cols-2">
      <Input id="pve-token-id" label={$LL.pveTokenId()} autocomplete="off" bind:value={tokenId} placeholder="root@pam!serverbox" />
      <Input
        id="pve-token-secret"
        label={$LL.pveTokenSecret()}
        type="password"
        autocomplete="new-password"
        bind:value={tokenSecret}
        placeholder={current?.has_token_secret ? $LL.bmcPasswordKept() : ''}
      />
    </div>
    <p class="text-[12px] text-(--text-tertiary) whitespace-pre-wrap">{$LL.pveTokenHint()}</p>
  {:else}
    <div class="grid gap-[13px] @2xl:grid-cols-2">
      <Input id="pve-user" label={$LL.bmcUsername()} autocomplete="off" bind:value={username} placeholder="root@pam" />
      <Input
        id="pve-password"
        label={$LL.bmcPassword()}
        type="password"
        autocomplete="new-password"
        bind:value={password}
        placeholder={current?.has_password ? $LL.bmcPasswordKept() : ''}
      />
    </div>
    <p class="text-[12px] text-(--text-tertiary)">{$LL.pvePasswordHint()}</p>
  {/if}

  <Card class="space-y-[9px]" title={$LL.bmcCert()} icon="shield_lock">
    {#if pin}
      <p class="break-all lk-mono text-[12px] text-(--text-secondary)">{prettyFingerprint(pin)}</p>
      <Button type="button" variant="secondary" size="sm" onclick={() => (pin = null)}>{$LL.pveCertForget()}</Button>
    {:else}
      <p class="text-[12px] text-(--text-tertiary)">{$LL.pveCertNone()}</p>
    {/if}
  </Card>

  <div class="flex justify-end gap-[9px]">
    <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button type="submit" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
