<script>
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

  const testimonials = [
    { key: 'admin', name: 'Papercube' },
    { key: 'infra', name: 'wyy' },
    { key: 'student', name: 'Eurafat45' },
  ]

  const screenshots = [
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/1.jpg', key: 'one', x: -18, y: 8, rotate: -7, motion: 18 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/2.jpg', key: 'two', x: -6, y: -4, rotate: -2, motion: 12 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/3.jpg', key: 'three', x: 7, y: 4, rotate: 3, motion: 14 },
    { src: 'https://cdn.lpkt.cn/serverbox/screenshot/4.jpg', key: 'four', x: 18, y: -2, rotate: 8, motion: 20 },
  ]

  const downloadGroups = [
    {
      key: 'iosMacos',
      sources: [
        { key: 'appStore', href: 'https://apps.apple.com/app/id1586449703' },
      ],
    },
    {
      key: 'android',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases' },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid' },
        { key: 'fdroid', href: 'https://f-droid.org/packages/tech.lolli.toolbox' },
        { key: 'openapk', href: 'https://www.openapk.net/serverbox/tech.lolli.toolbox/' },
      ],
    },
    {
      key: 'linux',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases' },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid' },
      ],
    },
    {
      key: 'windows',
      sources: [
        { key: 'github', href: 'https://github.com/lollipopkit/flutter_server_box/releases' },
        { key: 'cdn', href: 'https://cdn.lpkt.cn/serverbox/pkg/?sort=time&order=desc&layout=grid' },
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
</script>

{#if locale && isMounted}
  <main class="site">
    <header class="site-nav" id="top">
      <a class="brand" href="#top">ServerBox</a>
      <nav>
        <a href="#features">{$LL.nav.features()}</a>
        <a href="#capabilities">{$LL.nav.capabilities()}</a>
        <a href="#testimonials">{$LL.nav.testimonials()}</a>
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
        <a class="nav-cta" href="#download">{$LL.nav.download()}</a>
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
            style={`--base-x:${shot.x}%; --base-y:${shot.y}%; --base-r:${shot.rotate}deg; --move-x:${$stackMotion.x * shot.motion}px; --move-y:${$stackMotion.y * shot.motion}px; --tilt-x:${-$stackMotion.y * 6}deg; --tilt-y:${$stackMotion.x * 8}deg; --z:${index + 1};`}
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

      <div class="code-block">
        <span class="prompt">{$LL.capabilities.installIosPrompt()}</span>
        <span class="command">App Store: apps.apple.com/app/id1586449703</span>
        <span class="prompt">{$LL.capabilities.installReleasePrompt()}</span>
        <span class="command">github.com/lollipopkit/flutter_server_box/releases</span>
      </div>
    </section>

    <section class="download-section" id="download">
      <div class="section-head">
        <h2>{$LL.download.title()}</h2>
        <p>
          {$LL.download.subtitle()}
        </p>
      </div>

      <div class="download-grid">
        {#each downloadGroups as group}
          <article class="download-card">
            <div class="download-card-head">
              <h3>{$LL.download.platforms[group.key].title()}</h3>
              <p>{$LL.download.platforms[group.key].description()}</p>
            </div>
            <div class="download-links">
              {#each group.sources as source}
                <a href={source.href}>
                  <span>{$LL.download.sources[source.key].name()}</span>
                  <small>{$LL.download.sources[source.key].note()}</small>
                </a>
              {/each}
            </div>
          </article>
        {/each}
      </div>

      <p class="download-note">{$LL.download.note()}</p>
    </section>

    <section class="page-section" id="testimonials">
      <div class="section-head">
        <h2>{$LL.testimonials.title()}</h2>
      </div>

      <div class="testimonial-grid">
        {#each testimonials as t}
          <article class="testimonial-card">
            <p class="quote">&ldquo;{$LL.testimonials[t.key].quote()}&rdquo;</p>
            <div class="author">
              <p class="name">{t.name}</p>
              <p class="role">{$LL.testimonials[t.key].role()}</p>
            </div>
          </article>
        {/each}
      </div>
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
