<script module lang="ts">
  import type { DesktopProtocol, DesktopProtocolView, DesktopTarget } from '../types'

  /// The form's own fields, in the shapes the form edits: the port is a text
  /// field, because a port held as a number cannot be emptied while it is being
  /// retyped.
  ///
  /// The page owns this object and seeds it when the dialog opens, the way the
  /// users page does: a form that seeded itself from a route prop would be
  /// holding a copy of a row the next save may replace.
  export interface DesktopFormState {
    name: string
    protocol: DesktopProtocol
    host: string
    port: string
    username: string
    domain: string
    viewOnly: boolean
    shared: boolean
    /// Whether the port still follows the protocol, which it does for a route
    /// being made and does not for one being changed — an existing port is that
    /// route's own, so `5901` on an RDP route is a typed port rather than a
    /// stale VNC default. The first keystroke in the port field settles it.
    portFollowsProtocol: boolean
  }

  /// What a form opens with, for a new route or for one being changed.
  export function desktopFormState(
    target?: DesktopTarget,
    protocols: DesktopProtocolView[] = [],
  ): DesktopFormState {
    const protocol = target?.protocol ?? protocols[0]?.id ?? 'vnc'
    return {
      name: target?.name ?? '',
      protocol,
      host: target?.host ?? '',
      port: String(target?.port ?? defaultPort(protocols, protocol)),
      username: target?.username ?? '',
      domain: target?.domain ?? '',
      viewOnly: target?.view_only ?? false,
      shared: target?.shared ?? true,
      portFollowsProtocol: target === undefined,
    }
  }

  /// The port a route of `protocol` is given when none is named. Sent by the
  /// agent rather than hard-coded here, so a default it changes reaches this
  /// panel without a change of its own.
  export function defaultPort(protocols: DesktopProtocolView[], protocol: DesktopProtocol): number {
    return protocols.find((entry) => entry.id === protocol)?.default_port ?? 0
  }

  /// The route the set should hold: the whole of it, not only what changed,
  /// because a `PUT` replaces the set.
  ///
  /// An empty `username` or `domain` is sent as `null` rather than omitted,
  /// which is how a value is cleared — the endpoint takes the whole object, so
  /// omitting one would keep a value the operator removed.
  export function routeDraftOf(fields: DesktopFormState): DesktopTarget {
    return {
      name: fields.name.trim(),
      protocol: fields.protocol,
      host: fields.host.trim(),
      port: Number(fields.port.trim()),
      username: fields.username.trim() || null,
      domain: fields.domain.trim() || null,
      view_only: fields.viewOnly,
      shared: fields.shared,
    }
  }
</script>

<script lang="ts">
  import { Button, Input, Select } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'

  interface Props {
    /// The route being changed, or `undefined` for a new one.
    target?: DesktopTarget
    /// The protocols the agent offers, and the port each is given by default.
    protocols: DesktopProtocolView[]
    /// The fields, seeded by the page and edited here in place.
    fields: DesktopFormState
    /// Called with the route once the page's request is accepted. The page owns
    /// the list, the request and the notice; this owns the fields.
    onsaved: (route: DesktopTarget) => void
    oncancel: () => void
  }

  const { target, protocols, fields, onsaved, oncancel }: Props = $props()

  /// Derived rather than read once: the dialog is remounted per open, but a
  /// plain `const` still reads as a snapshot to the compiler.
  const editing = $derived(target !== undefined)

  function changeProtocol(next: string) {
    const protocol = next as DesktopTarget['protocol']
    if (fields.portFollowsProtocol) fields.port = String(defaultPort(protocols, protocol))
    fields.protocol = protocol
  }
</script>

<div class="space-y-4">
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="desktop-name">{$LL.desktopName()}</label>
    <Input id="desktop-name" bind:value={fields.name} placeholder="office" />
  </div>

  <div class="grid gap-4 sm:grid-cols-3">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-protocol">{$LL.desktopProtocol()}</label>
      <!-- An `onchange` rather than `bind:value`: the value is a union of
           protocol names and the control answers a string, and the port that
           follows the protocol has to move with it. -->
      <Select
        class="w-full"
        value={fields.protocol}
        onchange={(e: Event) => changeProtocol((e.currentTarget as HTMLSelectElement).value)}
      >
        {#each protocols as protocol (protocol.id)}
          <option value={protocol.id}>{protocol.id.toUpperCase()}</option>
        {/each}
      </Select>
    </div>
    <div class="space-y-1 sm:col-span-2">
      <label class="text-sm text-muted-fg" for="desktop-host">{$LL.desktopHost()}</label>
      <Input id="desktop-host" bind:value={fields.host} placeholder="10.0.0.7" />
    </div>
  </div>
  <p class="text-xs text-muted-fg">{$LL.desktopHostHint()}</p>

  <div class="grid gap-4 sm:grid-cols-3">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-port">{$LL.desktopPort()}</label>
      <Input
        id="desktop-port"
        inputmode="numeric"
        bind:value={fields.port}
        oninput={() => (fields.portFollowsProtocol = false)}
      />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-username">{$LL.desktopUsername()}</label>
      <Input id="desktop-username" bind:value={fields.username} />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-domain">{$LL.desktopDomain()}</label>
      <Input id="desktop-domain" bind:value={fields.domain} />
    </div>
  </div>

  <div class="space-y-2">
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.viewOnly} />
      {$LL.desktopViewOnly()}
    </label>
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.shared} />
      {$LL.desktopShared()}
    </label>
  </div>

  <!-- No password field: a route stores none, and the one a desktop asks for is
       typed when a session is opened, in the browser that runs it. -->
  <p class="text-xs text-muted-fg">{$LL.desktopPasswordHint()}</p>

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button onclick={() => onsaved(routeDraftOf(fields))}>
      {editing ? $LL.save() : $LL.desktopAdd()}
    </Button>
  </div>
</div>
