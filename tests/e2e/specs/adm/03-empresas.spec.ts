import { test, expect, gotoPage, uniq, waitForApex } from '../../support/apex';

/** Alta/baja vía el modelo del Interactive Grid: estable frente a cambios de layout. */
async function igSave(page: import('@playwright/test').Page) {
  await page.getByRole('button', { name: /^(Save|Guardar)$/ }).click();
  await waitForApex(page);
}

test.describe('ADM · Empresas (Interactive Grid)', () => {
  test('crea, encuentra y elimina una empresa', async ({ admPage: page }) => {
    const codigo = uniq('QA');
    await gotoPage(page, 'adm', 'empresas');

    await page.evaluate((cod) => {
      const view = (window as any).apex.region('empresas').call('getViews', 'grid');
      const rec = view.model.getRecord(view.model.insertNewRecord());
      view.model.setValue(rec, 'CODIGO', cod);
      view.model.setValue(rec, 'RAZON_SOCIAL', 'Empresa de prueba E2E');
      view.model.setValue(rec, 'ESTADO', 'A');
    }, codigo);
    await igSave(page);

    await gotoPage(page, 'adm', 'empresas');
    await expect(page.locator('#empresas').getByText(codigo)).toBeVisible();

    await page.evaluate((cod) => {
      const view = (window as any).apex.region('empresas').call('getViews', 'grid');
      const recs: any[] = [];
      view.model.forEach((r: any) => { if (view.model.getValue(r, 'CODIGO') === cod) recs.push(r); });
      view.model.deleteRecords(recs);
    }, codigo);
    await igSave(page);

    await gotoPage(page, 'adm', 'empresas');
    await expect(page.locator('#empresas').getByText(codigo)).toHaveCount(0);
  });
});
