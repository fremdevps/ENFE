-- =============================================================================
-- Datos iniciales del módulo de inventario (stk). Idempotente (merge).
--   - Unidades de medida con su código SIFEN (cUniMed). Verificar los códigos
--     contra la tabla vigente del Manual Técnico de SIFEN antes de emitir.
--   - Tipos de movimiento de stock con su comportamiento.
--   - Motivos de traslado con el motivo de emisión de la nota de remisión (iMotEmiNR).
--   - Funcionalidades y parámetros ERP_STK_* (todo el comportamiento opcional
--     se decide por datos, no en el código).
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;

-- Unidades de medida ------------------------------------------------------------
merge into erp_stk_unidad t
using (select 'UNI' codigo, 'Unidad' nombre, 'un' simbolo, 77 codigo_sifen, 0 decimales from dual union all
       select 'KG',   'Kilogramo',          'kg',   83,   4 from dual union all
       select 'G',    'Gramo',              'g',    86,   4 from dual union all
       select 'MG',   'Miligramo',          'mg',   90,   4 from dual union all
       select 'TN',   'Tonelada',           't',    99,   4 from dual union all
       select 'LT',   'Litro',              'l',    89,   4 from dual union all
       select 'ML',   'Mililitro',          'ml',   88,   4 from dual union all
       select 'M',    'Metro',              'm',    87,   4 from dual union all
       select 'CM',   'Centímetro',         'cm',   91,   4 from dual union all
       select 'MM',   'Milímetro',          'mm',   95,   4 from dual union all
       select 'KM',   'Kilómetro',          'km',   625,  4 from dual union all
       select 'M2',   'Metro cuadrado',     'm2',   109,  4 from dual union all
       select 'M3',   'Metro cúbico',       'm3',   110,  4 from dual union all
       select 'HA',   'Hectárea',           'ha',   869,  4 from dual union all
       select 'HS',   'Hora',               'h',    100,  2 from dual union all
       select 'DIA',  'Día',                'd',    102,  2 from dual union all
       select 'MES',  'Mes',                'mes',  98,   2 from dual union all
       select 'GL',   'Global',             'gl',   885,  0 from dual union all
       select 'CAJA', 'Caja',               'cj',   null, 0 from dual union all
       select 'PAQ',  'Paquete',            'pq',   null, 0 from dual union all
       select 'DOC',  'Docena',             'dz',   null, 0 from dual union all
       select 'BOL',  'Bolsa',              'bl',   null, 0 from dual union all
       select 'PAL',  'Pallet',             'pl',   null, 0 from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, simbolo, codigo_sifen, decimales)
    values (s.codigo, s.nombre, s.simbolo, s.codigo_sifen, s.decimales);

-- Tipos de movimiento -----------------------------------------------------------
-- naturaleza E/S/T · exige motivo · valida vencimiento · permite tránsito · manual
merge into erp_stk_tipo_movimiento t
using (select 'INV_INICIAL' codigo, 'Inventario inicial' nombre, 'E' naturaleza, 'N' motivo, 'N' vencimiento, 'N' transito, 'S' manual from dual union all
       select 'AJUSTE_ENT',      'Ajuste de entrada',                    'E', 'S', 'N', 'N', 'S' from dual union all
       select 'AJUSTE_SAL',      'Ajuste de salida',                     'S', 'S', 'N', 'N', 'S' from dual union all
       select 'BAJA',            'Baja por rotura, merma o vencimiento', 'S', 'S', 'N', 'N', 'S' from dual union all
       select 'REUBICACION',     'Cambio de ubicación en el depósito',   'T', 'N', 'N', 'N', 'S' from dual union all
       select 'COMPRA',          'Entrada por compra',                   'E', 'N', 'N', 'N', 'N' from dual union all
       select 'DEV_COMPRA',      'Devolución a proveedor',               'S', 'N', 'N', 'N', 'N' from dual union all
       select 'VENTA',           'Salida por venta',                     'S', 'N', 'S', 'N', 'N' from dual union all
       select 'DEV_VENTA',       'Devolución de cliente',                'E', 'N', 'N', 'N', 'N' from dual union all
       select 'CONSUMO',         'Consumo interno o de producción',      'S', 'N', 'S', 'N', 'N' from dual union all
       select 'PRODUCCION',      'Entrada de producción',                'E', 'N', 'N', 'N', 'N' from dual union all
       select 'TRAS_DESPACHO',   'Despacho de traslado',                 'T', 'N', 'S', 'S', 'N' from dual union all
       select 'TRAS_DESP_DEV',   'Despacho de devolución de traslado',   'T', 'N', 'N', 'S', 'N' from dual union all
       select 'TRAS_INTERNO',    'Traslado interno de un paso',          'T', 'N', 'S', 'N', 'N' from dual union all
       select 'TRAS_RECEPCION',  'Recepción de traslado',                'T', 'N', 'N', 'S', 'N' from dual union all
       select 'TRAS_PERDIDA',    'Pérdida en traslado',                  'S', 'N', 'N', 'S', 'N' from dual union all
       select 'TRAS_DEVOLUCION', 'Faltante de traslado devuelto al origen', 'T', 'N', 'N', 'S', 'N' from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, naturaleza, debe_exigir_motivo, debe_validar_vencimiento, debe_permitir_transito, es_manual)
    values (s.codigo, s.nombre, s.naturaleza, s.motivo, s.vencimiento, s.transito, s.manual);

