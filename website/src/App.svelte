<script>
  import { Button } from '@serverbox/webui'
  import {
    ExternalLink,
  } from '@lucide/svelte'
  import { spring } from 'svelte/motion'
  import { onMount } from 'svelte'
  import LL, { setLocale } from './i18n/i18n-svelte'
  import { loadLocale } from './i18n/i18n-util.sync'
  import {
    getInitialLocale,
    locales,
    localeStorageKey,
    syncLocaleToUrl,
  } from './lib/i18n'
  // store/ at build time: see store-data.js.
  import store from 'virtual:store'
  import LazyThemePreview from './lib/LazyThemePreview.svelte'

  // TODO: show once the plugin system ships in the app; until then a plugin
  // listed here would be one nobody can install.
  const showPlugins = false

  // Keep product and protocol names untranslated. This list is the single
  // source of truth; locale-specific copies would appear editable but be unused.
  const capabilities = [
    'Status chart', 'SSH Terminal', 'SFTP', 'SCP', 'Docker', 'Process',
    'Systemd', 'S.M.A.R.T', 'GPU', 'Sensors', 'Push', 'Home Widget', 'watchOS',
    'Monitor Agent', 'AI Agent', 'Globe', 'Benchmark', 'iperf',
    'Port Forward', 'Local Shell', 'Workspace', 'RDP', 'VNC', 'libvirt',
    'Proxmox VE', 'Redfish', 'Firewall', 'Cron', 'Users & Groups', 'Themes',
  ]

  // One per screenshot, in the order of the README's table. Features without
  // a screenshot are in `capabilities` above. `tag` is what the screen talks
  // to on the server, so it stays untranslated.
  const features = [
    { key: 'list', shot: 'home', tag: 'ssh · monitor' },
    { key: 'charts', shot: 'server-details', tag: '/proc · /sys' },
    { key: 'terminal', shot: 'terminal', tag: 'ssh' },
    { key: 'files', shot: 'files', tag: 'sftp' },
    { key: 'containers', shot: 'container', tag: 'docker · podman' },
    { key: 'processes', shot: 'process', tag: 'ps' },
    { key: 'services', shot: 'services', tag: 'systemctl' },
    { key: 'users', shot: 'users', tag: '/etc/passwd' },
    { key: 'agent', shot: 'agent', tag: 'llm · mcp' },
    { key: 'bench', shot: 'bench', tag: 'yabs' },
    { key: 'virt', shot: 'virt', tag: 'libvirt · pve' },
    { key: 'themes', shot: 'themes', tag: '.fsbt' },
  ]

  // Which feature the phone shows: the one scrolled to the middle of the
  // viewport, or the one last pressed.
  let activeFeature = $state(0)
  let featureItems = $state([])

  // The item whose middle is nearest the viewport's middle, read on every
  // scroll frame: a band-crossing observer missed items a fast wheel jumped.
  $effect(() => {
    const items = featureItems.filter(Boolean)
    if (!items.length) return
    let frame = 0
    const update = () => {
      frame = 0
      // The phone column is hidden below 860px; nothing to follow then.
      if (!window.matchMedia('(min-width: 861px)').matches) return
      const middle = window.innerHeight / 2
      let best = activeFeature
      let bestDistance = Infinity
      items.forEach((item, index) => {
        const rect = item.getBoundingClientRect()
        const distance = Math.abs(rect.top + rect.height / 2 - middle)
        if (distance < bestDistance) {
          bestDistance = distance
          best = index
        }
      })
      activeFeature = best
    }
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update)
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    update()
    return () => {
      window.removeEventListener('scroll', onScroll)
      if (frame) cancelAnimationFrame(frame)
    }
  })

  // The CDN stores original PNGs and 1440px JPEGs for the web under matching
  // names, so refreshing an image does not require a source-code change.
  const shotBase = 'https://cdn.lollipopkit.com/serverbox/screenshot'

  // The order matches the stack transforms below. Each key also selects its
  // localized alt text, so update all locales when changing a key's image.
  const screenshots = [
    { src: `${shotBase}/iphone/home.jpg`, key: 'one', x: -18, y: 8, hoverSlot: -1.5, rotate: -7, hoverRotate: -1.8, motion: 18 },
    { src: `${shotBase}/iphone/server-details.jpg`, key: 'two', x: -6, y: -4, hoverSlot: -0.5, rotate: -2, hoverRotate: -0.6, motion: 12 },
    { src: `${shotBase}/iphone/terminal.jpg`, key: 'three', x: 7, y: 4, hoverSlot: 0.5, rotate: 3, hoverRotate: 0.6, motion: 14 },
    { src: `${shotBase}/iphone/files.jpg`, key: 'four', x: 18, y: -2, hoverSlot: 1.5, rotate: 8, hoverRotate: 1.8, motion: 20 },
  ]

  const releases = 'https://github.com/lollipopkit/flutter_server_box/releases'

  // `file` says what the source gives you; formats and commands stay untranslated.
  const downloadGroups = [
    {
      key: 'ios',
      label: 'iOS',
      sources: [
        { label: 'App Store', href: 'https://apps.apple.com/app/id1586449703' },
        // Unsigned: the user signs it themselves.
        { label: 'GitHub Releases', file: '_NoSign.ipa', href: releases },
      ],
    },
    {
      key: 'macos',
      label: 'macOS',
      sources: [
        { label: 'GitHub Releases', file: '.dmg arm64 / amd64', href: releases },
        { label: 'Homebrew Cask', file: 'brew install --cask server-box', command: 'brew install --cask server-box' },
      ],
    },
    {
      key: 'android',
      label: 'Android',
      sources: [
        { label: 'GitHub Releases', file: '.apk arm64 / arm / amd64', href: releases },
        { label: 'F-Droid', href: 'https://f-droid.org/packages/tech.lolli.toolbox' },
        { label: 'OpenAPK', href: 'https://www.openapk.net/serverbox/tech.lolli.toolbox/' },
      ],
    },
    {
      key: 'linux',
      label: 'Linux',
      sources: [
        { label: 'GitHub Releases', file: '.AppImage', href: releases },
      ],
    },
    {
      key: 'windows',
      label: 'Windows',
      sources: [
        { label: 'GitHub Releases', file: '.zip', href: releases },
      ],
    },
  ]

  const stackMotion = spring(
    { x: 0, y: 0 },
    {
      stiffness: 0.12,
      damping: 0.38,
    },
  )

  function getLocaleBeforeRender() {
    if (typeof window === 'undefined') return undefined

    return getInitialLocale()
  }

  const initialLocale = getLocaleBeforeRender()

  if (initialLocale) {
    loadLocale(initialLocale)
    setLocale(initialLocale)
  }

  let locale = $state(initialLocale)
  let copiedCommand = $state(undefined)
  let copyFallbackCommand = $state(undefined)

  function applyLocale(nextLocale) {
    locale = nextLocale
    loadLocale(nextLocale)
    setLocale(nextLocale)
    localStorage.setItem(localeStorageKey, nextLocale)
  }

  onMount(() => {
    const nextLocale = locale || getInitialLocale()
    applyLocale(nextLocale)
    syncLocaleToUrl(nextLocale)
  })

  $effect(() => {
    if (!locale) return

    document.documentElement.lang = $LL.meta.lang()
    document.title = $LL.meta.title()
    document
      .querySelector('meta[name="description"]')
      ?.setAttribute('content', $LL.meta.description())
  })

  function handleLocaleChange(event) {
    const nextLocale = event.currentTarget.value
    applyLocale(nextLocale)
    syncLocaleToUrl(nextLocale)
  }

  function handleStackMove(event) {
    const rect = event.currentTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width - 0.5
    const y = (event.clientY - rect.top) / rect.height - 0.5

    stackMotion.set({ x, y })
  }

  function resetStack() {
    stackMotion.set({ x: 0, y: 0 })
  }

  function scrollToSection(event, id) {
    event.preventDefault()
    document.getElementById(id)?.scrollIntoView({
      behavior: 'smooth',
      block: 'start',
    })
  }

  async function copyCommand(command) {
    copyFallbackCommand = undefined

    try {
      await navigator.clipboard.writeText(command)
      copiedCommand = command
      window.setTimeout(() => {
        if (copiedCommand === command) copiedCommand = undefined
      }, 1800)
    } catch {
      copiedCommand = undefined
      copyFallbackCommand = command
      window.prompt($LL.download.copyPrompt(), command)
    }
  }
