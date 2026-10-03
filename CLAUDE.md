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

## Estándar de nomenclatura (obligatorio) — docs/Estandar_Tecnico_Nomenclatura_DB_PLSQL_V2.docx

- Tablas: `app_modulo_tabla` en **singular** (`erp_fin_factura`, `adm_seg_usuario`).
- PK `pk_<tabla>` · FK `fk_<padre sin _>_<hija sin _>` (`fk_admsegrol_admsegusuariorol`)
  · UK `uk_<desc>` · CK `ck_<desc>` · índice `idx_<desc>`.
  (`df_` no aplica: Oracle no permite nombrar DEFAULTs.)
- Triggers: `trg_<tabla>_<momento><evento>` → `_bi _bu _bd _ai _au _ad _biu _aiu _biud _aiud _io`.
- Paquetes: `<modulo>_<programa>_<tipo>`; `ctr` = DML/persistencia, `reg` = reglas de negocio.
- PL/SQL: variables `V_`, constantes `C_`, funciones `F_`, procedimientos `P_`;
  parámetros `I_` (in), `O_` (out), `IO_` (in out).
  Excepción: funciones que APEX invoca con nombres fijos (`p_username`, `p_password`).

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
