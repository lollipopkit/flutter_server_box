// What the site's Themes and Plugins sections list: `store/` in this
// repository, read at build time, as `virtual:store`.
//
// The same folder the site serves as /store.tar.gz for the app's theme store
// (scripts/store-tarball.sh), so the page and the app offer the same versions.
// Only what a visitor needs is exported: the newest version of each, where it
// downloads from and its digest, and for a theme the colors of its palette.
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { parse } from 'smol-toml'

const moduleId = 'virtual:store'
const resolvedId = '\0' + moduleId

/** `1.10.0` after `1.9.0`; a suffix (`-beta`) before the same numbers without. */
function compareVersions(a, b) {
  const nums = (v) => v.split(/[-+]/)[0].split('.').map((n) => Number.parseInt(n, 10) || 0)
  const [x, y] = [nums(a), nums(b)]
  for (let i = 0; i < 3; i++) {
    const d = (x[i] ?? 0) - (y[i] ?? 0)
    if (d !== 0) return d
  }
  return (b.includes('-') ? 1 : 0) - (a.includes('-') ? 1 : 0)
}

function newest(versions) {
  return [...(versions ?? [])].sort((a, b) => compareVersions(b.version, a.version))[0] ?? null
}

/** `0xFF282C34` (as TOML reads it, a number) to `#282c34`. */
function hex(value) {
  if (typeof value !== 'number' && typeof value !== 'bigint') return null
  return '#' + (Number(value) & 0xffffff).toString(16).padStart(6, '0')
}

/** An ARGB integer as CSS, keeping its alpha. */
function css(value) {
  const n = Number(value) >>> 0
  const a = (n >>> 24) / 255
  const rgb = hex(n)
  if (a >= 1) return rgb
  return `rgba(${(n >>> 16) & 255}, ${(n >>> 8) & 255}, ${n & 255}, ${a.toFixed(3)})`
}

// What a role is when a palette does not set it: Material's baseline, close
// enough for a preview of a theme that leaves it to its seed.
const baseline = {
  light: { surface: '#fef7ff', surfaceContainerLow: '#f7f2fa', surfaceContainer: '#f3edf7', surfaceContainerHigh: '#ece6f0', surfaceContainerHighest: '#e6e0e9', onSurface: '#1d1b20', onSurfaceVariant: '#49454f', outline: '#79747e', outlineVariant: '#cac4d0', onPrimary: '#ffffff', primaryContainer: '#eaddff', onPrimaryContainer: '#21005d', secondaryContainer: '#e8def8', onSecondaryContainer: '#1d192b', shadow: '#000000' },
  dark: { surface: '#141218', surfaceContainerLow: '#1d1b20', surfaceContainer: '#211f26', surfaceContainerHigh: '#2b2930', surfaceContainerHighest: '#36343b', onSurface: '#e6e0e9', onSurfaceVariant: '#cac4d0', outline: '#938f99', outlineVariant: '#49454f', onPrimary: '#381e72', primaryContainer: '#4f378b', onPrimaryContainer: '#eaddff', secondaryContainer: '#4a4458', onSecondaryContainer: '#e8def8', shadow: '#000000' },
}

/** A manifest color — ARGB or a role name — as CSS against `palette`. */
function color(value, palette) {
  if (typeof value === 'string') return palette[value] ?? null
  if (typeof value === 'number' || typeof value === 'bigint') return css(value)
  return null
}

function dataUri(file) {
  const bytes = readFileSync(file)
  const type = file.endsWith('.svg') ? 'image/svg+xml' : file.endsWith('.png') ? 'image/png' : 'image/jpeg'
  return `data:${type};base64,${bytes.toString('base64')}`
}

/** One component's fields for `mode`: common, then the brightness's own, with
 *  button states merged the same way, and every color resolved. */
function component(components, mode, name, palette) {
  const common = components?.[name] ?? {}
  const own = components?.[mode]?.[name] ?? {}
  const states = ['hovered', 'pressed', 'focused', 'selected', 'disabled']
  const flat = (t) => Object.fromEntries(Object.entries(t).filter(([k]) => !states.includes(k)))
  const resolve = (t) =>
    Object.fromEntries(
      // Every color field, as the app reads them: `...Color`, and the ones
      // named just `color` (progress, divider).
      Object.entries(t).map(([k, v]) => [k, k === 'color' || k.endsWith('Color') ? color(v, palette) : v]),
    )
  const out = resolve({ ...flat(common), ...flat(own) })
  for (const state of states) {
    const merged = { ...(common[state] ?? {}), ...(own[state] ?? {}) }
    if (Object.keys(merged).length) out[state] = resolve(merged)
  }
  return out
}

