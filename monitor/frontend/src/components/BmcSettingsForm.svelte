<script module lang="ts">
  import type { BmcSettingsPayload, BmcSettingsView } from '../types'

  /// The form's own fields.
  ///
  /// The page owns this object and seeds it when the dialog opens, the way
  /// `PveSettingsForm` does. `secret` is a plain string even though the wire
  /// type is `string | null`, because the three states a field has — blank
  /// meaning keep, blank meaning none is stored, and typed — are told apart by
  /// `secretSet` beside it rather than by the value.
  export interface BmcSettingsState {
    url: string
    username: string
    /// What was typed in the password field this time. Never seeded from the
    /// view: the agent does not send one back.
    secret: string
    /// Whether the agent holds a password, which is what makes "leave it blank"
    /// mean *keep* rather than *none*.
    secretSet: boolean
    /// Clears the stored password. A separate control because an empty password
    /// field already means "keep what is there", so without this a stored
    /// password could never be removed from this panel.
    clearSecret: boolean
    /// The pin, as it will be stored. Seeded from the view, and replaced by
    /// what a probe answers.
    fingerprint: string
  }

  export function bmcSettingsState(view: BmcSettingsView): BmcSettingsState {
    return {
      url: view.url,
      username: view.username,
      secret: '',
      secretSet: view.secret_set,
      clearSecret: false,
      fingerprint: view.fingerprint,
    }
  }

  /// The whole section, as the endpoint takes it: a `PUT` replaces what it
  /// names, so every field is sent and an empty address is how the section is
  /// cleared.
  ///
  /// `secret` follows the push convention — `null` keeps what is stored, `""`
  /// clears it, anything else replaces it. Clearing wins over a typed value:
  /// the two cannot both be meant, and a typed password beside a checked clear
  /// is more likely a change of mind than a request to store what was typed.
  export function bmcSettingsPayload(fields: BmcSettingsState): BmcSettingsPayload {
    const typed = fields.secret.trim()
    return {
      url: fields.url.trim(),
      username: fields.username.trim(),
      secret: fields.clearSecret ? '' : typed === '' ? null : typed,
      fingerprint: fields.fingerprint.trim(),
    }
  }
</script>

<script lang="ts">
  import { Button, Input } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'

  interface Props {
    /// The fields, seeded by the page and edited here in place.
    fields: BmcSettingsState
    /// Called with the section once the page's request is accepted. The page
    /// owns the request and the notice; this owns the fields.
    onsaved: (section: BmcSettingsPayload) => void
    /// Reads the certificate at the address as it stands. The page owns the
    /// request; what it answers is written into the field here.
    onprobe: () => void
    /// Whether a probe is in flight, so the button can say so.
    probing: boolean
    oncancel: () => void
  }

  const { fields, onsaved, onprobe, probing, oncancel }: Props = $props()

  /// Clearing and typing are the same field, so one takes precedence rather
  /// than the two being able to disagree on save. Typing in the password field
  /// unchecks the box for the same reason.
  function toggleClear(next: boolean) {
    fields.clearSecret = next
    if (next) fields.secret = ''
  }

  function onSecretInput() {
    fields.clearSecret = false
  }
</script>

<div class="space-y-4">
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-url">{$LL.bmcUrl()}</label>
    <Input id="bmc-url" bind:value={fields.url} placeholder="https://10.0.0.5" />
    <p class="text-xs text-muted-fg">{$LL.bmcUrlHint()}</p>
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-username">{$LL.bmcUsername()}</label>
    <Input id="bmc-username" bind:value={fields.username} placeholder="root" />
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-secret">{$LL.bmcPassword()}</label>
    <Input
      id="bmc-secret"
      type="password"
      bind:value={fields.secret}
      placeholder={fields.secretSet ? $LL.pushSecretKeep() : ''}
      disabled={fields.clearSecret}
      oninput={onSecretInput}
    />
    <p class="text-xs text-muted-fg">
      {fields.secretSet ? $LL.bmcSecretKeepHint() : $LL.bmcSecretNone()}
    </p>
    {#if fields.secretSet}
      <label class="flex items-center gap-2 text-sm text-fg">
        <input
          type="checkbox"
          checked={fields.clearSecret}
          onchange={(e: Event) => toggleClear((e.currentTarget as HTMLInputElement).checked)}
        />
        {$LL.bmcSecretClear()}
      </label>
    {/if}
  </div>

  <!-- The pin comes first in the order the work happens: a certificate is
       looked at, then stored, and only then is there anything to log in to.
       A save without one is refused by the agent, so the two fields are not
       equally optional. -->
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="bmc-fingerprint">{$LL.bmcFingerprint()}</label>
    <div class="flex items-center gap-2">
      <Input id="bmc-fingerprint" bind:value={fields.fingerprint} class="font-mono" />
      <Button variant="secondary" disabled={probing} onclick={onprobe}>
        {probing ? $LL.bmcProbing() : $LL.bmcProbe()}
      </Button>
    </div>
    <p class="text-xs text-muted-fg">{$LL.bmcFingerprintHint()}</p>
  </div>

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button onclick={() => onsaved(bmcSettingsPayload(fields))}>{$LL.save()}</Button>
  </div>
</div>
