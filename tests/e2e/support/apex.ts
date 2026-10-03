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

type Fila = Record<string, string | null>;

/** Inserta filas en un Interactive Grid vía su modelo JS (sin guardar). */
export async function igInsertar(page: Page, region: string, filas: Fila[]) {
  await page.evaluate(([reg, fs]) => {
    const model = (window as any).apex.region(reg).call('getViews', 'grid').model;
    for (const f of fs) {
      const rec = model.getRecord(model.insertNewRecord());
      for (const [col, val] of Object.entries(f)) model.setValue(rec, col, val ?? '');
    }
  }, [region, filas] as const);
}

/** Modifica las filas del IG cuyo valor en `col` es `valor` (sin guardar). Devuelve cuántas tocó. */
export async function igModificar(page: Page, region: string, col: string, valor: string, cambios: Fila) {
  return page.evaluate(([reg, c, v, cam]) => {
    const model = (window as any).apex.region(reg).call('getViews', 'grid').model;
    let n = 0;
    model.forEach((r: any) => {
      if (model.getValue(r, c) === v) {
        for (const [k, val] of Object.entries(cam)) model.setValue(r, k, val ?? '');
        n++;
      }
    });
    return n;
  }, [region, col, valor, cambios] as const);
}

/** Elimina las filas del IG cuyo valor en `col` es `valor` (sin guardar). */
export async function igEliminar(page: Page, region: string, col: string, valor: string) {
  return page.evaluate(([reg, c, v]) => {
    const model = (window as any).apex.region(reg).call('getViews', 'grid').model;
    const recs: any[] = [];
    model.forEach((r: any) => { if (model.getValue(r, c) === v) recs.push(r); });
    model.deleteRecords(recs);
    return recs.length;
  }, [region, col, valor] as const);
}

/** Filtra el IG con su campo de búsqueda (así la fila buscada queda cargada en el modelo). */
export async function igBuscar(page: Page, region: string, texto: string) {
  const campo = page.locator(`#${region}_ig_toolbar_search_field`);
  await campo.fill(texto);
  await campo.press('Enter');
  await waitForApex(page);
}

/** Clic en Guardar de la barra del IG y espera a que APEX termine. */
export async function igGuardar(page: Page) {
  await page.getByRole('button', { name: /^(Save|Guardar)$/ }).click();
  await waitForApex(page);
}

/** Busca en los <select> de un contenedor (o en un <select> por id) la opción cuyo texto cumple `texto` y devuelve su valor. */
export async function valorLov(page: Page, contenedor: string, texto: RegExp): Promise<string> {
  const valor = await page.evaluate(([sel, src, flags]) => {
    const re = new RegExp(src, flags);
    const opt = Array.from(document.querySelectorAll<HTMLOptionElement>(`${sel} option`))
      .find(o => re.test(o.text));
    return opt?.value ?? null;
  }, [contenedor, texto.source, texto.flags] as const);
  if (!valor) throw new Error(`No hay opción ${texto} en ${contenedor}`);
  return valor;
}

/** Fecha de hoy en el formato de fecha de la app (para columnas datePicker del IG). */
export async function hoyApex(page: Page): Promise<string> {
  return page.evaluate(() => {
    const apex = (window as any).apex;
    return apex.date.format(new Date(), apex.locale.getDateFormat());
  });
}

/** Sufijo único para datos de prueba (QA_E2E_...). */
export function uniq(prefix = 'QA_E2E'): string {
  return `${prefix}_${Date.now().toString(36).toUpperCase()}`;
}