/** The installer's merge: tables merge key by key, anything else replaces. */
function merge(base, overrides) {
  const out = { ...base }
  for (const [k, v] of Object.entries(overrides)) {
    const b = out[k]
    out[k] = b && v && typeof b === 'object' && typeof v === 'object' && !Array.isArray(b) && !Array.isArray(v) ? merge(b, v) : v
  }
  return out
}

/** The themes a package installs as: itself, or each of its variants drawn
 *  over its base tables. */
function themesOf(dir, manifest) {
  const { variants, ...base } = manifest
  if (!variants || typeof variants !== 'object') return [{ key: null, name: null, manifest, own: null }]
  return Object.entries(variants).map(([key, { name, ...overrides }]) => ({
    key,
    name,
    manifest: merge(base, overrides),
    own: path.join(dir, 'variants', key),
  }))
}

/** What the site draws a theme with, per mode. */
function preview(dir, manifest, own = null) {
  // A variant reads its own copy of a file first, as the installer does.
  const find = (name) => (own && existsSync(path.join(own, name)) ? path.join(own, name) : path.join(dir, name))
  const colors = manifest.colors ?? {}
  const icons = manifest.icons ?? {}
  const images = {}
  for (const [key, rel] of Object.entries(icons.images ?? {})) {
    const file = path.join(dir, rel)
    if (existsSync(file)) images[key] = dataUri(file)
  }
  const splash = manifest.splash
  const logo = splash?.logo && existsSync(find(splash.logo)) ? dataUri(find(splash.logo)) : null
  const modes = {}
  for (const mode of manifest.modes ?? []) {
    const palette = { ...baseline[mode] }
    if (colors.seed != null) palette.primary = css(colors.seed)
    for (const [role, v] of Object.entries(colors.palette?.[mode] ?? {})) palette[role] = css(v)
    palette.secondary ??= palette.primary
    palette.tertiary ??= palette.secondary
    const iconColors = {}
    for (const [key, v] of Object.entries(icons.colors ?? {})) iconColors[key] = color(v, palette)
    modes[mode] = {
      palette,
      iconColors,
      components: Object.fromEntries(
        Object.keys(manifest.components ?? {})
          .filter((n) => n !== 'light' && n !== 'dark')
          .concat(Object.keys(manifest.components?.[mode] ?? {}))
          .map((n) => [n, component(manifest.components, mode, n, palette)]),
      ),
      splash: splash ? { color: color(splash.color ?? 'surface', palette) ?? palette.surface } : null,
    }
  }
  return {
    modes,
    images,
    shapes: { card: 12, tile: 8, button: 10, ...(manifest.shapes ?? {}) },
    background: manifest.background?.type ?? 'none',
    // An image background as the app draws it: faint over the surface, once
    // and cover-fitted, or repeated every `tile` logical pixels.
    backgroundImage:
      manifest.background?.type === 'image' && existsSync(find(manifest.background.image))
        ? {
            src: dataUri(find(manifest.background.image)),
            opacity: manifest.background.opacity ?? 0.18,
            blur: manifest.background.blur ?? 0,
            tile: manifest.background.tile ?? 0,
          }
        : null,
    splash: splash ? { logo, duration: splash.duration ?? 600 } : null,
    style: icons.style ?? 'classic',
  }
}

function tomlFiles(dir) {
  if (!existsSync(dir)) return []
  return readdirSync(dir, { recursive: true })
    .map((f) => path.join(dir, f))
    .filter((f) => f.endsWith('.toml') && statSync(f).isFile())
}

/**
 * When a listing last changed, as its last commit says, for "recently
 * updated". A shallow clone knows only its own commit and a file not yet
 * committed has none; both read as the build's own time rather than failing
 * the site.
 */
