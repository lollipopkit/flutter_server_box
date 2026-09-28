import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { storeData } from './store-data.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// https://vite.dev/config/
export default defineConfig({
  // `virtual:store`: the themes (and plugins) in ../store, for their sections.
  plugins: [tailwindcss(), svelte(), storeData(path.resolve(__dirname, '../store'))],
  // Two pages: the site, and the theme store at /themes/.
  build: {
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'index.html'),
        themes: path.resolve(__dirname, 'themes/index.html'),
      },
    },
  },
  resolve: {
    alias: {
      $lib: path.resolve(__dirname, 'src/lib'),
    },
  },
})
