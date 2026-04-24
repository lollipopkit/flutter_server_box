<script>
  import {
    Apple,
    Archive,
    Download,
    ExternalLink,
    Package,
    Store,
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
  } from './lib/i18n.js'

  const capabilities = ['Status chart', 'SSH Terminal', 'SFTP', 'Docker', 'Process', 'Systemd', 'S.M.A.R.T', 'GPU', 'Sensors', 'Push', 'Home Widget', 'watchOS']

  const features = [
    { key: 'charts', icon: '⬡', wide: false },
    { key: 'workspace', icon: '⬡', wide: true },
    { key: 'terminal', icon: '⬡', wide: false },
    { key: 'native', icon: '⬡', wide: false },
    { key: 'platforms', icon: '⬡', wide: false },
  ]

  const screenshots = [
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/1.jpg', key: 'one', x: -18, y: 8, hoverSlot: -1.5, rotate: -7, hoverRotate: -1.8, motion: 18 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/2.jpg', key: 'two', x: -6, y: -4, hoverSlot: -0.5, rotate: -2, hoverRotate: -0.6, motion: 12 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/3.jpg', key: 'three', x: 7, y: 4, hoverSlot: 0.5, rotate: 3, hoverRotate: 0.6, motion: 14 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/4.jpg', key: 'four', x: 18, y: -2, hoverSlot: 1.5, rotate: 8, hoverRotate: 1.8, motion: 20 },
  ]

  const downloadGroups = [
    {
      key: 'iosMacos',
      sources: [
        { key: 'appStore', href: 'https://apps.apple.com/app/id1586449703', Icon: Apple },
        { key: 'homebrew', command: 'brew install --cask server-box', Icon: Package },
      ],
    },
    {
      key: 'android',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases', Icon: Download },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid', Icon: Archive },
        { key: 'fdroid', href: 'https://f-droid.org/packages/tech.lolli.toolbox', Icon: Store },
        { key: 'openapk', href: 'https://www.openapk.net/serverbox/tech.lolli.toolbox/', Icon: Package },
      ],
    },
    {
      key: 'linux',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases', Icon: Download },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid', Icon: Archive },
      ],
    },
    {
      key: 'windows',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases', Icon: Download },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid', Icon: Archive },
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
  let isMounted = $state(false)
  let copiedCommand = $state(undefined)

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

    isMounted = true
  })

  $effect(() => {
    if (!isMounted) return

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

  async function copyCommand(command) {
    try {
      await navigator.clipboard.writeText(command)
      copiedCommand = command
      window.setTimeout(() => {
        if (copiedCommand === command) copiedCommand = undefined
      }, 1800)
    } catch {
      copiedCommand = undefined
    }
  }
</script>

{#if locale && isMounted}
  <main class="site">
    <header class="site-nav" id="top">
      <a class="brand" href="#top">ServerBox</a>
      <nav>
        <a href="#features">{$LL.nav.features()}</a>
        <a href="#capabilities">{$LL.nav.capabilities()}</a>
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
      <h1>{$LL.hero.titlePrefix()}<br />{$LL.hero.titleSuffix()}</h1>
      <p class="hero-subtitle">
        {$LL.hero.subtitle()}
      </p>
      <div class="hero-actions">
        <a class="btn btn-primary" href="#download">{$LL.hero.primaryAction()}</a>
        <a class="btn btn-secondary" href="#features">{$LL.hero.secondaryAction()}</a>
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
            style={`--base-x:${shot.x}%; --base-y:${shot.y}%; --hover-slot:${shot.hoverSlot}; --base-r:${shot.rotate}deg; --hover-r:${shot.hoverRotate}deg; --move-x:${$stackMotion.x * shot.motion}px; --move-y:${$stackMotion.y * shot.motion}px; --tilt-x:${-$stackMotion.y * 6}deg; --tilt-y:${$stackMotion.x * 8}deg; --z:${index + 1};`}
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

      <div class="feature-grid">
        {#each features as feature}
          <article class="feature-card" class:wide={feature.wide}>
            <div class="icon">{feature.icon}</div>
            <h3>{$LL.features[feature.key].title()}</h3>
            <p>{$LL.features[feature.key].description()}</p>
          </article>
        {/each}
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
              <h3>{$LL.download.platforms[group.key].title()}</h3>
              <p>{$LL.download.platforms[group.key].description()}</p>
            </div>
            <div class="download-actions">
              {#each group.sources as source}
                {#if source.command}
                  <button
                    class="download-icon-btn"
                    type="button"
                    aria-label={`${$LL.download.platforms[group.key].title()} ${$LL.download.sources[source.key].name()}`}
                    onclick={() => copyCommand(source.command)}
                  >
                    <source.Icon size={17} strokeWidth={1.8} aria-hidden="true" />
                    <span>{copiedCommand === source.command ? $LL.download.copied() : $LL.download.sources[source.key].name()}</span>
                  </button>
                {:else}
                  <a class="download-icon-btn" href={source.href} aria-label={`${$LL.download.platforms[group.key].title()} ${$LL.download.sources[source.key].name()}`}>
                    <source.Icon size={17} strokeWidth={1.8} aria-hidden="true" />
                    <span>{$LL.download.sources[source.key].name()}</span>
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
          <a class="btn btn-secondary" href="https://apps.apple.com/app/id1586449703">{$LL.cta.appStoreAction()}</a>
          <a class="btn btn-primary" href="https://github.com/lollipopkit/flutter_server_box/releases">{$LL.cta.githubAction()}</a>
        </div>
      </div>
    </section>

    <footer class="site-footer">
      <span>© 2026 ServerBox</span>
      <div class="footer-links">
        <a href="#features">{$LL.footer.features()}</a>
        <a href="#capabilities">{$LL.footer.capabilities()}</a>
        <a href="https://github.com/lollipopkit/flutter_server_box">GitHub</a>
        <a href="https://github.com/lollipopkit/flutter_server_box/releases">{$LL.footer.releases()}</a>
      </div>
    </footer>
  </main>
{/if}
