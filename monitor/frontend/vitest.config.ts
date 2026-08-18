import { svelte } from '@sveltejs/vite-plugin-svelte'
import { svelteTesting } from '@testing-library/svelte/vite'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  // Single svelte instance across the linked @serverbox/ui package
  resolve: { dedupe: ['svelte'] },
  plugins: [svelte(), svelteTesting()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/tests/setup.ts'],
  },
})
