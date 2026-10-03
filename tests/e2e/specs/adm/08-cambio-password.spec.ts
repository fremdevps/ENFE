import { test, expect, uniq, login, gotoPage, waitForApex, apexError } from '../../support/apex';
import { crearUsuario, asignarRol, otraSesion } from '../../support/adm';

const CLAVE = 'Prueba2026x';

async function cambiar(page: import('@playwright/test').Page, actual: string, nueva: string, confirma = nueva) {
  await page.locator('#P90_PASSWORD_ACTUAL').fill(actual);
  await page.locator('#P90_PASSWORD_NUEVO').fill(nueva);
  await page.locator('#P90_PASSWORD_CONFIRMA').fill(confirma);
  await page.getByRole('button', { name: 'Cambiar contraseña' }).click();
  await waitForApex(page);
}

test.describe('ADM · Cambio de contraseña obligatorio (primer ingreso)', () => {
  test('el usuario nuevo es forzado a cambiar su contraseña y las reglas se validan', async ({ admPage: page, browser }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'Primer ingreso');
    await asignarRol(page, user, 'SUPERADMIN');
    await expect(apexError(page)).toHaveCount(0);

    const { ctx, page: otro } = await otraSesion(browser, 'adm', user, CLAVE);
    await expect(otro).not.toHaveURL(/\/login/i);
    await expect(otro).toHaveTitle(/Cambiar mi contraseña/);

    // No puede ir a otra página hasta cambiarla
    await gotoPage(otro, 'adm', 'usuarios');
    await expect(otro).toHaveTitle(/Cambiar mi contraseña/);

    await test.step('contraseña actual incorrecta', async () => {
      await cambiar(otro, 'NoEsLaActual1', 'Nueva2026x');
      await expect(otro.getByText('La contraseña actual no es correcta.')).toBeVisible();
    });
    await test.step('confirmación distinta', async () => {
      await cambiar(otro, CLAVE, 'Nueva2026x', 'Otra2026x');
      await expect(otro.getByText('La confirmación no coincide con la nueva contraseña.')).toBeVisible();
    });
    await test.step('nueva igual a la actual', async () => {
      await cambiar(otro, CLAVE, CLAVE);
      await expect(otro.getByText('La nueva contraseña debe ser distinta a la actual.')).toBeVisible();
    });
    await test.step('nueva sin cumplir la política', async () => {
      await cambiar(otro, CLAVE, 'debil', 'debil');
      await expect(otro.getByText(/al menos 8 caracteres/i)).toBeVisible();
    });
    await test.step('cambio correcto', async () => {
      await cambiar(otro, CLAVE, 'Nueva2026x');
      await expect(otro.getByText('Contraseña actualizada.')).toBeVisible();
      await expect(otro).not.toHaveTitle(/Cambiar mi contraseña/);
    });

    // Ya navega libremente y entra con la nueva clave
    await gotoPage(otro, 'adm', 'usuarios');
    await expect(otro).toHaveTitle(/Usuarios/);
    await ctx.close();

    const nuevo = await otraSesion(browser, 'adm', user, 'Nueva2026x');
    await expect(nuevo.page).not.toHaveURL(/\/login/i);
    await expect(nuevo.page).not.toHaveTitle(/Cambiar mi contraseña/);
    await nuevo.ctx.close();

    const viejo = await otraSesion(browser, 'adm', user, CLAVE);
    await expect(viejo.page).toHaveURL(/\/login/i);
    await viejo.ctx.close();
  });

  test('exige los tres campos', async ({ admPage: page }) => {
    await gotoPage(page, 'adm', 'cambiar-password');
    await page.getByRole('button', { name: 'Cambiar contraseña' }).click();
    await expect(page).toHaveTitle(/Cambiar mi contraseña/);
    await expect(apexError(page)).toBeVisible();
  });
});

test.describe('ERP · Acceso con rol asignado', () => {
  test('un usuario con rol entra al ERP con la sesión de ADM', async ({ admPage: page, browser }) => {
    const user = uniq();
    await crearUsuario(page, user, CLAVE, 'ERP');
    await asignarRol(page, user, 'SUPERADMIN');

    const { ctx, page: otro } = await otraSesion(browser, 'adm', user, CLAVE);
    await expect(otro).toHaveTitle(/Cambiar mi contraseña/);
    await cambiar(otro, CLAVE, 'Nueva2026x');
    await expect(otro.getByText('Contraseña actualizada.')).toBeVisible();

    await login(otro, 'erp', user, 'Nueva2026x');
    await expect(otro).not.toHaveURL(/\/login/i);
    await expect(otro.getByText('Mis módulos')).toBeVisible();
    await ctx.close();
  });
});
