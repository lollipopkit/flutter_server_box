import { svelte } from '@sveltejs/vite-plugin-svelte'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'

// A first-party desk app's UI (`monitor/apps/<SBM_APP>/ui`, with what they
// share in `monitor/apps/common/ui` as `$common`), built into
// `monitor/apps/<SBM_APP>/target/ui` for its package
// (`scripts/build-desk-app.sh`). It bundles the desk's `lk` components (they
// are ours; the frame stays an opaque origin) and `serverbox-desk`; the
// design system's CSS is the agent's (`/desk-app/desk.css`), not bundled.
const app = process.env.SBM_APP
if (!app || !/^[a-z][a-z0-9_]*$/.test(app)) throw new Error('SBM_APP=<app folder under monitor/apps>')
const here = (p: string) => fileURLToPath(new URL(p, import.meta.url))

/// The app's sources live outside this package: their bare imports
/// (`svelte`, `svelte/reactivity`) resolve as if from here, against the
/// panel's own dependencies.
function panelModules(): Plugin {
  const from = here('src/main.ts')
  return {
    name: 'sbm-panel-modules',
    enforce: 'pre',
    async resolveId(id, importer, options) {
      if (!importer || importer.startsWith(here('.')) || id.startsWith('.') || id.startsWith('/') || id.startsWith('\0') || id.includes(':')) return null
      return this.resolve(id, from, { ...options, skipSelf: true })
    },
  }
}

export default defineConfig({
  root: here(`../apps/${app}/ui`),
  base: './',
  publicDir: false,
  logLevel: 'warn',
  plugins: [panelModules(), svelte()],
  resolve: {
    alias: {
      $lk: here('src/desk/lk'),
      $common: here('../apps/common/ui'),
      'serverbox-desk': here('../sdk/serverbox-desk/src/index.ts'),
    },
  },
  build: {
    outDir: here(`../apps/${app}/target/ui`),
    emptyOutDir: true,
    target: 'es2022',
    assetsDir: 'assets',
    // Files a package may hold: plain names, no dot files.
    rollupOptions: { output: { entryFileNames: 'assets/[name]-[hash].js', chunkFileNames: 'assets/[name]-[hash].js', assetFileNames: 'assets/[name]-[hash][extname]' } },
  },
})
