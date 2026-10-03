import { test, expect, gotoPage, uniq, login, apexError } from '../../support/apex';
import { crearUsuario } from '../../support/adm';

test.describe('ADM · Control de acceso centralizado', () => {
  test('un usuario sin roles no puede entrar a ADM ni al ERP', async ({ admPage: page, browser }) => {
    const user = uniq();
    const pass = 'Prueba2026x';
    await crearUsuario(page, user, pass, 'Sin roles');
    await expect(apexError(page)).toHaveCount(0);

    // Otro navegador = otra persona
    const ctx = await browser.newContext();
    const otro = await ctx.newPage();
    for (const app of ['adm', 'erp'] as const) {
      await login(otro, app, user, pass);
      await expect(otro, `no debería entrar a ${app}`).toHaveURL(/\/login/i);
    }
    await ctx.close();

    // Queda registrado en la bitácora con resultado SIN_ACCESO
    await gotoPage(page, 'adm', 'bitacora-login');
    await expect(page.locator('#bitacora-login').getByText(user).first()).toBeVisible();
  });
});
