# Estado del proyecto

> Última actualización: **2026-10-10**, al cierre de la sesión `docs/sesiones/2026-10-10-erp-modular.md`.
> Al retomar: leer este archivo y la última bitácora de `docs/sesiones/`. Al terminar, actualizarlo.

## Resumen

| App | ID APEX | Estado |
|---|---|---|
| ADM · Administración Central (seguridad central) | 100 | Publicada (v0.3.0 en `main`) |
| ERP · Configuración (app maestra del ERP modular) | 200 | Fase 1 construida en `feature/erp-gen`; **deploy a DEV en curso** |
| ERP · Inventario / Compras / Ventas / Finanzas / Contabilidad | 210 / 220 / 230 / 240 / 250 | Diseñadas en `docs/arquitectura-erp.md`; sin construir |
| Verticales por rubro | 260–299 | Reservadas |

Rama activa: **`feature/erp-gen`** (desde `develop`, publicada en `origin`). Sin mergear a `develop`.

## Hecho (fase 1 del ERP: módulo `gen`)

- **Diseño**: `docs/arquitectura-erp.md` (objetivos O1–O9, app por módulo, estructura organizativa,
  adaptación por rubro, motor de impuestos, multimoneda, fases 2–6, escalabilidad, historial §9.2,
  rangos de error).
- **Base de datos** (`apps/erp/database/`): 30 tablas (29 `erp_gen_*` + `erp_stk_deposito`), un
  trigger `_bu` por tabla, la vista `erp_gen_usuario_empresa_v`, los tipos `erp_impuesto_calc_typ/_tab`
  y 14 paquetes (`ctr → reg → api`): parámetro, período, persona, funcionalidad, moneda/cotización e
  impuesto. Datos iniciales de Paraguay (monedas, IVA, categorías fiscales, rubros, roles,
  funcionalidades) y mensajes de error. Orden de instalación: `apps/erp/install/install.sql`.
  Abreviaturas: `apps/erp/database/ABREVIATURAS.md`.
- **App 200** (`apps/erp/apexlang/`, 62 páginas generadas con `tools/apexlang/erp_paginas.py`):
  empresa, sucursales, departamentos, puntos de expedición, depósitos, acceso por sucursal,
  funcionalidades y rubros, monedas y cotizaciones, impuestos/tasas/vigencias/categorías fiscales,
  prueba del cálculo de impuestos, personas (roles, documentos), países, ubicaciones, parámetros,
  períodos, feriados, habilitación de período por usuario y cambio de empresa activa
  (`APP_EMPRESA_ID`). Supporting objects regenerados.
- **Pruebas E2E** (`tests/e2e/specs/erp/`): session sharing, apertura de todas las pantallas y motor
  de impuestos.

## Verificado

- `apex validate` de la app 200: OK (offline).
- Pruebas públicas `npm run test:publico` contra DEV: **5/5** (antes del deploy).
- En DEV: tablas, triggers, vista, tipos y paquetes del ERP instalados; registro en seguridad central
  aplicado.

## En curso / pendiente de verificar

1. **Datos iniciales en DEV**: fallaron con ORA-12839 (DML paralelo por defecto en Autonomous).
   Corrección en curso: `alter session disable parallel dml` al inicio de los scripts de datos
   (cambios sin commitear en `apps/erp/database/data/*.sql`). Reinstalar y confirmar.
2. Objetos inválidos: `select * from user_objects where status <> 'VALID'` → vacío.
3. Importar la app 200 con supporting objects.
4. `@tools/apex/verificar_consultas.sql 200 QA_ADMIN` → `0 con error`.
5. Suite Playwright del ERP: `npx playwright test specs/erp`.
6. Actualizar `CHANGELOG.md` (hoy dice "pendiente de verificar") y mergear `feature/erp-gen` a
   `develop` con `--no-ff` cuando todo pase.

## Siguiente paso

Terminar el deploy y la verificación en DEV (lista de arriba, en orden). Después:

