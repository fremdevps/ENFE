import type { Page } from '@playwright/test';
import { gotoPage, waitForApex } from './apex';

/** Crea un usuario LOCAL desde la página 31 (Nuevo usuario). */
export async function crearUsuario(page: Page, user: string, password: string, nombres = 'Usuario') {
  await gotoPage(page, 'adm', 'nuevo-usuario');
  await page.locator('#P31_USERNAME').fill(user);
  await page.locator('#P31_EMAIL').fill(`${user.toLowerCase()}@prueba.local`);
  await page.locator('#P31_NOMBRES').fill(nombres);
  await page.locator('#P31_APELLIDOS').fill('E2E');
  await page.locator('#P31_TIPO_AUTENTICACION').selectOption('LOCAL');
  await page.locator('#P31_PASSWORD').fill(password);
  await page.getByRole('button', { name: 'Crear usuario' }).click();
  await waitForApex(page);
}
