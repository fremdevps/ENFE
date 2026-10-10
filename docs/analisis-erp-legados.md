# Análisis de ERP legados: SCV y Dolphin

> Objetivo: **entender** los dos ERP heredados y quedarnos con lo mejor de cada uno, sin copiar
> código ni estructuras físicas. Las decisiones resultantes están en `docs/arquitectura-erp.md`.
> Los archivos fuente (`SCV *.zip`, `dolphin-desktop.zip`) están en la raíz del repo y **no se
> versionan** (`.gitignore`).

## 1. Qué es cada uno

| | SCV | Dolphin (Datapar) |
|---|---|---|
| Fuente analizada | Modelo de SQL Developer Data Modeler (2012–2022) | Código Delphi (`.pas/.dfm`), PL/SQL, vistas y triggers; inicio de migración a APEX (2025) |
| Tamaño | 1.118 tablas, 814 FK, 126 diagramas | ~1.036 tablas referenciadas en el código (no hay DDL maestro en el repo) |
| Arquitectura | BD única; muchos rubros en el mismo modelo | Ejecutable de escritorio monolítico (`dolphin_XE7`) + BD Oracle; personalización por cliente con triggers propios (`triggers/<Cliente>/`) |
| Nombres | `PREFIJO+ENTIDAD` (7–12 letras), columnas húngaras (`NCODIMERCA`) | Igual estilo: tablas de 7 letras (`CFGFILI`, `FATFATU`), columnas `N/C/D + 4 + sufijo` (`NCODIFILI`) |
| Idiomas | Portugués y español | Portugués y español |

## 2. Estructura organizativa

| Nivel | SCV | Dolphin | ENFE |
|---|---|---|---|
| Empresa | `SYSEMPRE` (FK a persona) | `CFGEMPR` | `adm_gen_empresa` (ADM) + `erp_gen_empresa_config` |
| Sucursal | `SYSEMPFIL` / `PERPEFI` (filial de persona) | `CFGFILI` (empresa, municipio, estado) | `erp_gen_sucursal` (establecimiento SIFEN) |
| Departamento | — | **`CFGDEPA` dentro de la filial**; se usa como dimensión en stock, títulos y movimientos | `erp_gen_departamento` (unidad de negocio/área; de la empresa o de una sucursal) |
| Punto de expedición | `FATPVEND` (punto de venta) + timbrado | **`CFGPTEX` (filial + departamento)** | `erp_gen_punto_expedicion` (sucursal, departamento opcional) |
| Depósito | `MFMDEPOS`, `REMDEPOS` (dos tablas para lo mismo) | `FATDEPO` (filial) | `erp_stk_deposito` (sucursal, departamento opcional, tipo) |
| Acceso del usuario | `SYSCTRACEMP`, `SYSCTRAFIL` | **`CFGUSFI` (usuario + filial + departamento)** | `erp_gen_usuario_sucursal` (usuario + sucursal + departamento + punto por defecto) |

**Lo mejor de ambos:** de Dolphin, la cadena *empresa → filial → departamento → punto de
expedición* y el acceso del usuario por filial/departamento. De SCV, el vínculo punto de
expedición ↔ timbrado ↔ usuario. Mejora nuestra: una sola tabla por concepto (SCV duplicaba
depósitos) y el departamento opcional, para que una empresa chica no tenga que crearlo.

## 3. Personas / entidades

| | SCV | Dolphin | ENFE |
|---|---|---|---|
| Entidad única | `PERPERSO` + ~25 tablas satélite (`PERPERFI`, `PERPREND`…) | `CFGENTI` con RUC, cédula, dirección y municipio en la misma fila | `erp_gen_persona` + dirección y contacto |
| Roles | Tablas por rol (`PERPEVND` vendedor…) | **Clases N:M (`CFGCLEN`)**: cada clase indica en qué módulos se usa (`UFATCLAS`, `UFINCLAS`, `UCONCLAS`…) | **`erp_gen_tipo_rol` + `erp_gen_persona_rol` por empresa**, con indicadores de módulo |

**Decisión:** tomar las clases de Dolphin como **roles configurables**. Cliente, proveedor,
empleado, transportista, productor, socio de cooperativa… son datos, no tablas nuevas. Así se
adapta a cualquier rubro.

