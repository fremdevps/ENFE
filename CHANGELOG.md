# Changelog

Formato: [SemVer](https://semver.org/lang/es/). Ver `.claude/skills/git-flujo/SKILL.md`.

## [Sin publicar]
### Agregado
- **ERP modular**: diseño de una app APEX por módulo con sesión compartida y app maestra (200 ERP Configuración); `docs/arquitectura-erp.md`.
- Módulo General del ERP (30 tablas): monedas y cotizaciones, motor de impuestos configurable con vigencias y categorías fiscales, estructura organizativa (sucursal, departamento, punto de expedición, depósito, acceso por sucursal), personas con roles por empresa y validación de RUC, funcionalidades por rubro, parámetros y períodos.
- App 200 **ERP Configuración** con 62 páginas, empresa activa en la sesión (`APP_EMPRESA_ID`) y página para probar el cálculo de impuestos.
- Pruebas E2E del ERP (apertura de pantallas y motor de impuestos).
- **Historial de cambios** en ADM: tabla `adm_aud_cambio` (JSON con antes/después por campo), triggers generados para las tablas maestras, pantalla con filtros, región Historial en los formularios, permiso `ADM_AUD_CAMBIO_VER` y purga mensual (retención 84 meses); `docs/arquitectura-seguridad.md`.
### Verificado en DEV
- Instalación sin objetos inválidos, importación de la app 200, `verificar_consultas.sql` (50 consultas, 0 con error) y suite Playwright del ERP (33/33).
### Corregido
- ORA-12839 en los datos iniciales sobre Autonomous (DML paralelo).
- El motor de impuestos devuelve un resultado vacío cuando faltan datos, en lugar de un error.
### Problemas conocidos
- La suite Playwright de ADM con login sigue apuntando a las pantallas anteriores.

## [v0.3.0] - 2026-10-03
### Cambiado
- ADM rediseñado con el patrón recomendado por APEX para usuarios no técnicos: **listado (Interactive Report) + formulario en panel lateral**; modales para acciones puntuales.
- Usuarios y roles vía capa `api` (`adm_seg_usuario_api`, nuevo `adm_seg_rol_api`); catálogos simples con guardado automático (excepción documentada en el estándar).
- Inicio tipo **hub**: tarjetas por área, indicadores y gráficos del estado actual.
- Menú agrupado (Seguridad, Catálogo, Auditoría) y colapsado; breadcrumb con el nombre de cada página.
- Apps y login en **español**.
- Botones ordenados: Cancelar a la izquierda, acción principal a la derecha, abajo del formulario.
### Agregado
- **Cambio de contraseña obligatorio** con diseño de login (página 91, sin menú) y opción Salir.
- Rol del usuario gestionado desde su formulario (modal Asignar o quitar rol) y permisos del rol en shuttle; rol SUPERADMIN protegido.
- `tools/apexlang/adm_paginas.py`: generador de las pantallas de ADM.
- `tools/apex/verificar_consultas.sql`: ejecuta todas las consultas (regiones, gráficos, LOVs) de una app en una sesión real.
- `AGENTS.md` (instrucciones para cualquier LLM, definición de terminado y puntos de mejora) y `docs/PROMPT-INICIAL.md`.
- Skills con verificación obligatoria después de cada cambio.
### Corregido
- Indicadores del inicio (ORA-00937).
- Con cambio de contraseña pendiente, el login podía devolver a la pág. 90 en lugar de la 91.
### Problemas conocidos
- La suite Playwright **con login** apunta todavía a las pantallas anteriores (grids); debe adaptarse al nuevo diseño. Las pruebas públicas pasan (4/4).

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
- La búsqueda de la barra de los Interactive Grid falla (ORA-00936). **Resuelto en v0.3.0** (se reemplazaron los grids).
- Suite E2E con login pendiente de ejecución completa contra DEV.

## [v0.1.0] - 2026-10-03
### Agregado
- Seguridad centralizada (app ADM 100): usuarios, roles, permisos, aplicaciones, módulos, empresas, bitácora de accesos; login central con session sharing.
- App ERP (200) base con registro de módulos en ADM.
- Suite E2E inicial y skill de Playwright.