</script>

{#if locale}
  <main class="site">
    <header class="site-nav" id="top">
      <a class="brand" href="#top" onclick={(event) => scrollToSection(event, 'top')}>
        <img src="/app_icon.png" alt="" width="26" height="26" />
        ServerBox
      </a>
      <nav>
        <a href="#features" onclick={(event) => scrollToSection(event, 'features')}>{$LL.nav.features()}</a>
        <a href="#capabilities" onclick={(event) => scrollToSection(event, 'capabilities')}>{$LL.nav.capabilities()}</a>
        <a href="#themes" onclick={(event) => scrollToSection(event, 'themes')}>{$LL.nav.themes()}</a>
        {#if showPlugins}
          <a href="#plugins" onclick={(event) => scrollToSection(event, 'plugins')}>{$LL.nav.plugins()}</a>
        {/if}
        <a href="#download" onclick={(event) => scrollToSection(event, 'download')}>{$LL.nav.download()}</a>
        <a href="/docs/">{$LL.nav.docs()}</a>
      </nav>
      <div class="nav-actions">
        <label class="language-switcher">
          <span class="sr-only">{$LL.nav.languageLabel()}</span>
          <select
            id="locale"
            name="locale"
            aria-label={$LL.nav.languageLabel()}
            value={locale}
            onchange={handleLocaleChange}
          >
            {#each locales as item}
              <option value={item.code}>{item.label}</option>
            {/each}
          </select>
        </label>
      </div>
    </header>

    <section class="hero" id="hero">
      <div class="hero-copy">
        <p class="hero-platforms">iOS · Android · macOS · Linux · Windows</p>
        <h1>{$LL.hero.titlePrefix()}<br /><span>{$LL.hero.titleSuffix()}</span></h1>
        <p class="hero-subtitle">
          {$LL.hero.subtitle()}
        </p>
        <div class="hero-actions">
          <Button href="#download" onclick={(event) => scrollToSection(event, 'download')}>{$LL.hero.primaryAction()}</Button>
          <Button variant="secondary" href="#features" onclick={(event) => scrollToSection(event, 'features')}>{$LL.hero.secondaryAction()}</Button>
        </div>
      </div>

      <div
        class="screenshot-stack"
        aria-label={$LL.screenshots.label()}
        onmousemove={handleStackMove}
        onmouseleave={resetStack}
        role="img"
      >
        {#each screenshots as shot, index}
          <img
            class="screenshot-card"
            src={shot.src}
            alt={$LL.screenshots[shot.key]()}
            loading={index === 0 ? 'eager' : 'lazy'}
            referrerpolicy="no-referrer"
            style={`--base-x:${shot.x}%; --base-y:${shot.y}%; --hover-slot:${shot.hoverSlot}; --base-r:${shot.rotate}deg; --hover-r:${shot.hoverRotate}deg; --move-x:${$stackMotion.x * shot.motion}px; --move-y:${$stackMotion.y * shot.motion}px; --tilt-x:${-$stackMotion.y * 6}deg; --tilt-y:${$stackMotion.x * 8}deg; --z:${screenshots.length - index};`}
          />
        {/each}
      </div>
    </section>

    <section class="page-section" id="features">
      <div class="section-head">
        <h2>{$LL.features.title()}</h2>
        <p>
          {$LL.features.subtitle()}
        </p>
      </div>

      <div class="tour">
        <ol class="tour-list">
          {#each features as feature, index}
            <li bind:this={featureItems[index]}>
              <button
                type="button"
                class="tour-item"
                class:active={index === activeFeature}
                aria-pressed={index === activeFeature}
                onclick={() => featureItems[index]?.scrollIntoView({ behavior: 'smooth', block: 'center' })}
              >
                <span class="tour-tag">{feature.tag}</span>
                <span class="tour-title">{$LL.features[feature.key].title()}</span>
                <span class="tour-desc">{$LL.features[feature.key].description()}</span>
              </button>
              <!-- Phones get the picture beside its text; wider screens, the
                   one device frame. -->
              <img
                class="tour-shot-inline"
                src={`${shotBase}/iphone/${feature.shot}.jpg`}
                alt=""
                loading="lazy"
                decoding="async"
                referrerpolicy="no-referrer"
              />
            </li>
          {/each}
        </ol>
        <div class="tour-device">
          <div class="device-frame">
            {#each features as feature, index}
              <img
                class:shown={index === activeFeature}
                src={`${shotBase}/iphone/${feature.shot}.jpg`}
                alt={index === activeFeature ? $LL.features[feature.key].title() : ''}
                loading="lazy"
                decoding="async"
                referrerpolicy="no-referrer"
              />
            {/each}
          </div>
        </div>
      </div>
    </section>

    <section class="protocol-section" id="capabilities">
      <div class="section-head">
        <h2>{$LL.capabilities.title()}</h2>
        <p>
          {$LL.capabilities.subtitle()}
        </p>
      </div>

      <div class="protocol-badges">
        {#each capabilities as item}
          <span class="protocol-badge">{item}</span>
        {/each}
      </div>
    </section>

    <section class="page-section" id="themes">
      <div class="section-head">
        <h2>{$LL.themes.title()}</h2>
        <p>{$LL.themes.subtitle()}</p>
      </div>

      {#if store.themes.length}
        <!-- A glimpse, drawn from the themes themselves; the store page has
             the rest: search, every mode, icons, components. -->
        <p class="preview-note">{$LL.themes.previewNote()}</p>
        <div class="theme-strip">
          {#each store.themes.slice(0, 4) as theme (theme.id)}
            <a class="theme-strip-item" href={`/themes/?lang=${locale}#${theme.id}`}>
              <LazyThemePreview theme={theme.variants[0]} mode={theme.modes.includes('dark') ? 'dark' : theme.modes[0]} scale={0.72} />
              <span>{theme.name}</span>
            </a>
          {/each}
        </div>
      {:else}
        <div class="store-empty">
          <p>{$LL.themes.empty()}</p>
        </div>
      {/if}

      <div class="store-footer">
        <p class="download-note">{$LL.themes.note()}</p>
        <div class="store-actions">
          <a class="download-icon-btn" href="/docs/development/theme-authoring/">
            <span>{$LL.themes.authoring()}</span>
            <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
          </a>
          <Button href={`/themes/?lang=${locale}`}>{$LL.themes.browse()}</Button>
        </div>
      </div>
    </section>

    {#if showPlugins}
      <section class="page-section" id="plugins">
        <div class="section-head">
          <h2>{$LL.plugins.title()}</h2>
          <p>{$LL.plugins.subtitle()}</p>
        </div>

        {#if store.plugins.length}
          <div class="store-grid">
            {#each store.plugins as plugin (plugin.id)}
              <article class="feature-card store-card">
                <h3>{plugin.name}</h3>
                {#if plugin.description}<p>{plugin.description}</p>{/if}
                <div class="store-meta">
                  <span class="protocol-badge">v{plugin.latest.version}</span>
                  {#if plugin.license}<span class="protocol-badge">{plugin.license}</span>{/if}
                </div>
                {#if plugin.latest.url}
                  <div class="store-actions">
                    <a class="download-icon-btn" href={plugin.latest.url}>
                      <span>{$LL.plugins.download()}</span>
                      <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
                    </a>
                  </div>
                {/if}
                {#if plugin.latest.sha256}
                  <code class="store-digest" title={plugin.latest.sha256}>SHA-256 {plugin.latest.sha256.slice(0, 16)}…</code>
                {/if}
              </article>
            {/each}
          </div>
        {:else}
          <div class="store-empty">
            <p>{$LL.plugins.empty()}</p>
          </div>
        {/if}
      </section>
    {/if}

    <section class="download-section" id="download">
      <div class="section-head">
        <h2>{$LL.download.title()}</h2>
        <p>
          {$LL.download.subtitle()}
        </p>
      </div>

      <div class="download-list">
        {#each downloadGroups as group}
          <article class="download-platform">
            <div class="download-platform-copy">
              <h3>{group.label}</h3>
            </div>
            <div class="download-actions">
              {#each group.sources as source}
                {#if source.command}
                  <button
                    class="download-icon-btn"
                    type="button"
                    aria-label={`${group.label} ${source.label}`}
                    onclick={() => copyCommand(source.command)}
                  >
                    <span>
                      {#if copyFallbackCommand === source.command}
                        {source.command}
                      {:else if copiedCommand === source.command}
                        {$LL.download.copied()}
                      {:else}
                        {source.label}
                      {/if}
                    </span>
                    {#if source.file}<small>{source.file}</small>{/if}
                  </button>
                {:else}
                  <a class="download-icon-btn" href={source.href} aria-label={`${group.label} ${source.label}`}>
                    <span>{source.label}</span>
                    {#if source.file}<small>{source.file}</small>{/if}
                    <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
                  </a>
                {/if}
              {/each}
            </div>
          </article>
        {/each}
      </div>

      <p class="download-note">{$LL.download.note()}</p>
    </section>

    <section class="cta-section">
      <div class="cta-block">
        <h2>{$LL.cta.title()}</h2>
        <p>
          {$LL.cta.subtitle()}
        </p>
        <div class="cta-actions">
          <Button variant="secondary" href="https://apps.apple.com/app/id1586449703">{$LL.cta.appStoreAction()}</Button>
          <Button href="https://github.com/lollipopkit/flutter_server_box/releases">{$LL.cta.githubAction()}</Button>
        </div>
      </div>
    </section>

    <footer class="site-footer">
      <span>© 2026 lollipopkit</span>
      <div class="footer-links">
        <a href="#features" onclick={(event) => scrollToSection(event, 'features')}>{$LL.footer.features()}</a>
        <a href="#capabilities" onclick={(event) => scrollToSection(event, 'capabilities')}>{$LL.footer.capabilities()}</a>
        <a href="#themes" onclick={(event) => scrollToSection(event, 'themes')}>{$LL.nav.themes()}</a>
        <a href="https://github.com/lollipopkit/flutter_server_box">GitHub</a>
        <a href="https://github.com/lollipopkit/flutter_server_box/releases">{$LL.footer.releases()}</a>
      </div>
    </footer>
  </main>
{/if}
