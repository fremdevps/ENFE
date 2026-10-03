import { test, expect, gotoPage, apexError } from '../../support/apex';

const PAGINAS: Array<[alias: string, titulo: RegExp]> = [
  ['usuarios',         /Usuarios/],
  ['nuevo-usuario',    /Nuevo usuario/],
  ['usuario-roles',    /Roles por usuario/],
  ['reset-password',   /Resetear contraseña/],
  ['roles',            /Roles/],
  ['rol-permisos',     /Permisos por rol/],
  ['aplicaciones',     /Aplicaciones/],
  ['modulos',          /Módulos/],
  ['permisos',         /Permisos/],
  ['empresas',         /Empresas/],
  ['bitacora-login',   /Bitácora de accesos/],
  ['cambiar-password', /Cambiar mi contraseña/],
];

test.describe('ADM · Navegación', () => {
  test('el menú muestra las secciones principales', async ({ admPage: page }) => {
    const menu = page.locator('#t_TreeNav');
    for (const txt of ['Inicio', 'Seguridad', 'Catálogo de aplicaciones', 'Empresas', 'Bitácora de accesos']) {
      await expect(menu.getByText(txt, { exact: true })).toBeAttached();
    }
  });

  for (const [alias, titulo] of PAGINAS) {
    test(`abre la página ${alias} sin errores`, async ({ admPage: page }) => {
      await gotoPage(page, 'adm', alias);
      await expect(page).not.toHaveURL(/\/login/i);
      await expect(page).toHaveTitle(titulo);
      await expect(apexError(page)).toHaveCount(0);
    });
  }
});
