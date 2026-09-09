<script>
  import { ExternalLink } from '@lucide/svelte'
  import { onMount } from 'svelte'
  import catalog from 'virtual:plugin-catalog'
  import LL, { setLocale } from './i18n/i18n-svelte'
  import { loadLocale } from './i18n/i18n-util.sync'
  import {
    getInitialLocale,
    locales,
    localeStorageKey,
    syncLocaleToUrl,
  } from './lib/i18n'

  // The plugins, read out of `packages/plugins/*/manifest.json` at build time
  // by the `pluginCatalog` plugin in `vite.config.js`. So a version or a
  // permission shown here is the one in the package, not a copy of it that can
  // drift.
  const plugins = catalog

  // The same address the app ships with (`PluginRepoStore.officialUrls`), which
  // is the repository itself: a client fetches its latest tree. Written here
  // rather than fetched so the page can say what to type when a repository has
  // been removed.
  const officialAddress = 'https://github.com/lollipopkit/serverbox-plugins'

  const repoUrl = officialAddress
  const sourceBase =
    'https://github.com/lollipopkit/flutter_server_box/tree/main/packages'

  const howPoints = ['sandbox', 'permissions', 'anyRepo']

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
  let copied = $state(false)

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
    document.title = $LL.plugins.metaTitle()
    document
      .querySelector('meta[name="description"]')
      ?.setAttribute('content', $LL.plugins.metaDescription())
  })

  function handleLocaleChange(event) {
    applyLocale(event.currentTarget.value)
    syncLocaleToUrl(event.currentTarget.value)
  }

  async function copyAddress() {
    try {
      await navigator.clipboard.writeText(officialAddress)
      copied = true
      window.setTimeout(() => (copied = false), 1800)
    } catch {
      copied = false
      window.prompt($LL.download.copyPrompt(), officialAddress)
    }
  }
</script>

{#if locale}
  <main class="site">
    <header class="site-nav" id="top">
      <a class="brand" href="/">ServerBox</a>
      <nav>
        <a href="/#features">{$LL.nav.features()}</a>
        <a href="/plugins/" aria-current="page">{$LL.nav.plugins()}</a>
        <a href="/#download">{$LL.nav.download()}</a>
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

    <section class="hero hero-compact">
      <h1>{$LL.plugins.title()}</h1>
      <p class="hero-subtitle">{$LL.plugins.subtitle()}</p>
    </section>

    <section class="page-section" id="how">
      <div class="feature-grid">
        {#each howPoints as point}
          <article class="feature-card">
            <div class="icon">⬡</div>
            <h3>{$LL.plugins.how[point].title()}</h3>
            <p>{$LL.plugins.how[point].description()}</p>
          </article>
        {/each}
      </div>
    </section>

    <section class="page-section" id="list">
      <div class="section-head">
        <h2>{$LL.plugins.listTitle()}</h2>
        <p>{$LL.plugins.listSubtitle({ count: plugins.length })}</p>
      </div>

      <div class="plugin-grid">
        {#each plugins as plugin}
          <article class="plugin-card">
            <div class="plugin-head">
              <h3>{plugin.name}</h3>
              <span class="plugin-version">v{plugin.version}</span>
            </div>
            <p class="plugin-description">{plugin.description}</p>

            <dl class="plugin-meta">
              <div>
                <dt>{$LL.plugins.asks()}</dt>
                <dd>
                  {#if plugin.permissions.length === 0}
                    <span class="plugin-none">{$LL.plugins.asksNothing()}</span>
                  {:else}
                    {#each plugin.permissions as permission}
                      <span class="protocol-badge">{permission}</span>
                    {/each}
                  {/if}
                </dd>
              </div>
              <div>
                <dt>{$LL.plugins.appearsIn()}</dt>
                <dd>
                  {#each plugin.surfaces as surface}
                    <span class="protocol-badge">{surface}</span>
                  {/each}
                </dd>
              </div>
              <div>
                <dt>{$LL.plugins.languages()}</dt>
                <dd><span class="plugin-none">{plugin.locales.join(', ')}</span></dd>
              </div>
            </dl>

            <div class="plugin-foot">
              <span>ABI {plugin.abi}{plugin.license ? ` · ${plugin.license}` : ''}</span>
              <a href={`${sourceBase}/plugins/${plugin.dir}`}>
                <span>{$LL.plugins.source()}</span>
                <ExternalLink size={13} strokeWidth={1.8} aria-hidden="true" />
              </a>
            </div>
          </article>
        {/each}
      </div>
    </section>

    <section class="page-section" id="install">
      <div class="section-head">
        <h2>{$LL.plugins.install.title()}</h2>
      </div>

      <ol class="plugin-steps">
        <li>{$LL.plugins.install.stepOne()}</li>
        <li>{$LL.plugins.install.stepTwo()}</li>
        <li>{$LL.plugins.install.stepThree()}</li>
      </ol>

      <p class="install-note">{$LL.plugins.install.address()}</p>
      <div class="code-block">
        <span class="command">{officialAddress}</span>
      </div>
      <div class="hero-actions">
        <button class="download-icon-btn" type="button" onclick={copyAddress}>
          <span>{copied ? $LL.download.copied() : $LL.plugins.install.copy()}</span>
        </button>
      </div>
    </section>

    <section class="page-section" id="write">
      <div class="section-head">
        <h2>{$LL.plugins.write.title()}</h2>
        <p>{$LL.plugins.write.description()}</p>
      </div>

      <div class="download-actions">
        <a class="download-icon-btn" href={`${sourceBase}/plugin-api`}>
          <span>{$LL.plugins.write.sdk()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
        <a class="download-icon-btn" href={`${sourceBase}/plugins`}>
          <span>{$LL.plugins.write.examples()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
        <a class="download-icon-btn" href={repoUrl}>
          <span>{$LL.plugins.write.repository()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
      </div>
    </section>

    <footer class="site-footer">
      <span>© 2026 lollipopkit</span>
      <div class="footer-links">
        <a href="/">{$LL.plugins.home()}</a>
        <a href="/docs/">{$LL.nav.docs()}</a>
        <a href="https://github.com/lollipopkit/flutter_server_box">GitHub</a>
        <a href={repoUrl}>{$LL.nav.plugins()}</a>
      </div>
    </footer>
  </main>
{/if}
