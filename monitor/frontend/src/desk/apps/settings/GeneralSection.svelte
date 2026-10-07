<script lang="ts">
  /// This browser's own settings: the panel's language. Not tied to a
  /// server, kept on change — there is no save step here. The light/dark
  /// choice is under Appearance.

  import { Group, Row } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import LocaleToggle from './LocaleToggle.svelte'
</script>

<AppToolbar title={$LL.settingsGeneral()} />

<main class="flex max-w-[560px] flex-col gap-[17px] pb-[21px] pl-[17px] pr-[21px] pt-[5px]">
  <Group>
    <Row label={$LL.language()}>
      <LocaleToggle />
    </Row>
  </Group>
</main>
