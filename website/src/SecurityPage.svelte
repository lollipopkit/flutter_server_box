<script>
  import { Button } from '@serverbox/webui'
  import { ExternalLink, KeyRound, Lock, ShieldCheck, ShieldAlert, RefreshCw } from '@lucide/svelte'
  import LL, { setLocale } from './i18n/i18n-svelte'
  import { loadLocale } from './i18n/i18n-util.sync'
  import { docsHref, getInitialLocale, locales, persistUserLocale, syncLocaleToUrl } from './lib/i18n'

  const initialLocale = getInitialLocale()
  loadLocale(initialLocale)
  setLocale(initialLocale)
  let locale = $state(initialLocale)

  function applyLocale(next) {
    locale = next
    loadLocale(next)
    setLocale(next)
    persistUserLocale(next)
    syncLocaleToUrl(next, true)
  }

  $effect(() => {
    document.documentElement.lang = $LL.meta.lang()
    document.title = $LL.security.metaTitle()
    document.querySelector('meta[name="description"]')?.setAttribute('content', $LL.security.metaDescription())
  })

  const repo = 'https://github.com/lollipopkit/flutter_server_box'
  const releases = `${repo}/releases`

  const threatKeys = ['breach', 'downgrade', 'tamper', 'loss']
  const migrationKeys = ['apple', 'crossPlatform', 'existing']
  const primitives = ['age (X25519 + scrypt)', '128-bit Secret Key', 'BLAKE3', 'Ed25519', 'Crockford Base32']

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
      <a href="#how-it-works" onclick={(event) => scrollTo(event, 'how-it-works')}>{$LL.security.navHow()}</a>
      <a href="#threats" onclick={(event) => scrollTo(event, 'threats')}>{$LL.security.navThreats()}</a>
      <a href="#devices" onclick={(event) => scrollTo(event, 'devices')}>{$LL.security.navDevices()}</a>
      <a href={docsHref(locale, 'advanced/two-factor-encryption/')}>{$LL.nav.docs()}</a>
      <a href={`/?lang=${locale}`}>{$LL.os.navApp()}</a>
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
      <a class="nav-cta" href="https://api.lolli.tech">{$LL.nav.signIn()}</a>
    </div>
  </header>

  <section class="page-section os-hero">
    <div class="os-identity-row">
      <span class="os-formerly-badge">{$LL.security.badge()}</span>
    </div>
    <h1>{$LL.security.heroTitle()}<br /><span>{$LL.security.heroHighlight()}</span></h1>
    <p class="hero-subtitle">{$LL.security.subtitle()}</p>
    <p class="os-monitor-callout sec-warning-callout">
      <ShieldAlert size={18} strokeWidth={2} aria-hidden="true" />
      <span>{$LL.security.zeroKnowledgeNotice()}</span>
    </p>
    <div class="hero-actions">
      <Button href="#how-it-works" onclick={(event) => scrollTo(event, 'how-it-works')}>{$LL.security.primaryAction()}</Button>
      <Button variant="secondary" href={docsHref(locale, 'advanced/two-factor-encryption/')}>{$LL.security.docsAction()}</Button>
    </div>
  </section>

  <section class="page-section" id="how-it-works">
    <div class="section-head">
      <h2>{$LL.security.howTitle()}</h2>
      <p>{$LL.security.howSubtitle()}</p>
    </div>

    <div class="sec-factors">
      <article class="feature-card sec-factor-card">
        <div class="sec-card-head">
          <Lock size={18} strokeWidth={1.9} aria-hidden="true" />
          <span class="tour-tag">01 · {$LL.security.factor1Tag()}</span>
        </div>
        <h3>{$LL.security.factor1Title()}</h3>
        <p>{$LL.security.factor1Desc()}</p>
      </article>

      <article class="feature-card sec-factor-card">
        <div class="sec-card-head">
          <KeyRound size={18} strokeWidth={1.9} aria-hidden="true" />
          <span class="tour-tag">02 · {$LL.security.factor2Tag()}</span>
        </div>
        <h3>{$LL.security.factor2Title()}</h3>
        <p>{$LL.security.factor2Desc()}</p>
        <code class="sec-key-sample" dir="ltr">S1-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</code>
      </article>
    </div>

    <div class="code-block sec-diagram" dir="ltr">
      <span class="prompt"># {$LL.security.diagramStep1()}</span>
      <span class="command">passphrase = BLAKE3_derive_key("lkc sync v1 secret-key passphrase", secret_key || len(password) || password)</span>
      <span class="prompt"># {$LL.security.diagramStep2()}</span>
      <span class="command">identity.age = age_scrypt(passphrase, X25519_sync_keypair)</span>
      <span class="prompt"># {$LL.security.diagramStep3()}</span>
      <span class="command">remote_payload = age_x25519(sync_pubkey, servers / ssh_keys / settings / logs)</span>
      <span class="prompt"># {$LL.security.diagramStep4()}</span>
      <span class="command">lk_cloud_write = Ed25519_sign(account_key, payload || monotonic_version)</span>
    </div>

    <div class="protocol-badges" aria-label={$LL.security.primitivesLabel()}>
      {#each primitives as item}
        <span class="protocol-badge" dir="ltr">{item}</span>
      {/each}
    </div>
  </section>

  <section class="page-section" id="threats">
    <div class="section-head">
      <h2>{$LL.security.threatsTitle()}</h2>
      <p>{$LL.security.threatsSubtitle()}</p>
    </div>

    <div class="sec-threat-table">
      <div class="sec-threat-head" aria-hidden="true">
        <span>{$LL.security.colScenario()}</span>
        <span>{$LL.security.colBehavior()}</span>
      </div>
      {#each threatKeys as key}
        <article class="sec-threat-row">
          <div class="sec-threat-scenario">
            <ShieldCheck size={16} strokeWidth={1.9} aria-hidden="true" />
            <h3>{$LL.security.threats[key].scenario()}</h3>
          </div>
          <p>{$LL.security.threats[key].behavior()}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="page-section" id="devices">
    <div class="section-head">
      <h2>{$LL.security.devicesTitle()}</h2>
      <p>{$LL.security.devicesSubtitle()}</p>
    </div>

    <div class="sec-devices-grid">
      {#each migrationKeys as key}
        <article class="feature-card">
          <div class="sec-card-head">
            <RefreshCw size={16} strokeWidth={1.9} aria-hidden="true" />
            <span class="tour-tag">{$LL.security.devices[key].tag()}</span>
          </div>
          <h3>{$LL.security.devices[key].title()}</h3>
          <p>{$LL.security.devices[key].description()}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="page-section">
    <div class="store-footer">
      <p class="download-note">{$LL.security.footerNote()}</p>
      <div class="store-actions">
        <a class="download-icon-btn" href={docsHref(locale, 'privacy/')}>
          <span>{$LL.security.privacyLink()}</span>
          <ExternalLink size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
        <a class="download-icon-btn" href={repo}>
          <span>GitHub</span>
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
      <a href={`/os/?lang=${locale}`}>{$LL.nav.os()}<span class="beta-tag">{$LL.nav.beta()}</span></a>
      <a href={docsHref(locale)}>{$LL.nav.docs()}</a>
      <a href={releases}>{$LL.footer.releases()}</a>
    </div>
  </footer>
</main>
