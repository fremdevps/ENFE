import { test, expect, uniq } from '../../support/apex';
import { crearUsuario } from '../../support/adm';

test.describe('ADM · Manejo de errores central', () => {
  test('un dato duplicado muestra un mensaje claro (no el ORA-00001)', async ({ admPage: page }) => {
    const user = uniq();
    await crearUsuario(page, user, 'Prueba2026x');
    // Mismo usuario otra vez -> uk_adm_usu_username -> mensaje de adm_gen_mensaje_error
    await crearUsuario(page, user, 'Prueba2026x');
    await expect(page.getByText('Ya existe un usuario con ese nombre de usuario.')).toBeVisible();
    await expect(page.getByText(/ORA-\d{5}/)).toHaveCount(0);
  });
});
