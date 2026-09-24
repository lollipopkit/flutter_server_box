<script module lang="ts">
  // `PveAuthKind` is imported in the instance script: the two scripts of one
  // component share a scope, so it is one import for both.
  import type { PveSettingsPayload, PveSettingsView } from '../types'

  /// The form's own fields.
  ///
  /// The page owns this object and seeds it when the dialog opens, the way
  /// `DesktopForm` does. `secret` is a plain string even though the wire type
  /// is `string | null`, because the three states a field has — blank meaning
  /// keep, blank meaning none is stored, and typed — are told apart by
  /// `secretSet` beside it rather than by the value.
  export interface PveSettingsState {
    url: string
    auth: PveAuthKind
    username: string
    realm: string
    tokenId: string
    /// What was typed in the secret field this time. Never seeded from the
    /// view: the agent does not send one back.
    secret: string
    /// Whether the agent holds a credential, which is what makes "leave it
    /// blank" mean *keep* rather than *none*.
    secretSet: boolean
    /// Clears the stored credential. A separate control because an empty
    /// secret field already means "keep what is there", so without this a
    /// stored credential could never be removed from this panel.
    clearSecret: boolean
    ignoreCert: boolean
  }

  export function pveSettingsState(view: PveSettingsView): PveSettingsState {
    return {
      url: view.url,
      auth: view.auth,
      username: view.username,
      realm: view.realm,
      tokenId: view.token_id,
      secret: '',
      secretSet: view.secret_set,
      clearSecret: false,
      ignoreCert: view.ignore_cert,
    }
  }

  /// The whole section, as the endpoint takes it: a `PUT` replaces what it
  /// names, so every field is sent and an empty address is how the section is
  /// cleared.
  ///
  /// `secret` follows the push convention — `null` keeps what is stored, `""`
  /// clears it, anything else replaces it. Clearing wins over a typed value:
  /// the two cannot both be meant, and a typed secret beside a checked clear is
  /// more likely a change of mind than a request to store what was typed.
  export function pveSettingsPayload(fields: PveSettingsState): PveSettingsPayload {
    const typed = fields.secret.trim()
    return {
      url: fields.url.trim(),
      auth: fields.auth,
      username: fields.username.trim(),
      realm: fields.realm.trim(),
      token_id: fields.tokenId.trim(),
      secret: fields.clearSecret ? '' : typed === '' ? null : typed,
      ignore_cert: fields.ignoreCert,
    }
  }
</script>

<script lang="ts">
  import { Button, Input, Select } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import type { PveAuthKind } from '../types'

  interface Props {
    /// The fields, seeded by the page and edited here in place.
    fields: PveSettingsState
    /// Called with the section once the page's request is accepted. The page
    /// owns the request and the notice; this owns the fields.
    onsaved: (section: PveSettingsPayload) => void
    oncancel: () => void
  }

  const { fields, onsaved, oncancel }: Props = $props()

  /// A token credential is the same account name plus a token id, so the user
  /// and realm are asked for either way and only the id is additional.
  const token = $derived(fields.auth === 'token')

  /// Clearing and typing are the same field, so one takes precedence rather
  /// than the two being able to disagree on save. Typing in the secret field
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
    <label class="text-sm text-muted-fg" for="pve-url">{$LL.pveUrl()}</label>
    <Input id="pve-url" bind:value={fields.url} placeholder="https://10.0.0.7:8006" />
    <p class="text-xs text-muted-fg">{$LL.pveUrlHint()}</p>
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="pve-auth">{$LL.pveAuth()}</label>
    <Select
      class="w-full"
      value={fields.auth}
      onchange={(e: Event) =>
        (fields.auth = (e.currentTarget as HTMLSelectElement).value as PveAuthKind)}
    >
      <option value="password">{$LL.pveAuthPassword()}</option>
      <option value="token">{$LL.pveAuthToken()}</option>
    </Select>
  </div>

  <div class="grid gap-4 sm:grid-cols-2">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="pve-username">{$LL.pveUsername()}</label>
      <Input id="pve-username" bind:value={fields.username} placeholder="root" />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="pve-realm">{$LL.pveRealm()}</label>
      <Input id="pve-realm" bind:value={fields.realm} placeholder="pam" />
    </div>
  </div>

  {#if token}
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="pve-token">{$LL.pveTokenId()}</label>
      <Input id="pve-token" bind:value={fields.tokenId} placeholder="automation" />
    </div>
  {/if}

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="pve-secret">{$LL.pveSecret()}</label>
    <Input
      id="pve-secret"
      type="password"
      bind:value={fields.secret}
      placeholder={fields.secretSet ? $LL.pushSecretKeep() : ''}
      disabled={fields.clearSecret}
      oninput={onSecretInput}
    />
    <p class="text-xs text-muted-fg">
      {fields.secretSet ? $LL.pveSecretKeepHint() : $LL.pveSecretNone()}
    </p>
    {#if fields.secretSet}
      <label class="flex items-center gap-2 text-sm text-fg">
        <input
          type="checkbox"
          checked={fields.clearSecret}
          onchange={(e: Event) => toggleClear((e.currentTarget as HTMLInputElement).checked)}
        />
        {$LL.pveSecretClear()}
      </label>
    {/if}
  </div>

  {#if token}
    <p class="text-xs text-muted-fg">{$LL.pveTokenNote()}</p>
  {:else}
    <p class="text-xs text-muted-fg">{$LL.pvePasswordNote()}</p>
  {/if}

  <div class="space-y-1">
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.ignoreCert} />
      {$LL.pveIgnoreCert()}
    </label>
    <p class="text-xs text-muted-fg">{$LL.pveIgnoreCertHint()}</p>
  </div>

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button onclick={() => onsaved(pveSettingsPayload(fields))}>{$LL.save()}</Button>
  </div>
</div>
