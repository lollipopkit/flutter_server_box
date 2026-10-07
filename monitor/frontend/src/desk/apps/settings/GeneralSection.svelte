<script lang="ts">
  /// This browser's own settings: the panel's language and its light/dark
  /// choice. Neither is tied to a server, and both persist on change — there
  /// is no save step here.

  import { Group, Row } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import LocaleToggle from './LocaleToggle.svelte'
  import ThemeToggle from './ThemeToggle.svelte'
</script>

<AppToolbar title={$LL.settingsGeneral()} />

<main class="mx-auto max-w-[560px] px-[21px] pb-[21px] pt-[4px]">
  <Group>
    <Row label={$LL.language()}>
      <LocaleToggle />
    </Row>
    <Row label={$LL.theme()}>
      <ThemeToggle />
    </Row>
  </Group>
</main>
