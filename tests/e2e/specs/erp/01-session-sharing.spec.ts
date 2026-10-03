import { test, expect, env, sessionId, waitForApex } from '../../support/apex';

test.describe('ERP · Sesión compartida con ADM', () => {
  test('tras ingresar a ADM se entra al ERP sin volver a loguearse', async ({ admPage: page }) => {
    const sid = await sessionId(page);
    await page.goto(`${env('APEX_BASE_URL')}/erp/home?session=${sid}`);
    await waitForApex(page);
    await expect(page).not.toHaveURL(/\/login/i);
    await expect(page.getByText('Mis módulos')).toBeVisible();
    for (const mod of ['Finanzas', 'Inventario', 'Compras', 'Ventas', 'Producción']) {
      await expect(page.getByRole('cell', { name: mod })).toBeVisible();
    }
  });
});