- **Historial de cambios** (`adm_aud_cambio` + generador de triggers compound `trg_<app>_<abrev>_aiud`,
  diseño en `docs/arquitectura-erp.md` §9.2). Toca ADM.
- **Fase 2** (`feature/erp-doc`): tipo de documento, timbrado, numerador, números inutilizados y
  **SIFEN nativo** (§4).
- **Cambio en ADM** para reconocer apps por módulo (`adm_seg_modulo` ↔ app APEX) al crear la app 210.
- **Historial de git**: hay commits de `feature/erp-gen` con menciones de origen (ej. el mensaje de
  `7de7d7b` y el documento retirado en `5b2b49e`). Limpiarlos requiere reescribir y hacer force push
  de la rama: **pedir OK al dueño antes**.
- Investigaciones abiertas: coherencia de nombres, SIFEN 100 % nativo en Oracle, contratos de granos
  con fijaciones parciales de precio y tipo de cambio en cualquier orden (será app vertical).

## Reglas que no se negocian

- Leer `AGENTS.md`, `docs/ESTANDAR.md` (V3) y `docs/arquitectura-erp.md` antes de crear objetos.
- **Nativo primero**: Oracle (hasta 26ai) + APEX; lo imposible queda documentado para una API futura.
  Debe funcionar en OCI Autonomous y on-premise.
- Todo configurable por datos (impuestos sin columnas fijas, funcionalidades por rubro); nunca código
  por cliente. Multiempresa y multimoneda en todo documento.
- Nombres sin prefijos `f_`/`p_` (rutinas `verbo_objeto`).
- **No mencionar en el repo** (documentos, código, commits, nombres de objetos) los sistemas,
  productos, empresas o archivos de los que se tomaron ideas. El material de referencia está fuera
  del repositorio en `C:\Users\Francisco\Documents\ENFE-referencias` (no versionar ni copiar al repo).
- Probar y verificar siempre en el ambiente DEV; no especular resultados.
- Git: rama desde `develop`, micro commits, push frecuente (skill `git-flujo`).
- Usar agentes en paralelo cuando convenga.

## Ambiente de pruebas

| Dato | Valor |
|---|---|
| Conexión guardada (SQLcl / SQL Developer) | **`DEV ENFE OCI`** |
| Base | OCI Autonomous, versión 23.26 (26ai) |
| APEX | 26.1.5, workspace `DEV` |
| Usuario de conexión | `ADMIN` |
| Esquema de las apps | `WKSP_DEV` |

Credenciales: nunca en el repo (`.env.test` y `.secrets/` están en `.gitignore`).

## Comandos

SQLcl (desde **PowerShell**; en Git Bash `/nolog` y las rutas se rompen por la conversión de rutas):

```powershell
$sql = "$env:USERPROFILE\.vscode\extensions\oracle.sql-developer-26.3.0-win32-x64\dbtools\sqlcl\bin\sql.exe"
& $sql -S -name "DEV ENFE OCI" "@script.sql"
```

Instalar objetos del ERP en `WKSP_DEV` conectado como `ADMIN` (desde `apps/erp`):

```sql
alter session set current_schema = WKSP_DEV;
alter session disable parallel dml;   -- evita ORA-12839 en los merge de datos
@install/install.sql
```

APEXlang:

```powershell
python tools/apexlang/erp_paginas.py                       # regenerar páginas de la app 200 (no editar los .apx a mano)
powershell -File tools/build-supporting-objects.ps1 -App erp
"apex validate -input apps/erp/apexlang" | & $sql -S /nolog   # funciona offline, sin conexión
# apex import -input apps/erp/apexlang -id 200   (solo cuando el dueño lo pida; con supporting objects si cambió la BD)
```

Verificación:

```sql
select object_name, object_type from user_objects where status <> 'VALID';
@tools/apex/verificar_consultas.sql 200 QA_ADMIN
select * from adm_aud_error order by error_id desc;   -- primera fuente de diagnóstico
```

Playwright (desde `tests/e2e`):

```powershell
npm run test:publico            # sin login
npx playwright test specs/erp   # suite del ERP
npm run test:live               # en vivo (la lanza el dueño)
```
