import { test, expect, uniq, gotoPage, apexError, igBuscar, igInsertar, igEliminar, igGuardar, valorLov, igCelda } from '../../support/apex';
import { crearUsuario, asignarRol } from '../../support/adm';
import type { Page } from '@playwright/test';

/** Alta → verificación → baja → verificación en un Interactive Grid. */
async function crudIg(page: Page, alias: string, region: string, fila: Record<string, string>, clave: string) {
  const valor = fila[clave];
  await gotoPage(page, 'adm', alias);
  await igInsertar(page, region, [fila]);
  await igGuardar(page);
  await expect(apexError(page)).toHaveCount(0);

  await gotoPage(page, 'adm', alias);
  await igBuscar(page, region, valor);
  await expect(igCelda(page, region, valor)).toBeVisible();

  expect(await igEliminar(page, region, clave, valor)).toBe(1);
  await igGuardar(page);
  await expect(apexError(page)).toHaveCount(0);

  await gotoPage(page, 'adm', alias);
  await igBuscar(page, region, valor);
  await expect(igCelda(page, region, valor)).toHaveCount(0);
}

/** Inserta una fila que debe fallar y verifica el mensaje claro (sin ORA-). */
async function rechazoIg(page: Page, alias: string, region: string, filas: Record<string, string>[], mensaje: string) {
  await gotoPage(page, 'adm', alias);
  await igInsertar(page, region, filas);
  await igGuardar(page);
  await expect(page.getByText(mensaje)).toBeVisible();
  await expect(page.getByText(/ORA-\d{5}/)).toHaveCount(0);
}

test.describe('ADM · Catálogos (Interactive Grid)', () => {
  test('roles: crea y elimina un rol', async ({ admPage: page }) => {
    await crudIg(page, 'roles', 'roles',
      { CODIGO: uniq('QA_ROL'), NOMBRE: 'Rol de prueba E2E', ES_SUPERADMIN: 'N', ESTADO: 'A' }, 'CODIGO');
  });

  test('roles: el código debe ir en mayúsculas', async ({ admPage: page }) => {
    await rechazoIg(page, 'roles', 'roles',
      [{ CODIGO: uniq('qa_rol').toLowerCase(), NOMBRE: 'Minúsculas', ES_SUPERADMIN: 'N', ESTADO: 'A' }],
      'El código del rol debe estar en mayúsculas.');
  });

  test('roles: no permite códigos repetidos', async ({ admPage: page }) => {
    await rechazoIg(page, 'roles', 'roles',
      [{ CODIGO: 'SUPERADMIN', NOMBRE: 'Duplicado', ES_SUPERADMIN: 'N', ESTADO: 'A' }],
      'Ya existe un rol con ese código.');
  });

  test('roles: no se elimina un rol asignado a usuarios', async ({ admPage: page }) => {
    const rol = uniq('QA_ROL');
    await gotoPage(page, 'adm', 'roles');
    await igInsertar(page, 'roles', [{ CODIGO: rol, NOMBRE: 'Rol asignado E2E', ES_SUPERADMIN: 'N', ESTADO: 'A' }]);
    await igGuardar(page);
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x', 'Con rol');
    await asignarRol(page, user, rol);
    await expect(apexError(page)).toHaveCount(0);

    await gotoPage(page, 'adm', 'roles');
    await igBuscar(page, 'roles', rol);
    expect(await igEliminar(page, 'roles', 'CODIGO', rol)).toBe(1);
    await igGuardar(page);
    await expect(page.getByText('No se puede eliminar el rol: está asignado a usuarios.')).toBeVisible();
  });

  test('aplicaciones: crea y elimina una aplicación', async ({ admPage: page }) => {
    await crudIg(page, 'aplicaciones', 'aplicaciones',
      { CODIGO: uniq('QA_APL'), NOMBRE: 'App de prueba E2E', ORDEN: '999', ESTADO: 'A' }, 'CODIGO');
  });

  test('aplicaciones: el código debe ir en mayúsculas', async ({ admPage: page }) => {
    await rechazoIg(page, 'aplicaciones', 'aplicaciones',
      [{ CODIGO: uniq('qa_apl').toLowerCase(), NOMBRE: 'Minúsculas', ORDEN: '999', ESTADO: 'A' }],
      'El código de la aplicación debe estar en mayúsculas.');
  });

  test('aplicaciones: no permite códigos repetidos', async ({ admPage: page }) => {
    await rechazoIg(page, 'aplicaciones', 'aplicaciones',
      [{ CODIGO: 'ADM', NOMBRE: 'Duplicada', ORDEN: '999', ESTADO: 'A' }],
      'Ya existe una aplicación con ese código.');
  });

  test('aplicaciones: no se elimina una aplicación con módulos', async ({ admPage: page }) => {
    const apl = uniq('QA_APL');
    await gotoPage(page, 'adm', 'aplicaciones');
    await igInsertar(page, 'aplicaciones', [{ CODIGO: apl, NOMBRE: 'App con módulos E2E', ORDEN: '999', ESTADO: 'A' }]);
    await igGuardar(page);

    await gotoPage(page, 'adm', 'modulos');
    const aplId = await valorLov(page, '#modulos', new RegExp(`^${apl} - `));
    await igInsertar(page, 'modulos', [{ APLICACION_ID: aplId, CODIGO: 'QA_MOD', NOMBRE: 'Módulo E2E', ORDEN: '1', ESTADO: 'A' }]);
    await igGuardar(page);
    await expect(apexError(page)).toHaveCount(0);

    await gotoPage(page, 'adm', 'aplicaciones');
    await igBuscar(page, 'aplicaciones', apl);
    expect(await igEliminar(page, 'aplicaciones', 'CODIGO', apl)).toBe(1);
    await igGuardar(page);
    await expect(page.getByText('No se puede eliminar la aplicación: tiene módulos.')).toBeVisible();
  });

  test('empresas: no permite códigos repetidos', async ({ admPage: page }) => {
    const codigo = uniq('QA');
    await rechazoIg(page, 'empresas', 'empresas', [
      { CODIGO: codigo, RAZON_SOCIAL: 'Duplicada 1', ESTADO: 'A' },
      { CODIGO: codigo, RAZON_SOCIAL: 'Duplicada 2', ESTADO: 'A' },
    ], 'Ya existe una empresa con ese código.');
  });

  test('mensajes de error: crea y elimina un mensaje', async ({ admPage: page }) => {
    await crudIg(page, 'mensajes-error', 'mensajes-error',
      { CODIGO: uniq('QA_CK'), MENSAJE: 'Mensaje de prueba E2E' }, 'CODIGO');
  });

  test('mensajes de error: no permite repetir el constraint', async ({ admPage: page }) => {
    await rechazoIg(page, 'mensajes-error', 'mensajes-error',
      [{ CODIGO: 'UK_ADM_USU_USERNAME', MENSAJE: 'Duplicado' }],
      'Ya existe un mensaje para ese constraint.');
  });

  for (const [alias, region] of [['bitacora-login', 'bitacora-login'], ['bitacora-errores', 'bitacora-errores']]) {
    test(`${alias}: es solo lectura (sin botón Guardar)`, async ({ admPage: page }) => {
      await gotoPage(page, 'adm', alias);
      await expect(page.locator(`#${region}`)).toBeVisible();
      await expect(page.getByRole('button', { name: /^(Save|Guardar)$/ })).toHaveCount(0);
    });
  }
});