## 4. Monedas, cotización e impuestos

| | SCV | Dolphin | ENFE |
|---|---|---|---|
| Moneda contable / gerencial | `SYSMOCO` | **`CFGGERA`: moneda contable + gerencial**; títulos y stock guardan valor en moneda del documento, gerencial y contable | `moneda_id_funcional` + `moneda_id_reporte` en la empresa; documentos y saldos con montos en las tres |
| Cotización | `SYSTXCAMB` (compra/venta por par) | `CFGTXCB` (compra/venta por tipo) | `erp_gen_cotizacion` (par, compra/venta, fuente, general o por empresa) |
| IVA | **Fijo en columnas** (`NVL05`, `NVL10`, `NVLEX`) | `CFGCIVA`: % + % de base imponible + código SET; una tasa por código | Impuesto → tasa → **vigencia** + categoría fiscal con varias tasas y % de base; foto por ítem |
| Costo de stock | Varias tablas de costo | **`FATSECM`: saldo por producto + filial + departamento, costo contable y gerencial** | `erp_stk_saldo` con costo en moneda funcional y de reporte |

## 5. Documentos

| | SCV | Dolphin | ENFE |
|---|---|---|---|
| Tipo de documento | `FATTPFAT` (movimiento E/S/D/C, tipo CO/VE) | **`FATTPFT` con comportamiento** (movimiento, afecta costo, proceso, operación) | `erp_doc_tipo_documento` con signos de stock/cuenta, legal, SIFEN, regla contable |
| Timbrado | `TIMTIMBRAD` + vínculos | `CFGTIMB` con indicadores **electrónico / preimpreso / autoimpresor** | `erp_doc_timbrado` + `tipo_emision` |
| Vínculos | ~15 tablas de vínculo por factura | Columnas en la fila | Columnas opcionales con FK + tabla de aplicaciones financieras |

## 6. Arquitectura de aplicación

| | SCV | Dolphin | ENFE |
|---|---|---|---|
| Interfaz | (no incluida) | Escritorio monolítico; migración a APEX con paquetes `*_DML` + `*_SERVICE` y colecciones APEX | **Varias apps APEX por módulo** con sesión compartida y componentes de una app maestra |
| Capas de código | — | `DML` (tabla) / `SERVICE` (negocio): equivale a nuestro `ctr` / `api` | `ctr` → `reg` → `api` con `accessible by` |
| Personalización por cliente | Tablas del rubro en el modelo general | **Triggers por cliente** (`triggers/Favero`, `Inpasa`…): divergencia de código | Funcionalidades activables por empresa, perfiles de rubro, parámetros y puntos de extensión; **nunca triggers por cliente** |
| Integraciones | — | Carpetas por cliente (`integracao/ALBOR`, `GAtec`…) con tablas propias | Módulo de integración con tablas `_stg` y equivalencias genéricas (fase posterior) |

## 7. Qué tomamos y qué evitamos

**Tomamos**

1. Dolphin: empresa → sucursal → departamento → punto de expedición; acceso de usuario por sucursal/departamento.
2. Dolphin: roles de entidad configurables por módulo (clases).
3. Dolphin: moneda contable + gerencial y montos en las tres monedas en títulos y stock.
4. Dolphin: tipo de documento con comportamiento.
5. Dolphin: indicadores electrónico/preimpreso/autoimpresor del timbrado.
6. SCV: cobertura funcional por rubro (agro/safra, restaurante, motel, etc.) como **catálogo de
   módulos verticales** posibles.
7. SCV: reglas paraguayas (SET, Hechauka, retenciones, RUC).

**Evitamos**

1. Impuestos fijos en columnas (SCV).
2. Monolito de escritorio y personalización por triggers de cliente (Dolphin).
3. Nombres crípticos de 7 letras y mezcla portugués/español (ambos).
4. Tablas duplicadas para el mismo concepto (SCV: dos depósitos).
5. PK compuestas y precisión insuficiente (`NUMBER(4)` para productos).
6. Una tabla de vínculo por cada dato opcional (SCV).
