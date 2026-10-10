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
| O8 | **Nativo primero** | Todo se resuelve con Oracle Database (hasta 26ai) y APEX. Solo lo que de verdad no se pueda hacer nativo queda para una API externa futura, documentada como tal. |
| O9 | **Historial de cambios** | Quién cambió qué y cuándo, con valores antes/después en JSON, para maestros y configuración (§9.2). |

### Principios de modelado

- Reglas paraguayas como especificación funcional: SET/DNIT, RUC, timbrado, registro de comprobantes, retenciones.
- Nada fijo en columnas (montos por tasa, cuentas contables): todo por configuración.
- Claves sustitutas con precisión suficiente; datos principales de un documento como columnas de su cabecera (no tablas satélite 1:1).

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
| `erp_gen_rubro_func` | rufu | Funcionalidades que activa cada rubro |
| `erp_gen_empresa_func` | emfu | Funcionalidades activas de cada empresa |
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

- El **departamento** es una dimensión de análisis opcional: documentos, stock
  y finanzas podrán llevar `departamento_id` para reportes por unidad de negocio.
- Si un usuario no tiene filas en `erp_gen_usuario_sucursal`, opera todas las sucursales de la
  empresa, salvo que el parámetro `ERP_GEN_ACCESO_SUCURSAL_ESTRICTO = 'S'`.

### 3.5 Adaptación a cualquier rubro

Nada de tablas por cliente ni triggers por cliente. La adaptación es por **datos**:

1. **Funcionalidades** (`erp_gen_funcionalidad`): interruptores por empresa que muestran u
   ocultan campos, pantallas y validaciones (ej. `LOTE`, `VENCIMIENTO`, `SERIE`, `SAFRA`,
   `VENDEDOR`, `CENTRO_COSTO`, `DEPARTAMENTO`, `CONSIGNACION`).
   En APEX: condición `erp_gen_funcionalidad_api.es_activa_sn('LOTE', :APP_EMPRESA_ID) = 'S'`.
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
| `erp_doc_tipo_documento` | Códigos fiscales como datos (`codigo_sifen`, `codigo_registro_fiscal` del registro mensual de comprobantes), `max_items` (preimpresos), exige vendedor / RUC / documento de origen. Comportamiento: `signo_stock` (+1/−1/0), `signo_cuenta` (D/C/N), `es_legal`, `tipo_emision` (E electrónico / P preimpreso / I interno), `codigo_sifen` (1 FE, 4 AFE, 5 NCE, 6 NDE, 7 NRE), `requiere_documento_origen`, `regla_contable` |
| `erp_doc_timbrado` | Timbrado (número, vigencia desde/hasta, electrónico o preimpreso) por empresa |
| `erp_doc_numerador` | Correlativo por empresa + timbrado + establecimiento + punto + tipo de documento, con `numero_desde`/`numero_hasta`/`numero_actual` (rango obligatorio en preimpreso y autoimpresor), avisos por días al vencimiento y % de rango usado, y usuarios autorizados. Se toma con `select … for update` **en la misma transacción** del documento (nunca en transacción autónoma: quemaría números) |
| `erp_doc_numero_inutilizado` | Números anulados, inutilizados o extraviados (papel) y rangos inutilizados (evento SIFEN), con motivo obligatorio; salen en el registro mensual de comprobantes |

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
                     erp_doc_fe_firma / envío nativos  ◄── certificado en wallet / almacén seguro
                     (API externa solo si la plataforma no permite algún paso)
                                │ SOAP mTLS
                              SIFEN (siRecepDE / lotes / consultas / eventos)
                                │
                     respuesta ──► actualiza estado, CDC, mensajes ──► KuDE (PDF + QR)
