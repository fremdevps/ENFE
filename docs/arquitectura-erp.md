# Arquitectura del ERP (app `erp`, ID 200)

> Diseño funcional y de datos del ERP. Complementa `docs/ESTANDAR.md` (nomenclatura) y
> `docs/arquitectura-seguridad.md` (login, roles). Toda tabla nueva del ERP sigue este documento.

## 1. Objetivos de diseño

| # | Objetivo | Cómo se cumple |
|---|---|---|
| O1 | **Multiempresa** | `empresa_id` (FK `adm_gen_empresa`) NOT NULL en toda tabla transaccional y de configuración; índices que empiezan por `empresa_id`; la API valida la empresa activa (`APP_EMPRESA_ID`). |
| O2 | **Multimoneda** | Cada documento guarda moneda, cotización usada y montos en moneda del documento **y** en moneda funcional de la empresa. Saldos en la moneda del documento. Diferencia de cambio automática. |
| O3 | **Impuestos configurables** | Ningún impuesto ni tasa fijo en columnas. Impuestos, tasas con vigencia y categorías fiscales son datos; al emitir se guarda una **foto** del cálculo por ítem. |
| O4 | **Todo configurable** | Tipos de documento con comportamiento (stock, cuenta corriente, comprobante legal, contabilidad); parámetros por empresa; reglas contables como datos. |
| O5 | **Escalable en volumen** | PK identity con caché; saldos mantenidos (no se recalculan del histórico); documentos inmutables; períodos cerrados; particionamiento opcional; APIs por lote. |
| O6 | **Facturación electrónica** | Nace preparado para **SIFEN / e-Kuatia** (Paraguay): CDC, XML firmado, lotes, eventos, KuDE. La emisión en papel (timbrado preimpreso) es un caso particular. |
| O7 | **OCI y on-premise** | Oracle 19c + APEX 26.1; nada exclusivo de la nube sin alternativa. |

### Origen

El análisis del modelo heredado **SCV** (SQL Developer Data Modeler, 1.118 tablas, 2012–2022) se
usó como **especificación funcional** (reglas paraguayas: SET, RUC, timbrado, Hechauka,
retenciones). No se migra su DDL: tenía el IVA fijo en columnas (`NVL05/NVL10`), códigos con
precisión insuficiente (`NUMBER(4)`), 480 PK compuestas y ~15 tablas de vínculo por documento.
También se analizó **Dolphin** (Datapar). Comparación y decisiones en `docs/analisis-erp-legados.md`.

## 2. Módulos y aplicaciones APEX (no monolítico)

### 2.1 Una app APEX por módulo

El ERP **no es una sola aplicación**. Sigue el patrón que APEX soporta de forma nativa:

| Mecanismo APEX | Uso en ENFE |
|---|---|
| **Sesión compartida** (`sessionSharing: workspaceSharing` en el esquema de autenticación) | El usuario inicia sesión una vez y navega entre ADM y todas las apps del ERP sin volver a loguearse (ya funciona entre ADM y ERP). |
| **Suscripción de componentes compartidos** (`subscription { master: … }`) | Una **app maestra** define autenticación, authorization schemes, LOVs, app items (`APP_EMPRESA_ID`), procesos de aplicación y tema; las apps de módulo se suscriben y heredan los cambios. |
| **Un solo esquema** | Todas las apps usan los mismos paquetes `erp_*_api`; las apps son solo interfaz. Un módulo nuevo no duplica lógica. |

| ID APEX | App | Módulos | Contenido |
|---|---|---|---|
| 200 | **ERP · Configuración** (maestra) | `gen`, `doc` | Empresa, estructura organizativa, monedas, impuestos, personas, períodos, documentos y timbrado, SIFEN |
| 210 | ERP · Inventario | `stk` | Productos, depósitos, movimientos, saldos |
| 220 | ERP · Compras | `com` | Proveedores, órdenes, facturas de compra |
| 230 | ERP · Ventas | `ven` | Clientes, precios, pedidos, facturación |
| 240 | ERP · Finanzas | `fin` | Cuentas a cobrar/pagar, caja, bancos, cheques |
| 250 | ERP · Contabilidad | `cnt` | Plan de cuentas, asientos, cierres |
| 260–299 | Apps verticales por rubro | `prd`, `agr`, `rst`… | Producción, agro (safra), restaurante… solo si la empresa las activa |

