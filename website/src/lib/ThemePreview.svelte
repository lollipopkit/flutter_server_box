<script>
  // A phone-sized picture of the app in one theme and mode: the server list
  // with two cards, a tile list, a search field and two buttons, and the bottom
  // navigation. Everything is drawn from the theme's own manifest — palette,
  // component styles, radii, background and icons — as the app would.
  import ThemeIcon from './ThemeIcon.svelte'
  import { defaultIcon } from './defaultIcons.js'

  let { preview, mode, scale = 1 } = $props()

  const p = $derived(preview)
  const m = $derived(p.modes[mode])
  const c = $derived(m.palette)
  const card = $derived(m.components.card ?? {})
  const tile = $derived(m.components.tile ?? {})
  const button = $derived(m.components.button ?? {})
  const nav = $derived(m.components.navigation ?? {})
  const search = $derived(m.components.search ?? {})
  const textButton = $derived(m.components.textButton ?? {})
  const appBar = $derived(m.components.appBar ?? {})

  const background = $derived(
    p.background === 'gradient'
      ? `linear-gradient(135deg, color-mix(in srgb, ${c.primary} 22%, ${c.surface}), ${c.surface}, color-mix(in srgb, ${c.primary} 12%, ${c.surface}))`
      : c.surface,
  )

  // The picture is a phone about 390 logical pixels wide drawn 248 wide, so a
  // tile keeps its size relative to the screen.
  const phone = 248 / 390
  const image = $derived(p.backgroundImage)

  const inset = (v, fallback) => (v ? `${v[1]}px ${v[2]}px ${v[3]}px ${v[0]}px` : fallback)

  // The theme's image, else the app's own glyph for that key.
  const icon = (key) => p.images[key] ?? defaultIcon(p.style, key)
  const iconColor = (key, fallback) => m.iconColors[key] ?? fallback

  const tabs = ['server', 'ssh', 'file', 'agent']
  const labels = { server: 'Server', ssh: 'SSH', file: 'Files', agent: 'Agent' }
  const servers = [
    { name: 'web-01', sub: 'Ubuntu 24.04 · up 12d', cpu: 42, mem: 68 },
    { name: 'db-primary', sub: 'Debian 13 · up 47d', cpu: 18, mem: 81 },
  ]
</script>

