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
