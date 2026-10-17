import { svelte } from '@sveltejs/vite-plugin-svelte'
import { svelteTesting } from '@testing-library/svelte/vite'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  // Single svelte instance across the linked @serverbox/ui package
  resolve: { dedupe: ['svelte'] },
  plugins: [svelte(), svelteTesting()],
  test: {
    projects: [
      { test: {
        name: 'node', environment: 'node', include: ['src/tests/{format,fsPath,agentUrl,themeContrast}.test.ts'],
        // CSS is emptied in tests unless included; themeContrast reads the theme `?raw`
        css: { include: [/theme\.css/] },
      } },
      { extends: true, test: {
        name: 'browser', globals: true, environment: 'jsdom',
        include: ['src/**/*.test.ts'],
        exclude: ['src/tests/{format,fsPath,agentUrl,themeContrast}.test.ts'],
        setupFiles: ['./src/tests/setup.ts'],
      } },
    ],
  },
})
