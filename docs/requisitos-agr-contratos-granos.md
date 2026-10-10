# Requisitos: contratos de granos (app vertical AGR, ID 260)

> Estado: **borrador para validar con el dueño** (ver §6). Encaja en `docs/arquitectura-erp.md`
> (app vertical 260+, funcionalidades `SAFRA` y `PESAJE`, rubro `AGRO`). Usa el núcleo: personas,
> monedas, cotizaciones, depósitos, documentos, finanzas y contabilidad (`erp_*`).

Código de app propuesto: `agr`. Módulos: `ctr` contratos · `rcp` recepción/báscula · `cal` calidad · `gen` safra y parámetros del grano.

## 1. Principio de diseño: todo es una fijación

El mercado (precio) y el tipo de cambio cambian. Las fijaciones pueden ser **parciales, repetidas y en cualquier orden**: precio → cambio → precio → cambio…, o al revés.

- El contrato **no** tiene columnas de precio ni de cambio. Tiene **N componentes** (bolsa/CBOT, premio/base, flete, gastos, comisión, tipo de cambio, rollover, bonificaciones…), definidos por **tipo de contrato** como datos.
- Cada componente acumula **M fijaciones** con su cantidad, valor, unidad, moneda, referencia de mercado, fecha, hora y usuario. Las fijaciones son inmutables: se anulan con motivo.
- Cada componente tiene su propio **saldo por fijar**, independiente de los demás.
- Un caso nuevo (fijar el flete aparte, un precio único todo incluido, un precio en PYG/kg sin cambio) es un **dato**, no un cambio de estructura.
- El precio fijo es un caso particular: todo se fija al firmar, por el 100 %.

## 2. Glosario

| Término | Definición |
|---|---|
| Contrato de compra / venta | Compra al productor (persona con rol PRODUCTOR) o venta a exportador/industria; mismo modelo con `operacion` C/V |
| Componente de precio | Parte del precio final: bolsa (¢/bu), premio o base (± USD/t), flete, gastos, comisión, bonificaciones; el tipo de cambio es un componente de naturaleza "cambio" |
| A fijar | Componente abierto con fecha límite y posición de mercado (ej. SX26) |
| Orden de fijación | Instrucción condicionada ("fijar 200 t si CBOT llega a 1.080 ¢/bu, válida hasta…"); al ejecutarse genera una fijación |
| Rollover | Pasa el saldo no fijado de bolsa de una posición a otra; el spread se registra como fijación del componente ROLL |
| Cancelación / renegociación / transferencia | Reduce toneladas, o pasa saldo a otro contrato o productor, con trazabilidad |
| Entrega / aplicación | Recepción en báscula con análisis de calidad; los kilos comerciales se aplican a uno o varios contratos |
| Descuentos de calidad | Merma por humedad ((H − Hbase)/(100 − Hbase)) + manipuleo; impurezas, dañados, quebrados, verdes por tabla de rangos con vigencia; bonificaciones; secado como servicio |
| Liquidación | Provisoria (estimada o % de anticipo), final o de ajuste (nota de crédito/débito) |
| Anticipo / financiación / canje | Dinero o insumos antes de la cosecha, compensados al liquidar |
| Certificado de depósito / warrant | Grano en depósito, todavía del productor, que respalda un título |

## 3. Requisitos funcionales (RF) y reglas (RN)

**Requisitos funcionales**
- **RF-01** Contrato: tipo, contraparte, corredor y comisión, grano y variedad, safra, toneladas y tolerancia ±%, condición de entrega (silo, a retirar, FAS, FOB, CIF), base de peso (salida/llegada), depósito, moneda del precio y moneda de liquidación, condición de pago, tabla de calidad, fechas, número externo.
- **RF-02** Tipos de contrato con componentes configurables: obligatorio, fijo o a fijar, valor por defecto, unidad, moneda, días límite. Se copian al contrato.
- **RF-03** Fijaciones de cualquier componente, parciales y en cualquier orden, con referencia de mercado y cotización del momento.
- **RF-04** Conversión de unidades ¢/bu ↔ USD/t (factor bushel/tonelada por grano), USD/qq, PYG/kg.
- **RF-05** Órdenes de fijación; ejecución total o parcial.
- **RF-06** Anulación de fijación con motivo, como registro nuevo; solo si no se consumió en una liquidación final.
- **RF-07** Rollover individual y masivo, con spread por tonelada.
- **RF-08** Cancelación, ampliación, renegociación y transferencia.
- **RF-09** Plan de entregas por período.
- **RF-10** Báscula: pesaje, análisis por rubro, descuentos según la tabla vigente (foto guardada), transporte (chofer, chapa, transportista), remisión.
- **RF-11** Aplicar o desaplicar recepciones a contratos, mientras no haya liquidación final.
- **RF-12** Liquidación provisoria, final y de ajuste, con vista previa de tramos, impuestos, retenciones, anticipos, documento fiscal y cuenta a pagar/cobrar.
- **RF-13** Anticipos y financiaciones (dinero, insumos, canje) y su compensación.
- **RF-14** Ficha del contrato con saldos por componente (fijado, por fijar, fijado sin liquidar) y por cantidad (aplicada, liquidada, cancelada).
- **RF-15** Tablero de posición por grano, safra y posición, y exposición en USD sin cambio fijado.
- **RF-16** Historial de eventos del contrato (JSON).
- **RF-17** Alertas: fijaciones por vencer, entregas atrasadas, tolerancia excedida.
- **RF-18** Valores de mercado diarios por posición (manual o API) y valorización a mercado.

