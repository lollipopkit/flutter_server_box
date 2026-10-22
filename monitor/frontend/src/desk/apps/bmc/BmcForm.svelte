<script lang="ts">
  import { Button, Input } from '../../lk'
  import { api } from '../../../lib/api'
  import { bmcErrorText, prettyFingerprint } from '../../../lib/bmc'
  import { newId } from '../../../lib/newId'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { BmcCertInfo, BmcTarget, BmcTargetInput } from '../../../types'

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

<form id="bmc-form" class="grid gap-[13px]" onsubmit={submit}>
  <Input id="bmc-name" bind:value={name} label={$LL.bmcName()} placeholder="rack-1" />
  <Input
    id="bmc-url"
    value={url}
    label={$LL.bmcUrl()}
    hint={$LL.bmcUrlHint()}
    oninput={(e: Event) => changeUrl((e.currentTarget as HTMLInputElement).value)}
    placeholder="https://10.0.0.9"
    mono
  />
  <div class="grid gap-[13px] @2xl:grid-cols-2">
    <Input id="bmc-username" autocomplete="off" bind:value={username} label={$LL.bmcUsername()} />
    <Input id="bmc-password" type="password" autocomplete="new-password" bind:value={password} label={$LL.bmcPassword()} placeholder={initial?.has_password ? $LL.bmcPasswordKept() : ''} />
  </div>

  <section class="rounded-[13px] bg-(--surface-card) p-[13px_15px]">
    <h3 class="text-[15px] font-semibold">{$LL.bmcCert()}</h3>
    {#if pin}<p class="lk-mono mt-[7px] break-all text-[12px] text-(--text-secondary)">{prettyFingerprint(pin)}</p>
    {:else}<p class="mt-[7px] text-[12px] text-(--text-secondary)">{$LL.bmcCertNone()}</p>{/if}
    <Button type="button" class="mt-[9px]" variant="secondary" size="sm" icon="refresh" disabled={probing} onclick={() => void probe()}>{$LL.bmcCertRead()}</Button>
    {#if probeError}<p class="mt-[7px] text-[12px] text-(--color-danger)">{probeError}</p>{/if}
    {#if probed}
      {@const cert = probed}
      <dl class="mt-[9px] grid grid-cols-1 gap-x-[13px] @2xl:grid-cols-2">
        <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.bmcCertSubject()}</dt><dd class="break-all text-[12px]">{cert.subject}</dd></div>
        <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.bmcCertIssuer()}</dt><dd class="break-all text-[12px]">{cert.issuer}</dd></div>
        <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.bmcCertValid()}</dt><dd class="lk-num text-right text-[12px]">{date(cert.not_before)} – {date(cert.not_after)}</dd></div>
        <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">SHA-256</dt><dd class="lk-mono break-all text-right text-[12px]">{prettyFingerprint(cert.fingerprint)}</dd></div>
      </dl>
      {#if cert.not_after * 1000 < Date.now()}<p class="mt-[7px] text-[12px] text-(--color-warning)">{$LL.bmcCertExpired()}</p>{/if}
      <p class="mt-[7px] text-[12px] text-(--text-secondary)">{$LL.bmcCertCompare()}</p>
      <Button type="button" class="mt-[9px]" size="sm" variant="primary" icon="lock" onclick={() => (pin = cert.fingerprint)}>{$LL.bmcCertTrust()}</Button>
    {/if}
  </section>

  <div class="flex justify-end gap-[7px]">
    <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button type="submit" variant="primary" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
