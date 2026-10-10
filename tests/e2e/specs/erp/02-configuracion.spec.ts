import { test, expect, gotoPage, sessionId, apexError } from '../../support/apex';

/** Listados de la app ERP Configuración (alias de página → título). */
const LISTADOS: [string, string][] = [
  ['empresas-config', 'Datos de la empresa'],
  ['sucursales', 'Sucursales'],
  ['departamentos', 'Departamentos'],
  ['puntos-expedicion', 'Puntos de expedición'],
  ['depositos', 'Depósitos'],
  ['usuarios-sucursal', 'Usuarios por sucursal'],
  ['funcionalidades-empresa', 'Funcionalidades activas'],
  ['monedas', 'Monedas'],
  ['cotizaciones', 'Cotizaciones'],
  ['impuestos', 'Impuestos'],
  ['tasas', 'Tasas'],
  ['vigencias', 'Vigencias de tasas'],
  ['categorias-fiscales', 'Categorías fiscales'],
  ['categoria-tasas', 'Tasas por categoría'],
  ['personas', 'Personas'],
  ['roles-persona', 'Roles por empresa'],
  ['tipos-rol', 'Tipos de rol'],
  ['tipos-documento', 'Tipos de documento'],
  ['paises', 'Países'],
  ['ubicaciones', 'Ubicaciones'],
  ['funcionalidades', 'Funcionalidades'],
  ['rubros', 'Rubros'],
  ['rubro-funcionalidades', 'Funcionalidades por rubro'],
  ['parametros', 'Parámetros'],
  ['periodos', 'Períodos'],
];

test.describe('ERP · Pantallas de configuración', () => {
  for (const [alias, titulo] of LISTADOS) {
    test(`abre ${titulo} sin errores`, async ({ admPage: page }) => {
      await gotoPage(page, 'erp', alias, await sessionId(page));
      await expect(page).not.toHaveURL(/\/login/i);
      await expect(page.getByRole('heading', { name: titulo, exact: true }).first()).toBeVisible();
      await expect(apexError(page)).toHaveCount(0);
      await expect(page.getByText(/ORA-\d{5}/)).toHaveCount(0);
    });
  }

  test('los datos iniciales cargan monedas, IVA y rubros', async ({ admPage: page }) => {
    const sid = await sessionId(page);
    await gotoPage(page, 'erp', 'monedas', sid);
    await expect(page.locator('#monedas').getByText('PYG', { exact: true })).toBeVisible();
    await gotoPage(page, 'erp', 'categorias-fiscales', sid);
    await expect(page.locator('#categorias-fiscales').getByText('GRAV10', { exact: true })).toBeVisible();
    await gotoPage(page, 'erp', 'rubros', sid);
    await expect(page.locator('#rubros').getByText('AGRO', { exact: true })).toBeVisible();
  });
});
