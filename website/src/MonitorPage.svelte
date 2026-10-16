<script>
  // ServerBox Monitor on the site: what the agent adds to SSH, its panel,
  // alerts and access model, and how to install it.
  import { onMount } from 'svelte'
  import { Button } from '@serverbox/webui'
  import { Check, Copy, ExternalLink } from '@lucide/svelte'
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
    document.title = $LL.monitor.meta.title()
    document.querySelector('meta[name="description"]')?.setAttribute('content', $LL.monitor.meta.description())
  })

  const installer = 'https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh'
  const commands = {
    systemd: `curl -fsSL ${installer} | sh -s -- install`,
    openrc: `curl -fsSL ${installer} | sudo sh -s -- install`,
    docker:
      'git clone --depth 1 https://github.com/lollipopkit/flutter_server_box && cd flutter_server_box/monitor && docker compose up -d --build',
  }
  const passwordCommand = 'cd ~/.local/share/server-box-monitor && ./server_box_monitor user set-password admin'
  // The rule format of config.toml, as config.example.toml has it.
  const ruleExample = `[[monitoring.rules]]
name = "Network out"
monitor_type = "network"
matcher = "tx"
threshold = ">=10m/s"`

  // Screenshots of the panel live on the CDN beside the app's, as 1440px
  // JPEGs. A row shows its image once it has loaded, and its text alone
  // until then, or if there is none yet.
  const shotBase = 'https://cdn.lollipopkit.com/serverbox/screenshot/monitor'
  const rows = [
    { key: 'dashboard', shot: 'dashboard', tags: ['CPU', 'Memory', 'Disks', 'Network', 'GPU', 'Sensors', 'S.M.A.R.T'] },
    { key: 'terminal', shot: 'terminal', tags: ['Terminal', 'tmux', 'Files'] },
    { key: 'machine', shot: 'containers', tags: ['Docker', 'Podman', 'systemd', 'OpenRC', 'cron', 'ufw', 'firewalld'] },
    { key: 'reach', shot: 'desktop', tags: ['RDP', 'VNC', 'Redfish', 'Proxmox VE', 'libvirt'] },
  ]
  let shown = $state({})

  let tab = $state('systemd')
  let copied = $state(null)
  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text)
      copied = text
      setTimeout(() => {
        if (copied === text) copied = null
      }, 1600)
    } catch {
      window.prompt('', text)
    }
  }

  // The hero's terminal: the agent installed, then a sample every 7 seconds,
  // its default `interval_seconds`. Still when motion is reduced.
  let samples = $state([7, 14])
  onMount(() => {
    syncLocaleToUrl(locale)
    for (const { shot } of rows) {
      const probe = new Image()
      probe.referrerPolicy = 'no-referrer'
      probe.onload = () => (shown = { ...shown, [shot]: true })
      probe.src = `${shotBase}/${shot}.jpg`
    }
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const timer = setInterval(() => {
      samples = [...samples, samples.at(-1) + 7].slice(-3)
    }, 7000)
    return () => clearInterval(timer)
  })

  function scrollToSection(event, id) {
    event.preventDefault()
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
</script>

<main class="site monitor">
  <header class="site-nav" id="top">
    <a class="brand" href={`/?lang=${locale}`}>ServerBox</a>
    <nav>
      <a href={`/?lang=${locale}#features`}>{$LL.nav.features()}</a>
      <a href={`/monitor/?lang=${locale}`} aria-current="page">{$LL.nav.monitor()}</a>
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

  <section class="m-hero">
    <div class="m-hero-copy">
      <p class="m-eyebrow"><span class="m-live" aria-hidden="true"></span>{$LL.monitor.hero.eyebrow()}</p>
      <h1>{$LL.monitor.hero.title()}</h1>
      <p class="m-lede">{$LL.monitor.hero.subtitle()}</p>

      <div class="m-install">
        <span class="m-install-label">{$LL.monitor.hero.installLabel()}</span>
        <div class="m-command">
          <code>{commands.systemd}</code>
          <button type="button" onclick={() => copy(commands.systemd)} aria-label={$LL.monitor.hero.copy()}>
            {#if copied === commands.systemd}<Check size={16} />{:else}<Copy size={16} />{/if}
            <span>{copied === commands.systemd ? $LL.monitor.hero.copied() : $LL.monitor.hero.copy()}</span>
          </button>
        </div>
        <span class="m-install-note">{$LL.monitor.hero.installNote()}</span>
      </div>

      <div class="hero-actions m-hero-actions">
        <Button href="#install" onclick={(e) => scrollToSection(e, 'install')}>{$LL.monitor.nav.install()}</Button>
        <Button variant="secondary" href="/docs/advanced/monitor-agent/">{$LL.monitor.hero.guide()}</Button>
      </div>
    </div>

    <div class="m-relay">
      <div class="m-term" role="img" aria-label={$LL.monitor.hero.terminalLabel()}>
        <div class="m-term-bar"><i></i><i></i><i></i><span>server</span></div>
        <pre><span class="m-dim">$</span> curl -fsSL …/install.sh | sh -s -- install
<span class="m-ok">✓</span> {$LL.monitor.hero.installed()}
<span class="m-ok">✓</span> {$LL.monitor.hero.listening()}
{#each samples as t (t)}<span class="m-sample"><span class="m-dim">t+{t}s</span> {$LL.monitor.hero.sampled()}  cpu · mem · swap · disk · net · gpu
</span>{/each}<span class="m-dim"># {$LL.monitor.hero.cadence()}</span></pre>
      </div>
      <div class="m-wire" aria-hidden="true"></div>
      <div class="m-pocket">
        <img src="/monitor/ios-push.jpg" alt={$LL.monitor.hero.pushLabel()} width="750" height="440" />
        <img class="m-widget" src="/monitor/ios-widget.png" alt={$LL.monitor.hero.widgetLabel()} width="252" height="241" />
      </div>
    </div>
  </section>

  <div class="m-keywords" aria-label={$LL.monitor.hero.eyebrow()}>
    <span class="protocol-badge">Rust</span>
    {#each ['history', 'push', 'panel', 'roles', 'docker'] as k}
      <span class="protocol-badge">{$LL.monitor.keywords[k]()}</span>
    {/each}
  </div>

  <section class="page-section" id="why">
    <div class="section-head">
      <h2>{$LL.monitor.why.title()}</h2>
      <p>{$LL.monitor.why.subtitle()}</p>
    </div>
    <div class="m-why">
      {#each ['history', 'alerts', 'widgets', 'reach'] as k}
        <article>
          <h3>{$LL.monitor.why[k].title()}</h3>
          <p>{$LL.monitor.why[k].description()}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="page-section" id="panel">
    <div class="section-head">
      <h2>{$LL.monitor.panel.title()}</h2>
      <p>{$LL.monitor.panel.subtitle()}</p>
    </div>
    {#each rows as row, i}
      <article class="m-row" class:flip={i % 2 === 1} class:text-only={!shown[row.shot]}>
        <div class="m-row-copy">
          <h3>{$LL.monitor.panel[row.key].title()}</h3>
          <p>{$LL.monitor.panel[row.key].description()}</p>
          <div class="m-tags">
            {#each row.tags as tag}<span class="protocol-badge">{tag}</span>{/each}
          </div>
        </div>
        {#if shown[row.shot]}
          <figure class="m-shot">
            <img
              src={`${shotBase}/${row.shot}.jpg`}
              alt={`ServerBox Monitor — ${$LL.monitor.panel[row.key].title()}`}
              decoding="async"
              referrerpolicy="no-referrer"
            />
          </figure>
        {/if}
      </article>
    {/each}
  </section>

  <section class="page-section" id="alerts">
    <div class="section-head">
      <h2>{$LL.monitor.alerts.title()}</h2>
      <p>{$LL.monitor.alerts.subtitle()}</p>
    </div>
    <div class="m-alerts">
      <figure class="m-rule">
        <figcaption>{$LL.monitor.alerts.rule()}</figcaption>
        <pre>{ruleExample}</pre>
      </figure>
      <figure>
        <img src="/monitor/ios-push.jpg" alt={$LL.monitor.alerts.push()} loading="lazy" width="750" height="440" />
        <figcaption>{$LL.monitor.alerts.push()}</figcaption>
      </figure>
      <figure>
        <img src="/monitor/webhook.jpg" alt={$LL.monitor.alerts.webhook()} loading="lazy" width="1221" height="861" />
        <figcaption>{$LL.monitor.alerts.webhook()}</figcaption>
      </figure>
    </div>
    <div class="m-tags m-channels">
      {#each ['iOS', 'Bark', 'ServerChan', 'Webhook'] as channel}<span class="protocol-badge">{channel}</span>{/each}
    </div>
  </section>

  <section class="page-section" id="access">
    <div class="section-head">
      <h2>{$LL.monitor.access.title()}</h2>
      <p>{$LL.monitor.access.subtitle()}</p>
    </div>
    <div class="m-why">
      {#each ['roles', 'transport', 'account', 'audit'] as k}
        <article>
          <h3>{$LL.monitor.access[k].title()}</h3>
          <p>{$LL.monitor.access[k].description()}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="page-section" id="install">
    <div class="section-head">
      <h2>{$LL.monitor.install.title()}</h2>
      <p>{$LL.monitor.install.subtitle()}</p>
    </div>
    <ol class="m-steps">
      <li>
        <h3>{$LL.monitor.install.step1.title()}</h3>
        <p>{$LL.monitor.install.step1.description()}</p>
        <div class="m-tabs" role="tablist">
          {#each Object.keys(commands) as key}
            <button type="button" role="tab" aria-selected={tab === key} class:active={tab === key} onclick={() => (tab = key)}>
              {$LL.monitor.install.tabs[key]()}
            </button>
          {/each}
        </div>
        <div class="m-command" role="tabpanel">
          <code>{commands[tab]}</code>
          <button type="button" onclick={() => copy(commands[tab])} aria-label={$LL.monitor.hero.copy()}>
            {#if copied === commands[tab]}<Check size={16} />{:else}<Copy size={16} />{/if}
            <span>{copied === commands[tab] ? $LL.monitor.hero.copied() : $LL.monitor.hero.copy()}</span>
          </button>
        </div>
        {#if tab === 'docker'}<p class="m-install-note">{$LL.monitor.install.dockerNote()}</p>{/if}
      </li>
      <li>
        <h3>{$LL.monitor.install.step2.title()}</h3>
        <p>{$LL.monitor.install.step2.description()}</p>
        <div class="m-command">
          <code>{passwordCommand}</code>
          <button type="button" onclick={() => copy(passwordCommand)} aria-label={$LL.monitor.hero.copy()}>
            {#if copied === passwordCommand}<Check size={16} />{:else}<Copy size={16} />{/if}
            <span>{copied === passwordCommand ? $LL.monitor.hero.copied() : $LL.monitor.hero.copy()}</span>
          </button>
        </div>
      </li>
      <li>
        <h3>{$LL.monitor.install.step3.title()}</h3>
        <p>{$LL.monitor.install.step3.description()}</p>
      </li>
    </ol>
  </section>

  <section class="cta-section">
    <div class="cta-block">
      <h2>{$LL.monitor.cta.title()}</h2>
      <p>{$LL.monitor.cta.subtitle()}</p>
      <div class="cta-actions">
        <Button variant="secondary" href="https://github.com/lollipopkit/flutter_server_box/tree/main/monitor">
          {$LL.monitor.cta.source()}
        </Button>
        <Button href={`/?lang=${locale}#download`}>{$LL.monitor.cta.app()}</Button>
      </div>
    </div>
  </section>

  <footer class="site-footer">
    <span>© 2026 lollipopkit</span>
    <div class="footer-links">
      <a href="/docs/advanced/monitor-agent/">{$LL.monitor.hero.guide()} <ExternalLink size={12} aria-hidden="true" /></a>
      <a href="https://github.com/lollipopkit/flutter_server_box">GitHub</a>
      <a href="https://github.com/lollipopkit/flutter_server_box/releases">{$LL.footer.releases()}</a>
    </div>
  </footer>
</main>

<style>
  .m-hero {
    display: grid;
    grid-template-columns: minmax(0, 1.05fr) minmax(0, 1fr);
    gap: clamp(2rem, 5vw, 4.5rem);
    align-items: center;
    width: min(1080px, 92vw);
    margin: 0 auto;
    padding: clamp(3rem, 8vw, 6rem) 0 2.5rem;
  }
  .m-hero-copy {
    min-width: 0;
  }
  .m-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    margin: 0 0 1.1rem;
    font-family: var(--font-mono);
    font-size: 0.82rem;
    letter-spacing: 0.04em;
    color: var(--stone);
  }
  /* The page's one colour: an agent that is up. */
  .m-live {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #22c55e;
    box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5);
    animation: m-pulse 7s infinite;
  }
  @keyframes m-pulse {
    0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.55); }
    12% { box-shadow: 0 0 0 9px rgba(34, 197, 94, 0); }
    100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
  }
  .m-hero h1 {
    margin: 0;
    font-family: var(--font-display);
    font-size: clamp(2.3rem, 5.2vw, 4rem);
    font-weight: 800;
    line-height: 1.04;
    letter-spacing: -0.035em;
    color: var(--black);
    text-wrap: balance;
    /* CJK titles break at their punctuation, not inside a phrase. */
    word-break: keep-all;
    overflow-wrap: anywhere;
  }
  .m-lede {
    margin: 1.25rem 0 0;
    max-width: 36rem;
    font-size: 1.06rem;
    line-height: 1.65;
    color: var(--mid-gray);
  }
  .m-install {
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: 0.5rem;
    margin-top: 1.75rem;
  }
  .m-install-label {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--black);
  }
  .m-install-note {
    margin: 0;
    font-size: 0.82rem;
    color: var(--stone);
  }
  .m-command {
    display: flex;
    align-items: stretch;
    min-width: 0;
    border: 1px solid var(--border-light);
    border-radius: var(--radius-container);
    background: var(--snow);
    overflow: hidden;
  }
  .m-command code {
    flex: 1;
    min-width: 0;
    padding: 0.8rem 0.95rem;
    overflow-x: auto;
    white-space: nowrap;
    font-family: var(--font-mono);
    font-size: 0.82rem;
    color: var(--black);
  }
  .m-command button {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0 0.95rem;
    border: 0;
    border-left: 1px solid var(--border-light);
    background: transparent;
    font: inherit;
    font-size: 0.82rem;
    color: var(--mid-gray);
    cursor: pointer;
  }
  .m-command button:hover {
    color: var(--black);
    background: var(--light-gray);
  }
  .m-command button:focus-visible,
  .m-tabs button:focus-visible {
    outline: 2px solid var(--ring-blue);
    outline-offset: -2px;
  }
  .m-hero-actions {
    margin-top: 1.5rem;
    justify-content: flex-start;
  }

  /* The signature: the server's terminal, wired to the phone it tells. */
  .m-relay {
    position: relative;
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: 1.1rem;
  }
  .m-term {
    border: 1px solid var(--light-gray);
    border-radius: 14px;
    background: #0b0b0c;
    color: #e5e5e5;
    box-shadow: 0 24px 60px -28px rgba(0, 0, 0, 0.55);
    overflow: hidden;
  }
  .m-term-bar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0.6rem 0.8rem;
    border-bottom: 1px solid #1f1f22;
    font-family: var(--font-mono);
    font-size: 0.72rem;
    color: #737373;
  }
  .m-term-bar i {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: #2e2e33;
  }
  .m-term-bar span {
    margin-left: 0.4rem;
  }
  .m-term pre {
    margin: 0;
    padding: 0.9rem 1rem 1.1rem;
    min-height: 11.5rem;
    overflow-x: auto;
    font-family: var(--font-mono);
    font-size: 0.78rem;
    line-height: 1.7;
    white-space: pre;
  }
  .m-dim {
    color: #737373;
  }
  .m-ok {
    color: #22c55e;
  }
  .m-sample {
    animation: m-in 0.5s ease-out both;
  }
  @keyframes m-in {
    from { opacity: 0; transform: translateY(4px); }
  }
  .m-wire {
    justify-self: center;
    width: 2px;
    height: 2.2rem;
    margin: -0.3rem 0;
    background: repeating-linear-gradient(to bottom, var(--silver) 0 4px, transparent 4px 9px);
    animation: m-flow 1.2s linear infinite;
  }
  @keyframes m-flow {
    to { background-position: 0 9px; }
  }
  .m-pocket {
    position: relative;
    justify-self: center;
    width: min(100%, 380px);
  }
  .m-pocket img:first-child {
    display: block;
    width: 100%;
    height: auto;
    border-radius: 18px;
    box-shadow: 0 18px 40px -22px rgba(0, 0, 0, 0.5);
  }
  .m-widget {
    position: absolute;
    right: -1.4rem;
    bottom: -1.6rem;
    width: 34%;
    height: auto;
    border-radius: 18px;
    box-shadow: 0 14px 30px -16px rgba(0, 0, 0, 0.55);
  }

  .m-keywords {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 0.5rem;
    width: min(1080px, 92vw);
    margin: 1.5rem auto 0;
  }

  .m-why {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr));
    gap: 1px;
    border: 1px solid var(--border-light);
    border-radius: var(--radius-container);
    background: var(--border-light);
    overflow: hidden;
  }
  .m-why article {
    padding: 1.5rem 1.4rem 1.6rem;
    background: var(--white);
  }
  .m-why h3,
  .m-row h3,
  .m-steps h3 {
    margin: 0 0 0.5rem;
    font-family: var(--font-display);
    font-size: 1.08rem;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: var(--black);
  }
  .m-why p,
  .m-row p,
  .m-steps p {
    margin: 0;
    line-height: 1.6;
    color: var(--mid-gray);
  }

  .m-row {
    display: grid;
    grid-template-columns: minmax(0, 0.8fr) minmax(0, 1.2fr);
    gap: clamp(1.5rem, 4vw, 3.5rem);
    align-items: center;
    padding: 2.25rem 0;
    border-top: 1px solid var(--light-gray);
  }
  .m-row.flip .m-row-copy {
    order: 2;
  }
  /* No screenshot yet: the words take the row, the tags beside them. */
  .m-row.text-only {
    grid-template-columns: minmax(0, 1fr);
  }
  .m-row.text-only .m-row-copy {
    display: grid;
    grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr);
    column-gap: clamp(1.5rem, 4vw, 3.5rem);
  }
  .m-row.text-only .m-row-copy > :not(.m-tags) {
    grid-column: 1;
  }
  .m-row.text-only .m-tags {
    grid-column: 2;
    grid-row: 1 / span 2;
    align-content: start;
    margin-top: 0.2rem;
  }
  .m-row h3 {
    font-size: 1.45rem;
  }
  .m-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    margin-top: 1rem;
  }
  .m-shot {
    margin: 0;
  }
  .m-shot img {
    display: block;
    width: 100%;
    height: auto;
    border: 1px solid var(--border-light);
    border-radius: var(--radius-container);
    box-shadow: 0 20px 50px -30px rgba(0, 0, 0, 0.45);
  }

  .m-alerts {
    display: grid;
    grid-template-columns: minmax(0, 0.9fr) minmax(0, 1fr) minmax(0, 1.25fr);
    gap: 1.1rem;
    align-items: start;
  }
  .m-alerts figure {
    margin: 0;
  }
  .m-alerts img {
    display: block;
    width: 100%;
    height: auto;
    border-radius: var(--radius-container);
    border: 1px solid var(--border-light);
  }
  .m-alerts figcaption {
    margin-top: 0.55rem;
    font-size: 0.82rem;
    color: var(--stone);
  }
  .m-rule figcaption {
    margin: 0 0 0.55rem;
  }
  .m-rule pre {
    margin: 0;
    border: 1px solid var(--light-gray);
    padding: 1rem 1.05rem;
    border-radius: var(--radius-container);
    background: #0b0b0c;
    color: #e5e5e5;
    font-family: var(--font-mono);
    font-size: 0.8rem;
    line-height: 1.7;
    overflow-x: auto;
  }
  .m-channels {
    justify-content: center;
    margin-top: 1.4rem;
  }

  /* Install is a sequence, so it is numbered. */
  .m-steps {
    display: grid;
    gap: 1.25rem;
    margin: 0;
    padding: 0;
    list-style: none;
    counter-reset: step;
  }
  .m-steps li {
    position: relative;
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: 0.75rem;
    padding: 1.4rem 1.4rem 1.5rem 4rem;
    border: 1px solid var(--border-light);
    border-radius: var(--radius-container);
    counter-increment: step;
  }
  .m-steps li::before {
    content: counter(step);
    position: absolute;
    left: 1.35rem;
    top: 1.35rem;
    display: grid;
    place-items: center;
    width: 1.75rem;
    height: 1.75rem;
    border-radius: 50%;
    background: var(--black);
    color: var(--white);
    font-weight: 700;
    font-size: 0.85rem;
  }
  .m-steps h3 {
    margin: 0;
  }
  .m-tabs {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }
  .m-tabs button {
    padding: 0.35rem 0.85rem;
    border: 1px solid var(--border-light);
    border-radius: var(--radius-pill);
    background: transparent;
    font: inherit;
    font-size: 0.82rem;
    color: var(--mid-gray);
    cursor: pointer;
  }
  .m-tabs button.active {
    border-color: var(--black);
    background: var(--black);
    color: var(--white);
  }

  @media (max-width: 860px) {
    .m-hero {
      grid-template-columns: minmax(0, 1fr);
      padding-top: 2.5rem;
    }
    .m-row,
    .m-alerts {
      grid-template-columns: minmax(0, 1fr);
    }
    .m-row.flip .m-row-copy {
      order: 0;
    }
    .m-row.text-only .m-row-copy {
      grid-template-columns: minmax(0, 1fr);
    }
    .m-row.text-only .m-tags {
      grid-column: 1;
      grid-row: auto;
      margin-top: 1rem;
    }
    .m-widget {
      right: -0.4rem;
    }
  }
  @media (max-width: 520px) {
    .m-steps li {
      padding-left: 1.2rem;
      padding-top: 3.4rem;
    }
    .m-command button span {
      display: none;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .m-live,
    .m-wire,
    .m-sample {
      animation: none;
    }
  }
</style>
