---
name: playwright-e2e
description: Pruebas end-to-end con Playwright de las apps APEX (ADM, ERP, …). Usar cuando el dev pida correr las pruebas (en vivo viendo Chrome, en segundo plano, o una sola), ver el reporte o el modo UI en localhost, crear/depurar pruebas, o cuando se agregue una pantalla nueva que necesite cobertura.
---

# Pruebas E2E con Playwright

Suite en `tests/e2e/`. Corre contra el ambiente APEX indicado en `.env.test`
(raíz del repo, **ignorado por git**). Nunca escribir credenciales en specs.

## Ejecutar — según lo que pida el dev

Requisitos (una vez): Node.js LTS y `npm install` en `tests/e2e`. Usa el **Google Chrome
instalado** (`channel: 'chrome'`), no hace falta descargar navegadores.

| El dev dice… | Comando (desde `tests/e2e`) | Qué pasa |
|---|---|---|
| "en vivo", "quiero verlo", "con Chrome" | `npm run test:live` | Chrome visible, cámara lenta (400 ms por acción) |
| "en segundo plano", "en background", "corre las pruebas" | `npm test` | Sin ventana; al final, reporte HTML |
| "modo interactivo", "elegir pruebas" | `npm run test:ui` | UI de Playwright en **http://127.0.0.1:9323** |
| "ver el reporte", "qué falló" | `npm run report` | Reporte en **http://127.0.0.1:9324** (trace, video, capturas) |
| "solo una prueba / una pantalla" | `npx playwright test specs/adm/03-empresas.spec.ts --project=en-vivo` | Una sola, en vivo |
| "paso a paso", "depurar" | `npx playwright test <spec> --project=en-vivo --debug` | Inspector de Playwright |
| "sin login" (smoke) | `npm run test:publico` | Solo pruebas marcadas `@publico` |

Para dejar corriendo en segundo plano y seguir trabajando: lanzar `npm test` como proceso de
fondo y, al terminar, abrir `npm run report`.

**Credenciales:** las pruebas que inician sesión leen `.env.test` (raíz del repo, ignorado por
git). Claude NO ingresa credenciales en sitios que no sean `localhost`: si el ambiente es remoto
(OCI/on-prem), Claude corre solo `@publico` y el dev lanza el resto con los comandos de arriba.

## Después de CADA cambio (obligatorio)

Ningún cambio de pantalla, proceso o consulta se da por terminado sin esta secuencia
(ver "Definición de terminado" en `AGENTS.md`):

1. `apex validate -input apps/<app>/apexlang`
2. `apex import -input apps/<app>/apexlang -id <ID>` en DEV
3. `@tools/apex/verificar_consultas.sql <ID> QA_ADMIN` → debe decir `0 con error`
   (ejecuta todas las consultas de regiones, gráficos y LOVs en una sesión APEX real)
4. `npm run test:publico` (Claude lo corre siempre)
5. Suite completa con login (`npm test` o `npm run test:live`): la lanza el dev en ambientes
   remotos; Claude la corre solo en `localhost`.
6. Si la pantalla cambió: actualizar o crear su spec en el mismo commit.

Reportar el resultado real de cada paso. "Valida" no significa "funciona".

## Estructura

```
tests/e2e/
  playwright.config.ts     reporters list + html + junit, trace/video/screenshot al fallar
  support/apex.ts          login, gotoPage (alias + sesión), sessionId, waitForApex, apexError, fixture admPage, uniq()
  support/adm.ts           acciones de negocio reutilizables de ADM (crearUsuario, asignarRol, filaBitacora…)
  specs/<app>/NN-<tema>.spec.ts
```

## Reglas para escribir pruebas

1. **Un spec por pantalla/flujo**, numerado en orden de dependencia (`01-login`, `02-navegacion`…).
2. Usar la fixture `admPage` (ya autenticada) salvo que se pruebe el login.
3. Navegar con `gotoPage(page, app, alias)`: alias de página APEX en minúsculas
   (friendly URL `/r/<ws>/<app>/<alias>?session=…`). No usar números de página.
4. Selectores: items APEX por id (`#P31_USERNAME`), regiones por su `htmlDomId`
   (`#empresas`), botones por rol + nombre visible. Nada de clases CSS de tema.
5. **Listado + formulario** (diseño de ADM y ERP): el listado es un Interactive Report
   (región con `htmlDomId` = entidad, ej. `#usuarios`) y el alta/edición se hace en la página
   de formulario, que abre como panel lateral (modal drawer, se maneja con
   `page.frameLocator(...)` porque APEX lo muestra en un iframe), con los botones `Crear` /
   `Guardar cambios` / `Eliminar`. Las acciones van a la página del formulario (`usuario`,
   `asignar-rol`, `reset-password`…), no a una grilla editable. Verificar siempre recargando
   el listado. Hoy ninguna app usa Interactive Grid (ver AGENTS.md).
6. Datos de prueba con `uniq()` → prefijo `QA_E2E_`/`QA_`; nunca tocar datos reales.
7. Esperar con `waitForApex(page)` después de cada submit/navegación.
8. Errores: `apexError(page)` debe tener `toHaveCount(0)` en caminos felices.
9. Cada pantalla nueva en APEX ⇒ agregarla a `02-navegacion.spec.ts` + un spec de su flujo.

## Depurar un fallo

- `reports/html` → abrir el test → *Trace* (DOM, red, consola paso a paso).
- `npx playwright test <spec> --debug` para ir paso a paso.
- Si falla por login: revisar `adm_aud_login` (resultado `SIN_ACCESO`, `BLOQUEADO`…).
