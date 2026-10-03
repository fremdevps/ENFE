import { test, expect, uniq, login, gotoPage, apexError, igBuscar, igModificar, igGuardar, valorLov } from '../../support/apex';
import { crearUsuario, otraSesion, filaBitacora } from '../../support/adm';

const MAX_INTENTOS = 5;           // adm_seg_seguridad_reg.c_max_intentos
const CLAVE = 'Prueba2026x';

/** Selecciona el usuario en la página 32 por su texto "USERNAME - nombres apellidos". */
async function resetear(page: import('@playwright/test').Page, user: string, clave: string) {
  await gotoPage(page, 'adm', 'reset-password');
  await page.locator('#P32_USUARIO_ID').selectOption(await valorLov(page, '#P32_USUARIO_ID', new RegExp(`^${user} - `)));
  await page.locator('#P32_PASSWORD').fill(clave);
  await page.getByRole('button', { name: 'Resetear contraseña' }).click();
}

test.describe('ADM · Bloqueo por intentos y reseteo de contraseña', () => {
  test(`bloquea al usuario tras ${MAX_INTENTOS} intentos fallidos y el reseteo lo desbloquea`,
       async ({ admPage: page, browser }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'Bloqueo');
    await expect(apexError(page)).toHaveCount(0);

    const { ctx, page: otro } = await otraSesion(browser, 'adm', user, 'Incorrecta999');
    for (let i = 2; i <= MAX_INTENTOS; i++) await login(otro, 'adm', user, 'Incorrecta999');
    // Con la clave correcta sigue fuera: está bloqueado
    await login(otro, 'adm', user, CLAVE);
    await expect(otro).toHaveURL(/\/login/i);

    await expect(await filaBitacora(page, user, 'PASSWORD_INVALIDO')).toBeVisible();
    await expect(await filaBitacora(page, user, 'BLOQUEADO')).toBeVisible();

    await gotoPage(page, 'adm', 'usuarios');
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios tr', { hasText: user })).toContainText('Bloqueado');

    // Reseteo: desbloquea y reinicia intentos
    await resetear(page, user, 'Nueva2026x');
    await expect(page.getByText('Contraseña reseteada y usuario desbloqueado.')).toBeVisible();
    await gotoPage(page, 'adm', 'usuarios');
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios tr', { hasText: user })).toContainText('Activo');

    // Ya no figura BLOQUEADO: sin roles, ahora el rechazo es SIN_ACCESO
    await login(otro, 'adm', user, 'Nueva2026x');
    await expect(otro).toHaveURL(/\/login/i);
    await expect(await filaBitacora(page, user, 'SIN_ACCESO')).toBeVisible();
    await ctx.close();
  });

  test('desbloquea cambiando el estado a Activo en el listado', async ({ admPage: page, browser }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'Desbloqueo');
    const { ctx, page: otro } = await otraSesion(browser, 'adm', user, 'Incorrecta999');
    for (let i = 2; i <= MAX_INTENTOS; i++) await login(otro, 'adm', user, 'Incorrecta999');

    await gotoPage(page, 'adm', 'usuarios');
    await igBuscar(page, 'usuarios', user);
    expect(await igModificar(page, 'usuarios', 'USERNAME', user, { ESTADO: 'A' })).toBe(1);
    await igGuardar(page);
    await expect(apexError(page)).toHaveCount(0);

    await login(otro, 'adm', user, CLAVE);
    await expect(await filaBitacora(page, user, 'SIN_ACCESO')).toBeVisible();
    await ctx.close();
  });

  test('un usuario inactivo no puede ingresar', async ({ admPage: page, browser }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'Inactivo');
    await igBuscar(page, 'usuarios', user);
    await igModificar(page, 'usuarios', 'USERNAME', user, { ESTADO: 'I' });
    await igGuardar(page);

    const { ctx, page: otro } = await otraSesion(browser, 'adm', user, CLAVE);
    await expect(otro).toHaveURL(/\/login/i);
    await expect(await filaBitacora(page, user, 'INACTIVO')).toBeVisible();
    await ctx.close();
  });

  test('el reseteo valida la política de contraseña', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'Politica');
    await resetear(page, user, 'corta1');
    await expect(page.getByText(/al menos 8 caracteres/i)).toBeVisible();
  });

  test('no permite resetear la contraseña de un usuario SSO', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, '', 'SSO', { tipo: 'SSO' });
    await resetear(page, user, 'Nueva2026x');
    await expect(page.getByText(/no usa autenticación local/i)).toBeVisible();
  });
});
