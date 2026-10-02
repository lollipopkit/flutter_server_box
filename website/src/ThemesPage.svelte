<script>
  // The theme store on the site: every official theme, previewed as the app
  // would draw it, with its icons, palette, components and splash one click
  // away (`#<id>`). The data is store/ at build time — see store-data.js.
  import { onMount } from 'svelte'
  import { ExternalLink, ArrowLeft, Copy, Check } from '@lucide/svelte'
  import store from 'virtual:store'
  import LL, { setLocale } from './i18n/i18n-svelte'
  import { loadLocale } from './i18n/i18n-util.sync'
  import { getInitialLocale, locales, localeStorageKey, syncLocaleToUrl } from './lib/i18n'
  import ThemePreview from './lib/ThemePreview.svelte'
  import LazyThemePreview from './lib/LazyThemePreview.svelte'
  import ThemeIcon from './lib/ThemeIcon.svelte'
  import { loadPreview } from './lib/previews.js'

  const initialLocale = getInitialLocale()
  loadLocale(initialLocale)
  setLocale(initialLocale)
  let locale = $state(initialLocale)

  function applyLocale(next) {
    locale = next
    loadLocale(next)
    setLocale(next)
    try {
      localStorage.setItem(localeStorageKey, next)
    } catch {
      // private mode: the choice lasts for this page
    }
    syncLocaleToUrl(next)
  }

  // --- list ---
  let query = $state('')
  let modeFilter = $state('all')
  let sort = $state('name')
  // Which mode each card shows; a theme with both starts dark.
  let cardMode = $state({})
  const modeOf = (t) => cardMode[t.id] ?? (t.modes.includes('dark') ? 'dark' : t.modes[0])
  // Which variant each card shows; the first until one is picked.
  let cardVariant = $state({})
  const variantOf = (t, key = cardVariant[t.id]) => t.variants.find((v) => v.key === key) ?? t.variants[0]
  const hasVariants = (t) => t.variants.length > 1 || t.variants[0]?.key != null

  // A listing's description: a string as it is, or a table of language tags
  // looked up by the page's language, then its language alone, then English,
  // then whatever the listing has first — as the app does.
  function textOf(value) {
    if (typeof value === 'string') return value
    if (!value || typeof value !== 'object') return ''
    // Only string entries, as the app reads them: anything else in the table
    // is not text in any language.
    const table = Object.fromEntries(
      Object.entries(value)
        .filter(([, v]) => typeof v === 'string')
        .map(([k, v]) => [k.replaceAll('_', '-').toLowerCase(), v]),
    )
    const tag = locale.toLowerCase()
    return table[tag] ?? table[tag.split('-')[0]] ?? table.en ?? Object.values(table)[0] ?? ''
  }
  const allTexts = (value) =>
    typeof value === 'string'
      ? [value]
      : Object.values(value && typeof value === 'object' ? value : {}).filter((v) => typeof v === 'string')

  const shown = $derived.by(() => {
    const q = query.trim().toLowerCase()
    return store.themes
      .filter((t) => modeFilter === 'all' || t.modes.includes(modeFilter))
      .filter((t) =>
        !q ||
        [t.name, t.id, ...allTexts(t.description), ...t.variants.map((v) => v.name ?? '')].some((s) =>
          s.toLowerCase().includes(q),
        ),
      )
      .toSorted((a, b) =>
        sort === 'updated'
          ? b.updated.localeCompare(a.updated) || a.name.localeCompare(b.name)
          : a.name.localeCompare(b.name),
      )
  })

  // --- detail, by hash ---
  let openId = $state(null)
  let openKey = $state(null)
  const open = $derived(store.themes.find((t) => t.id === openId) ?? null)
  const openVariant = $derived(open ? variantOf(open, openKey) : null)
  let detailMode = $state('dark')
  // The open theme's preview data, fetched when it is opened. A failure is
  // the open theme's only while it is still the one open, and a retry starts
  // over (previews.js drops a failed fetch from its cache).
  let openPreview = $state(null)
  let openFailed = $state(false)
  let attempt = $state(0)
  $effect(() => {
    const t = openVariant
    attempt
    openPreview = null
    openFailed = false
    if (!t) return
    loadPreview(t).then(
      (p) => { if (openVariant === t) openPreview = p },
      () => { if (openVariant === t) openFailed = true },
    )
  })

  // `#<id>` opens a theme, `#<id>:light` in that mode, and `#<id>~<variant>`
  // one of its variants, so a link can say which.
  const hashOf = (id, key, mode) => `#${id}${key ? `~${key}` : ''}${mode ? `:${mode}` : ''}`
  function readHash() {
    const [target, mode] = decodeURIComponent(window.location.hash.slice(1)).split(':')
    const [id, key] = target.split('~')
    const t = store.themes.find((x) => x.id === id)
    openId = t?.id ?? null
    openKey = key ?? null
    if (t) detailMode = t.modes.includes(mode) ? mode : t.modes.includes('dark') ? 'dark' : t.modes[0]
    window.scrollTo({ top: 0 })
  }

  function showMode(mode) {
    detailMode = mode
    history.replaceState(null, '', `${location.pathname}${location.search}${hashOf(openId, openKey, mode)}`)
  }

  function showVariant(key) {
    openKey = key
    history.replaceState(null, '', `${location.pathname}${location.search}${hashOf(openId, key, detailMode)}`)
  }

  onMount(() => {
    syncLocaleToUrl(locale)
    readHash()
    window.addEventListener('hashchange', readHash)
    return () => window.removeEventListener('hashchange', readHash)
  })

  const modeLabel = (m) => (m === 'dark' ? $LL.themes.dark() : $LL.themes.light())

  const tabKeys = ['server', 'ssh', 'file', 'snippet', 'agent', 'benchmark', 'remoteDesktop', 'virt']
  const navKeys = ['more', 'settings', 'tune', 'privacy', 'agent', 'tabs', 'server', 'sort', 'terminal',
    'folder', 'cloud', 'snippet', 'inbox', 'key', 'info', 'download', 'desktop']
  const paletteRoles = [
    ['primary', 'onPrimary'], ['primaryContainer', 'onPrimaryContainer'],
    ['secondary', 'onSecondary'], ['secondaryContainer', 'onSecondaryContainer'],
    ['tertiary', 'onTertiary'], ['tertiaryContainer', 'onTertiaryContainer'],
    ['error', 'onError'], ['surface', 'onSurface'],
    ['surfaceContainerLow', 'onSurface'], ['surfaceContainer', 'onSurface'],
    ['surfaceContainerHigh', 'onSurface'], ['surfaceContainerHighest', 'onSurfaceVariant'],
    ['outline', 'surface'], ['outlineVariant', 'onSurface'],
  ]

  let copied = $state(false)
  async function copyDigest(digest) {
    try {
      await navigator.clipboard.writeText(digest)
      copied = true
      setTimeout(() => (copied = false), 1600)
    } catch {
      window.prompt('SHA-256', digest)
    }
  }

  function kib(bytes) {
    return bytes == null ? '' : `${(bytes / 1024).toFixed(bytes < 10240 ? 1 : 0)} KiB`
  }
