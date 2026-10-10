# AGENTS.md — Instrucciones para asistentes de IA (cualquier LLM)

Este archivo lo leen los asistentes de código (Claude Code, Codex, Cursor, Copilot, etc.).
Claude Code además lee `CLAUDE.md` y las skills de `.claude/skills/`.

## Qué es este proyecto

Plataforma multi-aplicación en **Oracle APEX 26.1+ (APEXlang)** sobre Oracle 19c+ (OCI Autonomous
y on-premise), con **seguridad centralizada** en la app **ADM (100)**; las demás apps (ERP 200, …)
consumen esa seguridad. Workspace `DEV`, esquema `WKSP_DEV` (OCI).

## Lectura obligatoria antes de cambiar algo

1. `docs/ESTANDAR.md` — nomenclatura y arquitectura (V3). **Obligatorio.**
2. `docs/arquitectura-seguridad.md` — cómo funciona el login, roles y permisos.
3. `.claude/skills/git-flujo/SKILL.md` — ramas, commits, versiones.
4. `.claude/skills/playwright-e2e/SKILL.md` — pruebas.
5. `CHANGELOG.md` — en qué versión estamos.

## Flujo de trabajo (siempre)

1. Rama desde `develop`: `feature/<app>-<tema>` (ver git-flujo). Nunca en `main`/`develop`.
2. Cambios de BD en `apps/<app>/database/...` (un objeto por archivo) + agregarlos a
   `apps/<app>/install/install.sql` y `deinstall.sql`.
3. Pantallas de ADM: se generan con `python tools/apexlang/adm_paginas.py`; las de ERP Configuración (app 200)
   con `python tools/apexlang/erp_paginas.py`
   (no editar a mano los `.apx` que genera). Otras apps: editar sus `.apx`.
4. Supporting Objects: `powershell -File tools/build-supporting-objects.ps1 -App <app>`.
5. **Verificar (ver "Definición de terminado")**.
6. Micro commits (Conventional Commits en español) + `git push` frecuente.
7. Merge `--no-ff` a `develop`; release a `main` con tag y `CHANGELOG.md`.

## Definición de terminado (DoD) — nada se da por hecho sin esto

| # | Verificación | Comando |
|---|---|---|
| 1 | Compila APEXlang | `apex validate -input apps/<app>/apexlang` |
| 2 | Se instala en DEV | `apex import -input apps/<app>/apexlang -id <ID>` (con `apex_application_install.set_auto_install_sup_obj(true)` si cambió la BD) |
| 3 | Objetos de BD válidos | `select * from user_objects where status <> 'VALID'` → vacío |
| 4 | **Todas las consultas de la app ejecutan** | `@tools/apex/verificar_consultas.sql <ID> QA_ADMIN` → `0 con error` |
| 5 | Pruebas sin login | `cd tests/e2e && npm run test:publico` |
| 6 | Suite completa con login | `npm test` / `npm run test:live` (la corre el dev; ver nota) |
| 7 | Pruebas actualizadas | Si cambió una pantalla, actualizar/agregar su spec en `tests/e2e/specs/<app>/` |

Reportar honestamente qué pasos se corrieron y cuáles no. Si algo falla, no decir "listo".

> **Nota credenciales:** los asistentes no deben escribir contraseñas en sitios remotos (OCI/on-prem).
> Pueden correr los pasos 1–5; el paso 6 lo lanza el dev, o se usa un ambiente local (`localhost`).
> Nunca subir credenciales: `.env.test` y `.secrets/` están en `.gitignore`.

## Puntos de mejora aprendidos (errores que NO hay que repetir)

### Verificación
- **Validar no es probar.** `apex validate` solo compila; hubo pantallas que validaban y fallaban
  en ejecución (ORA-00937 en indicadores, ORA-00936 en la búsqueda de grids). Siempre correr
  `verificar_consultas.sql` y Playwright antes de decir que algo funciona.
- **La bitácora de errores es la primera fuente de diagnóstico:** `select * from adm_aud_error order by error_id desc`.
- Al cambiar el diseño de una pantalla, **actualizar sus pruebas en el mismo cambio**.

### APEXlang (26.1)
- Install scripts: `installScript <id> ( execution { sequence } script { contentFile: archivo.sql } )`;
  los archivos van en `supporting-objects/install-scripts/`; **no** lleva `name`.
- Autenticación custom: `type: custom` + `settings { authFunctionName: paquete.funcion }`.
- Interactive Grid: cada columna visible necesita `columnFilter { enabled: true lovType: ... }`;
  si no, la búsqueda genera `and (())` → ORA-00936. (Preferimos reporte + formulario.)
- Acciones dinámicas: dentro de `action ( execution { ... } )` **no** usar `event:`.
- Condición de proceso por botón: `serverSideCondition { whenButtonPressed: @boton }`
  (`requestEquals` no existe).
- Botón que navega: `action: redirectThisApp` + `target { page }`; a URL: `action: redirectUrl` + `targetUrl`.
- Título de página: región breadcrumb con `name` = título de la página y template option
  `t-BreadcrumbRegion--useBreadcrumbTitle` (si no, el título muestra "Breadcrumb").
- Template options se validan contra una lista: usar solo las que `apex validate` acepta.
- Archivos `.apx` con finales de línea **LF** (`.gitattributes` lo fuerza).

### SQL / PL/SQL
- No mezclar funciones de grupo con columnas sueltas sin `group by` (usar subconsultas escalares).
- Funciones que devuelven `BOOLEAN` no se usan en SQL en 19c (usar variante `_sn` → 'S'/'N').
- Fechas de negocio con `current_date`/`localtimestamp`: **la BD en OCI está en UTC**.
- Paquetes: flujo `api → reg → ctr`, sin dependencias circulares; `accessible by` en los `ctr`.
- DDL de tablas re-ejecutable (el build lo envuelve); datos semilla con `merge`.

### Flujos de APEX
- Después del login, APEX vuelve a la **URL que se pidió**: los flujos obligatorios (cambio de
  contraseña) no deben dejar páginas "excluidas" por las que el usuario pueda quedar atrapado.
- Con session sharing entre apps no se re-ejecuta el login: proteger cada app con un
  authorization scheme a nivel aplicación (`ACCESO_APP`).

### Para el agente
- Generar archivos con scripts (Python) en lugar de heredocs de shell con comillas anidadas.
- Hacer micro commits y push a medida que se avanza; no acumular.
- Preguntar solo decisiones que cambian el diseño; lo demás, aplicar el estándar.
