# Revisión del estándar V2 → propuesta V3

> **Documento histórico.** La V3 ya está aprobada y aplicada: la regla vigente es
> **`docs/ESTANDAR.md`**. Las tablas de abajo se actualizaron con la forma final (en particular:
> constraints, índices y triggers con `<app>_<abrev>`, y funciones/procedimientos **sin prefijo**).

**Veredicto:** la base es **buena** y se parece a la de Oracle: prefijo de producto y módulo en
tablas, prefijos de constraints, sufijos de triggers, parámetros con modo. Pero tiene **huecos y
ambigüedades** que, con varias apps y varias personas, terminan en nombres que chocan o que cada
uno interpreta distinto. La V3 no cambia lo que ya funciona: **cierra esos huecos**. Todo en
español está bien.

Referencias: Oracle E-Business Suite *Naming Standards* (prefijo de producto, paquetes
`prod_modulo`, *table handlers* `tabla_PKG`, nombres ≤ 30 caracteres en EBS) y la guía *Trivadis
PL/SQL & SQL Coding Guidelines* (la más usada en la comunidad Oracle: `l_`, `g_`, `co_`, `c_`,
`r_`, `t_`, `e_`).

---

## 1. Problemas encontrados (en orden de riesgo)

| # | Regla V2 | Problema | Riesgo |
|---|---|---|---|
| 1 | `uk_descripcion`, `ck_descripcion`, `IDX_DESC` | Los nombres de constraints e índices son **únicos por esquema**, no por tabla. `ck_estado` en dos tablas de dos apps ⇒ **ORA-02264 al instalar la segunda app**. | Alto |
| 2 | Paquetes `modulo_programa_tipo` | Los ejemplos mezclan app y módulo (`erp_pedidos_ctr` vs `fin`). Con varias apps, `cliente_ctr` de ERP y de CRM **chocan**. | Alto |
| 3 | `fk_tablapadre_tablahijo` sin `_` | Ilegible (`fk_admsegaplicacion_admsegmodulo`) y largo. Oracle y Trivadis nombran la FK **desde la tabla hija** (es donde vive la FK). | Medio |
| 4 | `df_DESC` | **Oracle no permite nombrar un DEFAULT.** La regla no se puede cumplir. | Bajo (confunde) |
| 5 | Mayúsculas/minúsculas mezcladas (`IDX_`, `pk_`) | Oracle guarda todo en MAYÚSCULAS. Definir una sola forma de escribir el código. | Bajo |
| 6 | No dice nada de: secuencias, vistas, sinónimos, tipos, columnas (PK, auditoría, flags), variables globales de paquete, cursores, records, excepciones, **objetos APEX**. | Cada uno inventa ⇒ inconsistencia. | Medio |
| 7 | Solo dos capas de paquete (`ctr`, `reg`) | Falta la capa que consume APEX/REST: hoy APEX llama directo a `ctr`/`reg` y cualquier cambio interno rompe pantallas. | Medio |
| 8 | Sin límite de longitud | On-prem < 12.2 limita a **30 caracteres**. `trg_adm_seg_usuario_rol_bu` ya tiene 26. | Medio (on-prem) |

---

## 2. Propuesta V3 (cambios sobre V2)

### 2.1 Regla general
- Código en **minúsculas**. Identificadores de negocio en español, `snake_case`.
- **Máximo 30 caracteres** por identificador (compatible con cualquier on-prem). Si no alcanza,
  usar la **abreviatura de tabla** (ver 2.3).
- Cada tabla declara en su comentario una **abreviatura única de 3-4 letras** dentro de la app:
  `adm_seg_usuario` → `usu`, `erp_fin_factura` → `fac`.

### 2.2 Tablas y columnas
| Objeto | V3 | Ejemplo |
|---|---|---|
| Tabla | `app_mod_entidad` (singular) — **igual que V2** | `erp_fin_factura` |
| PK (columna) | `<entidad>_id`, identity | `factura_id` |
| FK (columna) | mismo nombre que la PK referida | `cliente_id` |
| Flags | `es_`/`tiene_` + `varchar2(1)` `S/N` | `es_superadmin` |
| Estado | `estado varchar2(1)` + CK | `A/I/B` |
| Auditoría | `creado_por`, `fecha_creacion`, `modificado_por`, `fecha_modificacion` | — |

### 2.3 Constraints e índices (cambia: **siempre llevan la tabla**)
| Tipo | V3 | Ejemplo |
|---|---|---|
| PK | `pk_<app>_<abrev>` | `pk_erp_fac` |
| FK | `fk_<app>_<abrev_hija>_<abrev_padre>[_<rol>]` | `fk_erp_fac_cli` · `fk_adm_usu_emp_def` |
| UK | `uk_<app>_<abrev>_<columnas>` | `uk_adm_usu_username` |
| CK | `ck_<app>_<abrev>_<regla>` | `ck_erp_fac_monto_pos` |
| Índice | `idx_<app>_<abrev>_<columnas>` | `idx_erp_fac_fecha_emision` |
| Default | **se elimina `df_`** (no existe en Oracle) | — |