```

- **Nativo primero (O8)**: armado del XML, validación, CDC, QR, cola, envío SOAP con TLS mutuo, eventos y KuDE se
  implementan en Oracle + APEX. La firma XML-DSig se resuelve con las capacidades nativas de
  cada versión (detalle en el diseño de la fase 2); si alguna plataforma no lo permite, ese único
  paso queda como API externa futura, con el resto del flujo igual.
- El documento comercial (factura) y el documento electrónico son entidades separadas: la factura
  existe aunque SIFEN esté caído (**contingencia**, tipo de emisión 2) y se reenvía después.
- Los documentos aprobados son **inmutables**; se corrigen con NCE/NDE o se cancelan por evento.
- La regla de inmutabilidad vive en la **API de anulación** de cada módulo (y en las anulaciones en cascada), nunca solo en pantallas: si el documento tiene un DE aprobado, se exige el evento de cancelación dentro del plazo parametrizado.
- `erp_doc_fe_documento`: **UK sobre `cdc`** y **UK sobre (documento de origen, tipo)**: un solo DE por documento comercial. Origen genérico (`origen_modulo`, `origen_id`): facturas, notas, remisiones y movimientos de stock.
- Estado de envío separado del estado SIFEN: envío (pendiente, en lote, enviado, sin respuesta, error técnico) y resultado (aprobado, aprobado con observación, rechazado, cancelado, inutilizado) más estados del receptor (notificado, conforme, parcialmente conforme, disconforme, desconocido) y nominación.
- Respuestas de la DNIT **estructuradas** (`codigo_respuesta`, `mensaje`) y catálogo de códigos con "cómo resolver"; nunca interpretar textos.
- Cola con `select … for update skip locked`, lotes de hasta 50 DE, reintentos con espera creciente (`intentos`, `proximo_intento`), fallback de consulta de lote a consulta por CDC, control de las 72 h desde la firma y de las 48 h de consulta de lote.
- Código de seguridad del CDC **aleatorio** (no derivado de datos del documento).
- Contingencia (`tipo_emision = 2`): emitir, imprimir KuDE y regularizar dentro del plazo.
- KuDE en formatos A4, A5 y cinta; envío por correo al receptor con reintentos.
- **Compras**: todo comprobante de proveedor guarda timbrado + número o CDC, validados (vigencia del timbrado a la fecha de emisión, unicidad por proveedor + número); servicio de consulta RUC / timbrado / CDC ante la DNIT con resultados en caché y padrón de RUC cargado por job.

## 5. Inventario (`stk`) — fase 3

Producto (con categoría fiscal, unidad base, marca, tipo bien/servicio, maneja lote S/N),
unidad y conversión, presentación, código de barras, depósito (`erp_stk_deposito`, ya creado en la fase 1), movimiento
(cabecera + ítems, generado por el tipo de documento) y **`erp_stk_saldo`**
(empresa, depósito, producto, lote) actualizado en la misma transacción. Costo promedio
ponderado en moneda funcional **y de reporte** en `erp_stk_saldo` (costo contable y gerencial). Saldo **actual** mantenido
en la transacción y movimientos con costo unitario guardado; el costo histórico, si se necesita, sale de un cierre mensual
(`erp_stk_saldo_periodo`). No se admiten movimientos con fecha anterior a un período cerrado (evita reprocesos).

## 6. Ventas y compras (`ven` / `com`) — fase 4

- Cliente / proveedor por empresa (sobre `erp_gen_persona`): condición de pago, límite de
  crédito por moneda, lista de precio, vendedor, cuenta contable.
- Lista de precio (moneda, incluye impuesto, vigencia) + precio por producto y presentación.
- Pedido → factura → nota de crédito/débito → remisión. Cada documento:
  cabecera (`empresa_id`, sucursal, punto, tipo, número, fecha, persona, moneda, cotización,
  condición, totales en moneda doc y funcional, estado), ítems, `_item_impuesto` (foto),
  `_impuesto` (resumen por tasa), vencimientos.
- Estados: `B` borrador · `E` emitido · `A` anulado. Un documento emitido no se modifica.
- Persona, moneda, cotización funcional y de reporte, condición, timbrado y punto son **columnas de la cabecera** (sin tablas satélite 1:1).
- Pedido: cantidad pendiente por ítem (facturación parcial), plan de vencimientos, motivo de cancelación, descuentos autorizados con usuario y límite.
- Línea de crédito por cliente con vigencia y monto por moneda.
- Maestro-detalle en APEX: colección de APEX con **vista tipada** sobre ella (nombre de colección provisto por la API) antes de grabar.

## 7. Finanzas (`fin`) — fase 5

- **`erp_fin_documento`**: toda cuenta a cobrar/pagar (de factura, nota, anticipo, préstamo) en su
  moneda, con **cuotas** (`erp_fin_documento_cuota`: vencimiento, importe, saldo).
- **`erp_fin_aplicacion`**: qué recibo/orden de pago/nota de crédito cancela qué cuota, con
  monto en ambas monedas y diferencia de cambio, sin tablas de vínculo por cada combinación.
- Recibo, orden de pago, formas de pago (efectivo, cheque, transferencia, tarjeta), cheques
  emitidos (chequera) y recibidos, caja (apertura/cierre/arqueo), cuentas bancarias,
  retenciones (IVA/renta, comprobante de retención) e intereses por mora configurables.
- **Operaciones financieras con signo** (pago, descuento, interés, retención, diferencia de cambio) aplicadas sobre la cuota;
  saldo de la cuota mantenido en la transacción (no vistas materializadas on commit).
- Interés por mora en la cuota (tipo, tasa mensual, desde antes o después del vencimiento); días hábiles con `erp_gen_feriado`.
- Retenciones como `erp_gen_impuesto` de tipo R: tasa con vigencia y **monto mínimo** (`erp_gen_impuesto_tasa_vig.monto_minimo`),
  base sobre la foto de impuestos del documento, excepciones por persona, comprobante de retención (emitido o recibido) con
  respuesta de la DNIT; la retención recibida es un medio de cobro.
- Aprobación de órdenes de pago por niveles; descuento de cheques y documentos.

## 8. Contabilidad (`cnt`) — fase 6

Plan de cuentas jerárquico por empresa (analítica/sintética, naturaleza, grupo
activo/pasivo/patrimonio/ingreso/egreso, controla diferencia de cambio), ejercicio, asiento
(cabecera + líneas débito/crédito en moneda funcional y opcional en moneda origen), centro de
costo, **reglas contables** (`tipo de documento + concepto → cuenta`, con overrides por
categoría de producto, cliente o sucursal) y **saldo contable por cuenta y período** mantenido.
Los módulos no escriben asientos: llaman `erp_cnt_asiento_api.generar(documento)`, que aplica las
reglas.
- Asiento con origen genérico (`origen_modulo`, `origen_id`) y líneas D/C simples (una cuenta por línea).
- Si una regla falla, el documento no se pierde: queda en `erp_cnt_asiento_pendiente` para reprocesar.
- Plan de cuentas con clasificación corto/largo plazo y cuentas que controlan diferencia de cambio (revalúo solo en esas).
- Ninguna cuenta contable fija en columnas: IVA débito/crédito por tasa, retenciones, redondeo, diferencia de cambio e intereses salen de reglas por concepto.
- Libros legales (compras, ventas, diario, mayor, balance) como funciones o vistas parametrizadas por empresa, período y moneda.

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

### 9.2 Historial de cambios

| Opción | Uso en ENFE |
|---|---|
| **Tabla genérica con JSON + trigger compound generado por tabla** | **Elegida** para el historial funcional: igual en ADB, SE2 y EE; captura todo DML (también fuera de la capa `ctr`); muestra "qué columna cambió". |
| Flashback Time Travel (FDA) | Complemento opcional de recuperación (gratis sin compresión); no como historial funcional (en ADB la retención es global y requiere ADMIN). |
| Unified Auditing | Solo auditoría de seguridad (accesos, DDL, privilegios); no guarda valores por columna. |
| Tabla inmutable (19.11+) | Opción para que el historial no se pueda borrar ni modificar; congela la estructura de la tabla. |

- Tabla **`adm_aud_cambio`** (en ADM, transversal a todas las apps): app, tabla, `registro_id`, `registro_padre_id`, `empresa_id`,
  operación (I/U/D), `cambios` (JSON: arreglo `[{"col":…,"antes":…,"despues":…}]`, solo columnas cambiadas; en D la fila completa),
  usuario, fecha, app/página/sesión APEX, id de transacción y módulo. CLOB con `is json` en 19c; tipo `JSON` cuando el mínimo sea 21c+.
- Generador `adm_aud_cambio_utl` que produce el trigger `trg_<app>_<abrev>_aiud` (compound, inserción por lote) por cada tabla
  auditada. Excluye columnas de auditoría, LOB y columnas sensibles (contraseñas, hashes, tokens: solo registra "cambió").
  **No autónomo**: si la transacción se deshace, el historial también.
- Se auditan maestros y configuración (empresa, sucursal, punto, depósito, monedas, impuestos, personas, roles, rubros,
  parámetros, períodos) y la seguridad de ADM. Los documentos transaccionales no: son inmutables y sus cambios de estado se
  registran como eventos desde la API.
- En APEX: región **Historial** (timeline + detalle Campo / Antes / Después) en cada formulario de edición, y pantalla de
  historial con filtros en ADM. Retención por parámetro y purga mensual por job; particionamiento mensual opcional.

## 10. Errores del ERP

Rango −20100 … −20299 (ESTANDAR §4.2), por módulo:

| Módulo | Rango |
|---|---|
| gen | −20100 … −20129 (en uso: −20100 … −20113; −20112 = empresa sin acceso, página 95) |
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
