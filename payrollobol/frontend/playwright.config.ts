import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  use: { baseURL: 'http://127.0.0.1:5180', browserName: 'chromium', trace: 'retain-on-failure' },
  webServer: { command: 'node scripts/e2e-server.mjs', url: 'http://127.0.0.1:5180', reuseExistingServer: false },
})