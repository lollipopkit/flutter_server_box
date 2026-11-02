<script>
  // ServerBox OS: ServerBox Monitor on the server, installed on a Linux system
  // or booted as the whole system from an sbOS image.
  import { Button } from '@serverbox/webui'
  import { ExternalLink } from '@lucide/svelte'
  import LL, { setLocale } from './i18n/i18n-svelte'
  import { loadLocale } from './i18n/i18n-util.sync'
  import { getInitialLocale, locales, localeStorageKey, syncLocaleToUrl } from './lib/i18n'

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

  $effect(() => {
    document.documentElement.lang = $LL.meta.lang()
    document.title = $LL.os.metaTitle()
    document.querySelector('meta[name="description"]')?.setAttribute('content', $LL.os.metaDescription())
  })

  const releases = 'https://github.com/lollipopkit/flutter_server_box/releases'

  // The beta's tour. Shown as its thumbnail until played, so YouTube is
  // reached only by someone who asks for the video.
  const video = 'ecMRqXkWqCg'
  let playing = $state(false)
  const script = 'https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh'

  // Each key selects its localized title and description.
  const points = ['desk', 'apps', 'storage', 'agent', 'alerts', 'backups', 'security', 'app']

  // `prompt` selects the localized comment; the commands stay as they are.
  const installs = [
    { prompt: 'promptUser', command: `curl -fsSL ${script} | sh -s -- install` },
    { prompt: 'promptOpenrc', command: `curl -fsSL ${script} | sudo sh -s -- install` },
    { prompt: 'promptRoot', command: `curl -fsSL ${script} | sudo sh -s -- install --system` },
  ]

  // The files on a release: names, bases and boot modes stay untranslated.
  const images = [
    { file: 'sbOS_GNU_x64.img', about: 'Debian 13 · systemd · BIOS, UEFI' },
    { file: 'sbOS_GNU_arm64.img', about: 'Debian 13 · systemd · UEFI' },
    { file: 'sbOS_musl_x64.img', about: 'Alpine Linux · OpenRC · BIOS, UEFI' },
    { file: 'sbOS_musl_arm64.img', about: 'Alpine Linux · OpenRC · UEFI' },
  ]
  const steps = ['stepWrite', 'stepBoot', 'stepInstall']

  let copied = $state(undefined)

  async function copy(command) {
    try {
      await navigator.clipboard.writeText(command)
      copied = command
      window.setTimeout(() => {
        if (copied === command) copied = undefined
      }, 1800)
    } catch {
      window.prompt($LL.download.copyPrompt(), command)
    }
  }

  function scrollTo(event, id) {
    event.preventDefault()
    const smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches
    document.getElementById(id)?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto', block: 'start' })
  }
</script>

