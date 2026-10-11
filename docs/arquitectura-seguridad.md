# Arquitectura de seguridad centralizada

Todas las aplicaciones APEX (ADM, ERP, CRM, …) comparten **un único control de
usuarios, roles y permisos** que vive en la app **ADM** (Administración Central).
Funciona igual en **OCI Autonomous Database** y **on-premise** (no usa nada
exclusivo de la nube).

## Piezas

```
                ┌──────────────────────────── esquema WKSP_DEV ───────────────────────────┐
                │  adm_seg_aplicacion ─< adm_seg_modulo ─< adm_seg_permiso                │
                │                                              │                          │
                │  adm_seg_rol ─────────< adm_seg_rol_permiso >┘                          │
                │      │                                                                  │
                │  adm_seg_usuario_rol >── adm_seg_usuario        adm_gen_empresa         │
                │                                                                         │
                │  adm_seg_usuario_permiso_v  (permisos efectivos)                        │
                │  adm_seg_seguridad_reg  (autenticar + es_/tiene_*)                      │
                │  adm_seg_usuario_api / adm_seg_rol_api  (mantenimiento desde APEX)      │
                └─────────────────────────────────────────────────────────────────────────┘
                        ▲                     ▲                      ▲
                 App ADM (portal +      App ERP                App CRM …
                 mantenimiento)     (solo consume)          (solo consume)
```

| Concepto | Tabla | Ejemplo |
|---|---|---|
| Aplicación | `adm_seg_aplicacion` | ADM, ERP, CRM |
| Módulo | `adm_seg_modulo` | ERP → GEN, FIN, STK |
| Permiso | `adm_seg_permiso` | `ERP_GEN_PERIODO_CERRAR` (ACCION) o una página APEX (PAGINA) |
| Rol | `adm_seg_rol` | `ERP_ADMINISTRADOR`, `SUPERADMIN` (global) |
| Asignación | `adm_seg_usuario_rol` | usuario + rol + empresa + vigencia |

## Autenticación

Un solo esquema de autenticación **Custom** en todas las apps
(`shared-components/authentications.apx`):

- *Authentication Function Name*: `adm_seg_seguridad_reg.autenticar`
  (única función con parámetros `p_username` / `p_password`: nombres fijos que exige APEX,
  excepción documentada en `docs/ESTANDAR.md` §5.2).
- **Session Sharing → Workspace Sharing** en todas las apps ⇒ el usuario inicia
  sesión una vez y navega entre apps.
- Contraseñas con PBKDF2-HMAC-SHA512 + salt (`adm_seg_password_utl`; requiere
  `grant execute on dbms_crypto`, ver `apps/adm/install/00_prerequisitos_dba.sql`).
- Bloqueo tras 5 intentos fallidos (`adm_seg_seguridad_reg.c_max_intentos`),
  bitácora en `adm_aud_login` (`OK`, `PASSWORD_INVALIDO`, `BLOQUEADO`, `INACTIVO`,
  `USUARIO_NO_EXISTE`, `SIN_ACCESO`).
- `autenticar` además verifica que el usuario tenga acceso a la app que lo
  invoca (`tiene_acceso_app`) ⇒ el acceso por app se controla desde ADM.

**SSO a futuro (opcional):** `tipo_autenticacion = 'SSO'` permite usar *Social
Sign-In* (OpenID Connect) con cualquier proveedor: OCI IAM, Microsoft Entra ID,
Google, Keycloak (on-prem). El proveedor autentica; la autorización sigue siendo
la de ADM. Hoy `autenticar` solo acepta usuarios `LOCAL`.

## Autorización (en cada app)

Cada app declara sus *Authorization Schemes* en `shared-components/authorizations.apx`
(en ERP los genera `tools/apexlang/erp_paginas.py`); todos llaman a
`adm_seg_seguridad_reg`, así la regla vive en un solo lugar.

| Scheme | Tipo | Código |
|---|---|---|
| `ACCESO_APP` (a nivel aplicación) | PL/SQL Function Body | `return adm_seg_seguridad_reg.tiene_acceso_app(:APP_USER, :APP_ID);` |
| `ES_SUPERADMIN` | idem | `return adm_seg_seguridad_reg.es_superadmin(:APP_USER);` |
| `ACCESO_PAGINA` | idem | `return adm_seg_seguridad_reg.tiene_acceso_pagina(:APP_USER, :APP_ID, :APP_PAGE_ID);` |
| Por permiso (ej. `ADM_SEG_USUARIO_VER`) | idem | `return adm_seg_seguridad_reg.tiene_permiso(:APP_USER, 'ADM_SEG_USUARIO_VER');` |
| Por permiso y empresa (ERP, ej. `ERP_GEN_PERIODO_CERRAR`) | idem | `return adm_seg_seguridad_reg.tiene_permiso(:APP_USER, 'ERP_GEN_PERIODO_CERRAR', :APP_EMPRESA_ID);` |

