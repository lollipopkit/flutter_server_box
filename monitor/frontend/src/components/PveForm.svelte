<script lang="ts">
  import { Button, Input, Select } from '@serverbox/webui'
  import { prettyFingerprint } from '../lib/bmc'
  import { pveDraft } from '../lib/virt'
  import { LL } from '../i18n/i18n-svelte'
  import type { PveAuthKind, PveConfigInput, PveConfigView } from '../types'

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

<form class="space-y-4" onsubmit={submit}>
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="pve-addr">{$LL.pveAddr()}</label>
    <Input
      id="pve-addr"
      value={addr}
      oninput={(e: Event) => changeAddr((e.currentTarget as HTMLInputElement).value)}
      placeholder="https://127.0.0.1:8006"
    />
    <p class="text-xs text-muted-fg">{$LL.pveAddrHint()}</p>
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="pve-auth">{$LL.pveAuth()}</label>
    <Select id="pve-auth" class="w-full" bind:value={auth}>
      <option value="token">{$LL.pveAuthToken()}</option>
      <option value="password">{$LL.pveAuthPassword()}</option>
    </Select>
  </div>

  {#if auth === 'token'}
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="pve-token-id">{$LL.pveTokenId()}</label>
        <Input id="pve-token-id" autocomplete="off" bind:value={tokenId} placeholder="root@pam!serverbox" />
      </div>
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="pve-token-secret">{$LL.pveTokenSecret()}</label>
        <Input
          id="pve-token-secret"
          type="password"
          autocomplete="new-password"
          bind:value={tokenSecret}
          placeholder={current?.has_token_secret ? $LL.bmcPasswordKept() : ''}
        />
      </div>
    </div>
    <p class="text-xs text-muted-fg whitespace-pre-wrap">{$LL.pveTokenHint()}</p>
  {:else}
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="pve-user">{$LL.bmcUsername()}</label>
        <Input id="pve-user" autocomplete="off" bind:value={username} placeholder="root@pam" />
      </div>
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="pve-password">{$LL.bmcPassword()}</label>
        <Input
          id="pve-password"
          type="password"
          autocomplete="new-password"
          bind:value={password}
          placeholder={current?.has_password ? $LL.bmcPasswordKept() : ''}
        />
      </div>
    </div>
    <p class="text-xs text-muted-fg">{$LL.pvePasswordHint()}</p>
  {/if}

  <div class="space-y-2 rounded-lg border border-line p-3">
    <p class="text-sm text-fg-strong">{$LL.bmcCert()}</p>
    {#if pin}
      <p class="break-all font-mono text-xs text-muted-fg">{prettyFingerprint(pin)}</p>
      <Button type="button" variant="secondary" size="sm" onclick={() => (pin = null)}>{$LL.pveCertForget()}</Button>
    {:else}
      <p class="text-xs text-muted-fg">{$LL.pveCertNone()}</p>
    {/if}
  </div>

  <div class="flex justify-end gap-2">
    <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button type="submit" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
