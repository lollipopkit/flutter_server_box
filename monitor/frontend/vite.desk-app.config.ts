import { defineConfig } from 'vite'

// The design system an installed app's frame loads from the agent
// (`/apps/{id}/ui/{ticket}/_desk/desk.css`, `api::apps::ui`): `lk.css` with
// its fonts, built on its own into dist/desk-app after the panel. `desk.css`
// keeps its name (the agent and `lkui` ask for it by name);
// the fonts are hashed and referenced relatively.
export default defineConfig({
  base: './',
  publicDir: false,
  logLevel: 'warn',
  build: {
    outDir: 'dist/desk-app',
    emptyOutDir: true,
    assetsDir: '',
    rollupOptions: {
      input: { desk: 'src/desk/lk/lk.css' },
      output: {
        assetFileNames: (asset) => (asset.names.some((n) => n.endsWith('.css')) ? 'desk.css' : '[name]-[hash][extname]'),
      },
    },
  },
})
