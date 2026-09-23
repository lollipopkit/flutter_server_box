import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const pluginsDir = path.resolve(__dirname, '../packages/plugins')

/**
 * The plugins page's content, read from the manifests at build time.
 *
 * A virtual module rather than an import from `../packages`: those files are
 * outside this project's root, so importing them directly would mean widening
 * `server.fs.allow` and shipping the whole manifest to the browser. Reading
 * them here also means the page cannot disagree with what the app installs —
 * the version, the ABI and the permissions on screen are the ones in the
 * package.
 */
/** One `l10n/<locale>.json`, or nothing if it is not there or will not parse. */
function readTable(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'))
  } catch {
    return {}
  }
}

/**
 * A manifest string: an `l10n.` key looked up, or the string itself.
 *
 * Undefined for a key nothing translates, so the caller falls back rather than
 * printing `l10n.pluginName` on a public page. The packer refuses to build such
 * a package at all — see `manifestL10nKeys` in `packages/plugin-tools`.
 */
function resolve(value, table) {
  if (typeof value !== 'string') return undefined
  if (!value.startsWith('l10n.')) return value
  const hit = table[value.slice('l10n.'.length)]
  return typeof hit === 'string' ? hit : undefined
}

function pluginCatalog() {
  const virtualId = 'virtual:plugin-catalog'
  const resolvedId = `\0${virtualId}`

  const read = () =>
    fs
      .readdirSync(pluginsDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => {
        const file = path.join(pluginsDir, entry.name, 'manifest.json')
        if (!fs.existsSync(file)) return undefined

        const m = JSON.parse(fs.readFileSync(file, 'utf8'))
        // A manifest names its plugin with an `l10n.` key, resolved against
        // the same files the app reads — so this page says what the app says,
        // in the language the reader picked. English is the fallback and what
        // the list is sorted by: it is the one locale a package must ship.
        const strings = {}
        for (const locale of m.l10n ?? []) {
          const table = readTable(path.join(pluginsDir, entry.name, 'l10n', `${locale}.json`))
          strings[locale] = {
            name: resolve(m.name, table) ?? m.id,
            description: resolve(m.description, table) ?? '',
          }
        }
        return {
          dir: entry.name,
          strings,
          name: strings.en?.name ?? m.name ?? m.id,
          description: strings.en?.description ?? m.description ?? '',
          id: m.id,
          version: m.version,
          abi: m.abi,
          license: m.license,
          locales: m.l10n ?? [],
          permissions: Object.keys(m.permissions ?? {}),
          // Which of the app's surfaces it appears on. The keys, not a
          // description of them: they are the app's own names for its places.
          surfaces: Object.keys(m.contributes ?? {}),
        }
      })
      .filter(Boolean)
      .sort((a, b) => a.name.localeCompare(b.name))

  return {
    name: 'serverbox-plugin-catalog',
    resolveId: (source) => (source === virtualId ? resolvedId : null),
    load(id) {
      if (id !== resolvedId) return null
      const plugins = read()
      // So `npm run dev` picks up a manifest edit without a restart.
      for (const plugin of plugins) {
        this.addWatchFile(path.join(pluginsDir, plugin.dir, 'manifest.json'))
        // The names live here now, so an edit to a translation is an edit to
        // the page.
        for (const locale of Object.keys(plugin.strings)) {
          this.addWatchFile(
            path.join(pluginsDir, plugin.dir, 'l10n', `${locale}.json`),
          )
        }
      }
      return `export default ${JSON.stringify(plugins)}`
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [tailwindcss(), svelte(), pluginCatalog()],
  resolve: {
    alias: {
      $lib: path.resolve(__dirname, 'src/lib'),
    },
  },
  build: {
    rollupOptions: {
      // Two pages, not a router. `plugins/index.html` so the deploy serves it
      // at `/plugins/` — a page worth linking to from outside needs its own
      // address, its own title and its own description, and a hash route has
      // none of those.
      input: {
        main: path.resolve(__dirname, 'index.html'),
        plugins: path.resolve(__dirname, 'plugins/index.html'),
      },
    },
  },
})