Beneficios: cada app se despliega, versiona y prueba por separado; un cliente instala solo lo que
usa; varios devs trabajan en paralelo sin pisarse; las pantallas pesadas de un módulo no afectan
a los demás.

Seguridad: cada app de módulo se registra en ADM con su `apex_app_id`. Pendiente en ADM:
asociar `adm_seg_modulo` con su app APEX para que `tiene_acceso_app` reconozca las apps de
módulo. Se hace al crear la segunda app (210).

### 2.2 Módulos de base de datos

| Código | Módulo | Contenido | Páginas |
|---|---|---|---|
| `gen` | General | País, ubicación, moneda, cotización, impuestos, categoría fiscal, estructura organizativa, persona y roles, funcionalidades por rubro, parámetros, períodos | app 200 |
| `doc` | Documentos | Tipo de documento, timbrado, numeración, facturación electrónica (SIFEN) | app 200 |
| `stk` | Inventario | Producto, unidad, marca, depósito, movimiento, saldo de stock, lote | app 210 |
| `ven` | Ventas | Cliente, lista de precio, pedido, factura de venta, nota de crédito/débito, remisión | app 230 |
| `com` | Compras | Proveedor, solicitud, orden de compra, factura de compra, autofactura | app 220 |
| `fin` | Finanzas | Cuenta a cobrar/pagar (cuotas), recibo, orden de pago, aplicación, retención, cheque, caja, banco, diferencia de cambio | app 240 |
| `cnt` | Contabilidad | Plan de cuentas, ejercicio, asiento, regla contable, centro de costo, saldo contable | app 250 |
| `prd` | Producción | (reservado) | app 260+ |

Dependencias (siempre hacia abajo, nunca circulares):

```
             ven   com
               \   /
   cnt ◄────── fin ──► (asientos por regla)
                 |
                doc ──► stk
                 |
                gen ──► adm (empresa, usuario, permisos)
```

## 3. General (`gen`) — fase 1

### 3.1 Tablas

| Tabla | Abrev. | Para qué |
|---|---|---|
| `erp_gen_pais` | pai | País (ISO 3166), moneda por defecto |
| `erp_gen_ubicacion` | ubi | Jerarquía geográfica configurable por país (departamento → distrito → ciudad), con código oficial (SIFEN) |
| `erp_gen_moneda` | mon | Moneda ISO 4217, decimales de importe y de precio |
| `erp_gen_cotizacion` | cot | Cotización compra/venta por fecha y par de monedas; general o por empresa |
| `erp_gen_impuesto` | imp | Impuesto (IVA, ISC, IRE, IRP…) y retenciones, por país |
| `erp_gen_impuesto_tasa` | imta | Tasa de un impuesto con vigencia (`fecha_desde/hasta`) |
| `erp_gen_categoria_fiscal` | cafi | Cómo tributa un producto: gravado 10, gravado 5, exento, gravado parcial… |
| `erp_gen_categoria_tasa` | cata | Tasas que componen una categoría y qué % de la base afecta cada una |
| `erp_gen_empresa_config` | emcf | Extensión ERP de `adm_gen_empresa`: país, moneda funcional, precio con impuesto, datos fiscales |
| `erp_gen_sucursal` | suc | Sucursal / establecimiento (código SIFEN de 3 dígitos) |
| `erp_gen_departamento` | dpto | Departamento / unidad de negocio de la empresa o de una sucursal |
| `erp_gen_punto_expedicion` | ptex | Punto de expedición (3 dígitos) de una sucursal, opcionalmente de un departamento |
| `erp_gen_usuario_sucursal` | ussu | Sucursales y departamentos que puede operar cada usuario, con punto de expedición por defecto |
| `erp_gen_funcionalidad` | func | Catálogo de funcionalidades activables (lotes, series, safra, vendedores, centros de costo…) |
| `erp_gen_rubro` | rub | Perfil de rubro (comercio, agro, industria, servicios…) con sus funcionalidades sugeridas |
| `erp_gen_rubro_funcionalidad` | rufu | Funcionalidades que activa cada rubro |
| `erp_gen_empresa_funcionalidad` | emfu | Funcionalidades activas de cada empresa |
| `erp_gen_tipo_rol` | tirl | Roles de persona configurables (cliente, proveedor, empleado, transportista, productor…) |
| `erp_gen_persona_rol` | prro | Roles de cada persona por empresa |
| `erp_stk_deposito` | dpo | Depósito de una sucursal (módulo `stk`, creado con la estructura organizativa) |
| `erp_gen_tipo_doc_identidad` | tdi | RUC, cédula, pasaporte… con código oficial |
| `erp_gen_persona` | prs | Persona física o jurídica **única** (cliente, proveedor, empleado son roles: `erp_gen_persona_rol`) |
| `erp_gen_persona_direccion` | prdi | Direcciones (fiscal, entrega, cobro) |
| `erp_gen_persona_contacto` | prco | Teléfonos, correos, contactos |
| `erp_gen_parametro` | par | Parámetros clave/valor tipados; por empresa con valor general por defecto |
| `erp_gen_periodo` | peri | Período (año/mes) abierto o cerrado por empresa y módulo |