### 2.4 Otros objetos (nuevo)
| Objeto | V3 | Ejemplo |
|---|---|---|
| Secuencia (si no hay identity) | `seq_<app>_<abrev>[_<uso>]` | `seq_erp_fac_numero` |
| Vista | `<app_mod_entidad>_v` | `adm_seg_usuario_permiso_v` |
| Vista materializada | `<...>_mv` | `erp_ven_resumen_mes_mv` |
| Trigger | `trg_<app>_<abrev>_<momento><evento>` | `trg_erp_fac_biu` |
| Tipo objeto / colección | `<app>_<nombre>_typ` / `_tab` | `erp_linea_typ` |
| Sinónimo | mismo nombre que el objeto | — |
| Job (scheduler) | `job_<app>_<accion>` | `job_erp_cierre_diario` |

### 2.5 Paquetes (cambia: **siempre `app_mod_` delante**, 3 capas)
`<app>_<mod>_<entidad>_<capa>`

| Capa | Responsabilidad | Quién la llama | Equivalente Oracle EBS |
|---|---|---|---|
| `ctr` | DML puro de **una** tabla (insert/update/delete/lock) | solo `reg` / `api` | *table handler* `tabla_PKG` |
| `reg` | Reglas de negocio, validaciones, cálculos | `api` | `_PVT` |
| `api` (**nuevo**) | Fachada estable para APEX, REST y otras apps. Valida permisos, traduce errores a mensajes. | APEX / ORDS / otras apps | `_PUB` |
| `utl` (**nuevo**, opcional) | Utilitarios sin estado de negocio | todos | — |

Ejemplos: `erp_fin_factura_ctr`, `erp_fin_factura_reg`, `erp_fin_factura_api`, `adm_seg_seguridad_reg`.
Regla de oro: **APEX solo llama a paquetes `api`** (y la seguridad central a `adm_seg_seguridad_reg`).
Así se puede refactorizar por dentro sin romper pantallas.

### 2.6 Código PL/SQL (se amplía V2)
| Elemento | V2 | V3 |
|---|---|---|
| Variable local | `V_` | `v_` (igual, en minúsculas) |
| Constante | `C_` | `c_` (igual) |
| Variable global de paquete | — | `g_` |
| Cursor | — | `cur_` |
| Record | — | `r_` |
| Tipo (colección/record) | — | `t_` |
| Excepción | — | `e_` |
| Función / Procedure | `F_` / `P_` | **sin prefijo**: `verbo_objeto` (ESTANDAR §5.1), ej. `tiene_permiso`, `anular` |
| Parámetros | `I_` / `O_` / `IO_` | `i_` / `o_` / `io_` (**excepción documentada**: la función de autenticación que APEX invoca con `p_username`/`p_password`) |
| Códigos de error | — | `raise_application_error` en rango por app: ADM −20000..−20099, ERP −20100..−20299… |

### 2.7 Objetos APEX (nuevo)
| Objeto | V3 | Ejemplo |
|---|---|---|
| ID de app | fijo por app: ADM 100, ERP 200, CRM 300… | — |
| Alias de app / página | minúsculas con guion | `adm`, `nuevo-usuario` |
| Páginas | rangos por módulo: 1-9 inicio, 10-99 módulo 1, 100-199 módulo 2… 9999 login | — |
| Items | `P<pág>_<COLUMNA>` (estándar APEX) | `P31_USERNAME` |
| Región (Static ID) | minúsculas con guion, = entidad | `empresas` |
| Authorization scheme | `<CODIGO_PERMISO>` (mismo código que en ADM) | `ADM_SEG_ROL_GESTIONAR` |
| LOV compartida | plural de la entidad | `usuarios`, `estado-ai` |
| Código de permiso | `APP_MOD_ENTIDAD_ACCION` | `ERP_FIN_FACTURA_ANULAR` |

---

## 3. Impacto en lo ya construido (aplicado)

Los cambios en ADM se aplicaron al adoptar la V3:

- Constraints e índices renombrados a la forma `<tipo>_<app>_<abrev>_…` (ej. `uk_adm_usu_username`,
  `ck_adm_emp_estado`); abreviaturas en `apps/adm/database/ABREVIATURAS.md`.
- Paquetes con `app_mod_` delante: la seguridad central es `adm_seg_seguridad_reg`
  (`autenticar`, `tiene_permiso`, `tiene_acceso_app`, `tiene_acceso_pagina`, `es_superadmin`,
  `debe_cambiar_password`), el DML de usuarios `adm_seg_usuario_ctr` y APEX usa
  `adm_seg_usuario_api` / `adm_seg_rol_api` en lugar de llamar a `ctr`.
- Funciones y procedimientos sin prefijo `f_`/`p_`.
- Las pantallas APEX cumplen 2.7.
