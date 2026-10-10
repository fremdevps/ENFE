# Diseño: configuración general del ERP

> Estado: **diseño aprobado en principio ("todo debe ser configurable"); implementación pendiente.**
> Reemplaza el esquema actual de `erp_gen_parametro` (clave y valor en la misma fila) y las páginas 80/81.
> Complementa `docs/arquitectura-erp.md` §3.6.

## 1. Por qué cambia el esquema actual

Hoy `erp_gen_parametro` mezcla la definición con el valor. Problemas:
- el tipo y la descripción se repiten en cada fila;
- el usuario tiene que tipear el código;
- no hay lista de valores ni validación;
- solo hay dos niveles (general y empresa);
- el valor por defecto vive en el código que llama, lo que contradice "todo configurable".

Se separa la **definición** (catálogo que mantiene el sistema) del **valor** (lo que cambia el cliente).

## 2. Modelo

| Tabla | Abrev. | Contenido |
|---|---|---|
| `erp_gen_parametro` (catálogo) | par | código único, módulo, grupo, nombre, descripción, ayuda, tipo de dato (texto, número, fecha, sí/no, lista, referencia a un maestro), valor por defecto, mínimo, máximo, expresión regular, unidad, niveles permitidos (empresa, sucursal, usuario), editable por el cliente, sensible, funcionalidad de la que depende, efecto del cambio (inmediato, solo documentos nuevos, bloqueado si hay movimientos), orden, estado |
| `erp_gen_parametro_grupo` | pagr | módulo, código, nombre, ícono, orden |
| `erp_gen_parametro_opcion` | paop | valores permitidos de un parámetro de tipo lista, con nombre y descripción |
| `erp_gen_parametro_valor` | pava | parámetro, nivel (general, empresa, sucursal, usuario) con sus claves, valor, motivo y auditoría |

- El catálogo lo mantienen solo los scripts de instalación (`merge`). Un parámetro nuevo es un dato, no un cambio de pantalla.
- El cliente solo escribe valores.
- Migración: las filas actuales pasan a definiciones más su valor general.

## 3. Resolución y API

- **Cascada:** usuario → sucursal → empresa → general → valor por defecto. Cada nivel participa solo si la definición lo permite.
- **Lectura** (`erp_gen_parametro_api`): `obtener_texto`, `obtener_numero`, `obtener_fecha`, `obtener_sn`, con empresa, sucursal y usuario opcionales. Un código inexistente da error (hoy devuelve vacío en silencio). `obtener_origen` dice de qué nivel sale el valor.
- **Escritura:** `guardar_valor` y `restablecer_valor`. Se valida tipo, rango, formato, pertenencia a la lista, nivel permitido y efecto.
- **Caché** por petición dentro del paquete.
- **Auditoría:** historial de cambios sobre los valores, y motivo obligatorio en los parámetros críticos.

## 4. Pantalla "Configuración general"

- Selector de ámbito (General, Empresa activa, Sucursal, Usuario) y buscador.
- Pestañas por módulo y grupos colapsables.
- Cada fila: nombre, valor vigente, de dónde viene ("Propio", "Heredado de Empresa", "Por defecto"), ayuda, y acciones Editar y Restablecer.
- Control según el tipo: interruptor para sí/no, lista con la descripción de cada opción, número con unidad y rango, fecha, lista emergente para referencias, enmascarado para sensibles.
- Historial por parámetro y vista de "diferencias respecto al estándar".
- Permiso para editar y otro aparte para los parámetros críticos.

## 5. Regla para decidir dónde va cada cosa

Se pregunta en este orden:

1. ¿Enciende o apaga un bloque entero (pantallas, campos, validaciones)? → **funcionalidad** por empresa.
2. ¿Cambia según el comprobante? → atributo del **tipo de documento**.
3. ¿Cambia según el ítem? → atributo del **producto o su categoría**; vacío hereda del parámetro.
4. ¿Cambia según la contraparte? → **cliente o proveedor**, o su categoría.
5. ¿Es una cuenta contable o un porcentaje de impuesto? → **regla contable o motor de impuestos**. Nunca un parámetro.
6. ¿Es una tabla de reglas (tramos, vigencias, topes por usuario)? → **entidad propia** (regla de comisión, política de mora, autorización).
7. ¿Es identidad o estructura de la empresa (país, monedas, rubro)? → columnas de la configuración de empresa.
8. ¿Es un secreto? → credencial; el parámetro guarda solo la referencia.
9. Si es una política simple que varía por organización → **parámetro**.

