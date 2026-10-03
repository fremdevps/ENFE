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
                │  adm_seguridad_reg  (login + F_TIENE_*)   adm_usuario_ctr (DML)         │
                └─────────────────────────────────────────────────────────────────────────┘
                        ▲                     ▲                      ▲
                 App ADM (portal +      App ERP                App CRM …
                 mantenimiento)     (solo consume)          (solo consume)
```

| Concepto | Tabla | Ejemplo |
|---|---|---|
| Aplicación | `adm_seg_aplicacion` | ADM, ERP, CRM |
| Módulo | `adm_seg_modulo` | ERP → FIN, STK, PRD |
| Permiso | `adm_seg_permiso` | `ERP_FIN_FACTURA_ANULAR` (ACCION), página 20 (PAGINA) |
| Rol | `adm_seg_rol` | `ERP_CONTADOR`, `SUPERADMIN` (global) |
| Asignación | `adm_seg_usuario_rol` | usuario + rol + empresa + vigencia |

## Autenticación

Un solo esquema de autenticación **Custom** en todas las apps:

- *Authentication Function Name*: `adm_seguridad_reg.f_autenticar`
- **Session Sharing → Workspace Sharing** (mismo *cookie name*, p.ej. `ENFE_SESSION`)
  en todas las apps ⇒ el usuario inicia sesión una vez y navega entre apps.
- Contraseñas con PBKDF2-HMAC-SHA512 + salt (requiere `grant execute on dbms_crypto`).
- Bloqueo tras 5 intentos fallidos, bitácora en `adm_aud_login`.
- `F_AUTENTICAR` además verifica que el usuario tenga acceso a la app que lo
  invoca ⇒ el acceso por app se controla desde ADM.

**SSO a futuro (opcional):** `tipo_autenticacion = 'SSO'` permite usar *Social
Sign-In* (OpenID Connect) con cualquier proveedor: OCI IAM, Microsoft Entra ID,
Google, Keycloak (on-prem). El proveedor autentica; la autorización sigue siendo
la de ADM.

## Autorización (en cada app)

Definir los *Authorization Schemes* **una vez en ADM** y **suscribirlos** desde
las demás apps (Shared Components → Subscription), así un cambio se propaga.

| Scheme | Tipo | Código | Evaluación |
|---|---|---|---|
| `ACCESO_PAGINA` | PL/SQL Function Returning Boolean | `return adm_seguridad_reg.f_tiene_acceso_pagina(:APP_USER, :APP_ID, :APP_PAGE_ID);` | Once per page view |
| `ES_SUPERADMIN` | idem | `return adm_seguridad_reg.f_es_superadmin(:APP_USER);` | Once per session |
| Por permiso (ej. `ERP_FIN_FACTURA_ANULAR`) | idem | `return adm_seguridad_reg.f_tiene_permiso(:APP_USER, 'ERP_FIN_FACTURA_ANULAR', :APP_EMPRESA_ID);` | Once per page view |

- Páginas: asignar `ACCESO_PAGINA` y registrar la página como permiso tipo
  `PAGINA` en ADM. **Denegar por defecto**: página no registrada = sin acceso
  (salvo SUPERADMIN). Login (9999) y Home pública no llevan scheme.
- Botones/procesos: scheme por permiso `ACCION`.

## Agregar una app nueva (ej. CRM)

1. Crear `apps/crm/` copiando la estructura de `apps/erp/`.
2. Registrar en ADM: aplicación `CRM` (+ `apex_app_id`), módulos, permisos, roles.
3. En la app: suscribir autenticación y authorization schemes desde ADM,
   mismo cookie de Session Sharing.
4. Sus Supporting Objects **no** crean tablas de seguridad; solo validan que
   `ADM_SEGURIDAD_REG` exista (prerequisito) y crean sus propias tablas `crm_*`.

## Escalabilidad

- Si en el futuro cada app vive en su propio esquema/workspace: mover ADM a un
  esquema `SEG`, otorgar `execute on adm_seguridad_reg` + `select on
  adm_seg_usuario_permiso_v` a cada esquema y crear sinónimos.
- Multi-empresa desde el inicio (`empresa_id` en roles); con VPD/RAS se puede
  restringir filas por empresa más adelante.
