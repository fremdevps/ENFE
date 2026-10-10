# Estado del proyecto

> Última actualización: **2026-10-10**, al cierre de la sesión `docs/sesiones/2026-10-10-erp-modular.md`.
> Al retomar: leer este archivo y la última bitácora de `docs/sesiones/`. Al terminar, actualizarlo.

## Resumen

| App | ID APEX | Estado |
|---|---|---|
| ADM · Administración Central (seguridad central) | 100 | Publicada (v0.3.0 en `main`) |
| ERP · Configuración (app maestra del ERP modular) | 200 | Fase 1 construida en `feature/erp-gen`; **desplegada y verificada en DEV** |
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

## Verificado en DEV ENFE OCI (2026-10-10)

| # | Verificación | Resultado |
|---|---|---|
| 1 | `apex validate` de la app 200 | Correcta |
| 2 | Instalación de base de datos en `WKSP_DEV` | 30 tablas, 30 triggers, 1 vista, 2 tipos, 14 paquetes |
| 3 | Objetos inválidos | Ninguno |
| 4 | Datos iniciales | Cargados (monedas, IVA, categorías, rubros, roles, 8 módulos, 15 permisos, 67 mensajes) |
| 5 | Importación de la app 200 "ERP Configuración" | Correcta, 62 páginas |
| 6 | `verificar_consultas.sql 200 QA_ADMIN` | 50 consultas, **0 con error** |
| 7 | Motor de impuestos por SQL | IVA 10 % incluido 110.000 → 100.000 + 10.000; IVA 5 % sobre 100.000 → 5.000; exento; USD con 2 decimales |
| 8 | Dígito verificador de RUC, períodos, funcionalidades, cotización inexistente | Resultados esperados |
| 9 | Pruebas públicas (`npm run test:publico`) | 5/5 |
| 10 | Suite Playwright del ERP (`npx playwright test specs/erp --project=chrome`) | **33/33** |

Problemas encontrados y resueltos en el deploy:

- **ORA-12839** en los `merge` de datos: Autonomous usa DML paralelo por defecto. Los scripts de datos
  empiezan con `alter session disable parallel dml`.
- La página "Probar cálculo" fallaba sin datos: el motor ahora devuelve un resultado vacío si falta
  categoría, monto o moneda.

## Pendiente

1. **Mergear `feature/erp-gen` a `develop`** (`--no-ff`). Está frenado por una decisión del dueño:
   limpiar o no el historial de git de la rama (ver el punto 2).
2. **Historial de git**: hay commits de `feature/erp-gen` con menciones de origen (el mensaje de
   `7de7d7b` y versiones anteriores de documentos). Limpiarlos requiere reescribir la rama y hacer
   force push: **pedir OK al dueño antes**. Conviene hacerlo antes del merge a `develop`.
3. **Suite E2E de ADM desactualizada**: los specs de `tests/e2e/specs/adm/` (03, 04, 07, 09 y
   `support/adm.ts`) todavía asumen Interactive Grid y alias viejos (`nuevo-usuario`, `usuario-roles`).
   Hay que reescribirlos para listado + panel lateral. No afecta al ERP.
4. **Historial de cambios** (`adm_aud_cambio` + generador de triggers compound
   `trg_<app>_<abrev>_aiud`, diseño en `docs/arquitectura-erp.md` §9.2). Toca ADM.
5. **Fase 2** (`feature/erp-doc`): tipo de documento, timbrado, numerador, números inutilizados y
   **SIFEN nativo** (§4). Primer paso recomendado: prueba de concepto de la firma (formato de clave
   de `DBMS_CRYPTO.SIGN` y XML canónico por construcción) contra el ambiente de test de SIFEN.
6. **Cambio en ADM** para reconocer apps por módulo (`adm_seg_modulo` ↔ app APEX) al crear la app 210.
7. **Contratos de granos** (app vertical AGR): requisitos en
   `docs/requisitos-agr-contratos-granos.md`, con 13 preguntas abiertas para el dueño.
8. Cargar la tabla geográfica oficial (departamentos, distritos, ciudades) y los feriados.

### SIFEN nativo: resultado de la investigación

- Nativo en todas las plataformas: armado del XML, CDC, hash y QR (`DBMS_CRYPTO`, `APEX_BARCODE`),
  firma RSA-SHA256 (`DBMS_CRYPTO.SIGN`, requiere 19.9 o superior), ZIP de lotes (`APEX_ZIP`), cola y
  jobs (`DBMS_SCHEDULER`, `for update skip locked`).
- La canonicalización no existe como función: se emite el XML ya en forma canónica.
- Validación contra XSD: en Autonomous solo con `DBMS_XMLSCHEMA_UTIL` y un XSD único (aplanado).
- **Único bloqueo**: en Autonomous con endpoint público (como DEV, Always Free) la base no puede
  presentar el certificado de cliente del TLS mutuo. Ese envío queda como API futura, o se usa
  endpoint privado. On-premise funciona con wallet.
- KuDE: página HTML imprimible o PDF generado en PL/SQL.

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
