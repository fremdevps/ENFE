# ENFE — guía para Claude

Plataforma multi-aplicación en **Oracle APEX 26.1+** (APEXlang). Debe funcionar
en **OCI Autonomous Database y on-premise**: no usar paquetes exclusivos de la
nube (DBMS_CLOUD, etc.) sin alternativa on-prem.

- Workspace APEX: `DEV` — esquema `WKSP_DEV` (OCI; on-prem puede variar).
- Seguridad centralizada en la app **ADM**: ver `docs/arquitectura-seguridad.md`.
  Las demás apps NUNCA crean sus propias tablas de usuarios/roles; consumen
  `adm_seguridad_reg`.

## Estructura

```
apps/<app>/database/{tables,views,triggers,packages,data}   fuente SQL (un objeto por archivo)
apps/<app>/install/        install.sql (orden), deinstall.sql, prerequisitos
apps/<app>/apexlang/       app APEX en APEXlang (.apx, siempre LF)
docs/                      estándar (docx) y arquitectura
.claude/skills/            skills oficiales Oracle (oracle-apex, oracle-db)
```

## Estándar técnico (obligatorio) — docs/ESTANDAR.md (V3)

Leer `docs/ESTANDAR.md` antes de crear cualquier objeto. Resumen:
- Todo lleva código de app; máximo 30 caracteres; minúsculas.
- Tablas `app_mod_entidad` (singular) con abreviatura registrada en `apps/<app>/database/ABREVIATURAS.md`.
- Derivados con `<app>_<abrev>`: `pk_erp_fac`, `fk_erp_fac_cli`, `uk_/ck_/idx_erp_fac_...`, `trg_erp_fac_biu`, `seq_erp_fac`.
- Paquetes `app_mod_entidad_{ctr|reg|api|utl}`; APEX/REST solo llaman `*_api`; ctr/reg nunca hacen COMMIT.
- PL/SQL en minúsculas: `v_ c_ g_ cur_ r_ t_ e_`, parámetros `i_ o_ io_`; funciones/procedimientos SIN prefijo (`verbo_objeto`, verbos por capa en 5.1); errores en el rango de la app.

## Convenciones propias

- Columnas de auditoría: `creado_por`, `fecha_creacion` (DEFAULT ON NULL),
  `modificado_por`, `fecha_modificacion` (trigger `_bu`).
- PK `<entidad>_id` identity. `estado` varchar2(1) con CK.
- Scripts de datos idempotentes (`merge`). Nunca credenciales ni wallets en el repo.
- Al crear un objeto: agregarlo a `apps/<app>/install/install.sql` y a `deinstall.sql`.

## APEXlang / SQLcl

```
apex export   -applicationid <ID> -dir apps/<app>/apexlang -exptype APEXLANG
apex validate -input apps/<app>/apexlang
apex import   -input apps/<app>/apexlang
```
Validar siempre antes de importar. Importar solo cuando el usuario lo pida.