Patrón de excepción: columna opcional en el maestro (vacío = hereda) y parámetro como valor por defecto.

## 6. Las cuatro decisiones que quedan configurables

| Decisión | Cómo queda |
|---|---|
| Base de comisiones | Funcionalidad `COMISION` + parámetro por empresa: sobre lo vendido, sobre lo cobrado o por regla (cada regla define su base y tramos) |
| Método de costo | Parámetro por empresa (promedio ponderado o último costo) + excepción opcional por producto. Bloqueado cuando ya hay movimientos |
| Caja con o sin turno y arqueo | Parámetros por empresa o sucursal + excepción por caja (una caja chica puede no tener turno) |
| Línea de negocio | Funcionalidad `LINEA_NEGOCIO`, independiente de `DEPARTAMENTO`, con parámetros de obligatoriedad y de origen (producto, documento o manual) |

## 7. Catálogo inicial

Niveles: G general · E empresa · S sucursal · U usuario. El valor por defecto es el recomendado para Paraguay.

### 7.1 General, documentos e inventario

| Código | Qué decide | Valores | Defecto | Nivel |
|---|---|---|---|---|
| ERP_GEN_PERIODO_ESTRICTO | Exigir período creado y abierto | Sí / No | No | G, E |
| ERP_GEN_ACCESO_SUCURSAL_ESTRICTO | Operar solo las sucursales asignadas | Sí / No | No | G, E |
| ERP_GEN_COTIZACION_DIAS_MAX | Antigüedad máxima de la cotización (días) | Número | 1 | G, E |
| ERP_GEN_COTIZACION_FALTANTE | Qué hacer sin cotización del día | Bloquear / Avisar / Usar la última | Bloquear | E |
| ERP_GEN_COTIZACION_TIPO | Tipo de cotización por defecto | Compra / Venta / Según la operación | Venta | E |
| ERP_GEN_PRECIO_INCLUYE_IMP | Precios con impuesto incluido | Sí / No | Sí | E |
| ERP_GEN_SABADO_HABIL | Sábado es día hábil | Sí / No | No | E, S |
| ERP_GEN_PERSONA_DOC_DUPLICADO | Documento de identidad repetido | Bloquear / Avisar / Permitir | Bloquear | G |
| ERP_GEN_RUC_VALIDAR_DV | Validar el dígito verificador | Sí / No | Sí | G |
| ERP_GEN_DEPARTAMENTO_OBLIG | Departamento obligatorio | Sí / No | No | E |
| ERP_GEN_LINEA_NEGOCIO_OBLIG | Línea de negocio obligatoria | Sí / No | No | E |
| ERP_GEN_LINEA_NEGOCIO_ORIGEN | De dónde sale la línea de negocio | Producto / Documento / Manual | Producto | E |
| ERP_GEN_ADJUNTO_MB_MAX | Tamaño máximo de adjunto (MB) | 1–50 | 5 | G, E |
| ERP_GEN_AUDITORIA_RETENCION_MES | Meses de historial de cambios | Número | 84 | G |
| ERP_GEN_TOLERANCIA_REDONDEO | Diferencia de redondeo admitida | Número | 1 | E |
| ERP_GEN_SUCURSAL_DEFECTO | Sucursal al iniciar sesión | Sucursal | — | U |
| ERP_DOC_FECHA_DIAS_ATRAS | Días hacia atrás para emitir | Número | 0 | E, S |
| ERP_DOC_FECHA_FUTURA | Permitir fecha futura | Sí / No | No | E |
| ERP_DOC_NUMERADOR_AVISO_DIAS | Avisar N días antes del vencimiento del timbrado | Número | 30 | E |
| ERP_DOC_NUMERADOR_AVISO_PORC | Avisar al % de rango usado | 1–100 | 90 | E |
| ERP_DOC_ANULACION_MOTIVO_OBLIG | Exigir motivo al anular | Sí / No | Sí | E |
| ERP_DOC_ANULACION_OTRO_USUARIO | Anular documentos de otro usuario | No / Con permiso / Sí | Con permiso | E |
| ERP_DOC_FE_LOTE_TAMANO | Documentos electrónicos por lote | 1–50 | 50 | G, E |
| ERP_DOC_FE_REINTENTOS_MAX | Reintentos de envío | Número | 10 | G |
| ERP_DOC_FE_FORMATO_IMPRESION | Formato de la representación gráfica | A4 / A5 / Cinta | A4 | E, S |
| ERP_DOC_FE_CORREO_AUTOMATICO | Enviar al receptor al aprobar | Sí / No | Sí | E |
| ERP_STK_METODO_COSTO | Método de costo | Promedio / Último | Promedio | E |
| ERP_STK_STOCK_NEGATIVO | Salida sin stock | Bloquear / Avisar / Permitir | Bloquear | E, S |
| ERP_STK_LOTE_SUGERENCIA | Orden de lotes sugerido | Por vencimiento / Por ingreso / Manual | Por vencimiento | E |
| ERP_STK_VENCIDO_SALIDA | Salida de lote vencido | Bloquear / Avisar | Bloquear | E |
| ERP_STK_AJUSTE_APROBACION | Los ajustes requieren aprobación | Sí / No | Sí | E |
| ERP_STK_TRASLADO_MODO | Circuito de traslado | Directo / Con tránsito | Con tránsito | E |
| ERP_STK_TRASLADO_APROBACION | El traslado requiere aprobación | Sí / No | No | E, S |
| ERP_STK_TRASLADO_TOLERANCIA | Tolerancia de diferencia en recepción (%) | 0–100 | 0 | E |
| ERP_STK_TRASLADO_DIAS_ALERTA | Alertar tránsito con más de N días | Número | 3 | E |