<div class="tp" style={`--s:${scale}; background:${background}; color:${c.onSurface};`}>
  {#if image}
    <div
      class="tp-image"
      style={`background-image:url("${image.src}"); opacity:${image.opacity}; filter:${image.blur ? `blur(${image.blur * phone}px)` : 'none'}; ${image.tile ? `background-repeat:repeat; background-position:0 0; background-size:${image.tile * phone}px auto;` : 'background-size:cover; background-position:center;'}`}
    ></div>
  {/if}
  <div class="tp-bar" style={`background:${appBar.backgroundColor ?? 'transparent'}; color:${appBar.titleColor ?? appBar.foregroundColor ?? c.onSurface};`}>
    <span class="tp-title">Servers</span>
    <span class="tp-actions">
      <ThemeIcon src={icon('nav.sort')} color={iconColor('nav.sort', appBar.iconColor ?? c.onSurfaceVariant)} size={18} />
      <ThemeIcon src={icon('nav.settings')} color={iconColor('nav.settings', appBar.iconColor ?? c.onSurfaceVariant)} size={18} />
    </span>
  </div>

  <div class="tp-body">
    {#each servers as s, i}
      <div
        class="tp-card"
        style={`background:${card.backgroundColor ?? c.surfaceContainerLow}; border-radius:${card.radius ?? p.shapes.card}px; border:${card.borderWidth ?? 0}px solid ${card.borderColor ?? 'transparent'}; margin:${inset(card.margin, '4px')}; box-shadow:${card.elevation ? `0 ${card.elevation / 2}px ${card.elevation * 1.5}px ${card.shadowColor ?? c.shadow ?? '#000'}33` : 'none'};`}
      >
        <div class="tp-card-head">
          <ThemeIcon src={icon('nav.server')} color={iconColor('nav.server', c.primary)} size={16} />
          <span class="tp-name">{s.name}</span>
          <span class="tp-dot" style={`background:${i === 0 ? c.tertiary : c.primary}`}></span>
        </div>
        <div class="tp-sub" style={`color:${c.onSurfaceVariant}`}>{s.sub}</div>
        <div class="tp-meter"><span style={`color:${c.onSurfaceVariant}`}>CPU</span><i style={`background:${c.outlineVariant}`}><b style={`width:${s.cpu}%; background:${c.primary}`}></b></i></div>
        <div class="tp-meter"><span style={`color:${c.onSurfaceVariant}`}>MEM</span><i style={`background:${c.outlineVariant}`}><b style={`width:${s.mem}%; background:${c.secondary}`}></b></i></div>
      </div>
    {/each}

    <div class="tp-tiles">
      {#each [['nav.terminal', 'Terminal', true], ['nav.folder', 'Files', false]] as [key, label, selected]}
        <div
          class="tp-tile"
          style={`border-radius:${tile.radius ?? p.shapes.tile}px; background:${selected ? (tile.selectedTileColor ?? c.secondaryContainer) : (tile.backgroundColor ?? 'transparent')}; color:${selected ? (tile.selectedColor ?? c.onSecondaryContainer) : (tile.textColor ?? c.onSurface)}; border:${tile.borderWidth ?? 0}px solid ${tile.borderColor ?? 'transparent'};`}
        >
          <ThemeIcon
            src={icon(key)}
            color={iconColor(key, selected ? (tile.selectedColor ?? c.onSecondaryContainer) : (tile.iconColor ?? c.onSurfaceVariant))}
            size={16}
          />
          <span>{label}</span>
        </div>
      {/each}
    </div>

    <div class="tp-row">
      <!-- A search pill: its own component, never the form input's box. -->
      <span
        class="tp-input"
        style={`border-radius:${search.radius ?? 999}px; background:${search.backgroundColor ?? c.surfaceContainerLow}; border:${search.borderWidth ?? 0}px solid ${search.borderColor ?? 'transparent'}; color:${search.hintColor ?? c.onSurfaceVariant};`}
      >Search</span>
      <span
        class="tp-button tp-text"
        style={`border-radius:${textButton.radius ?? p.shapes.button}px; background:${textButton.backgroundColor ?? 'transparent'}; color:${textButton.foregroundColor ?? c.primary}; border:${textButton.borderWidth ?? 0}px solid ${textButton.borderColor ?? 'transparent'};`}
      >Logs</span>
      <span
        class="tp-button"
        style={`border-radius:${button.radius ?? p.shapes.button}px; background:${button.backgroundColor ?? c.primary}; color:${button.foregroundColor ?? c.onPrimary}; border:${button.borderWidth ?? 0}px solid ${button.borderColor ?? 'transparent'};`}
      >Connect</span>
    </div>
  </div>

  <div class="tp-nav" style={`background:${nav.backgroundColor ?? c.surfaceContainer};`}>
    {#each tabs as t, i}
      {@const selected = i === 0}
      {@const key = `tab.${t}${selected ? '.selected' : ''}`}
      <div class="tp-tab">
        <span
          class="tp-indicator"
          style={`background:${selected ? (nav.indicatorColor ?? c.secondaryContainer) : 'transparent'}; border-radius:${nav.indicatorRadius ?? 16}px;`}
        >
          <ThemeIcon
            src={icon(key)}
            color={iconColor(key, selected ? (nav.selectedIconColor ?? c.onSecondaryContainer) : (nav.unselectedIconColor ?? c.onSurfaceVariant))}
            size={20}
          />
        </span>
        <span
          class="tp-label"
          style={`color:${selected ? (nav.selectedLabelColor ?? c.onSurface) : (nav.unselectedLabelColor ?? c.onSurfaceVariant)}`}
        >{labels[t]}</span>
      </div>
    {/each}
  </div>
</div>

<style>
  /* Drawn at one phone size and scaled as a whole, so every radius and gap
     keeps its proportion to the rest. */
  .tp {
    position: relative;
    isolation: isolate;
    zoom: var(--s);
    width: 248px;
    height: 470px;
    border-radius: 26px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    font-family: var(--font-body);
    font-size: 12px;
    box-shadow: 0 0 0 1px rgba(127, 127, 127, 0.25);
  }

  .tp-image {
    position: absolute;
    inset: 0;
    z-index: -1;
    pointer-events: none;
  }

  .tp-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 22px 16px 8px;
  }

  .tp-title {
    font-weight: 700;
    font-size: 18px;
  }

  .tp-actions {
    display: flex;
    gap: 12px;
  }

  .tp-body {
    flex: 1;
    padding: 0 8px;
    overflow: hidden;
  }

  .tp-card {
    padding: 10px 12px;
  }

  .tp-card-head {
    display: flex;
    align-items: center;
    gap: 7px;
  }

  .tp-name {
    font-weight: 600;
    flex: 1;
  }

  .tp-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
  }

  .tp-sub {
    margin: 2px 0 7px 23px;
    font-size: 10.5px;
  }

  .tp-meter {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 9.5px;
    margin-top: 4px;
  }

  .tp-meter span {
    width: 26px;
  }

  .tp-meter i {
    flex: 1;
    height: 5px;
    border-radius: 3px;
    overflow: hidden;
  }

  .tp-meter b {
    display: block;
    height: 100%;
    border-radius: 3px;
  }

  .tp-tiles {
    margin: 8px 4px;
    display: grid;
    gap: 2px;
  }

  .tp-tile {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 7px 10px;
  }

  .tp-row {
    display: flex;
    gap: 8px;
    margin: 8px 4px;
    align-items: center;
  }

  .tp-input {
    flex: 1;
    padding: 7px 10px;
    font-size: 11px;
  }

  .tp-button {
    padding: 7px 14px;
    font-weight: 600;
    font-size: 11px;
  }

  .tp-text {
    padding: 7px 6px;
  }

  .tp-nav {
    display: flex;
    justify-content: space-around;
    padding: 8px 4px 14px;
  }

  .tp-tab {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
  }

  .tp-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 52px;
    height: 28px;
  }

  .tp-label {
    font-size: 10px;
    font-weight: 500;
  }
</style>
