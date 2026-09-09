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
        return {
          dir: entry.name,
          id: m.id,
          name: m.name ?? m.id,
          description: m.description ?? '',
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
