<script lang="ts">
  /// What the account confirms before a web app is deployed: which project it
  /// is, who makes it, its version, licence, source, the images it will pull,
  /// the folders and port it will use, what its compose files do here, and
  /// that it is third-party software. Each box must be ticked to go on; the
  /// agent refuses a deploy without them too.

  import { Button, Checkbox, Dialog, Icon } from '../../desk/lk'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import type { StackManifest, StackNotice, StackPreview } from '../../types'
  import { mcpNotices, noticeText } from './notices'
  import { pick } from './text'

  interface Props {
    open: boolean
    manifest: StackManifest
    preview: StackPreview | null
    oncontinue: (consent: { acknowledged: boolean; acceptLicense: boolean }) => void
    onclose: () => void
  }

  const { open, manifest, preview, oncontinue, onclose }: Props = $props()

  let acknowledged = $state(false)
  let accepted = $state(false)

  // Asked afresh each time it opens: a box ticked for other settings is not
  // a decision about these.
  $effect(() => {
    if (open) {
      acknowledged = false
      accepted = false
    }
  })

  const title = $derived(pick(manifest.title, $locale))
  const ready = $derived(acknowledged && (!manifest.license.accept || accepted))
  const notices = $derived([...manifest.notices.map((n: StackNotice) => noticeText(n, $LL)), ...mcpNotices(manifest, $LL)])

  function settingLabel(key: string): string {
    const label = manifest.settings.find((s) => s.key === key)?.label
    return label ? pick(label, $locale) : key
  }
</script>

<Dialog {open} wide title={$LL.stackConfirmTitle({ name: title })} {onclose}>
  <div class="space-y-[13px] text-left text-[13px] text-(--text-secondary)">
    <p>{$LL.stackConfirmIntro()}</p>
    <!-- What is installed scrolls; what must be ticked stays in view. -->
    <div class="max-h-[40vh] space-y-[13px] overflow-y-auto pr-[5px]">

    <dl class="grid grid-cols-[auto_1fr] gap-x-[13px] gap-y-[7px]">
      <dt class="text-(--text-tertiary)">{$LL.stackProject()}</dt>
      <dd class="text-(--text-primary)">
        <a class="text-(--color-accent-text) hover:underline" href={manifest.homepage} target="_blank" rel="noreferrer noopener">{manifest.project}</a>
      </dd>
      {#if manifest.developer}
        <dt class="text-(--text-tertiary)">{$LL.stackDeveloper()}</dt>
        <dd class="text-(--text-primary)">{manifest.developer}</dd>
      {/if}
      <dt class="text-(--text-tertiary)">{$LL.stackVersion()}</dt>
      <dd class="lk-mono text-(--text-primary)">{manifest.version}</dd>
      <dt class="text-(--text-tertiary)">{$LL.stackLicense()}</dt>
      <dd>
        <a class="text-(--color-accent-text) hover:underline" href={manifest.license.url} target="_blank" rel="noreferrer noopener">{manifest.license.spdx}</a>
      </dd>
      <dt class="text-(--text-tertiary)">{$LL.stackSource()}</dt>
      <dd class="min-w-0">
        <a class="lk-mono break-all text-(--color-accent-text) hover:underline" href={manifest.source} target="_blank" rel="noreferrer noopener">{manifest.source}</a>
      </dd>
      {#if preview}
        <dt class="text-(--text-tertiary)">{$LL.stackImages()}</dt>
        <dd class="lk-mono min-w-0 space-y-[3px] break-all text-[12px] text-(--text-primary)">
          {#each preview.images as image (image)}<div>{image}</div>{/each}
        </dd>
        {#if preview.built?.length}
          <dt class="text-(--text-tertiary)">{$LL.stackBuilt()}</dt>
          <dd class="lk-mono min-w-0 space-y-[3px] break-all text-[12px] text-(--text-primary)">
            {#each preview.built as image (image)}<div>{image}</div>{/each}
          </dd>
        {/if}
        <dt class="text-(--text-tertiary)">{$LL.stackData()}</dt>
        <dd class="lk-mono min-w-0 space-y-[3px] break-all text-[12px] text-(--text-primary)">
          {#each preview.data_paths as path (path)}<div>{path}</div>{/each}
        </dd>
        {#if preview.port != null}
          <dt class="text-(--text-tertiary)">{$LL.stackPort()}</dt>
          <dd class="lk-num text-(--text-primary)">{preview.port}</dd>
        {/if}
        {#each preview.moved as m (m.setting)}
          <dt class="text-(--text-tertiary)">{settingLabel(m.setting)}</dt>
          <dd class="text-(--color-warning)">{$LL.stackPortMoved({ from: m.from, to: m.to })}</dd>
        {/each}
      {/if}
    </dl>

    {#if notices.length}
      <ul class="space-y-[5px]">
        {#each notices as text (text)}
          <li class="flex items-start gap-[7px]"><Icon name="info" size={15} class="mt-[1px] shrink-0" />{text}</li>
        {/each}
      </ul>
    {/if}
    </div>

    <p class="flex items-start gap-[7px] rounded-(--radius-md) bg-(--color-warning-soft) p-[9px] text-(--text-primary)">
      <Icon name="warning" size={16} class="mt-[1px] shrink-0 text-(--color-warning)" />
      {$LL.stackThirdParty({ name: manifest.project })}
    </p>

    <div class="space-y-[7px]">
      <Checkbox bind:checked={acknowledged} label={$LL.stackAckThirdParty({ name: manifest.project })} />
      {#if manifest.license.accept}
        <Checkbox bind:checked={accepted} label={$LL.stackLicenseAccept({ spdx: manifest.license.spdx })} />
      {/if}
    </div>
  </div>
  {#snippet actions()}
    <Button variant="secondary" onclick={onclose}>{$LL.cancel()}</Button>
    <Button disabled={!ready} onclick={() => oncontinue({ acknowledged, acceptLicense: accepted })}>{$LL.stackContinue()}</Button>
  {/snippet}
</Dialog>
