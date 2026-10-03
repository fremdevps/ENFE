import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Credenciales y URL de pruebas: <repo>/.env.test (ignorado por git)
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });

export default defineConfig({
  testDir: './specs',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,          // comparten datos en DEV: secuencial y predecible
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'reports/html', open: 'never' }],
    ['junit', { outputFile: 'reports/junit.xml' }],
  ],
  outputDir: 'reports/artifacts',
  use: {
    baseURL: process.env.APEX_BASE_URL,
    locale: 'es-PE',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 15_000,
  },
  projects: [
    // Segundo plano (por defecto): Chrome instalado, sin ventana
    { name: 'chrome', use: { ...devices['Desktop Chrome'], channel: 'chrome', headless: true } },
    // En vivo: Chrome visible y en cámara lenta para seguir cada paso
    { name: 'en-vivo', use: { ...devices['Desktop Chrome'], channel: 'chrome', headless: false,
                              viewport: { width: 1440, height: 900 },
                              launchOptions: { slowMo: 400 } } },
  ],
});
