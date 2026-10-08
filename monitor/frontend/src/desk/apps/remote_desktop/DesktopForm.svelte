<script module lang="ts">
  import type { Desktop, DesktopProtocol, DesktopProtocolView } from '../../../types'
  import { newId } from '../../../lib/newId'

  /// The form's fields, in the shapes the form edits: the port is text, so it
  /// can be emptied while it is retyped. The page owns this object and seeds
  /// it when the dialog opens.
  export interface DesktopFormState {
    id: string
    name: string
    protocol: DesktopProtocol
    host: string
    port: string
    username: string
    domain: string
    viewOnly: boolean
    shared: boolean
    /// Whether the port still follows the protocol: true for a new route
    /// until the port is typed in.
    portFollowsProtocol: boolean
  }

  export function desktopFormState(
    desktop?: Desktop,
    protocols: DesktopProtocolView[] = [],
  ): DesktopFormState {
    const protocol = desktop?.protocol ?? protocols[0]?.id ?? 'vnc'
    return {
      id: desktop?.id ?? newId(),
      name: desktop?.name ?? '',
      protocol,
      host: desktop?.host ?? '127.0.0.1',
      port: String(desktop?.port ?? defaultPort(protocols, protocol)),
      username: desktop?.username ?? '',
      domain: desktop?.domain ?? '',
      viewOnly: desktop?.view_only ?? false,
      shared: desktop?.shared ?? true,
      portFollowsProtocol: desktop === undefined,
    }
  }

  /// Sent by the agent rather than hard-coded here.
  export function defaultPort(protocols: DesktopProtocolView[], protocol: DesktopProtocol): number {
    return protocols.find((entry) => entry.id === protocol)?.default_port ?? 0
  }

  /// The route the set should hold, whole, since a `PUT` replaces the set. An
  /// empty user name or domain is `null`, which is how a value is cleared; a
  /// port that is not a number is 0, which the agent refuses as `invalidPort`.
  export function desktopDraftOf(fields: DesktopFormState): Desktop {
    const port = Number.parseInt(fields.port.trim(), 10)
    return {
      id: fields.id,
      name: fields.name.trim(),
      protocol: fields.protocol,
      host: fields.host.trim(),
      port: Number.isInteger(port) && port > 0 && port <= 65535 ? port : 0,
      username: fields.username.trim() || null,
      domain: fields.protocol === 'rdp' ? fields.domain.trim() || null : null,
      view_only: fields.viewOnly,
      shared: fields.shared,
    }
  }
</script>

<script lang="ts">
  import { Button, Checkbox, Input, Select } from '@lollipopkit/desk-ui'
  import { LL } from '../../../i18n/i18n-svelte'

  interface Props {
    /// The route being changed, or `undefined` for a new one.
    desktop?: Desktop
    protocols: DesktopProtocolView[]
    fields: DesktopFormState
    onsaved: (desktop: Desktop) => void
    oncancel: () => void
  }

  const { desktop, protocols, fields, onsaved, oncancel }: Props = $props()

  const editing = $derived(desktop !== undefined)

  function changeProtocol(next: string) {
    const protocol = next as DesktopProtocol
    if (fields.portFollowsProtocol) fields.port = String(defaultPort(protocols, protocol))
    fields.protocol = protocol
  }
</script>

<div class="grid gap-[13px]">
  <Input id="desktop-name" bind:value={fields.name} label={$LL.desktopName()} placeholder="office" />

  <div class="grid gap-[13px] @2xl:grid-cols-3">
    <Select
      id="desktop-protocol"
      class="w-full"
      label={$LL.desktopProtocol()}
      value={fields.protocol}
      options={protocols.map((protocol) => ({ value: protocol.id, label: protocol.id.toUpperCase() }))}
      onchange={(e: Event) => changeProtocol((e.currentTarget as HTMLSelectElement).value)}
    />
    <div class="@2xl:col-span-2">
      <Input id="desktop-host" bind:value={fields.host} label={$LL.desktopHost()} placeholder="127.0.0.1" hint={$LL.desktopHostHint()} />
    </div>
  </div>

  <div class="grid gap-[13px] @2xl:grid-cols-2">
    <Input id="desktop-port" label={$LL.desktopPort()} inputmode="numeric" bind:value={fields.port} oninput={() => (fields.portFollowsProtocol = false)} mono />
    <Input id="desktop-username" bind:value={fields.username} label={$LL.desktopUsername()} />
  </div>

  <!-- A Windows account's domain; VNC has none. -->
  {#if fields.protocol === 'rdp'}<Input id="desktop-domain" bind:value={fields.domain} label={$LL.desktopDomain()} />{/if}

  <div class="grid gap-[9px]">
    <Checkbox bind:checked={fields.viewOnly} label={$LL.desktopViewOnly()} />
    <Checkbox bind:checked={fields.shared} label={$LL.desktopShared()} />
  </div>

  <!-- No password field: a route stores none. -->
  <p class="text-[12px] text-(--text-secondary)">{$LL.desktopPasswordHint()}</p>

  <div class="flex justify-end gap-[7px]">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button variant="primary" onclick={() => onsaved(desktopDraftOf(fields))}>{editing ? $LL.save() : $LL.desktopAdd()}</Button>
  </div>
</div>