<main class="site">
  <header class="site-nav" id="top">
    <a class="brand" href={`/?lang=${locale}`}>
      <img src="/app_icon.png" alt="" width="26" height="26" />
      ServerBox
    </a>
    <nav>
      <a href={`/?lang=${locale}#features`}>{$LL.nav.features()}</a>
      <a href={`/os/?lang=${locale}`} aria-current="page">{$LL.nav.os()}<span class="beta-tag">{$LL.nav.beta()}</span></a>
      <a href={`/themes/?lang=${locale}`}>{$LL.nav.themes()}</a>
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

  <section class="page-section os-hero">
    <p class="hero-platforms">Linux · x64 · arm64</p>
    <h1>{$LL.os.heroTitle()}<span class="beta-tag beta-tag--hero">{$LL.nav.beta()}</span><br /><span>{$LL.os.tagline()}</span></h1>
    <p class="hero-subtitle">{$LL.os.subtitle()}</p>
    <div class="hero-actions">
      <Button href="#install" onclick={(event) => scrollTo(event, 'install')}>{$LL.os.installAction()}</Button>
      <Button variant="secondary" href="#preview" onclick={(event) => scrollTo(event, 'preview')}>{$LL.os.previewAction()}</Button>
    </div>
  </section>

  <section class="page-section" id="preview">
    <div class="section-head">
      <h2>{$LL.os.previewTitle()}</h2>
      <p>{$LL.os.previewSubtitle()}</p>
    </div>
    <div class="os-video">
      {#if playing}
        <iframe
          src={`https://www.youtube-nocookie.com/embed/${video}?autoplay=1&rel=0`}
          title="ServerBox Web OS (Beta)"
          allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
          referrerpolicy="strict-origin-when-cross-origin"
          allowfullscreen
        ></iframe>
      {:else}
        <button type="button" class="os-video-play" aria-label={$LL.os.previewPlay()} onclick={() => (playing = true)}>
          <img src={`https://i.ytimg.com/vi/${video}/maxresdefault.jpg`} alt="" loading="lazy" decoding="async" referrerpolicy="no-referrer" />
          <span class="os-video-icon" aria-hidden="true"></span>
        </button>
      {/if}
    </div>
    <div class="os-video-foot">
      <a class="download-icon-btn" href={`https://youtu.be/${video}`}>
        <span>{$LL.os.previewYoutube()}</span>
        <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
      </a>
    </div>
  </section>

  <section class="page-section" id="features">
    <div class="section-head">
      <h2>{$LL.os.featuresTitle()}</h2>
      <p>{$LL.os.featuresSubtitle()}</p>
    </div>
    <div class="os-grid">
      {#each points as point}
        <article class="feature-card">
          <h3>{$LL.os[point].title()}</h3>
          <p>{$LL.os[point].description()}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="page-section" id="install">
    <div class="section-head">
      <h2>{$LL.os.installTitle()}</h2>
      <p>{$LL.os.installSubtitle()}</p>
    </div>

    <h3 class="os-subhead">{$LL.os.linuxTitle()}</h3>
    <div class="code-block os-code">
      {#each installs as item}
        <span class="prompt">{$LL.os[item.prompt]()}</span>
        <span class="command">{item.command}</span>
      {/each}
    </div>
    <div class="os-row">
      <p class="install-note">{$LL.os.linuxNote()}</p>
      <button class="download-icon-btn" type="button" onclick={() => copy(installs[0].command)}>
        <span>{copied === installs[0].command ? $LL.download.copied() : $LL.os.copy()}</span>
      </button>
    </div>

    <h3 class="os-subhead">{$LL.os.imageTitle()}</h3>
    <div class="download-list">
      {#each images as image}
        <article class="download-platform">
          <div class="download-platform-copy">
            <h3 class="os-image">{image.file}</h3>
          </div>
          <div class="download-actions">
            <span class="os-image-about">{image.about}</span>
            <a class="download-icon-btn" href={releases} aria-label={image.file}>
              <span>GitHub Releases</span>
              <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
            </a>
          </div>
        </article>
      {/each}
    </div>
    <ol class="os-steps">
      {#each steps as step}
        <li>{$LL.os[step]()}</li>
      {/each}
    </ol>
    <p class="install-note">{$LL.os.liveNote()}</p>
  </section>

  <section class="page-section">
    <div class="store-footer">
      <p class="download-note">{$LL.os.note()}</p>
      <div class="store-actions">
        <a class="download-icon-btn" href="/docs/advanced/monitor-agent/">
          <span>{$LL.os.docs()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
        <Button href={`/?lang=${locale}#download`}>{$LL.os.appAction()}</Button>
      </div>
    </div>
  </section>

  <footer class="site-footer">
    <span>© 2026 lollipopkit</span>
    <div class="footer-links">
      <a href={`/?lang=${locale}`}>ServerBox</a>
      <a href="https://github.com/lollipopkit/flutter_server_box/tree/main/monitor">monitor/</a>
      <a href={releases}>{$LL.footer.releases()}</a>
    </div>
  </footer>
</main>