Los plazos normativos de documentos electrónicos (72 h de envío, 48 h y 168 h de cancelación) también van como parámetros generales, editables solo por actualización del sistema.

### 7.2 Ventas y compras

| Código | Qué decide | Valores | Defecto | Nivel |
|---|---|---|---|---|
| ERP_VEN_COMISION_BASE | Base de comisiones | Vendido / Cobrado / Por regla | Cobrado | E |
| ERP_VEN_COMISION_SIN_IMPUESTO | Comisión sobre monto sin IVA | Sí / No | Sí | E |
| ERP_VEN_COMISION_NC_DESCUENTA | Las notas de crédito descuentan comisión | Sí / No | Sí | E |
| ERP_VEN_PRECIO_EDITABLE | Cambiar el precio sugerido | No / Sí / No menor | No menor | E, S |
| ERP_VEN_SIN_PRECIO | Producto sin precio en lista | Bloquear / Permitir | Bloquear | E |
| ERP_VEN_DESC_ITEM_MAX | % máximo de descuento por ítem | 0–100 | 0 | E |
| ERP_VEN_DESC_GLOBAL_MAX | % máximo de descuento global | 0–100 | 0 | E |
| ERP_VEN_MARGEN_CONTROL | Venta bajo el margen mínimo | No / Avisar / Bloquear | Avisar | E |
| ERP_VEN_CREDITO_CONTROL | Límite de crédito excedido | No / Avisar / Bloquear | Bloquear | E |
| ERP_VEN_CREDITO_MOMENTO | Dónde se controla el crédito | Pedido / Factura / Ambos | Ambos | E |
| ERP_VEN_CREDITO_INCLUYE_CHEQUE | Los cheques en cartera consumen límite | Sí / No | Sí | E |
| ERP_VEN_MORA_BLOQUEO_DIAS | Bloquear con atraso mayor a N días | Número | 30 | E |
| ERP_VEN_PEDIDO_OBLIGATORIO | Facturar solo desde pedido | Sí / No | No | E |
| ERP_VEN_PEDIDO_SALDO_CONTROL | Facturar más que lo pedido | No / Avisar / Bloquear | Bloquear | E |
| ERP_VEN_PEDIDO_MODIFICAR | Modificar pedidos | No / Sin factura / Parcial / Sí | Sin factura | E |
| ERP_VEN_PEDIDO_VIGENCIA_DIAS | Vigencia del pedido (días) | Número | 30 | E |
| ERP_VEN_ITEM_DUPLICADO | Producto repetido en el documento | Permitir / Avisar / Bloquear | Avisar | E |
| ERP_VEN_CLIENTE_OCASIONAL | Venta a cliente sin registrar | Sí / No | Sí | E, S |
| ERP_COM_PRECIO_SUGERIDO | Precio sugerido en la orden de compra | Última compra / Lista del proveedor / Ninguno | Última compra | E |
| ERP_COM_ORDEN_OBLIGATORIA | La factura de compra exige orden | Sí / No | No | E |
| ERP_COM_TOLERANCIA_PRECIO | Tolerancia de precio factura vs. orden (%) | Número | 0 | E |
| ERP_COM_APROBACION_MONTO | Aprobar órdenes desde un monto | Número | — | E |
| ERP_COM_TIMBRADO_VALIDAR | Timbrado del proveedor vencido | No / Avisar / Bloquear | Bloquear | E |
| ERP_COM_IMPORT_PRORRATEO | Reparto de gastos de importación | Por valor / Peso / Cantidad | Por valor | E |

