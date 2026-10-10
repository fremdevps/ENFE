# Requisitos: traslados de stock (módulo `stk`, app 210)

> Estado: **borrador para validar con el dueño** (ver §7). Encaja en `docs/arquitectura-erp.md` §5.
> Los códigos de la nota de remisión están verificados contra el Manual Técnico SIFEN v150 (pág. 79).

## 1. Principio: el traslado es un solo documento

La mercadería no "se teletransporta": sale del depósito de origen, queda **en tránsito** y entra al destino cuando el destino la recibe.

- El **traslado** es una entidad propia, con un estado único y su historial.
- Cada transición genera **un** movimiento de stock con dos líneas por ítem:
  - al despachar: −origen, +tránsito;
  - al recibir: −tránsito, +destino.
- Son dos movimientos por traslado (uno si es interno de un paso), nunca cuatro documentos encadenados.
- Origen y destino se leen siempre en la cabecera del traslado, sin inversiones.
- El depósito de tránsito es el de tipo `T` de la sucursal de origen (`erp_stk_deposito`). El origen es dueño de la mercadería hasta la recepción.

Qué evitamos:
- una cabecera única de más de cien columnas para todos los tipos de documento;
- estados en banderas sueltas sin catálogo;
- recepción todo o nada, sin registrar faltantes;
- conductor y vehículo duplicados en código y en texto libre;
- lotes como texto.

## 2. Requisitos funcionales

- **RF-01 Solicitud.** Borrador con origen, destino, motivo, fecha requerida e ítems. La inicia el origen (envío) o el destino (pedido de reposición).
- **RF-02 Aprobación.** Opcional por parámetro. Aprobar reserva el stock; rechazar exige motivo.
- **RF-03 Despacho.** Confirma cantidades despachadas (≤ aprobadas), lotes, series y transporte. Genera el movimiento origen → tránsito y, si corresponde, la nota de remisión.
- **RF-04 Despacho parcial.** Lo no despachado se cancela o pasa a un traslado hijo.
- **RF-05 Consulta de tránsito.** Qué hay en tránsito, desde cuándo, hacia dónde, con qué remisión y con qué atraso.
- **RF-06 Recepción.** Total o parcial, en una o varias recepciones. Por ítem: recibido conforme, dañado, faltante, sobrante.
- **RF-07 Diferencias.** Cada faltante se cierra como pérdida (con responsable), devolución a origen o recepción posterior. El sobrante requiere un despacho complementario.
- **RF-08 Rechazo y devolución.** El destino rechaza todo o parte; vuelve por un traslado de devolución enlazado.
- **RF-09 Anulación.** Antes del despacho libera la reserva. En tránsito revierte y cancela la remisión. Con recepciones registradas no se anula: se devuelve.
- **RF-10 Tiempos.** Salida y llegada estimadas y reales; horas estimadas sugeridas por ruta (par de sucursales); demora; alerta de tránsitos vencidos.
- **RF-11 Ubicaciones** (funcionalidad activable). Ubicación de retiro en origen y de guardado en destino.
- **RF-12 Lotes, series y vencimientos.** Se conservan en el traslado; sugerencia de despacho por vencimiento más próximo.
- **RF-13 Flete** (funcionalidad `FLETE`). Costo de flete y capitalización opcional en destino.
- **RF-14 Trazabilidad.** Línea de tiempo de eventos, movimientos, remisión y traslados relacionados.
- **RF-15 Impresión.** Orden de picking, KuDE de la remisión, acta de recepción con diferencias.

## 3. Reglas de negocio

- **RN-01** Origen ≠ destino; misma empresa (salvo destino tercero); depósitos activos; ninguno de tipo tránsito.
- **RN-02 Tipo de traslado:**
  - `I` interno: misma sucursal y dirección; sin remisión; puede ser de un paso.
  - `R` con remisión: entre sucursales o direcciones distintas; siempre dos pasos; motivo 7 "traslado entre locales de la empresa" (el RUC del receptor es el del emisor).
  - `T` a terceros: consignación (2), transformación (8), reparación (9), exhibición (11), ferias (12).
