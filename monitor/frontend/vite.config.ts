import { defineConfig, loadEnv } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'

/// The agent the dev server talks to: the local one unless SBM_DEV_AGENT
/// (the environment or a .env file) names another, e.g. a test VM's
/// https://192.168.31.100:3770.
const agent = loadEnv('development', '.', 'SBM_DEV_').SBM_DEV_AGENT || 'http://localhost:3770'

// https://vitejs.dev/config/
export default defineConfig({
  // Single svelte instance across the linked @serverbox/ui package
  resolve: { dedupe: ['svelte'] },
  plugins: [svelte(), tailwindcss()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: agent,
        changeOrigin: true,
        // A test agent's certificate is usually self-signed; this is the dev
        // server's own hop, never a shipped build's.
        secure: false,
        // The terminal endpoint is a WebSocket upgrade; without this the dev
        // server answers the handshake itself and it never reaches the agent.
        ws: true,
      },
    },
  },
  build: {
    outDir: 'dist',
  },
})
