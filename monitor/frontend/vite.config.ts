import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'

// https://vitejs.dev/config/
export default defineConfig({
  // Single svelte instance across the linked @serverbox/ui package
  resolve: { dedupe: ['svelte'] },
  plugins: [svelte(), tailwindcss()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:3770',
        changeOrigin: true,
        // The terminal and tunnel endpoints are WebSocket upgrades; without
        // this the dev server answers the handshake itself and they never
        // reach the agent
        ws: true,
      },
    },
  },
  build: {
    outDir: 'dist',
  },
})