- **RN-03** No se despacha más que el disponible (saldo − reservado) si el depósito controla stock.
- **RN-04** El stock en tránsito no se vende ni se reserva, pero suma al inventario valorizado.
- **RN-05** Saldo del depósito de tránsito = suma de pendientes de los traslados abiertos (invariante verificable).
- **RN-06** Recibido + dañado + faltante resuelto ≤ despachado.
- **RN-07** El traslado no cambia el costo: entra a tránsito y a destino al costo con que salió, en moneda funcional y de reporte.
- **RN-08** El flete capitalizable se suma al costo de entrada en destino, prorrateado; si no, es gasto.
- **RN-09** Con tipo `R` o `T` no hay despacho sin remisión generada ni sin datos mínimos de transporte.
- **RN-10** Fin estimado ≥ inicio estimado ≥ emisión; recepción real ≥ despacho real.
- **RN-11** Cada transición valida el período `stk` abierto en la fecha del movimiento.
- **RN-12** Crear y despachar exige acceso al origen; recibir, al destino. Opcional: quien despacha no recibe.
- **RN-13** Producto con lote o serie: obligatorio al despachar; no se despachan lotes vencidos, salvo devolución o baja.
- **RN-14** Lo dañado entra a cuarentena, no disponible.
- **RN-15** Un traslado tiene como máximo una remisión vigente.
- **RN-16** Un traslado despachado es inmutable; las correcciones van por eventos.
- **RN-17** Solo la capa `ctr` de movimientos toca el saldo, en la misma transacción y con bloqueo ordenado de filas.
- **RN-18** Numeración interna por empresa y sucursal de origen, independiente del número fiscal.

## 4. Modelo de tablas (borrador)

| Tabla | Propósito |
|---|---|
| `erp_stk_producto`, `erp_stk_lote` | Producto (lote, serie, vencimiento, peso) y lotes |
| `erp_stk_ubicacion` | Ubicaciones dentro del depósito: almacenaje, recepción, despacho, cuarentena (activable) |
| `erp_stk_tipo_movimiento` | Catálogo: despacho, recepción, reverso y pérdida de traslado, ajuste… |
| `erp_stk_movimiento` / `erp_stk_movimiento_item` | Un movimiento por evento, líneas con signo, costo unitario funcional y de reporte, origen genérico (módulo, tabla, id) |
| `erp_stk_saldo` | Saldo y reservado por depósito, producto, lote y ubicación; costo promedio funcional y de reporte |
| `erp_stk_motivo_traslado` | Motivos con su código SIFEN y tipo de traslado aplicable |
| `erp_stk_ruta_traslado` | Kilómetros y horas estimadas por par de sucursales |
| `erp_stk_traslado` | Cabecera: tipo, motivo, depósitos de origen, tránsito y destino, fechas estimadas y reales, transporte, datos fiscales, flete, usuarios, estado |
| `erp_stk_traslado_item` | Cantidades solicitada, aprobada, despachada, recibida, dañada, faltante y devuelta; costo al despachar |
| `erp_stk_traslado_recep` / `erp_stk_traslado_recep_det` | Recepciones y su detalle, con el tipo de resolución de cada diferencia |
| `erp_stk_traslado_evento` | Historial inmutable de transiciones (JSON) |
| `erp_stk_usuario_deposito` | Restricción fina: quién despacha y quién recibe en cada depósito (opcional) |

La nota de remisión no es otra tabla de negocio: es un documento electrónico cuyo origen es el traslado. La cabecera aporta lo que exige: motivo, responsable de la emisión, kilómetros, transporte, fechas y direcciones.

## 5. Estados

```
B Borrador → S Solicitado → P Aprobado → T En tránsito → C Completado
                 │ rechazar → X             ├ recepción parcial → R → C
   anular → A (antes del despacho)          ├ con diferencias → D → resolver → C
                                            └ anular sin recepciones → A (revierte)
```

| Transición | Efecto en stock |
|---|---|
| Aprobar | Reserva en origen |
| Anular o rechazar antes del despacho | Libera la reserva |
| Despachar | −origen, +tránsito, al costo de origen |
| Recibir | −tránsito, +destino (lo dañado va a cuarentena) |
| Faltante como pérdida | −tránsito, con asiento de pérdida |
| Faltante como devolución | −tránsito, +origen |
| Anular en tránsito | Reverso total y cancelación de la remisión |

