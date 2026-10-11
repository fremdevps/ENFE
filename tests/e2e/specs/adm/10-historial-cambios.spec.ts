import { test, expect, gotoPage, waitForApex } from '../../support/apex';

/**
 * Historial de cambios (adm_aud_cambio).
 * Requiere la app 100 importada con las páginas 62 (historial-cambios) y 63 (detalle-cambio)
 * y la región "Historial" de los formularios. Solo lectura: no crea ni modifica datos.
 */
test.describe('ADM · Historial de cambios', () => {
  test('el listado abre, filtra por operación y muestra el detalle Campo / Antes / Después', async ({ admPage: page }) => {
    await gotoPage(page, 'adm', 'historial-cambios');
    await expect(page.locator('#historial-cambios')).toBeVisible();
    await expect(page.locator('#P62_TABLA')).toBeVisible();

    await page.locator('#P62_OPERACION').selectOption('U');
    await page.getByRole('button', { name: 'Buscar' }).click();
    await waitForApex(page);
    await expect(page.locator('#P62_OPERACION')).toHaveValue('U');
    const filas = page.locator('#historial-cambios .a-IRR-table tbody tr');
    await expect(filas.first()).toBeVisible();
    await expect(page.locator('#historial-cambios')).not.toContainText('Eliminación');

    // Lupa de la primera fila -> modal con el detalle
    await page.locator('#historial-cambios a:has(.fa-search)').first().click();
    const modal = page.frameLocator('iframe[title="Detalle del cambio"]');
    await expect(modal.locator('#detalle-cambio')).toBeVisible();
    for (const encabezado of ['Campo', 'Antes', 'Después']) {
      await expect(modal.locator('#detalle-cambio th', { hasText: encabezado }).first()).toBeVisible();
    }
    await modal.getByRole('button', { name: 'Cerrar' }).click();

    await page.getByRole('button', { name: 'Limpiar filtros' }).click();
    await waitForApex(page);
    await expect(page.locator('#P62_OPERACION')).toHaveValue('');
  });

  test('el formulario de empresa muestra la región Historial en edición, sin abrir otro modal', async ({ admPage: page }) => {
    await gotoPage(page, 'adm', 'empresas');
    await page.locator('#empresas a:has(.fa-edit)').first().click();
    const form = page.frameLocator('iframe[title="Empresa"]');
    await expect(form.locator('#P51_CODIGO')).toBeVisible();
    await expect(form.locator('#historial')).toBeVisible();
    await expect(form.locator('#historial')).toContainText('Historial');
  });

  test('el historial nunca muestra el hash de la contraseña', async ({ admPage: page }) => {
    await gotoPage(page, 'adm', 'historial-cambios');
    await page.locator('#P62_TABLA').selectOption('ADM_SEG_USUARIO');
    await page.getByRole('button', { name: 'Buscar' }).click();
    await waitForApex(page);
    const lupas = page.locator('#historial-cambios a:has(.fa-search)');
    if (await lupas.count() === 0) test.skip(true, 'Todavía no hay cambios de usuarios registrados');
    await lupas.first().click();
    const modal = page.frameLocator('iframe[title="Detalle del cambio"]');
    await expect(modal.locator('#detalle-cambio')).toBeVisible();
    // Un hash PBKDF2 de 64 bytes son 128 dígitos hexadecimales seguidos
    await expect(modal.locator('#detalle-cambio')).not.toContainText(/[0-9A-F]{64,}/);
  });
});