**Persona global, roles por empresa.** Una persona (RUC/cédula) existe una sola vez en el
esquema; los datos comerciales por empresa (crédito, lista de precio, condición de pago, cuenta
contable) viven en `erp_ven_cliente` / `erp_com_proveedor` con `empresa_id`. Así un grupo de
empresas comparte el padrón sin duplicar personas.

### 3.2 Motor de impuestos

```
erp_gen_impuesto (IVA)
   └── erp_gen_impuesto_tasa  IVA10 10% desde 1992-01-01 · IVA5 5% · ...
erp_gen_categoria_fiscal (GRAV10, GRAV5, EXENTO, PARCIAL_30_5 …)
   └── erp_gen_categoria_tasa  (categoria, tasa, % de base)
```

- Un producto tiene **categoría fiscal**, nunca una tasa.
- `erp_gen_impuesto_api.obtener_calculo(categoria, fecha, monto, incluye_impuesto, moneda)` devuelve una
  colección `erp_impuesto_calc_tab` con una fila por tasa: base imponible, impuesto, y la parte
  exenta/no gravada. Se resuelve la tasa **vigente a la fecha del documento**.
- Gravado parcial (ej. 30 % de la base al 5 % y el resto exento): la suma de `% de base` de una
  categoría no puede superar 100; lo que falta es exento.
- Precio con impuesto incluido (lo habitual en Paraguay): `base = parte / (1 + tasa)`;
  sin incluir: `impuesto = base × tasa`. Redondeo a los decimales de la moneda.
- Cada documento guarda el resultado en `<documento>_item_impuesto` (foto) y un resumen por tasa
  en la cabecera (libro IVA / Hechauka / SIFEN). **Cambiar una tasa no altera documentos emitidos.**
- Pendiente para una versión siguiente: impuestos en cascada (ISC que forma base del IVA) con
  `orden` y "aplica sobre impuestos anteriores".

### 3.3 Multimoneda

- `erp_gen_empresa_config.moneda_id_funcional`: moneda contable de la empresa (PYG).
  Opcional `moneda_id_reporte` (USD) para reportes de grupo.
- `erp_gen_cotizacion`: `(empresa_id null = general, moneda_origen, moneda_destino, fecha)`.
  La búsqueda toma la última cotización `<= fecha` (a igual fecha, la de la empresa antes que la
  general); si solo existe el par inverso, usa `1 / tasa`. El parámetro
  `ERP_GEN_COTIZACION_DIAS_MAX` limita la antigüedad admitida. Fuente: `BCP`, `SET`, `MAN` (manual).
- Todo documento: `moneda_id`, `cotizacion`, montos en moneda del documento y
  `*_funcional`. Los reportes nunca reconvierten.
- Cobro/pago en moneda distinta a la del documento: se aplica con la cotización del día y la
  diferencia contra la cotización original genera **diferencia de cambio** (asiento automático).

### 3.4 Estructura organizativa

```
adm_gen_empresa ── erp_gen_empresa_config (país, monedas, rubro, datos fiscales)
   ├── erp_gen_departamento   (opcional; de toda la empresa o de una sucursal)
   └── erp_gen_sucursal       (establecimiento 001, 002…)
          ├── erp_gen_punto_expedicion  (001, 002… ; departamento opcional)
          └── erp_stk_deposito          (departamento opcional; propio, consignación, tránsito)
erp_gen_usuario_sucursal: usuario + sucursal [+ departamento] + punto por defecto
```

- El **departamento** es una dimensión de análisis opcional (como en Dolphin): documentos, stock
  y finanzas podrán llevar `departamento_id` para reportes por unidad de negocio.
- Si un usuario no tiene filas en `erp_gen_usuario_sucursal`, opera todas las sucursales de la
  empresa, salvo que el parámetro `ERP_GEN_ACCESO_SUCURSAL_ESTRICTO = 'S'`.

