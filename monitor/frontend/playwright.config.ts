import { defineConfig } from '@playwright/test'

/// Opt-in end-to-end runs against a live agent (`e2e/`), never in CI:
/// each test skips itself unless its variables are set (see its header).
export default defineConfig({
  testDir: 'e2e',
  testMatch: '*.e2e.ts',
  outputDir: 'e2e/.results',
  timeout: 20 * 60_000,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL: process.env.SBM_E2E_PANEL_URL,
    ignoreHTTPSErrors: true,
    viewport: { width: 1500, height: 950 },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    // A browser macOS has not given Local Network access (one started from a
    // background process) reaches a LAN agent only through a local proxy.
    proxy: process.env.SBM_E2E_BROWSER_PROXY ? { server: process.env.SBM_E2E_BROWSER_PROXY } : undefined,
  },
})
