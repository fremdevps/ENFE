import { test as base, expect, Page } from '@playwright/test';

export const APPS = { adm: 'adm', erp: 'erp' } as const;
type App = keyof typeof APPS;

export function env(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Falta la variable ${name} en .env.test`);
  return v;
}

/** Espera a que APEX termine de cargar la página (sin peticiones pendientes). */
export async function waitForApex(page: Page) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForFunction(() => (window as any).apex?.jQuery !== undefined, null, { timeout: 30_000 });
  await page.waitForLoadState('networkidle');
}

/** ID de sesión APEX actual (apex.env.APP_SESSION). */
export async function sessionId(page: Page): Promise<string> {
  return page.evaluate(() => (window as any).apex.env.APP_SESSION as string);
}

/** Navega a una página por alias conservando la sesión (friendly URLs). */
export async function gotoPage(page: Page, app: App, alias: string, session?: string) {
  const sid = session ?? (await sessionId(page));
  await page.goto(`${env('APEX_BASE_URL')}/${APPS[app]}/${alias.toLowerCase()}?session=${sid}`);
  await waitForApex(page);
}

/** Login en la página 9999 de cualquier app. */
export async function login(page: Page, app: App, user: string, password: string) {
  await page.goto(`${env('APEX_BASE_URL')}/${APPS[app]}/login`);
  await waitForApex(page);
  await page.locator('#P9999_USERNAME').fill(user);
  await page.locator('#P9999_PASSWORD').fill(password);
  await page.getByRole('button', { name: /sign in|iniciar|ingresar/i }).click();
  await waitForApex(page);
}

/** Mensaje de error de APEX visible (notificación o mensaje inline). */
export function apexError(page: Page) {
  return page.locator('#t_Alert_Notification, .t-Alert--danger, .a-Notification--error, .t-Form-error').first();
}

/** Fixture: página ya autenticada como QA_ADMIN en ADM. */
export const test = base.extend<{ admPage: Page }>({
  admPage: async ({ page }, use) => {
    await login(page, 'adm', env('TEST_ADMIN_USER'), env('TEST_ADMIN_PASSWORD'));
    await expect(page).not.toHaveURL(/\/login/i);
    await use(page);
  },
});

export { expect };

/** Sufijo único para datos de prueba (QA_E2E_...). */
export function uniq(prefix = 'QA_E2E'): string {
  return `${prefix}_${Date.now().toString(36).toUpperCase()}`;
}
