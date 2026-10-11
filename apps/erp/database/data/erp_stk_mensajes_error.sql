-- =============================================================================
-- Mensajes de error por constraint del módulo de inventario (idempotente).
-- Los usa el manejador central adm_gen_error_api.
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;
merge into adm_gen_mensaje_error t
using (
    select 'UK_ERP_UNI_CODIGO'              codigo, 'Ya existe una unidad de medida con ese código.' mensaje from dual union all
    select 'CK_ERP_UNI_CODIGO_MAYUS',               'El código de la unidad debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_UNI_DECIMALES',                  'Los decimales de la unidad deben estar entre 0 y 4.' from dual union all
    select 'UK_ERP_CTG_EMP_CODIGO',                 'Ya existe una categoría con ese código en la empresa.' from dual union all
    select 'CK_ERP_CTG_CODIGO_MAYUS',               'El código de la categoría debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_CTG_PADRE',                      'Una categoría no puede depender de sí misma.' from dual union all
    select 'CK_ERP_CTG_ATRIBUTOS_JSON',             'La definición de atributos de la categoría no es un JSON válido.' from dual union all
    select 'FK_ERP_CTG_CTG_PADRE',                  'No se puede eliminar la categoría: tiene categorías dependientes.' from dual union all
    select 'UK_ERP_MAR_EMP_CODIGO',                 'Ya existe una marca con ese código en la empresa.' from dual union all
    select 'CK_ERP_MAR_CODIGO_MAYUS',               'El código de la marca debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_PRO_EMP_CODIGO',                 'Ya existe un producto con ese código en la empresa.' from dual union all
    select 'CK_ERP_PRO_CODIGO_MAYUS',               'El código del producto debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_PRO_TIPO',                       'El tipo de producto debe ser bien, servicio, kit o producción.' from dual union all
    select 'CK_ERP_PRO_LOTE_SERIE',                 'Un producto se controla por lote o por número de serie, no por ambos.' from dual union all
    select 'CK_ERP_PRO_VENCIMIENTO',                'Para controlar vencimientos el producto debe manejar lote o serie.' from dual union all
    select 'CK_ERP_PRO_SIN_STOCK',                  'Un servicio o un kit no puede manejar lote ni serie.' from dual union all
    select 'CK_ERP_PRO_METODO_COSTO',               'El método de costo debe ser promedio ponderado (P) o último costo (U).' from dual union all
    select 'CK_ERP_PRO_FACTORES',                   'Los factores de las unidades de compra y de venta deben ser mayores que cero.' from dual union all
    select 'CK_ERP_PRO_DESCUENTO_MAX',              'El descuento máximo debe estar entre 0 y 100.' from dual union all
    select 'CK_ERP_PRO_MEDIDAS',                    'El peso y el volumen no pueden ser negativos.' from dual union all
    select 'CK_ERP_PRO_ATRIBUTOS_JSON',             'Los atributos del producto no son un JSON válido.' from dual union all
    select 'FK_ERP_PRO_UNI',                        'No se puede eliminar la unidad: la usan productos.' from dual union all
    select 'FK_ERP_PRO_CTG',                        'No se puede eliminar la categoría: tiene productos.' from dual union all
    select 'FK_ERP_PRO_MAR',                        'No se puede eliminar la marca: tiene productos.' from dual union all
    select 'FK_ERP_PRO_CAFI',                       'No se puede eliminar la categoría fiscal: la usan productos.' from dual union all
    select 'UK_ERP_PRCD_EMP_TIPO_VALOR',            'Ese código ya está asignado a un producto de la empresa.' from dual union all
    select 'CK_ERP_PRCD_TIPO',                      'El tipo de código debe ser barras de unidad, barras de bulto, proveedor o externo.' from dual union all
    select 'CK_ERP_PRCD_FACTOR',                    'El contenido del bulto debe ser mayor que cero.' from dual union all
    select 'UK_ERP_PRUN_PRO_UNI',                   'El producto ya tiene una conversión para esa unidad.' from dual union all
    select 'CK_ERP_PRUN_FACTOR',                    'El factor de conversión debe ser mayor que cero.' from dual union all
    select 'UK_ERP_PREQ_PRO_EQUIV',                 'Ese producto ya figura como equivalente.' from dual union all
    select 'CK_ERP_PREQ_DISTINTO',                  'Un producto no puede ser equivalente de sí mismo.' from dual union all
    select 'FK_ERP_PREQ_PRO_EQUIV',                 'No se puede eliminar el producto: es equivalente de otro.' from dual union all
    select 'UK_ERP_PRDP_PRO_DPO',                   'El producto ya tiene sus parámetros cargados para ese depósito.' from dual union all
    select 'CK_ERP_PRDP_CANTIDADES',                'El mínimo y el punto de pedido no pueden ser negativos, y el máximo no puede ser menor que el mínimo.' from dual union all
    select 'UK_ERP_PRPV_PRO_PRS',                   'El producto ya tiene cargado ese proveedor.' from dual union all
    select 'CK_ERP_PRPV_CANTIDADES',                'El mínimo de compra y el plazo no pueden ser negativos, y el múltiplo debe ser mayor que cero.' from dual union all
    select 'UK_ERP_KIT_PRO_COMPONENTE',             'El kit ya incluye ese componente.' from dual union all
    select 'CK_ERP_KIT_CANTIDAD',                   'La cantidad del componente debe ser mayor que cero.' from dual union all
    select 'CK_ERP_KIT_DISTINTO',                   'Un kit no puede ser componente de sí mismo.' from dual union all
    select 'FK_ERP_KIT_PRO_COMPONENTE',             'No se puede eliminar el producto: es componente de un kit.' from dual union all
    select 'UK_ERP_LOT_PRO_CODIGO',                 'El producto ya tiene un lote o una serie con ese número.' from dual union all
    select 'CK_ERP_LOT_VIGENCIA',                   'El vencimiento del lote no puede ser anterior a su elaboración.' from dual union all
    select 'FK_ERP_LOT_PRO',                        'No se puede eliminar el producto: tiene lotes.' from dual union all
    select 'UK_ERP_DPUB_DPO_CODIGO',                'El depósito ya tiene una ubicación con ese código.' from dual union all
    select 'CK_ERP_DPUB_CODIGO_MAYUS',              'El código de la ubicación debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_DPUB_CUARENTENA',                'Una ubicación de cuarentena no puede estar disponible para la venta.' from dual union all
    select 'FK_ERP_DPUB_DPO',                       'No se puede eliminar el depósito: tiene ubicaciones.' from dual union all
    select 'UK_ERP_VEH_EMP_CHAPA',                  'Ya existe un vehículo con esa chapa en la empresa.' from dual union all
    select 'CK_ERP_VEH_CHAPA_MAYUS',                'La chapa del vehículo debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_VEH_PESOS',                      'La capacidad, la tara y la tolerancia no pueden ser negativas.' from dual union all
    select 'UK_ERP_USDP_USU_DPO',                   'El usuario ya tiene asignado ese depósito.' from dual union all
    select 'UK_ERP_TIMO_CODIGO',                    'Ya existe un tipo de movimiento con ese código.' from dual union all
    select 'CK_ERP_TIMO_CODIGO_MAYUS',              'El código del tipo de movimiento debe estar en mayúsculas.' from dual union all
    select 'FK_ERP_MOV_TIMO',                       'No se puede eliminar el tipo de movimiento: tiene movimientos.' from dual union all
    select 'UK_ERP_MOV_REVERSADO',                  'El movimiento ya fue anulado.' from dual union all
    select 'CK_ERP_MOIT_CANTIDAD',                  'La cantidad de la línea no puede ser cero.' from dual union all
    select 'CK_ERP_MOIT_COSTO',                     'El costo de la línea no puede ser negativo.' from dual union all
    select 'FK_ERP_MOIT_PRO',                       'No se puede eliminar el producto: tiene movimientos de stock.' from dual union all
    select 'FK_ERP_MOIT_DPO',                       'No se puede eliminar el depósito: tiene movimientos de stock.' from dual union all
    select 'FK_ERP_MOIT_LOT',                       'No se puede eliminar el lote: tiene movimientos de stock.' from dual union all
    select 'FK_ERP_MOIT_DPUB',                      'No se puede eliminar la ubicación: tiene movimientos de stock.' from dual union all
    select 'UK_ERP_SAL_CLAVE',                      'Ya existe el saldo de ese producto en el depósito.' from dual union all
    select 'CK_ERP_SAL_RESERVADA',                  'La cantidad reservada no puede ser negativa.' from dual union all
    select 'FK_ERP_SAL_PRO',                        'No se puede eliminar el producto: tiene saldo de stock.' from dual union all
    select 'FK_ERP_SAL_DPO',                        'No se puede eliminar el depósito: tiene saldo de stock.' from dual union all
    select 'UK_ERP_MOTR_CODIGO',                    'Ya existe un motivo de traslado con ese código.' from dual union all
    select 'CK_ERP_MOTR_CODIGO_MAYUS',              'El código del motivo de traslado debe estar en mayúsculas.' from dual union all
    select 'FK_ERP_TRA_MOTR',                       'No se puede eliminar el motivo: lo usan traslados.' from dual union all
    select 'UK_ERP_RUTR_EMP_ORIGEN_DESTINO',        'Ya existe una ruta entre esas dos sucursales.' from dual union all
    select 'CK_ERP_RUTR_SUCURSALES',                'La sucursal de origen y la de destino de la ruta deben ser distintas.' from dual union all
    select 'CK_ERP_RUTR_VALORES',                   'Las horas y los kilómetros de la ruta no pueden ser negativos.' from dual union all
    select 'UK_ERP_TRA_EMP_SUC_NUMERO',             'Ya existe un traslado con ese número en la sucursal.' from dual union all
    select 'CK_ERP_TRA_DEPOSITOS',                  'El depósito de origen y el de destino deben ser distintos.' from dual union all
    select 'CK_ERP_TRA_UN_PASO',                    'Solo un traslado interno puede ser de un paso; los demás necesitan depósito de tránsito.' from dual union all
    select 'CK_ERP_TRA_FECHAS_ESTIMADAS',           'La llegada estimada no puede ser anterior a la salida estimada.' from dual union all
    select 'CK_ERP_TRA_FECHAS_REALES',              'La recepción no puede ser anterior al despacho.' from dual union all
    select 'CK_ERP_TRA_FLETE',                      'El flete no puede ser negativo.' from dual union all
    select 'FK_ERP_TRA_VEH',                        'No se puede eliminar el vehículo: lo usan traslados.' from dual union all
    select 'FK_ERP_TRA_DPO_ORIGEN',                 'No se puede eliminar el depósito: tiene traslados.' from dual union all
    select 'FK_ERP_TRA_DPO_DESTINO',                'No se puede eliminar el depósito: tiene traslados.' from dual union all
    select 'FK_ERP_TRA_DPO_TRANSITO',               'No se puede eliminar el depósito: tiene traslados en tránsito.' from dual union all
    select 'UK_ERP_TRIT_TRA_LINEA',                 'El traslado ya tiene una línea con ese número.' from dual union all
    select 'CK_ERP_TRIT_SOLICITADA',                'La cantidad solicitada debe ser mayor que cero.' from dual union all
    select 'CK_ERP_TRIT_NO_NEGATIVAS',              'Las cantidades del traslado no pueden ser negativas.' from dual union all
    select 'CK_ERP_TRIT_DESPACHADA',                'No se puede despachar más de lo aprobado.' from dual union all
    select 'CK_ERP_TRIT_RECIBIDA',                  'Lo recibido, dañado, faltante, perdido y devuelto no puede superar lo despachado.' from dual union all
    select 'FK_ERP_TRIT_PRO',                       'No se puede eliminar el producto: figura en traslados.' from dual union all
    select 'FK_ERP_TRIT_TRA',                       'No se puede eliminar el traslado: tiene ítems.' from dual union all
    select 'UK_ERP_TRRE_TRA_NUMERO',                'El traslado ya tiene una recepción con ese número.' from dual union all
    select 'UK_ERP_TRRD_TRRE_TRIT',                 'La recepción ya tiene cargado ese ítem.' from dual union all
    select 'CK_ERP_TRRD_CANTIDADES',                'Las cantidades de la recepción no pueden ser negativas.' from dual union all
    select 'UK_ERP_STNU_EMP_SUC_CODIGO',            'Ya existe ese numerador para la sucursal.' from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje
 when not matched then
    insert (codigo, mensaje) values (s.codigo, s.mensaje);

commit;
