# ENFE

Plataforma multi-aplicación (ADM, ERP, CRM, …) sobre **Oracle APEX 26.1+** con
**seguridad centralizada**. Funciona en **OCI Autonomous Database** y **on-premise**.

- Workspace APEX: `DEV` (esquema `WKSP_DEV`)
- Estándar de nomenclatura: [docs/Estandar_Tecnico_Nomenclatura_DB_PLSQL_V2.docx](docs/Estandar_Tecnico_Nomenclatura_DB_PLSQL_V2.docx)
- Arquitectura de seguridad: [docs/arquitectura-seguridad.md](docs/arquitectura-seguridad.md)
- **¿Trabajas con un asistente de IA?** Lee [AGENTS.md](AGENTS.md) y usa el [prompt inicial](docs/PROMPT-INICIAL.md).

## Estructura

```
apps/
  adm/                Administración Central: usuarios, roles, permisos, apps, empresas
    database/         tables/ views/ triggers/ packages/ data/   (fuente SQL)
    install/          install.sql, deinstall.sql, 00_prerequisitos_dba.sql
    apexlang/         app APEX en formato APEXlang
  erp/                ERP (misma estructura)
docs/
.claude/skills/       skills oficiales de Oracle (APEX/APEXlang y Database) para Claude
```

## Requisitos

| | Versión |
|---|---|
| Oracle APEX | 26.1 o superior (APEXlang) |
| SQLcl | 26.1.2 o superior (`apex validate` / `apex import`) |
| VS Code | extensión **Oracle SQL Developer** (incluye SQLcl) |

## Conexión

- **OCI:** cada desarrollador baja **su propio wallet** (Autonomous Database → *Database connection*),
  lo guarda **fuera del repo** y crea la conexión *Cloud Wallet* en SQL Developer (servicio `_low`/`_tp`).
  Si no conecta: agregar tu IP en *Network → Access control list*.
- **On-prem:** conexión *Basic* (host / puerto / service name).

## Instalación de ADM (primera vez)

1. **DBA** (ADMIN en OCI, SYS/SYSTEM on-prem): `apps/adm/install/00_prerequisitos_dba.sql`
2. **Esquema WKSP_DEV**: desde `apps/adm` → `@install/install.sql`
   (o vía Supporting Objects al importar la app APEX)
3. El superadmin **`ADMIN`** se crea solo en cada instalación (rol SUPERADMIN, contraseña aleatoria).
   Fijar su contraseña inicial: `@database/data/adm_seg_password_admin.sql` (la pide por consola;
   el sistema obliga a cambiarla en el primer ingreso).

## Flujo de trabajo (APEXlang)

```
apex export   -applicationid <ID> -dir apps/<app>/apexlang -exptype APEXLANG
apex validate -input apps/<app>/apexlang
apex import   -input apps/<app>/apexlang
```

1. `git pull` → 2. cambios (.apx o SQL) → 3. `apex validate` → 4. `apex import` a DEV
→ 5. probar → 6. commit + push. Avisar si dos personas tocan la misma página.

Los `.apx` deben ir con finales de línea **LF** (lo fuerza `.gitattributes`).
