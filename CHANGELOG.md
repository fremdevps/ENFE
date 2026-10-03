# Changelog

Formato: [SemVer](https://semver.org/lang/es/). Ver `.claude/skills/git-flujo/SKILL.md`.

## [v0.2.0] - 2026-10-03
### Cambiado
- Estándar técnico **V3** (`docs/ESTANDAR.md`) aplicado a ADM: abreviaturas de tabla, constraints/índices/triggers `<tipo>_adm_<abrev>`, paquetes por capas `utl → ctr → reg → api` con `accessible by`, rutinas sin prefijo F_/P_, código en minúsculas.
- Fechas de negocio con la hora del usuario (`current_date`), auditoría `timestamp with local time zone`.
- Nombres visibles sin "ENFE": "Administración Central" (100) y "ERP" (200).
- Menú lateral expandido con iconos; breadcrumb con título en cada pantalla; botón Cancelar en formularios.
### Agregado
- Manejo de errores central (`adm_gen_error_api.manejar_error_apex`): mensajes por constraint (`adm_gen_mensaje_error`), errores de negocio en español, incidentes en `adm_aud_error`. Pantallas *Mensajes de error* y *Bitácora de errores*.
- Comentarios en todas las columnas; ayuda de página/items y comentarios normalizados en APEX.
- Supporting Objects idempotentes; superadmin `ADMIN` garantizado en toda instalación; cambio de contraseña obligatorio.
- Suite Playwright (56 pruebas): modo en vivo (Chrome visible) y segundo plano. Skills `playwright-e2e` y `git-flujo`.
### Corregido
- Dependencia circular entre paquetes de seguridad.
- Login enviado sin usuario fallaba con ORA-01400.
### Problemas conocidos
- La búsqueda de la barra de los Interactive Grid falla (ORA-00936). Se resuelve en v0.3.0 al reemplazar los grids por reporte + formulario.
- Suite E2E con login pendiente de ejecución completa contra DEV.

## [v0.1.0] - 2026-10-03
### Agregado
- Seguridad centralizada (app ADM 100): usuarios, roles, permisos, aplicaciones, módulos, empresas, bitácora de accesos; login central con session sharing.
- App ERP (200) base con registro de módulos en ADM.
- Suite E2E inicial y skill de Playwright.