-- Motivos de traslado (código SIFEN iMotEmiNR) ----------------------------------
-- interno · con remisión entre locales · a terceros · devolución
merge into erp_stk_motivo_traslado t
using (select 'INTERNO' codigo, 'Movimiento interno entre depósitos' nombre, cast(null as number) codigo_sifen, 'S' interno, 'N' remision, 'N' tercero, 'N' devolucion from dual union all
       select 'VENTA',          'Traslado por venta',                              1,  'N', 'N', 'N', 'N' from dual union all
       select 'CONSIGNACION',   'Traslado por consignación',                       2,  'N', 'N', 'S', 'N' from dual union all
       select 'EXPORTACION',    'Exportación',                                     3,  'N', 'N', 'N', 'N' from dual union all
       select 'COMPRA',         'Traslado por compra',                             4,  'N', 'N', 'N', 'N' from dual union all
       select 'IMPORTACION',    'Importación',                                     5,  'N', 'N', 'N', 'N' from dual union all
       select 'DEVOLUCION',     'Traslado por devolución',                         6,  'S', 'S', 'S', 'S' from dual union all
       select 'ENTRE_LOCALES',  'Traslado entre locales de la empresa',            7,  'N', 'S', 'N', 'N' from dual union all
       select 'TRANSFORMACION', 'Traslado de bienes por transformación',           8,  'N', 'N', 'S', 'N' from dual union all
       select 'REPARACION',     'Traslado de bienes por reparación',               9,  'N', 'N', 'S', 'N' from dual union all
       select 'EMISOR_MOVIL',   'Traslado por emisor móvil',                       10, 'N', 'N', 'N', 'N' from dual union all
       select 'EXHIBICION',     'Exhibición o demostración',                       11, 'N', 'N', 'S', 'N' from dual union all
       select 'FERIA',          'Participación en ferias',                         12, 'N', 'N', 'S', 'N' from dual union all
       select 'ENCOMIENDA',     'Traslado de encomienda',                          13, 'N', 'N', 'N', 'N' from dual union all
       select 'DECOMISO',       'Decomiso',                                        14, 'N', 'N', 'N', 'N' from dual union all
       select 'OTRO',           'Otro',                                            99, 'N', 'S', 'S', 'N' from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, codigo_sifen, es_tipo_interno, es_tipo_remision, es_tipo_tercero, es_devolucion)
    values (s.codigo, s.nombre, s.codigo_sifen, s.interno, s.remision, s.tercero, s.devolucion);

-- Funcionalidades activables del módulo -----------------------------------------
merge into erp_gen_funcionalidad t
using (select 'UBICACION' codigo, 'Ubicaciones dentro del depósito' nombre, 'STK' modulo,
              'Lleva el stock por ubicación (almacenaje, recepción, despacho) dentro de cada depósito.' descripcion from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, modulo, descripcion)
    values (s.codigo, s.nombre, s.modulo, s.descripcion);

-- Parámetros (empresa_id null = valor por defecto de todas las empresas) ---------
merge into erp_gen_parametro t
using (select 'ERP_STK_METODO_COSTO' codigo, 'P' valor, 'T' tipo_dato,
              'Método de costo de los productos que no definen el suyo: P = promedio ponderado, U = último costo.' descripcion from dual union all
       select 'ERP_STK_TRASLADO_APROBACION', 'S', 'S',
              'S = los traslados solicitados requieren aprobación antes del despacho. N = se aprueban solos al solicitarlos.' from dual union all
       select 'ERP_STK_TRASLADO_SEGREGAR', 'N', 'S',
              'S = el usuario que despacha un traslado no puede recibirlo.' from dual union all
       select 'ERP_STK_TRASLADO_UN_PASO', 'S', 'S',
              'S = se permiten traslados internos de un paso (sale y entra en el mismo movimiento, sin tránsito).' from dual union all
       select 'ERP_STK_TRASLADO_TOLERANCIA', '0', 'N',
              'Porcentaje de faltante sobre lo despachado que se da de baja automáticamente como merma al recibir. 0 = sin tolerancia.' from dual union all
       select 'ERP_STK_TRASLADO_PERDIDA_RESP', 'N', 'S',
              'S = resolver un faltante como pérdida exige indicar la persona responsable.' from dual) s
   on (t.codigo = s.codigo and t.empresa_id is null)
 when not matched then
    insert (empresa_id, codigo, valor, tipo_dato, descripcion)
    values (null, s.codigo, s.valor, s.tipo_dato, s.descripcion);

commit;
