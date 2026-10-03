<script lang="ts">
  import { Button, Input } from '@serverbox/webui'
  import { api } from '../lib/api'
  import { bmcErrorText, prettyFingerprint } from '../lib/bmc'
  import { newId } from '../lib/newId'
  import { LL } from '../i18n/i18n-svelte'
  import type { BmcCertInfo, BmcTarget, BmcTargetInput } from '../types'

  /// One BMC target's fields. The password is never shown: empty means
  /// "keep the stored one" for a target that has one. The certificate is
  /// pinned only from what this agent itself read off the address, after the
  /// operator compared it with the BMC's own console.
  interface Props {
    /// The target being changed, or `undefined` for a new one.
    target?: BmcTarget
    busy: boolean
    onsaved: (target: BmcTargetInput) => void
    oncancel: () => void
  }

  const { target, busy, onsaved, oncancel }: Props = $props()

  // Seeded once from the target the dialog opened on.
  const initial = (() => target)()
  let name = $state(initial?.name ?? '')
  let url = $state(initial?.url ?? 'https://')
  let username = $state(initial?.username ?? '')
  let password = $state('')
  let pin = $state<string | null>(initial?.cert_sha256 ?? null)
  let probed = $state<BmcCertInfo | null>(null)
  let probing = $state(false)
  let probeError = $state('')

  /// A pin belongs to the address it was read from.
  function changeUrl(next: string) {
    url = next
    if (next.trim() !== (initial?.url ?? '')) pin = null
    probed = null
  }

  async function probe() {
    probing = true
    probeError = ''
    probed = null
    try {
      probed = await api.probeBmc(url.trim())
    } catch (e) {
      probeError = bmcErrorText(e)
    } finally {
      probing = false
    }
  }

  function date(seconds: number): string {
    return new Date(seconds * 1000).toLocaleDateString()
  }

  function submit(e: SubmitEvent) {
    e.preventDefault()
    onsaved({
      id: initial?.id ?? newId(),
      name: name.trim(),
      url: url.trim(),
      username: username.trim(),
      password: password === '' && initial?.has_password ? null : password,
      cert_sha256: pin,
    })
  }
</script>

<form class="space-y-4" onsubmit={submit}>
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-name">{$LL.bmcName()}</label>
    <Input id="bmc-name" bind:value={name} placeholder="rack-1" />
  </div>
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-url">{$LL.bmcUrl()}</label>
    <Input
      id="bmc-url"
      value={url}
      oninput={(e: Event) => changeUrl((e.currentTarget as HTMLInputElement).value)}
      placeholder="https://10.0.0.9"
    />
    <p class="text-xs text-muted-fg">{$LL.bmcUrlHint()}</p>
  </div>
  <div class="grid gap-4 sm:grid-cols-2">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="bmc-username">{$LL.bmcUsername()}</label>
      <Input id="bmc-username" autocomplete="off" bind:value={username} />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="bmc-password">{$LL.bmcPassword()}</label>
      <Input
        id="bmc-password"
        type="password"
        autocomplete="new-password"
        bind:value={password}
        placeholder={initial?.has_password ? $LL.bmcPasswordKept() : ''}
      />
    </div>
  </div>

  <div class="space-y-2 rounded-lg border border-line p-3">
    <p class="text-sm text-fg-strong">{$LL.bmcCert()}</p>
    {#if pin}
      <p class="break-all font-mono text-xs text-muted-fg">{prettyFingerprint(pin)}</p>
    {:else}
      <p class="text-xs text-muted-fg">{$LL.bmcCertNone()}</p>
    {/if}
    <Button type="button" variant="secondary" size="sm" disabled={probing} onclick={() => void probe()}>
      {$LL.bmcCertRead()}
    </Button>
    {#if probeError}
      <p class="text-xs text-danger">{probeError}</p>
    {/if}
    {#if probed}
      {@const cert = probed}
      <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
        <dt class="text-faint-fg">{$LL.bmcCertSubject()}</dt>
        <dd class="break-all text-muted-fg">{cert.subject}</dd>
        <dt class="text-faint-fg">{$LL.bmcCertIssuer()}</dt>
        <dd class="break-all text-muted-fg">{cert.issuer}</dd>
        <dt class="text-faint-fg">{$LL.bmcCertValid()}</dt>
        <dd class="text-muted-fg">{date(cert.not_before)} – {date(cert.not_after)}</dd>
        <dt class="text-faint-fg">SHA-256</dt>
        <dd class="break-all font-mono text-muted-fg">{prettyFingerprint(cert.fingerprint)}</dd>
      </dl>
      {#if cert.not_after * 1000 < Date.now()}
        <p class="text-xs text-warning">{$LL.bmcCertExpired()}</p>
      {/if}
      <p class="text-xs text-muted-fg">{$LL.bmcCertCompare()}</p>
      <Button type="button" size="sm" onclick={() => (pin = cert.fingerprint)}>{$LL.bmcCertTrust()}</Button>
    {/if}
  </div>

  <div class="flex justify-end gap-2">
    <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button type="submit" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
