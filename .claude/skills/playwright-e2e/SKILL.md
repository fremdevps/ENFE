---
name: playwright-e2e
description: Pruebas end-to-end con Playwright de las apps APEX de ENFE (ADM, ERP, …). Usar al crear, ejecutar, depurar o revisar pruebas automatizadas de pantallas APEX, ver el reporte HTML o el modo UI en localhost, o cuando se agregue una pantalla nueva que necesite cobertura.
---

# Pruebas E2E con Playwright (ENFE)

Suite en `tests/e2e/`. Corre contra el ambiente APEX indicado en `.env.test`
(raíz del repo, **ignorado por git**). Nunca escribir credenciales en specs.

## Ejecutar

```
cd tests/e2e
npm install                 # primera vez
npm run install:browsers    # primera vez (Chromium)
npm test                    # toda la suite (headless) + reporte en reports/html
npm run test:ui             # modo UI interactivo  -> http://127.0.0.1:9323
npm run report              # reporte HTML         -> http://127.0.0.1:9324
npx playwright test specs/adm/03-empresas.spec.ts --headed   # una sola, viendo el navegador
```

`.env.test` requiere: `APEX_BASE_URL` (…/ords/r/<workspace>), `TEST_ADMIN_USER`,
`TEST_ADMIN_PASSWORD` (superadmin de pruebas, p.ej. QA_ADMIN).

## Estructura

```
tests/e2e/
  playwright.config.ts     reporters list + html + junit, trace/video/screenshot al fallar
  support/apex.ts          login, gotoPage (alias + sesión), waitForApex, apexError, fixture admPage, uniq()
  support/adm.ts           acciones de negocio reutilizables de ADM (crearUsuario…)
  specs/<app>/NN-<tema>.spec.ts
```

## Reglas para escribir pruebas

1. **Un spec por pantalla/flujo**, numerado en orden de dependencia (`01-login`, `02-navegacion`…).
2. Usar la fixture `admPage` (ya autenticada) salvo que se pruebe el login.
3. Navegar con `gotoPage(page, app, alias)`: alias de página APEX en minúsculas
   (friendly URL `/r/<ws>/<app>/<alias>?session=…`). No usar números de página.
4. Selectores: items APEX por id (`#P31_USERNAME`), regiones por su `htmlDomId`
   (`#empresas`), botones por rol + nombre visible. Nada de clases CSS de tema.
5. **Interactive Grid**: alta/baja/edición vía el modelo JS
   (`apex.region('<id>').call('getViews','grid').model`) y luego clic en *Guardar*.
   Es estable frente a cambios de layout; verificar siempre recargando la página.
6. Datos de prueba con `uniq()` → prefijo `QA_E2E_`/`QA_`; nunca tocar datos reales.
7. Esperar con `waitForApex(page)` después de cada submit/navegación.
8. Errores: `apexError(page)` debe tener `toHaveCount(0)` en caminos felices.
9. Cada pantalla nueva en APEX ⇒ agregarla a `02-navegacion.spec.ts` + un spec de su flujo.

## Depurar un fallo

- `reports/html` → abrir el test → *Trace* (DOM, red, consola paso a paso).
- `npx playwright test <spec> --debug` para ir paso a paso.
- Si falla por login: revisar `adm_aud_login` (resultado `SIN_ACCESO`, `BLOQUEADO`…).
