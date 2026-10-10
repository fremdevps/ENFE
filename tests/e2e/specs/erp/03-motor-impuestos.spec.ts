import { test, expect, gotoPage, sessionId, waitForApex, apexError } from '../../support/apex';

/** El motor de impuestos se prueba desde la página 50 (Probar cálculo). */
async function calcular(page: import('@playwright/test').Page, categoria: RegExp, monto: string, incluye: 'Sí' | 'No') {
  await gotoPage(page, 'erp', 'probar-impuestos', await sessionId(page));
  await page.locator('#P50_CATEGORIA_FISCAL_ID').selectOption({ label: (await page.locator('#P50_CATEGORIA_FISCAL_ID option')
    .filter({ hasText: categoria }).first().textContent())!.trim() });
  await page.locator('#P50_MONTO').fill(monto);
  await page.locator('#P50_INCLUYE_IMPUESTO').selectOption({ label: incluye });
  await page.locator('#P50_MONEDA_ID').selectOption({ label: 'PYG - Guaraní' });
  await page.getByRole('button', { name: 'Calcular' }).click();
  await waitForApex(page);
  await expect(apexError(page)).toHaveCount(0);
}

test.describe('ERP · Motor de impuestos', () => {
  test('IVA 10 % incluido: 110.000 = 100.000 + 10.000', async ({ admPage: page }) => {
    await calcular(page, /^GRAV10 /, '110000', 'Sí');
    const fila = page.locator('#resultado tbody tr').filter({ hasText: 'IVA10' });
    await expect(fila).toContainText(/100\.?000/);
    await expect(fila).toContainText(/10\.?000/);
  });

  test('IVA 5 % sin incluir: base 100.000 genera 5.000', async ({ admPage: page }) => {
    await calcular(page, /^GRAV5 /, '100000', 'No');
    const fila = page.locator('#resultado tbody tr').filter({ hasText: 'IVA5' });
    await expect(fila).toContainText(/5\.?000/);
  });

  test('exento: todo el monto queda como base exenta', async ({ admPage: page }) => {
    await calcular(page, /^EXENTO /, '50000', 'Sí');
    const fila = page.locator('#resultado tbody tr').filter({ hasText: 'EXENTO' });
    await expect(fila).toContainText(/50\.?000/);
  });
});