</script>

<main class="site">
  <header class="site-nav" id="top">
    <a class="brand" href={`/?lang=${locale}`}>ServerBox</a>
    <nav>
      <a href={`/?lang=${locale}#features`}>{$LL.nav.features()}</a>
      <a href={`/themes/?lang=${locale}`} aria-current="page">{$LL.nav.themes()}</a>
      <a href={`/?lang=${locale}#download`}>{$LL.nav.download()}</a>
      <a href="/docs/">{$LL.nav.docs()}</a>
    </nav>
    <div class="nav-actions">
      <label class="language-switcher">
        <span class="sr-only">{$LL.nav.languageLabel()}</span>
        <select aria-label={$LL.nav.languageLabel()} value={locale} onchange={(e) => applyLocale(e.currentTarget.value)}>
          {#each locales as item}
            <option value={item.code}>{item.label}</option>
          {/each}
        </select>
      </label>
    </div>
  </header>

  {#if open && openFailed}
    <section class="page-section store-detail">
      <div class="store-empty">
        <p>{$LL.themes.loadFailed()}</p>
        <div class="store-actions">
          <button type="button" class="download-icon-btn" onclick={() => attempt++}>{$LL.themes.retry()}</button>
          <a class="download-icon-btn" href="#">{$LL.themes.back()}</a>
        </div>
      </div>
    </section>
  {:else if open && !openPreview}
    <section class="page-section store-detail"><p class="muted">…</p></section>
  {:else if open}
    {@const pv = openPreview}
    {@const tabs = tabKeys.filter((t) => pv.images[`tab.${t}`] || pv.images[`tab.${t}.selected`])}
    {@const navs = navKeys.filter((n) => pv.images[`nav.${n}`])}
    {@const m = pv.modes[detailMode]}
    {@const b = m.components.button ?? {}}
    {@const r = b.radius ?? pv.shapes.button}
    {@const i = m.components.input ?? {}}
    {@const d = m.components.dialog ?? {}}
    {@const sh = m.components.sheet ?? {}}
    <section class="page-section store-detail">
      <a class="download-icon-btn store-back" href="#">
        <ArrowLeft size={14} strokeWidth={1.8} aria-hidden="true" />
        <span>{$LL.themes.back()}</span>
      </a>

      <div class="detail-head">
        <div>
          <h1>{open.name}{openVariant.name ? ` · ${openVariant.name}` : ''}</h1>
          <p>{textOf(open.description)}</p>
          {#if hasVariants(open)}
            <div class="store-modes store-variants" role="radiogroup" aria-label={open.name}>
              {#each open.variants as v (v.key)}
                <button type="button" role="radio" aria-checked={v.key === openVariant.key} class="protocol-badge"
                  class:active={v.key === openVariant.key} onclick={() => showVariant(v.key)}>{v.name}</button>
              {/each}
            </div>
          {/if}
          <div class="store-meta">
            {#each open.modes as mode}<span class="protocol-badge">{modeLabel(mode)}</span>{/each}
            {#if open.latest}<span class="protocol-badge">v{open.latest.version}</span>{/if}
            {#if open.license}<span class="protocol-badge">{open.license}</span>{/if}
            <span class="protocol-badge">{open.id}</span>
          </div>
        </div>
        {#if open.modes.length > 1}
          <div class="store-modes" role="radiogroup" aria-label={$LL.themes.modeLabel()}>
            {#each open.modes as mode}
              <button type="button" role="radio" aria-checked={detailMode === mode} class="protocol-badge"
                class:active={detailMode === mode} onclick={() => showMode(mode)}>{modeLabel(mode)}</button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="detail-grid">
        <div class="detail-preview">
          <ThemePreview preview={pv} mode={detailMode} scale={1.15} />
          <p class="preview-note">{$LL.themes.previewNote()}</p>
        </div>

        <div class="detail-sections">
          <!-- Only the icons the theme draws: a key it leaves to the app's
               built-in glyph has nothing to show here. -->
          {#if tabs.length || navs.length}
          <section class="detail-card" style={`background:${m.palette.surface}; color:${m.palette.onSurface}`}>
            <h2>{$LL.themes.icons()}</h2>
            {#if tabs.length}
            <h3 style={`color:${m.palette.onSurfaceVariant}`}>{$LL.themes.tabIcons()}</h3>
            <div class="icon-grid">
              {#each tabs as t}
                <div class="icon-cell" title={`tab.${t}`}>
                  <ThemeIcon src={pv.images[`tab.${t}`]} color={m.palette.onSurfaceVariant} size={26} label={`tab.${t}`} />
                  <ThemeIcon src={pv.images[`tab.${t}.selected`]}
                    color={m.iconColors[`tab.${t}.selected`] ?? m.components.navigation?.selectedIconColor ?? m.palette.onSecondaryContainer}
                    size={26} label={`tab.${t}.selected`} />
                </div>
              {/each}
            </div>
            {/if}
            {#if navs.length}
            <h3 style={`color:${m.palette.onSurfaceVariant}`}>{$LL.themes.navIcons()}</h3>
            <div class="icon-grid">
              {#each navs as n}
                <div class="icon-cell" title={`nav.${n}`}>
                  <ThemeIcon src={pv.images[`nav.${n}`]} color={m.iconColors[`nav.${n}`] ?? m.palette.onSurface} size={26} label={`nav.${n}`} />
                </div>
              {/each}
            </div>
            {/if}
          </section>
          {/if}

          <section class="detail-card">
            <h2>{$LL.themes.palette()}</h2>
            <div class="swatch-grid">
              {#each paletteRoles as [role, on]}
                {#if m.palette[role]}
                  <div class="swatch" style={`background:${m.palette[role]}; color:${m.palette[on]}`}>
                    <span>{role}</span>
                    <code>{m.palette[role]}</code>
                  </div>
                {/if}
              {/each}
            </div>
          </section>

          <section class="detail-card" style={`background:${m.palette.surface}; color:${m.palette.onSurface}`}>
            <h2>{$LL.themes.components()}</h2>
            <div class="comp-row">
              {#each [['', {}], [$LL.themes.hovered(), b.hovered ?? {}], [$LL.themes.pressed(), b.pressed ?? {}], [$LL.themes.disabled(), b.disabled ?? {}]] as [label, st]}
                <div class="comp-item">
                  <span class="comp-button" style={`border-radius:${st.radius ?? r}px; background:${st.backgroundColor ?? b.backgroundColor ?? m.palette.primary}; color:${st.foregroundColor ?? b.foregroundColor ?? m.palette.onPrimary}; border:${st.borderWidth ?? b.borderWidth ?? 0}px solid ${st.borderColor ?? b.borderColor ?? 'transparent'}; box-shadow: inset 0 0 0 999px ${st.overlayColor ?? 'transparent'};`}>Connect</span>
                  <small style={`color:${m.palette.onSurfaceVariant}`}>{label || $LL.themes.base()}</small>
                </div>
              {/each}
            </div>
            <div class="comp-row">
              {#each [[i.borderColor ?? m.palette.outline, 'user@host'], [i.focusedBorderColor ?? m.palette.primary, 'root@10.0.0.2|']] as [border, text]}
                <span class="comp-input" style={`border-radius:${i.radius ?? 8}px; background:${i.filled ? (i.fillColor ?? m.palette.surfaceContainerHighest) : 'transparent'}; border:${Math.max(i.borderWidth ?? 1, 1)}px solid ${border}; color:${m.palette.onSurface}`}>{text}</span>
              {/each}
            </div>
            <div class="comp-stage" style={`background:${d.barrierColor ?? 'rgba(0,0,0,.5)'}`}>
              <div class="comp-dialog" style={`background:${d.backgroundColor ?? m.palette.surfaceContainerHigh}; border-radius:${d.radius ?? 24}px; border:${d.borderWidth ?? 0}px solid ${d.borderColor ?? 'transparent'}; color:${m.palette.onSurface}`}>
                <strong>Delete web-01?</strong>
                <p style={`color:${m.palette.onSurfaceVariant}`}>Its settings and history go with it.</p>
                <div class="comp-dialog-actions">
                  <span style={`color:${m.palette.primary}`}>Cancel</span>
                  <span style={`color:${m.palette.error}`}>Delete</span>
                </div>
              </div>
              <div class="comp-sheet" style={`background:${sh.backgroundColor ?? m.palette.surfaceContainerLow}; border-radius:${sh.radius ?? 28}px ${sh.radius ?? 28}px 0 0; border:${sh.borderWidth ?? 0}px solid ${sh.borderColor ?? 'transparent'}; border-bottom:none; color:${m.palette.onSurface}`}>
                <i style={`background:${sh.dragHandleColor ?? m.palette.onSurfaceVariant}`}></i>
                <span>Sort by name</span>
              </div>
            </div>
          </section>

          {#if pv.splash && m.splash}
            <section class="detail-card">
              <h2>{$LL.themes.splash()}</h2>
              <div class="splash-box" style={`background:${m.splash.color}`}>
                {#if pv.splash.logo}
                  <img src={pv.splash.logo} alt="" width="96" height="96" />
                {/if}
              </div>
              <small class="muted">{pv.splash.duration} ms</small>
            </section>
          {/if}

          <section class="detail-card">
            <h2>{$LL.themes.install()}</h2>
            <p class="muted">{$LL.themes.installSteps({ name: open.name })}</p>
            {#if open.latest}
              <div class="store-actions">
                {#if open.latest.url}
                  <a class="download-icon-btn" href={open.latest.url}>
                    <span>{$LL.themes.download()}</span>
                    <small class="muted">{kib(open.latest.size)}</small>
                    <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
                  </a>
                {/if}
                {#if open.homepage}
                  <a class="download-icon-btn" href={open.homepage}>
                    <span>{$LL.themes.source()}</span>
                    <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
                  </a>
                {/if}
              </div>
              {#if open.latest.sha256}
                <button type="button" class="store-digest-full" onclick={() => copyDigest(open.latest.sha256)}>
                  <code>SHA-256 {open.latest.sha256}</code>
                  {#if copied}<Check size={14} aria-hidden="true" />{:else}<Copy size={14} aria-hidden="true" />{/if}
                </button>
              {/if}
            {/if}
          </section>
        </div>
      </div>
    </section>
  {:else}
    <section class="page-section">
      <div class="section-head">
        <h1 class="store-title">{$LL.themes.storeTitle()}</h1>
        <p>{$LL.themes.storeSubtitle()}</p>
      </div>

      <div class="store-toolbar">
        <input class="store-search" type="search" bind:value={query}
          placeholder={$LL.themes.search()} aria-label={$LL.themes.search()} />
        <div class="store-modes" role="radiogroup" aria-label={$LL.themes.modeLabel()}>
          {#each [['all', $LL.themes.all()], ['light', $LL.themes.light()], ['dark', $LL.themes.dark()]] as [value, label]}
            <button type="button" role="radio" aria-checked={modeFilter === value} class="protocol-badge"
              class:active={modeFilter === value} onclick={() => (modeFilter = value)}>{label}</button>
          {/each}
        </div>
        <label class="language-switcher store-sort">
          <span class="sr-only">{$LL.themes.sortLabel()}</span>
          <select bind:value={sort} aria-label={$LL.themes.sortLabel()}>
            <option value="name">{$LL.themes.sortName()}</option>
            <option value="updated">{$LL.themes.sortUpdated()}</option>
          </select>
        </label>
      </div>

      {#if store.themes.length}
        <p class="preview-note">{$LL.themes.previewNote()}</p>
      {/if}

      {#if !store.themes.length}
        <div class="store-empty"><p>{$LL.themes.empty()}</p></div>
      {:else if !shown.length}
        <div class="store-empty"><p>{$LL.themes.noMatch()}</p></div>
      {/if}

      <div class="store-grid store-grid-wide">
        {#each shown as theme (theme.id)}
          {@const mode = modeOf(theme)}
          {@const variant = variantOf(theme)}
          {@const href = hashOf(theme.id, variant.key)}
          <article class="feature-card store-card">
            <a class="store-preview-link" {href} aria-label={`${theme.name} — ${$LL.themes.details()}`}>
              {#key variant.previewUrl}<LazyThemePreview theme={variant} {mode} scale={0.9} />{/key}
            </a>
            <div class="store-card-head">
              <h3><a {href}>{theme.name}</a></h3>
              {#if theme.modes.length > 1}
                <div class="store-modes small" role="radiogroup" aria-label={$LL.themes.modeLabel()}>
                  {#each theme.modes as m}
                    <button type="button" role="radio" aria-checked={mode === m} class="protocol-badge"
                      class:active={mode === m} onclick={() => (cardMode = { ...cardMode, [theme.id]: m })}>{modeLabel(m)}</button>
                  {/each}
                </div>
              {/if}
            </div>
            {#if hasVariants(theme)}
              <div class="store-modes small store-variants" role="radiogroup" aria-label={theme.name}>
                {#each theme.variants as v (v.key)}
                  <button type="button" role="radio" aria-checked={v.key === variant.key} class="protocol-badge"
                    class:active={v.key === variant.key} onclick={() => (cardVariant = { ...cardVariant, [theme.id]: v.key })}>{v.name}</button>
                {/each}
              </div>
            {/if}
            {#if textOf(theme.description)}<p>{textOf(theme.description)}</p>{/if}
            <div class="store-meta">
              {#each theme.modes as m}<span class="protocol-badge">{modeLabel(m)}</span>{/each}
              {#if theme.latest}<span class="protocol-badge">v{theme.latest.version}</span>{/if}
              {#if theme.license}<span class="protocol-badge">{theme.license}</span>{/if}
            </div>
            <div class="store-actions">
              <a class="download-icon-btn" {href}><span>{$LL.themes.details()}</span></a>
              {#if theme.latest?.url}
                <a class="download-icon-btn" href={theme.latest.url}>
                  <span>{$LL.themes.download()}</span>
                  <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
                </a>
              {/if}
            </div>
          </article>
        {/each}
      </div>

      <div class="store-footer">
        <p class="download-note">{$LL.themes.note()}</p>
        <a class="download-icon-btn" href="/docs/development/theme-authoring/">
          <span>{$LL.themes.authoring()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
      </div>
    </section>
  {/if}

  <footer class="site-footer">
    <span>© 2026 lollipopkit</span>
    <div class="footer-links">
      <a href={`/?lang=${locale}`}>ServerBox</a>
      <a href="https://github.com/lollipopkit/flutter_server_box">GitHub</a>
      <a href="https://github.com/lollipopkit/flutter_server_box/tree/main/store">store/</a>
    </div>
  </footer>
</main>