- El nombre del scheme es **el mismo código del permiso** registrado en ADM
  (datos semilla: `apps/adm/database/data/adm_seg_datos_iniciales.sql`,
  `apps/erp/database/data/erp_seg_registro.sql`).
- **Aplicación:** `ACCESO_APP` como scheme de la app (también protege a quien llega
  por session sharing sin pasar por el login de esa app).
- **Páginas:** el scheme del permiso que las gobierna (ej. Usuarios → `ADM_SEG_USUARIO_VER`).
  `ACCESO_PAGINA` queda disponible para páginas registradas como permiso tipo `PAGINA`:
  **deniega por defecto** (página no registrada = sin acceso, salvo SUPERADMIN).
  Login (9999), Inicio y las páginas de contraseña propia no llevan scheme de página
  (las cubre `ACCESO_APP`).
- **Botones/procesos:** scheme por permiso `ACCION`. Las reglas que además se validan en
  PL/SQL las hace el paquete `api` (ej. `erp_gen_periodo_api.reabrir` exige
  `ERP_GEN_PERIODO_REABRIR`).

## Agregar una app nueva (ej. CRM)

1. Crear `apps/crm/` copiando la estructura de `apps/erp/`.
2. Registrar en ADM con un script de datos idempotente (`merge`), como
   `apps/erp/database/data/erp_seg_registro.sql`: aplicación `CRM` (+ `apex_app_id`),
   módulos, permisos y roles.
3. En la app: autenticación custom `adm_seg_seguridad_reg.autenticar` con Workspace
   Sharing, `ACCESO_APP` a nivel aplicación y un scheme por código de permiso.
4. Sus Supporting Objects **no** crean tablas de seguridad: requieren ADM instalado
   antes y crean sus propias tablas `crm_*`.

## Escalabilidad

- Si en el futuro cada app vive en su propio esquema/workspace: mover ADM a un
  esquema `SEG`, otorgar `execute on adm_seg_seguridad_reg` y `adm_gen_error_api`
  (manejo de errores) + `select on adm_seg_usuario_permiso_v` (y las tablas ADM que
  lean sus vistas y scripts de registro) a cada esquema y crear sinónimos.
- Multi-empresa desde el inicio (`empresa_id` en roles); con VPD/RAS se puede
  restringir filas por empresa más adelante.

## Historial de cambios

Registro de **quién cambió qué dato y cuándo**, con el valor anterior y el nuevo de cada campo.
Vive en ADM y sirve a todas las apps. Diseño: `docs/arquitectura-erp.md` §9.2.

| Pieza | Qué hace |
|---|---|
| `adm_aud_cambio` | Una fila por registro modificado: app, tabla, `registro_id`, `registro_padre_id`, `empresa_id`, operación (`I`/`U`/`D`), `cambios` (JSON), usuario, fecha, app/página/sesión APEX, transacción y módulo. |
| `trg_<app>_<abrev>_aiud` | Trigger compound **generado** por tabla auditada: compara cada columna, acumula las filas y las inserta por lote (`forall`, 500 filas por ejecución). |
| `adm_aud_cambio_utl` | `generar_trigger` (lee el diccionario y escribe el trigger) y `agregar_*` (arman el JSON). |
| `adm_aud_cambio_api` / `_ctr` | Registro por lote y purga. El `ctr` solo lo usan el `api` y el trigger de protección (`accessible by`). |
| `adm_aud_cambio_v`, `adm_aud_cambio_det_v` | Consulta: cabecera con descripciones, y detalle con una fila por campo (Campo / Antes / Después). |
| `trg_adm_cam_bud` | El historial es de solo inserción: rechaza todo `update` y todo `delete` que no sea la purga (ORA-20040). |
| `job_adm_purgar_cambio` | Purga mensual por retención. |

### Qué se audita

- Maestros y configuración. En ADM: empresa, aplicación, módulo, permiso, rol, permisos del rol,
  usuario, roles del usuario y mensajes de error. Los documentos transaccionales no (son
  inmutables; sus cambios de estado se registran como eventos desde la API).
- Formato de `cambios`: `[{"col":"estado","antes":"A","despues":"I"}, …]`, **solo las columnas
  que cambiaron**. En un alta, las columnas con valor (`antes` nulo); en una baja, la fila
  completa en `antes`. Un `update` que no cambia ningún valor auditado no deja fila.
- Fechas en ISO 8601 (`2026-03-15T00:00:00`, con zona si la columna la tiene), números como
  número JSON sin máscara, `raw` en hexadecimal.
- **Nunca se guardan**: las columnas de auditoría (`creado_por`, `fecha_creacion`,
  `modificado_por`, `fecha_modificacion`), las LOB y de tipos no escalares, y la PK (va en
  `registro_id`).