**Reglas de negocio**
- **RN-01** Por componente: Σ fijaciones vigentes ≤ toneladas × (1 + tolerancia) − canceladas. Se controla bloqueando el componente con `for update`.
- **RN-02** Los saldos por fijar de cada componente son independientes.
- **RN-03** Las fijaciones son inmutables (solo anulación con motivo) y guardan fecha, hora, usuario y referencias.
- **RN-04** No se fija después de la fecha límite sin prórroga o permiso.
- **RN-05** El componente de cambio existe solo si la moneda del precio es distinta de la de liquidación. Si no está fijado al liquidar, se aplica la política del tipo de contrato: `B` bloquear, `D` cotización del día, `P` liquidación provisoria.
- **RN-06** La liquidación final requiere los componentes obligatorios fijados para la cantidad liquidada.
- **RN-07** Liquidado ≤ aplicado ≤ contrato × (1 + tolerancia), salvo ampliación.
- **RN-08** Cada fijación se consume una sola vez, en orden FIFO por fecha, salvo asignación manual.
- **RN-09** Cancelar toneladas ya fijadas exige anular fijaciones o liquidar la diferencia contra el mercado.
- **RN-10** Una recepción sin contrato queda en depósito (stock de terceros). La aplicación a un contrato de compra transfiere la propiedad.
- **RN-11** Los descuentos de calidad se calculan con la tabla vigente a la fecha del análisis y se guardan como foto.
- **RN-12** Período abierto (módulo AGR) y filtro por empresa activa.
- **RN-13** Impuestos y retenciones desde el motor del núcleo (categoría fiscal del grano; retención tipo R con mínimo), nunca fijos en código.
- **RN-14** Autofactura si el productor no es contribuyente; si lo es, su factura con CDC o timbrado validado; factura electrónica en ventas.
- **RN-15** El contrato pasa a cumplido automáticamente dentro de la tolerancia.
- **RN-16** Estados `B` borrador → `V` vigente → `C` cumplido; `X` cancelado; `A` anulado solo sin fijaciones, aplicaciones ni liquidaciones.

## 4. Modelo de tablas (borrador)

Todas llevan auditoría estándar y `empresa_id`. PK identity (cache 1000 en las transaccionales). Importes `number(18,2)`, toneladas `number(18,4)`, valores unitarios y tasas `number(18,6)`.

