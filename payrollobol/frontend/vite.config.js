import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vite'
import { localPayrollPlugin } from './server/bridge.ts'

export default defineConfig({
  plugins: [svelte(), localPayrollPlugin()],
  server: { host: '127.0.0.1', port: 5173 },
  preview: { host: '127.0.0.1', port: 4173 },
  test: { include: ['src/**/*.test.ts', 'server/**/*.test.ts'] },
})