**Ejemplo.** Producto con costo 10.000; saldos iniciales: origen 300, destino 40.

| Paso | Origen | Reservado | Tránsito | Destino |
|---|---|---|---|---|
| Aprobar 100 | 300 | 100 | 0 | 40 |
| Despachar 100 | 200 | 0 | 100 | 40 |
| Recibir 95, faltan 5 | 200 | 0 | 5 | 135 |
| Resolver 5 como pérdida | 200 | 0 | 0 | 135 |

El costo no cambia en ningún paso. La pérdida es de 50.000.

## 6. Casos de prueba

| CP | Verifica | Esperado |
|---|---|---|
| CP-01 | Origen = destino | Error |
| CP-02 | Destino de tipo tránsito | Rechazado |
| CP-03 | Aprobar 100 con 80 disponibles | Error por stock insuficiente |
| CP-04 | Aprobar 100 con 300 | Reservado = 100, saldo sin cambio |
| CP-05 | Despachar | 1 movimiento, 2 líneas por ítem, suma con signo = 0 |
| CP-06 | Despachar con remisión sin chapa o conductor | Error de datos de transporte |
| CP-07 | Despachar con remisión | 1 documento electrónico; un segundo intento falla |
| CP-08 | Interno de un paso | 1 movimiento, sin tránsito ni remisión |
| CP-09 | Recibir 60 y luego 40 | Parcial y luego completado; tránsito 0 |
| CP-10 | Recibir 95 con 5 faltantes | Con diferencias; al resolver, completado |
| CP-11 | Recibir 101 de 100 | Error |
| CP-12 | Recibir 90 y 10 dañados | 90 disponibles, 10 en cuarentena |
| CP-13 | Usuario sin acceso al destino recibe | Error de permiso |
| CP-14 | Mismo usuario despacha y recibe (segregación activa) | Bloqueado |
| CP-15 | Recepción en período cerrado | Error de período |
| CP-16 | Anular en tránsito | Saldos iniciales restaurados |
| CP-17 | Anular con recepción | Rechazado; se ofrece devolución |
| CP-18 | Costo | Igual en despacho y recepción; el promedio de origen no cambia |
| CP-19 | Flete capitalizable | Costo de entrada = costo + prorrateo |
| CP-20 | Lote obligatorio | Sin lote falla; el destino recibe el mismo lote |
| CP-21 | Invariante de tránsito | Saldo de tránsito = pendientes de traslados abiertos |
| CP-22 | Venta desde depósito de tránsito | Rechazada |
| CP-23 | Editar ítems en tránsito | Rechazado |
| CP-24 | Tránsito vencido | Aparece con horas de atraso |
| CP-25 | Dos despachos concurrentes | Ninguno deja saldo negativo |
| CP-26 | Cada transición | Una fila de evento con usuario y estados |
| CP-27 | Rechazo total en destino | Traslado de devolución enlazado |

## 7. Preguntas abiertas para validar

1. ¿El costo promedio es por empresa o por depósito/sucursal?
2. ¿La aprobación previa al despacho es obligatoria, opcional por depósito o por monto?
3. ¿Quién es dueño del stock en tránsito para reportes y seguros: origen (propuesto) o destino?
4. ¿Se permiten traslados internos de un paso? ¿Entre depósitos de la misma sucursal con distinta dirección se exige remisión?
5. ¿Un traslado puede salir en varios camiones? La propuesta es un traslado = un despacho = una remisión.
6. Faltantes: ¿quién asume la pérdida y a qué cuenta va? ¿Hay tolerancia automática (merma de graneles)?
7. Sobrantes: ¿se aceptan con despacho complementario o se devuelven?
8. ¿Maestro de vehículos y conductores, o basta la persona con rol transportista?
9. ¿Las ubicaciones internas entran en la primera versión?
10. ¿Traslados a terceros (consignación, reparación) en esta fase?
11. Traslados entre empresas del grupo: son venta y compra, no traslado. ¿Confirmado?
12. ¿Plazo máximo en tránsito antes de alertar o bloquear?
13. ¿Remisión en contingencia cuando no hay conexión?
14. El rango de errores de `stk` (20 códigos) queda corto: ¿se amplía?