### 7.3 Finanzas y caja

| Código | Qué decide | Valores | Defecto | Nivel |
|---|---|---|---|---|
| ERP_FIN_CAJA_SESION | Caja con apertura y cierre de turno | Sí / No | Sí | E, S |
| ERP_FIN_CAJA_ARQUEO | Arqueo al cierre | No / Opcional / Obligatorio | Obligatorio | E, S |
| ERP_FIN_CAJA_ARQUEO_CIEGO | El cajero no ve el saldo esperado | Sí / No | Sí | E, S |
| ERP_FIN_CAJA_DIFERENCIA_MAX | Diferencia tolerada sin aprobación | Número | 0 | E |
| ERP_FIN_CAJA_SESION_POR | Una sesión abierta por | Caja / Usuario | Caja | E |
| ERP_FIN_PAGO_CIRCUITO | Circuito de pagos | Directo / Con orden de pago | Con orden de pago | E |
| ERP_FIN_OP_APROBACION_MONTO | Aprobar órdenes de pago desde un monto | Número | — | E |
| ERP_FIN_MORA_CALCULO | Cálculo de interés por mora | No / Simple / Compuesto | Simple | E |
| ERP_FIN_MORA_DESDE | La mora corre desde | Vencimiento / Emisión | Vencimiento | E |
| ERP_FIN_MORA_DIAS_GRACIA | Días de gracia | Número | 0 | E |
| ERP_FIN_APLICACION_ORDEN | Aplicación automática de cobros | Más antiguo / Manual | Más antiguo | E |
| ERP_FIN_COBRO_OTRA_MONEDA | Cobrar en moneda distinta al documento | Sí / No | Sí | E |
| ERP_FIN_RETENCION_AUTOMATICA | Calcular retenciones al pagar | Sí / No | Sí | E |
| ERP_FIN_ANTICIPO_APLICACION | Aplicar anticipos al facturar | Automática / Preguntar / Manual | Preguntar | E |

### 7.4 Contabilidad

| Código | Qué decide | Valores | Defecto | Nivel |
|---|---|---|---|---|
| ERP_CNT_ASIENTO_MOMENTO | Generación de asientos | En línea / Diferido | En línea | E |
| ERP_CNT_ASIENTO_FALLA | Si la regla contable falla | Dejar pendiente / Bloquear | Dejar pendiente | E |
| ERP_CNT_EJERCICIO_MES_INICIO | Mes de inicio del ejercicio | 1–12 | 1 | E |
| ERP_CNT_PLAN_MASCARA | Máscara del plan de cuentas | Texto | 9.9.99.99.999 | E |
| ERP_CNT_CENTRO_COSTO_OBLIG | Centro de costo obligatorio en resultados | Sí / No | No | E |
| ERP_CNT_DIF_CAMBIO_REVALUO | Revalúo mensual automático | Sí / No | Sí | E |
| ERP_CNT_CIERRE_EXIGE_MODULOS | Cerrar contabilidad exige módulos cerrados | Sí / No | Sí | E |

## 8. Lo que no va en parámetros

- **Cuentas contables** por defecto: van en reglas contables por concepto.
- **Porcentajes de impuestos y retenciones**: van en el motor de impuestos, con vigencia.
- **Claves y direcciones de servicios externos**: van como credenciales.
- **Opciones propias de un rubro** (báscula, contratos de granos, restaurante, hotelería): van en funcionalidades y apps verticales.
- **Reglas en SQL escritas por el usuario**: nunca; solo listas cerradas.

## 9. Preguntas abiertas

1. ¿El cliente final edita todo, o hay parámetros reservados al implementador? ¿Quién autoriza los críticos?
2. Parámetros que cambian el pasado (método de costo, máscara del plan, inicio del ejercicio): ¿bloqueo cuando hay movimientos, o cambio con fecha de vigencia?
3. Comisiones: ¿conviven en una misma empresa vendedores "sobre cobrado" y "sobre vendido"? Si es así, el valor por defecto sería "por regla".
4. Caja: ¿la sesión es por caja o por usuario? ¿Arqueo ciego por defecto? ¿Quién aprueba diferencias?
5. Línea de negocio: ¿siempre derivada de la categoría del producto, o editable por ítem?
6. Último costo: ¿se usa para valorizar el stock o solo para el precio sugerido y la reposición?
7. ¿Hace falta exportar e importar la configuración entre empresas y tener plantillas por rubro?