### 3.5 Adaptación a cualquier rubro

Nada de tablas por cliente ni triggers por cliente. La adaptación es por **datos**:

1. **Funcionalidades** (`erp_gen_funcionalidad`): interruptores por empresa que muestran u
   ocultan campos, pantallas y validaciones (ej. `LOTE`, `VENCIMIENTO`, `SERIE`, `SAFRA`,
   `VENDEDOR`, `CENTRO_COSTO`, `DEPARTAMENTO`, `CONSIGNACION`).
   En APEX: condición `erp_gen_funcionalidad_api.esta_activa_sn('LOTE', :APP_EMPRESA_ID) = 'S'`.
2. **Rubros** (`erp_gen_rubro`): plantillas que activan un conjunto de funcionalidades al
   configurar la empresa (comercio, distribuidora, agro/cooperativa, industria, servicios,
   restaurante…). Se pueden ajustar después, empresa por empresa.
3. **Roles de persona configurables** (`erp_gen_tipo_rol`) con indicadores de en qué módulos se
   usa cada rol.
4. **Parámetros** (`erp_gen_parametro`) para comportamientos puntuales.
5. **Apps verticales** (260–299) para rubros con procesos propios, que reutilizan el núcleo.

### 3.6 Períodos

`erp_gen_periodo (empresa, modulo, anio, mes, estado)`. Toda API que registra un documento llama
`erp_gen_periodo_api.validar_abierto(empresa, modulo, fecha)`. Cerrar un período bloquea altas,
anulaciones y modificaciones con fecha en ese mes; reabrir requiere permiso
`ERP_GEN_PERIODO_REABRIR`.

## 4. Documentos (`doc`) y SIFEN — fase 2

### 4.1 Motor de documentos

Un único concepto de **tipo de documento** define el comportamiento; factura, nota de crédito,
remisión, recibo, autofactura y orden de pago son configuraciones, no tablas de vínculo.

| Tabla | Para qué |
|---|---|
| `erp_doc_tipo_documento` | Comportamiento: `signo_stock` (+1/−1/0), `signo_cuenta` (D/C/N), `es_legal`, `tipo_emision` (E electrónico / P preimpreso / I interno), `codigo_sifen` (1 FE, 4 AFE, 5 NCE, 6 NDE, 7 NRE), `requiere_documento_origen`, `regla_contable` |
| `erp_doc_timbrado` | Timbrado (número, vigencia desde/hasta, electrónico o preimpreso) por empresa |
| `erp_doc_numerador` | Correlativo por empresa + timbrado + establecimiento + punto + tipo; se toma con `select … for update` en la transacción (ESTANDAR §1.3) |
| `erp_doc_numero_inutilizado` | Rangos inutilizados (evento SIFEN de inutilización) |

### 4.2 Facturación electrónica SIFEN (e-Kuatia)

Datos de referencia (Manual Técnico SIFEN v150, DNIT):

- **Tipos de DE**: 1 Factura (FE) · 4 Autofactura (AFE) · 5 Nota de crédito (NCE) ·
  6 Nota de débito (NDE) · 7 Nota de remisión (NRE).
- **CDC** de 44 dígitos: tipo DE (2) + RUC (8) + DV (1) + establecimiento (3) + punto (3) +
  número (7) + tipo contribuyente (1) + fecha AAAAMMDD (8) + tipo de emisión (1) +
  código de seguridad (9) + dígito verificador (1).
- Numeración visible `001-001-0000001`; al llegar a 9.999.999 avanza la serie (AA, AB…).
- XML firmado con el **certificado digital** del contribuyente; QR con el **CSC**;
  representación gráfica **KuDE** (PDF).
- Plazos: envío hasta **72 h** desde la firma; **cancelación** de FE hasta 48 h después de
  aprobada (otros DE hasta 168 h); **inutilización** de números dentro de los primeros 15 días del
  mes siguiente. (Verificar contra la normativa vigente al implementar.)
- Obligatoriedad progresiva por grupos (RG DNIT 52: grupos 15–23 entre mar-2026 y jun-2027;
  proveedores del Estado desde 2-ene-2026, RG 41/2025).

Tablas:

