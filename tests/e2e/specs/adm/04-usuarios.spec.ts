import { test, expect, uniq, apexError, gotoPage, igBuscar, igModificar, igGuardar } from '../../support/apex';
import { crearUsuario } from '../../support/adm';

test.describe('ADM · Gestión de usuarios', () => {
  test('crea un usuario local y aparece en el listado', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x');
    await expect(apexError(page)).toHaveCount(0);
    await expect(page).toHaveTitle(/Usuarios/);
    await expect(page.getByText(/Usuario creado/)).toBeVisible();
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios').getByText(user)).toBeVisible();
  });

  test('guarda el usuario en mayúsculas', async ({ admPage: page }) => {
    const user = uniq().toLowerCase();
    await crearUsuario(page, user, 'Prueba2026x');
    await expect(apexError(page)).toHaveCount(0);
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios').getByText(user.toUpperCase())).toBeVisible();
  });

  test('crea un usuario SSO sin contraseña', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, '', 'SSO', { tipo: 'SSO' });
    await expect(apexError(page)).toHaveCount(0);
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios').getByText(user)).toBeVisible();
  });

  test('exige los campos obligatorios', async ({ admPage: page }) => {
    await gotoPage(page, 'adm', 'nuevo-usuario');
    await page.getByRole('button', { name: 'Crear usuario' }).click();
    await expect(page).toHaveTitle(/Nuevo usuario/);
    await expect(apexError(page)).toBeVisible();
  });

  for (const [caso, clave] of [['corta', 'abc1'], ['sin números', 'SoloLetras'], ['sin letras', '12345678'],
                               ['vacía (LOCAL)', '']] as const) {
    test(`rechaza una contraseña ${caso}`, async ({ admPage: page }) => {
      await crearUsuario(page, uniq(), clave, 'Débil');
      await expect(page.getByText(/al menos 8 caracteres|necesita contraseña/i)).toBeVisible();
      await expect(page.getByText(/ORA-\d{5}/)).toHaveCount(0);
    });
  }

  test('rechaza un email repetido con mensaje claro', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x');
    await crearUsuario(page, `${user}_2`, 'Prueba2026x', 'Usuario', { email: `${user.toLowerCase()}@prueba.local` });
    await expect(page.getByText('Ya existe un usuario con ese correo electrónico.')).toBeVisible();
    await expect(page.getByText(/ORA-\d{5}/)).toHaveCount(0);
  });

  test('edita los nombres desde el listado', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x');
    const nuevo = `Editado ${user}`;
    await igBuscar(page, 'usuarios', user);
    expect(await igModificar(page, 'usuarios', 'USERNAME', user, { NOMBRES: nuevo })).toBe(1);
    await igGuardar(page);
    await expect(apexError(page)).toHaveCount(0);

    await gotoPage(page, 'adm', 'usuarios');
    await igBuscar(page, 'usuarios', user);
    await expect(page.locator('#usuarios').getByText(nuevo)).toBeVisible();
  });
});
