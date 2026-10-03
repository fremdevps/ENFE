import type { Browser, Page } from '@playwright/test';
import { gotoPage, waitForApex, login, igInsertar, igGuardar, valorLov, hoyApex } from './apex';

type OpcionesUsuario = { email?: string; tipo?: 'LOCAL' | 'SSO' };

/** Crea un usuario desde la página 31 (Nuevo usuario). */
export async function crearUsuario(page: Page, user: string, password: string, nombres = 'Usuario',
                                   opc: OpcionesUsuario = {}) {
  await gotoPage(page, 'adm', 'nuevo-usuario');
  await page.locator('#P31_USERNAME').fill(user);
  await page.locator('#P31_EMAIL').fill(opc.email ?? `${user.toLowerCase()}@prueba.local`);
  await page.locator('#P31_NOMBRES').fill(nombres);
  await page.locator('#P31_APELLIDOS').fill('E2E');
  await page.locator('#P31_TIPO_AUTENTICACION').selectOption(opc.tipo ?? 'LOCAL');
  if (password) await page.locator('#P31_PASSWORD').fill(password);
  await page.getByRole('button', { name: 'Crear usuario' }).click();
  await waitForApex(page);
}

/** Asigna un rol (por código) a un usuario desde la página 33 (Roles por usuario). */
export async function asignarRol(page: Page, user: string, codigoRol: string) {
  await gotoPage(page, 'adm', 'usuario-roles');
  const usuarioId = await valorLov(page, '#usuario-roles', new RegExp(`^${user.toUpperCase()} - `));
  const rolId     = await valorLov(page, '#usuario-roles', new RegExp(`^${codigoRol} - `));
  await igInsertar(page, 'usuario-roles', [
    { USUARIO_ID: usuarioId, ROL_ID: rolId, FECHA_DESDE: await hoyApex(page) },
  ]);
  await igGuardar(page);
}

/** Abre otro contexto (otra persona, sin cookies) e intenta iniciar sesión. */
export async function otraSesion(browser: Browser, app: 'adm' | 'erp', user: string, password: string) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await login(page, app, user, password);
  return { ctx, page };
}

/** Fila de la bitácora de accesos para un usuario y resultado (más reciente primero). */
export async function filaBitacora(page: Page, user: string, resultado: string) {
  await gotoPage(page, 'adm', 'bitacora-login');
  return page.locator('#bitacora-login tr', { hasText: user.toUpperCase() }).filter({ hasText: resultado }).first();
}