function updatedAt(file) {
  try {
    const out = execFileSync('git', ['log', '-1', '--format=%cI', '--', file], {
      cwd: path.dirname(file),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim()
    if (out) return out
  } catch {
    // no git, or not a repository: the build's time below
  }
  return new Date().toISOString()
}

function release(v) {
  if (!v) return null
  return { version: v.version, url: v.url ?? null, sha256: v.sha256 ?? null, size: v.size ?? null }
}

function readThemes(store) {
  const dir = path.join(store, 'themes')
  return tomlFiles(dir)
    // `themes/<id>.toml`; the folders beside them are the themes themselves.
    .filter((f) => path.dirname(f) === dir)
    .map((file) => {
      const listing = parse(readFileSync(file, 'utf8'))
      const latest = newest(listing.version)
      const manifestPath = path.join(dir, listing.id, 'manifest.toml')
      const manifest = existsSync(manifestPath) ? parse(readFileSync(manifestPath, 'utf8')) : {}
      const themeDir = path.join(dir, listing.id)
      // Drawn before its preview loads: the page's color and its accent.
      const placeholder = (m) =>
        Object.fromEntries(
          (m.modes ?? []).map((mode) => {
            const colors = m.colors ?? {}
            const pal = colors.palette?.[mode] ?? {}
            return [mode, {
              surface: pal.surface != null ? css(pal.surface) : baseline[mode].surface,
              primary: pal.primary != null ? css(pal.primary) : colors.seed != null ? css(colors.seed) : null,
            }]
          }),
        )
      // One entry per theme the package installs as: the package itself, or
      // each variant, which the card offers to pick from. The first is what
      // the card shows until one is picked.
      const variants = themesOf(themeDir, manifest).map((t) => ({
        key: t.key,
        name: t.name,
        preview: preview(themeDir, t.manifest, t.own),
        placeholder: placeholder(t.manifest),
      }))
      return {
        id: listing.id,
        name: listing.name,
        // A string, or a table of language tags; the page picks one.
        description: listing.description ?? '',
        homepage: listing.homepage ?? null,
        license: listing.license ?? null,
        modes: manifest.modes ?? [],
        variants,
        latest: release(latest),
        updated: updatedAt(file),
      }
    })
    .filter((t) => t.latest)
    .sort((a, b) => a.name.localeCompare(b.name))
}

function readPlugins(store) {
  return tomlFiles(path.join(store, 'plugins'))
    .map((file) => {
      const listing = parse(readFileSync(file, 'utf8'))
      return {
        id: listing.id,
        name: listing.name,
        description: listing.description ?? '',
        license: listing.license ?? null,
        latest: release(newest(listing.version)),
        updated: updatedAt(file),
      }
    })
    .filter((p) => p.latest)
    .sort((a, b) => a.name.localeCompare(b.name))
}

/**
 * What a page imports is the list — names, modes, versions, a placeholder
 * color — and each theme's preview (palette, components, every icon as a data
 * URI) is a file of its own, fetched when its card comes into view:
 * `/themes/preview/<id>.<hash>.json`, the hash of its content so a new version
 * of a theme is never served from an old cache.
 *
 * @param {string} store the `store/` folder
 */
export function storeData(store) {
  const read = () => {
    const themes = readThemes(store)
    const files = new Map()
    for (const t of themes) {
      for (const v of t.variants) {
        const body = JSON.stringify(v.preview)
        const hash = createHash('sha256').update(body).digest('hex').slice(0, 12)
        const name = `themes/preview/${t.id}${v.key ? `~${v.key}` : ''}.${hash}.json`
        files.set('/' + name, body)
        v.previewUrl = '/' + name
        delete v.preview
      }
    }
    return { data: { themes, plugins: readPlugins(store) }, files }
  }

  const plugin = {
    name: 'serverbox-store',
    resolveId(id) {
      return id === moduleId ? resolvedId : null
    },
    load(id) {
      if (id !== resolvedId) return null
      // Every file under store/, so an edited icon or manifest reloads too.
      for (const f of readdirSync(store, { recursive: true })) {
        const full = path.join(store, f)
        if (statSync(full).isFile()) this.addWatchFile(full)
      }
      return `export default ${JSON.stringify(read().data)}`
    },
    generateBundle() {
      for (const [name, source] of read().files) {
        this.emitFile({ type: 'asset', fileName: name.slice(1), source })
      }
    },
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (!req.url?.startsWith('/themes/preview/')) return next()
        const body = read().files.get(req.url.split('?')[0])
        if (!body) return next()
        res.setHeader('Content-Type', 'application/json')
        res.end(body)
      })
    },
  }
  return plugin
}
