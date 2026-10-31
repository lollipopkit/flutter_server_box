import { defineConfig } from 'vite'

// The desk serves the UI under a ticketed path (`/api/v1/apps/{id}/ui/{ticket}/`),
// so every URL in the bundle must be relative.
export default defineConfig({
  base: './',
  build: { outDir: 'dist', assetsDir: 'assets' },
})