| Tabla | Propósito |
|---|---|
| `agr_gen_safra` | Ciclo agrícola (o la safra del núcleo si se generaliza) |
| `agr_gen_grano` | Extensión del producto: bushel por tonelada, humedad base, tabla de calidad |
| `agr_gen_posicion` / `agr_gen_posicion_valor` | Posiciones de mercado (CBOT, B3, MATBA…) y su valor diario |
| `agr_ctr_tipo_componente` | Catálogo de componentes: naturaleza (P valor por unidad / C cambio / R porcentaje), signo, unidad, requiere posición, orden de cálculo |
| `agr_ctr_tipo_contrato` / `agr_ctr_tipo_contrato_comp` | Tipo de contrato (operación, política de cambio, método de tramos FIFO o promedio, tipo de documento) y sus componentes |
| `agr_cal_rubro`, `agr_cal_tabla`, `agr_cal_tabla_rango` | Calidad: rubros, tablas con vigencia y rangos de descuento, bonificación, merma y servicio |
| `agr_ctr_contrato` | Cabecera con saldos mantenidos (aplicado, liquidado, cancelado) |
| `agr_ctr_contrato_comp` | Componentes del contrato, con modo, posición actual, fecha límite y saldos (fijado, consumido) |
| `agr_ctr_orden_fijacion` | Órdenes de fijación |
| `agr_ctr_fijacion` | Fijación inmutable: cantidad, valor, unidad, valor normalizado por tonelada, moneda, posición, valor de mercado, cotización de referencia, origen (manual, orden, rollover, renegociación, firma), anulación, estado |
| `agr_ctr_movimiento` | Cancelación, ampliación, renegociación, transferencia, rollover, prórroga |
| `agr_ctr_entrega_plan` | Plan de entregas |
| `agr_ctr_evento` | Historial funcional del contrato (JSON) |
| `agr_rcp_recepcion` / `agr_rcp_analisis` | Ticket de báscula y foto del análisis por rubro |
| `agr_ctr_aplicacion` | Recepción → contrato |
| `agr_ctr_liquidacion` / `agr_ctr_liquidacion_tramo` / `agr_ctr_liquidacion_imp` | Liquidación, tramos valorizados y foto de impuestos |
| `agr_ctr_fijacion_consumo` | Qué fijación pagó qué tramo (RN-08) |
| `agr_ctr_financiacion` | Anticipos, insumos y canje |

## 5. Cálculo del valor liquidable (tramos)

1. **Cantidad liquidable** Q = neto de báscula − descuentos + bonificaciones.
2. Por cada componente se consumen fijaciones FIFO hasta cubrir Q. Se unen los cortes de todos los componentes y quedan **tramos**, cada uno con un único valor por componente.
3. Precio del tramo Pₛ = Σ signo × valor por tonelada.
4. Importe = Σ qₛ × Pₛ × TCₛ.
5. Luego se suman impuestos y se restan retenciones, servicios, comisión y anticipos.
6. Método alternativo: promedio ponderado.

**Ejemplo.** Contrato de 1.000 t de soja: precio = CBOT + premio − flete − gastos. Premio −45, flete −28 y gastos −7 USD/t están fijados al firmar.

Fijaciones en el orden en que ocurrieron:
1. CBOT: 300 t a 1.050 ¢/bu (385,81 USD/t).
2. Cambio: 400 t a 7.300.
3. CBOT: 500 t a 1.000 ¢/bu (367,44 USD/t).
4. Cambio: 300 t a 7.250.

Entrega: 625.000 kg netos − 25.000 kg de descuentos = 600 t.

| Tramo | t | Precio USD/t | USD | TC | PYG |
|---|---|---|---|---|---|
| 1 | 300 | 305,81 | 91.743,00 | 7.300 | 669.723.900 |
| 2 | 100 | 287,44 | 28.744,00 | 7.300 | 209.831.200 |
| 3 | 200 | 287,44 | 57.488,00 | 7.250 | 416.788.000 |
| **Total** | **600** | | **177.975,00** | | **1.296.343.100** |

Saldos que quedan:
- CBOT: 200 t fijadas sin liquidar y 200 t por fijar.
- Cambio: 100 t fijadas sin liquidar y 300 t por fijar.

## 6. Preguntas abiertas para validar

1. ¿La fijación de cambio se expresa en toneladas o en monto USD?
2. ¿Cruce precio × cambio por tramos FIFO o promedio ponderado? ¿Se admite asignación manual?
3. Sin cambio fijado al liquidar: ¿bloquear, cotización del día (¿cuál? ¿compra o venta?) o provisoria?
4. ¿Premio y base en ¢/bu o USD/t? ¿Precio FAS calculado desde FOB o pactado directo?
5. Rollover: ¿quién paga el spread y dónde se registra?
6. Liquidaciones provisorias: ¿qué % y cómo se ajustan?
7. Cancelación de toneladas fijadas: ¿washout, multa o anulación sin costo?
8. ¿Certificados de depósito o warrants? ¿Tarifa de almacenaje?
9. Retenciones de IVA y renta por tipo de productor y casos de autofactura (validar con el contador).
10. ¿Canje de insumos por granos con compensación automática?
11. ¿Registrar coberturas en bolsa (futuros u opciones) o solo la posición física?
12. Cotización CBOT: ¿API automática o carga manual?
13. Rango de errores AGR −20400…−20499 y registro de abreviaturas en `apps/agr/database/ABREVIATURAS.md`.