- **Columnas reservadas** (nombre con `password`, `hash`, `token`, `clave`, `secret` o `salt`,
  si son texto de más de un carácter, número o `raw`): solo queda que cambiaron
  (`"reservado":true`), jamás el valor. El hash y el salt de la contraseña no aparecen en el
  historial. Indicadores como `debe_cambiar_password` (S/N) y fechas sí guardan su valor.
- No es autónomo: si la transacción se deshace, su historial también.
- En `adm_seg_usuario` se excluyen `intentos_fallidos` y `fecha_ultimo_login` (cambian en cada
  ingreso; eso ya está en `adm_aud_login`).

### Agregar una tabla al historial

Requisitos: PK numérica de una sola columna y la abreviatura en el comentario de la tabla
(`Abrev: xxx`). Desde la raíz del repositorio, en SQLcl y con el esquema de las apps como
`current_schema`:

```
@tools/db/generar_trigger_historial.sql <tabla> <columna_padre|_> <excluidas|_> <reservadas|_>

@tools/db/generar_trigger_historial.sql erp_gen_sucursal _ _ _
@tools/db/generar_trigger_historial.sql adm_seg_usuario_rol usuario_id _ _
```

Siempre cuatro argumentos; `_` significa "sin valor". Escribe
`apps/<app>/database/triggers/trg_<app>_<abrev>_aiud.sql` (se versiona; no se edita a mano).
Después: instalarlo, agregarlo a `install.sql` en la sección **Triggers de historial** (va después
de los paquetes) y regenerar los Supporting Objects. Si cambian las columnas de la tabla, se
vuelve a generar con el comando que figura en la cabecera del propio archivo.

- `columna_padre`: columna con la PK del padre, para ver los cambios de una tabla hija junto al
  registro padre (roles en el usuario, permisos en el rol).
- `excluidas` / `reservadas`: listas separadas por comas (sin espacios).
- Para pruebas, `adm_aud_cambio_utl.crear_trigger('<tabla>')` lo genera y compila en un paso.
- Si la tabla tiene una FK `on delete cascade`, sus bajas se insertan fila por fila: Oracle no
  ejecuta la sección `after statement` de la tabla hija cuando el borrado llega desde el padre.
  El generador lo detecta solo.

### Retención y purga

- `job_adm_purgar_cambio` corre el día 1 de cada mes a las 03:00 y borra lo anterior a la
  retención: **84 meses** por defecto. Para cambiarla:
  `exec dbms_scheduler.set_job_argument_value('JOB_ADM_PURGAR_CAMBIO', 1, '120')`.
  La instalación no pisa un job existente, así que el valor configurado se conserva.
- Purga manual: `adm_aud_cambio_api.purgar(i_meses_retencion => n, o_filas => v)` (sin commit)
  o `ejecutar_purga(n)` (con commit). Mínimo 1 mes.
- Particionamiento mensual opcional: `apps/adm/install/opcional/particionar_historial.sql`
  (Autonomous lo incluye; on-premise requiere Enterprise Edition + Partitioning).

### Consulta

- **ADM → Auditoría → Historial de cambios** (página 62, permiso `ADM_AUD_CAMBIO_VER`): listado
  con filtros por dato, usuario, operación, empresa y fechas; la lupa abre el detalle Campo /
  Antes / Después.
- Región **Historial** en cada formulario de edición de ADM: cambios del registro abierto y de
  sus tablas hijas. Va dentro del formulario, plegada; no abre otro modal.
- Otras apps la reutilizan desde su generador: `base.HISTORIAL = dict(auth='<scheme>')` antes de
  generar los formularios (ver el encabezado de `tools/apexlang/adm_paginas.py`).
- Por SQL: `select * from adm_aud_cambio_det_v where tabla = 'ADM_SEG_USUARIO' and registro_id = :id`.
  El nombre del campo sale del comentario de la columna: conviene que sea corto y claro.

### Decisiones tomadas al implementarlo

| Tema | Decisión |
|---|---|
| Armado del JSON | `json_array_t` / `json_object_t` (nativos, 12.2+): escapan bien y escriben números como número. |
| Tamaño | El JSON viaja como `varchar2(32767)` para no crear un LOB temporal por fila; si lo supera, esa fila se inserta sola como CLOB. |
| Lectura del JSON | `json_table` sobre el CLOB; los valores de más de 4000 bytes se muestran truncados (el dato completo queda en `cambios`). |
| Etiquetas | Las vistas leen `all_tab_comments` / `all_col_comments` del esquema actual: `user_*` dentro de una vista responde por el usuario conectado, no por el dueño. |
| Protección | Trigger de sentencia en lugar de tabla inmutable: permite la purga y no congela la estructura. No impide un `truncate` (es DDL). |
| Pruebas | `tests/sql/adm/historial.sql` (repetible, sin dejar datos). |