| Tabla | Para qué |
|---|---|
| `erp_doc_fe_config` | Por empresa: ambiente (test/producción), id y valor de CSC (referencia a secreto, **nunca en el repo**), URL de servicios, tipo de contribuyente |
| `erp_doc_fe_documento` | Un registro por DE: `cdc`, código de seguridad, XML firmado (CLOB), estado (`P` pendiente · `E` enviado · `A` aprobado · `O` aprobado con observación · `R` rechazado · `C` cancelado), mensajes, fecha de firma y de respuesta |
| `erp_doc_fe_lote` | Lote asíncrono enviado (n.º de lote, estado, respuesta) |
| `erp_doc_fe_evento` | Cancelación, inutilización, conformidad, disconformidad, desconocimiento, notificación de recepción |
| `erp_doc_fe_log` | Cada intercambio (request/response) para auditoría y soporte |

Arquitectura de integración:

```
APEX / REST ──► erp_*_api.emitir ──► erp_doc_fe_documento (estado P, XML sin firmar)
                                                │  (cola)
                         job_erp_fe_enviar ─────┘
                                │
                     Conector de firma y envío  ◄── certificado .p12 (fuera de la BD)
                     (servicio Java/Node; o PL/SQL + wallet si la plataforma lo permite)
                                │ SOAP mTLS
                              SIFEN (siRecepDE / lotes / consultas / eventos)
                                │
                     respuesta ──► actualiza estado, CDC, mensajes ──► KuDE (PDF + QR)
```

- **La firma XML-DSig y el SOAP con certificado cliente se hacen en un conector externo**
  intercambiable. En PL/SQL puro la firma XML es frágil, y en Autonomous el uso de certificados
  cliente está limitado. La BD solo arma el documento, encola y guarda respuestas, así el núcleo
  es igual en OCI y on-premise.
- El documento comercial (factura) y el documento electrónico son entidades separadas: la factura
  existe aunque SIFEN esté caído (**contingencia**, tipo de emisión 2) y se reenvía después.
- Los documentos aprobados son **inmutables**; se corrigen con NCE/NDE o se cancelan por evento.

## 5. Inventario (`stk`) — fase 3

Producto (con categoría fiscal, unidad base, marca, tipo bien/servicio, maneja lote S/N),
unidad y conversión, presentación, código de barras, depósito (`erp_stk_deposito`, ya creado en la fase 1), movimiento
(cabecera + ítems, generado por el tipo de documento) y **`erp_stk_saldo`**
(empresa, depósito, producto, lote) actualizado en la misma transacción. Costo promedio
ponderado en moneda funcional **y de reporte** en `erp_stk_saldo` (idea de Dolphin: costo contable y gerencial).

## 6. Ventas y compras (`ven` / `com`) — fase 4

- Cliente / proveedor por empresa (sobre `erp_gen_persona`): condición de pago, límite de
  crédito por moneda, lista de precio, vendedor, cuenta contable.
- Lista de precio (moneda, incluye impuesto, vigencia) + precio por producto y presentación.
- Pedido → factura → nota de crédito/débito → remisión. Cada documento:
  cabecera (`empresa_id`, sucursal, punto, tipo, número, fecha, persona, moneda, cotización,
  condición, totales en moneda doc y funcional, estado), ítems, `_item_impuesto` (foto),
  `_impuesto` (resumen por tasa), vencimientos.
- Estados: `B` borrador · `E` emitido · `A` anulado. Un documento emitido no se modifica.

## 7. Finanzas (`fin`) — fase 5

- **`erp_fin_documento`**: toda cuenta a cobrar/pagar (de factura, nota, anticipo, préstamo) en su
  moneda, con **cuotas** (`erp_fin_documento_cuota`: vencimiento, importe, saldo).
- **`erp_fin_aplicacion`**: qué recibo/orden de pago/nota de crédito cancela qué cuota, con
  monto en ambas monedas y diferencia de cambio. Reemplaza los ~15 vínculos `FIN*` de SCV.
- Recibo, orden de pago, formas de pago (efectivo, cheque, transferencia, tarjeta), cheques
  emitidos (chequera) y recibidos, caja (apertura/cierre/arqueo), cuentas bancarias,
  retenciones (IVA/renta, comprobante de retención) e intereses por mora configurables.

## 8. Contabilidad (`cnt`) — fase 6

