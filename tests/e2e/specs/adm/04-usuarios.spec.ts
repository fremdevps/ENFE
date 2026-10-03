import { test, expect, uniq, apexError } from '../../support/apex';
import { crearUsuario } from '../../support/adm';

test.describe('ADM · Gestión de usuarios', () => {
  test('crea un usuario local y aparece en el listado', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x');
    await expect(apexError(page)).toHaveCount(0);
    await expect(page).toHaveTitle(/Usuarios/);
    await expect(page.locator('#usuarios').getByText(user)).toBeVisible();
  });

  test('rechaza una contraseña que no cumple la política', async ({ admPage: page }) => {
    await crearUsuario(page, uniq(), 'abc', 'Débil');
    await expect(page.getByText(/al menos 8 caracteres/i)).toBeVisible();
  });
});
