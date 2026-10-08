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
        // The agent refuses a WebSocket whose Origin it does not allow, and
        // `changeOrigin` rewrites only Host. A handshake from this dev server's
        // own page is presented as the agent's own origin; any other origin
        // passes through unchanged and is judged by the agent as usual.
        configure: (proxy) => {
          // The event's shape, written out: this config is checked without
          // Node's types.
          const events = proxy as unknown as {
            on(
              event: 'proxyReqWs',
              listener: (
                proxyReq: { setHeader(name: string, value: string): void },
                req: { headers: { origin?: string; host?: string } },
              ) => void,
            ): void
          }
          events.on('proxyReqWs', (proxyReq, req) => {
            const { origin, host } = req.headers
            if (origin && host && URL.parse(origin)?.host === host) {
              proxyReq.setHeader('origin', new URL(agent).origin)
            }
          })
        },
      },
    },
  },
  build: {
    outDir: 'dist',
  },
})
