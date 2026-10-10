import { test, expect, env, sessionId, waitForApex } from '../../support/apex';

test.describe('ERP · Sesión compartida con ADM', () => {
  test('tras ingresar a ADM se entra al ERP sin volver a loguearse', async ({ admPage: page }) => {
    const sid = await sessionId(page);
    await page.goto(`${env('APEX_BASE_URL')}/erp/home?session=${sid}`);
    await waitForApex(page);
    await expect(page).not.toHaveURL(/\/login/i);
    await expect(page.getByRole('heading', { name: 'Puesta en marcha' })).toBeVisible();
    for (const tarjeta of ['Datos de la empresa', 'Sucursales', 'Puntos de expedición', 'Depósitos', 'Monedas', 'Personas']) {
      await expect(page.locator('#accesos').getByText(tarjeta, { exact: true })).toBeVisible();
    }
  });
});