Plan de cuentas jerárquico por empresa (analítica/sintética, naturaleza, grupo
activo/pasivo/patrimonio/ingreso/egreso, controla diferencia de cambio), ejercicio, asiento
(cabecera + líneas débito/crédito en moneda funcional y opcional en moneda origen), centro de
costo, **reglas contables** (`tipo de documento + concepto → cuenta`, con overrides por
categoría de producto, cliente o sucursal) y **saldo contable por cuenta y período** mantenido.
Los módulos no escriben asientos: llaman `erp_cnt_asiento_api.generar(documento)`, que aplica las
reglas.

## 9. Escalabilidad y volumen

| Técnica | Detalle |
|---|---|
| Claves | Identity `cache 1000` en tablas transaccionales; `number` sin precisión. El número legal sale de `erp_doc_numerador`, nunca de una secuencia. |
| Saldos mantenidos | stock, cuotas, saldo contable por período: se actualizan en la transacción del documento. Las consultas de saldo no suman histórico. |
| Inmutabilidad | Documentos emitidos solo se anulan o se corrigen con otro documento; facilita auditoría, réplica y particionamiento. |
| Índices | Todo índice de búsqueda empieza por `empresa_id`; toda FK indexada. |
| Particionamiento | Opcional: `apps/erp/install/opcional/particionar.sql` (intervalo mensual por fecha del documento) para cabeceras, ítems, movimientos y asientos (`alter table … modify partition by … online`, 12.2+). En Autonomous está incluido; on-premise requiere **Enterprise Edition + opción Partitioning**. El modelo base no depende de él. |
| Procesos masivos | APIs que reciben colecciones (`erp_*_tab`), `forall`/`bulk collect`, jobs `job_erp_*` (facturación por lote, envío SIFEN, cierre). |
| Reportes | Vistas `_v` y, para tableros, tablas resumen o `_mv` refrescadas por job. |
| Seguridad por fila | Hoy: la API filtra por `APP_EMPRESA_ID`. VPD (`DBMS_RLS`, contexto `ctx_erp`) es opción futura (requiere Enterprise Edition on-premise). |

### 9.1 Validación contra las guías de Oracle

Revisado con las guías oficiales incluidas en `.claude/skills/oracle-db` (design, appdev, performance):

| Decisión | Guía Oracle | Resultado |
|---|---|---|
| Identity `by default on null`, `cache 1000` en transaccionales, nunca `nocache`; número legal en tabla de correlativos con `for update` | `appdev/sequences-identity.md`, `appdev/locking-concurrency.md` | Adoptado (ESTANDAR §1.3) |
| Particionamiento por intervalo mensual para tablas de solo inserción, índices locales | `design/partitioning-strategy.md` | Adoptado como opcional: requiere opción Partitioning (EE) on-premise |
| Índice único local exige la clave de partición | `design/partitioning-strategy.md` §6 | Las UK de número de documento (empresa + timbrado + número) serán **índices globales** o incluirán la fecha |
| Claves sustitutas, no naturales | `design/data-modeling.md` | Adoptado: PK identity; RUC, códigos ISO, etc. como UK |
| Aislamiento por tenant con VPD (`DBMS_RLS` + contexto) | `design/data-modeling.md`, `security/` | Futuro (EE on-premise); hoy filtro por `APP_EMPRESA_ID` en la API |
| Colas sin contención con `for update skip locked` | `appdev/locking-concurrency.md` | Para el envío SIFEN (`job_erp_fe_enviar`) en la fase 2 |
| Sin índices bitmap en OLTP | `design/data-modeling.md` | Solo B-tree |

## 10. Errores del ERP

Rango −20100 … −20299 (ESTANDAR §4.2), por módulo:

| Módulo | Rango |
|---|---|
| gen | −20100 … −20129 (en uso: −20100 … −20111) |
| doc | −20130 … −20159 |
| stk | −20160 … −20179 |
| ven | −20180 … −20199 |
| com | −20200 … −20219 |
| fin | −20220 … −20259 |
| cnt | −20260 … −20289 |
| reservado | −20290 … −20299 |

## 11. Plan de fases

| Fase | Módulo | Rama | Estado |
|---|---|---|---|
| 1 | `gen` + estructura organizativa + depósito + app 200 | `feature/erp-gen` | en curso |
| 2 | `doc` + SIFEN (modelo y cola; conector aparte) | `feature/erp-doc` | pendiente |
| 3 | `stk` | `feature/erp-stk` | pendiente |
| 4 | `ven` / `com` | `feature/erp-ven`, `feature/erp-com` | pendiente |
| 5 | `fin` | `feature/erp-fin` | pendiente |
| 6 | `cnt` | `feature/erp-cnt` | pendiente |
