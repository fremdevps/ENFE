import { test, expect } from '@playwright/test';
import { env, login, waitForApex, apexError } from '../../support/apex';

test.describe('ADM · Login central', () => {
  test('muestra la página de login', async ({ page }) => {
    await page.goto(`${env('APEX_BASE_URL')}/adm/login`);
    await waitForApex(page);
    await expect(page.locator('#P9999_USERNAME')).toBeVisible();
    await expect(page.locator('#P9999_PASSWORD')).toBeVisible();
  });

  test('rechaza un usuario inexistente', async ({ page }) => {
    await login(page, 'adm', 'QA_NO_EXISTE', 'ClaveInvalida123');
    await expect(page).toHaveURL(/\/login/i);
    await expect(apexError(page)).toBeVisible();
  });

  test('permite ingresar al superadmin de pruebas', async ({ page }) => {
    await login(page, 'adm', env('TEST_ADMIN_USER'), env('TEST_ADMIN_PASSWORD'));
    await expect(page).not.toHaveURL(/\/login/i);
    await expect(page.getByText(env('TEST_ADMIN_USER'), { exact: false }).first()).toBeVisible();
  });
});
