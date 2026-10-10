-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/erp/database)

-- >>> apps/erp/database/data/erp_gen_datos_iniciales.sql
-- =============================================================================
-- Datos iniciales del módulo General (idempotente: merge).
-- Base para Paraguay; todo es configurable desde las pantallas del ERP.
-- No incluye la tabla geográfica oficial de SIFEN (departamentos, distritos,
-- ciudades): se carga aparte desde la publicación de la DNIT.
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;

-- Monedas ----------------------------------------------------------------------
merge into erp_gen_moneda t
using (select 'PYG' codigo, 'Guaraní'          nombre, '₲'   simbolo, 0 decimales, 2 decimales_precio from dual union all
       select 'USD',        'Dólar estadounidense',    'US$',         2,           4                  from dual union all
       select 'BRL',        'Real brasileño',          'R$',          2,           4                  from dual union all
       select 'ARS',        'Peso argentino',          'AR$',         2,           4                  from dual union all
       select 'EUR',        'Euro',                    '€',           2,           4                  from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, simbolo, decimales, decimales_precio)
    values (s.codigo, s.nombre, s.simbolo, s.decimales, s.decimales_precio);

-- Países -------------------------------------------------------------------------
merge into erp_gen_pais t
using (select p.codigo, p.codigo_iso3, p.nombre, p.prefijo, m.moneda_id
         from (select 'PY' codigo, 'PRY' codigo_iso3, 'Paraguay'       nombre, '+595' prefijo, 'PYG' moneda from dual union all
               select 'BR',        'BRA',             'Brasil',                '+55',          'BRL'        from dual union all
               select 'AR',        'ARG',             'Argentina',             '+54',          'ARS'        from dual union all
               select 'US',        'USA',             'Estados Unidos',        '+1',           'USD'        from dual) p
         left join erp_gen_moneda m on m.codigo = p.moneda) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, codigo_iso3, nombre, prefijo_telefono, moneda_id)
    values (s.codigo, s.codigo_iso3, s.nombre, s.prefijo, s.moneda_id);

-- Impuestos de Paraguay ------------------------------------------------------------
merge into erp_gen_impuesto t
using (select p.pais_id, i.codigo, i.nombre, i.tipo, i.codigo_oficial
         from erp_gen_pais p
        cross join (select 'IVA' codigo, 'Impuesto al Valor Agregado'      nombre, 'I' tipo, '1' codigo_oficial from dual union all
                    select 'ISC',        'Impuesto Selectivo al Consumo',          'I',      '2'                from dual union all
                    select 'RET_IVA',    'Retención de IVA',                       'R',      null               from dual union all
                    select 'RET_RENTA',  'Retención de renta',                     'R',      null               from dual) i
        where p.codigo = 'PY') s
   on (t.pais_id = s.pais_id and t.codigo = s.codigo)
 when not matched then
    insert (pais_id, codigo, nombre, tipo, codigo_oficial)
    values (s.pais_id, s.codigo, s.nombre, s.tipo, s.codigo_oficial);

merge into erp_gen_impuesto_tasa t
using (select i.impuesto_id, x.codigo, x.nombre, x.codigo_oficial
         from erp_gen_impuesto i
         join erp_gen_pais p on p.pais_id = i.pais_id and p.codigo = 'PY'
         join (select 'IVA' impuesto, 'IVA10' codigo, 'IVA 10 %' nombre, '10' codigo_oficial from dual union all
               select 'IVA',          'IVA5',         'IVA 5 %',          '5'                from dual) x
           on x.impuesto = i.codigo) s
   on (t.impuesto_id = s.impuesto_id and t.codigo = s.codigo)
 when not matched then
    insert (impuesto_id, codigo, nombre, codigo_oficial)
    values (s.impuesto_id, s.codigo, s.nombre, s.codigo_oficial);

-- Vigencia inicial de carga: ajustar fecha_desde a la norma si se migran documentos antiguos.
merge into erp_gen_impuesto_tasa_vig t
using (select ta.impuesto_tasa_id, date '2000-01-01' fecha_desde,
              case ta.codigo when 'IVA10' then 10 when 'IVA5' then 5 end porcentaje
         from erp_gen_impuesto_tasa ta
         join erp_gen_impuesto i on i.impuesto_id = ta.impuesto_id and i.codigo = 'IVA'
         join erp_gen_pais p on p.pais_id = i.pais_id and p.codigo = 'PY'
        where ta.codigo in ('IVA10', 'IVA5')) s
   on (t.impuesto_tasa_id = s.impuesto_tasa_id and t.fecha_desde = s.fecha_desde)
 when not matched then
    insert (impuesto_tasa_id, fecha_desde, porcentaje, observacion)
    values (s.impuesto_tasa_id, s.fecha_desde, s.porcentaje, 'Carga inicial: verificar contra la norma vigente');

-- Categorías fiscales ------------------------------------------------------------------
merge into erp_gen_categoria_fiscal t
using (select p.pais_id, c.codigo, c.nombre, c.codigo_oficial, c.descripcion
         from erp_gen_pais p
        cross join (select 'GRAV10' codigo, 'Gravado 10 %'  nombre, '1' codigo_oficial, 'Tasa general de IVA' descripcion from dual union all
                    select 'GRAV5',         'Gravado 5 %',          '1',                'Tasa reducida de IVA (canasta básica, inmuebles, medicamentos…)' from dual union all
                    select 'EXENTO',        'Exento',               '3',                'Operaciones exentas de IVA' from dual union all
                    select 'EXONERADO',     'Exonerado',            '2',                'Operaciones exoneradas de IVA' from dual) c
        where p.codigo = 'PY') s
   on (t.pais_id = s.pais_id and t.codigo = s.codigo)
 when not matched then
    insert (pais_id, codigo, nombre, codigo_oficial, descripcion)
    values (s.pais_id, s.codigo, s.nombre, s.codigo_oficial, s.descripcion);

merge into erp_gen_categoria_tasa t
using (select c.categoria_fiscal_id, ta.impuesto_tasa_id
         from erp_gen_categoria_fiscal c
         join erp_gen_pais p on p.pais_id = c.pais_id and p.codigo = 'PY'
         join erp_gen_impuesto i on i.pais_id = p.pais_id and i.codigo = 'IVA'
         join erp_gen_impuesto_tasa ta on ta.impuesto_id = i.impuesto_id
        where (c.codigo = 'GRAV10' and ta.codigo = 'IVA10')
           or (c.codigo = 'GRAV5'  and ta.codigo = 'IVA5')) s
   on (t.categoria_fiscal_id = s.categoria_fiscal_id and t.impuesto_tasa_id = s.impuesto_tasa_id)
 when not matched then
    insert (categoria_fiscal_id, impuesto_tasa_id, porcentaje_base)
    values (s.categoria_fiscal_id, s.impuesto_tasa_id, 100);

-- Tipos de documento de identidad (Paraguay) --------------------------------------------
merge into erp_gen_tipo_doc_identidad t
using (select p.pais_id, d.codigo, d.nombre, d.es_tributario, d.tiene_dv, d.formato_regexp, d.codigo_oficial
         from erp_gen_pais p
        cross join (select 'RUC' codigo, 'RUC' nombre, 'S' es_tributario, 'S' tiene_dv, '^[0-9A-Z]{1,8}$' formato_regexp, null codigo_oficial from dual union all
                    select 'CI',  'Cédula de identidad paraguaya',  'N', 'N', '^[0-9]{1,8}$', '1' from dual union all
                    select 'PAS', 'Pasaporte',                      'N', 'N', null,           '2' from dual union all
                    select 'CIE', 'Cédula extranjera',              'N', 'N', null,           '3' from dual union all
                    select 'CRE', 'Carnet de residencia',           'N', 'N', null,           '4' from dual union all
                    select 'INN', 'Innominado',                     'N', 'N', null,           '5' from dual union all
                    select 'DIP', 'Tarjeta diplomática',            'N', 'N', null,           '6' from dual union all
                    select 'OTR', 'Otro documento',                 'N', 'N', null,           '9' from dual) d
        where p.codigo = 'PY') s
   on (t.pais_id = s.pais_id and t.codigo = s.codigo)
 when not matched then
    insert (pais_id, codigo, nombre, es_tributario, tiene_dv, formato_regexp, codigo_oficial)
    values (s.pais_id, s.codigo, s.nombre, s.es_tributario, s.tiene_dv, s.formato_regexp, s.codigo_oficial);

-- Funcionalidades activables (adaptación por rubro) -------------------------------------
merge into erp_gen_funcionalidad t
using (select 'DEPARTAMENTO' codigo, 'Departamentos / unidades de negocio' nombre, 'GEN' modulo,
              'Pide el departamento en documentos, stock y finanzas para reportes por unidad de negocio.' descripcion from dual union all
       select 'VENDEDOR',     'Vendedores y comisiones',        'VEN', 'Asigna vendedor a clientes, pedidos y facturas.' from dual union all
       select 'LOTE',         'Control por lote',               'STK', 'Registra el lote en entradas y salidas de stock.' from dual union all
       select 'VENCIMIENTO',  'Fecha de vencimiento de lotes',  'STK', 'Controla vencimientos (farmacia, alimentos, agroquímicos).' from dual union all
       select 'SERIE',        'Número de serie',                'STK', 'Registra números de serie por unidad (equipos, vehículos).' from dual union all
       select 'CONSIGNACION', 'Consignación',                   'STK', 'Stock propio en poder de terceros y de terceros en poder de la empresa.' from dual union all
       select 'CENTRO_COSTO', 'Centros de costo',               'CNT', 'Distribuye gastos e ingresos por centro de costo.' from dual union all
       select 'SAFRA',        'Safra / zafra agrícola',         'COM', 'Asocia documentos y financiaciones a la safra (agro, cooperativas).' from dual union all
       select 'PESAJE',       'Báscula / pesaje',               'STK', 'Entradas y salidas por peso con descuentos por humedad e impurezas.' from dual union all
       select 'FLETE',        'Fletes y transporte',            'VEN', 'Transportista, vehículo y costo de flete en remisiones.' from dual union all
       select 'PRODUCCION',   'Producción / fórmulas',          'PRD', 'Órdenes de producción con consumo de insumos.' from dual union all
       select 'IMPORTACION',  'Importación / despacho',         'COM', 'Costeo de importaciones y gastos de despacho.' from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, modulo, descripcion)
    values (s.codigo, s.nombre, s.modulo, s.descripcion);

merge into erp_gen_rubro t
using (select 'COMERCIO'      codigo, 'Comercio minorista / mayorista' nombre, 'Ventas al contado y crédito con stock simple.' descripcion from dual union all
       select 'DISTRIBUIDORA',        'Distribuidora',                          'Reparto con vendedores, lotes, vencimientos y fletes.' from dual union all
       select 'AGRO',                 'Agro / cooperativa / acopio',             'Safra, báscula, financiación a productores y lotes.' from dual union all
       select 'INDUSTRIA',            'Industria',                               'Producción, lotes y centros de costo por planta.' from dual union all
       select 'SERVICIOS',            'Servicios',                               'Sin stock o con stock mínimo; centros de costo.' from dual union all
       select 'FARMACIA',             'Farmacia / salud',                        'Lotes y vencimientos obligatorios.' from dual union all
       select 'IMPORTADORA',          'Importadora',                             'Importación, multimoneda, lotes y series.' from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, descripcion)
    values (s.codigo, s.nombre, s.descripcion);

merge into erp_gen_rubro_func t
using (select r.rubro_id, f.funcionalidad_id
         from (select 'COMERCIO' rubro, 'VENDEDOR' func from dual union all
               select 'DISTRIBUIDORA', 'VENDEDOR'     from dual union all
               select 'DISTRIBUIDORA', 'LOTE'         from dual union all
               select 'DISTRIBUIDORA', 'VENCIMIENTO'  from dual union all
               select 'DISTRIBUIDORA', 'FLETE'        from dual union all
               select 'AGRO',          'SAFRA'        from dual union all
               select 'AGRO',          'PESAJE'       from dual union all
               select 'AGRO',          'LOTE'         from dual union all
               select 'AGRO',          'DEPARTAMENTO' from dual union all
               select 'AGRO',          'CENTRO_COSTO' from dual union all
               select 'INDUSTRIA',     'PRODUCCION'   from dual union all
               select 'INDUSTRIA',     'LOTE'         from dual union all
               select 'INDUSTRIA',     'CENTRO_COSTO' from dual union all
               select 'INDUSTRIA',     'DEPARTAMENTO' from dual union all
               select 'SERVICIOS',     'CENTRO_COSTO' from dual union all
               select 'FARMACIA',      'LOTE'         from dual union all
               select 'FARMACIA',      'VENCIMIENTO'  from dual union all
               select 'IMPORTADORA',   'IMPORTACION'  from dual union all
               select 'IMPORTADORA',   'LOTE'         from dual union all
               select 'IMPORTADORA',   'SERIE'        from dual) x
         join erp_gen_rubro r on r.codigo = x.rubro
         join erp_gen_funcionalidad f on f.codigo = x.func) s
   on (t.rubro_id = s.rubro_id and t.funcionalidad_id = s.funcionalidad_id)
 when not matched then
    insert (rubro_id, funcionalidad_id) values (s.rubro_id, s.funcionalidad_id);

-- Roles de persona ------------------------------------------------------------------------
merge into erp_gen_tipo_rol t
using (select 'CLIENTE' codigo, 'Cliente' nombre, 'S' es_ventas, 'N' es_compras, 'S' es_cobrar, 'N' es_pagar, 'N' es_stock from dual union all
       select 'PROVEEDOR',     'Proveedor',          'N', 'S', 'N', 'S', 'N' from dual union all
       select 'EMPLEADO',      'Empleado',           'N', 'N', 'S', 'S', 'N' from dual union all
       select 'VENDEDOR',      'Vendedor',           'S', 'N', 'N', 'S', 'N' from dual union all
       select 'TRANSPORTISTA', 'Transportista',      'S', 'S', 'N', 'S', 'S' from dual union all
       select 'PRODUCTOR',     'Productor',          'S', 'S', 'S', 'S', 'S' from dual union all
       select 'BANCO',         'Banco / financiera', 'N', 'N', 'S', 'S', 'N' from dual) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (codigo, nombre, es_ventas, es_compras, es_cobrar, es_pagar, es_stock)
    values (s.codigo, s.nombre, s.es_ventas, s.es_compras, s.es_cobrar, s.es_pagar, s.es_stock);

-- Parámetros generales (empresa_id null = valor por defecto de todas) -------------------
merge into erp_gen_parametro t
using (select 'ERP_GEN_COTIZACION_DIAS_MAX' codigo, null valor, 'N' tipo_dato,
              'Antigüedad máxima (días) de la cotización usada. Vacío = sin límite.' descripcion from dual union all
       select 'ERP_GEN_PERIODO_ESTRICTO', 'N', 'S',
              'S = solo se registran documentos en períodos creados y abiertos. N = período sin crear se considera abierto.' from dual union all
       select 'ERP_GEN_ACCESO_SUCURSAL_ESTRICTO', 'N', 'S',
              'S = el usuario solo opera las sucursales asignadas. N = sin asignaciones opera todas las de la empresa.' from dual) s
   on (t.codigo = s.codigo and t.empresa_id is null)
 when not matched then
    insert (empresa_id, codigo, valor, tipo_dato, descripcion)
    values (null, s.codigo, s.valor, s.tipo_dato, s.descripcion);

commit;

-- >>> apps/erp/database/data/erp_gen_mensajes_error.sql
-- =============================================================================
-- Mensajes de error por constraint del módulo General del ERP (idempotente).
-- Los usa el manejador central adm_gen_error_api.
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;
merge into adm_gen_mensaje_error t
using (
    select 'UK_ERP_MON_CODIGO'              codigo, 'Ya existe una moneda con ese código.' mensaje from dual union all
    select 'CK_ERP_MON_CODIGO_MAYUS',               'El código de la moneda debe estar en mayúsculas (ISO 4217).' from dual union all
    select 'CK_ERP_MON_DECIMALES',                  'Los decimales de importe deben estar entre 0 y 4.' from dual union all
    select 'CK_ERP_MON_DECIMALES_PRECIO',           'Los decimales de precio deben estar entre 0 y 6.' from dual union all
    select 'UK_ERP_PAI_CODIGO',                     'Ya existe un país con ese código.' from dual union all
    select 'UK_ERP_PAI_CODIGO_ISO3',                'Ya existe un país con ese código ISO de 3 letras.' from dual union all
    select 'CK_ERP_PAI_CODIGO_MAYUS',               'Los códigos del país deben estar en mayúsculas.' from dual union all
    select 'UK_ERP_UBI_PAIS_TIPO_CODIGO',           'Ya existe una ubicación de ese tipo con ese código oficial en el país.' from dual union all
    select 'UK_ERP_IMP_PAIS_CODIGO',                'Ya existe un impuesto con ese código en el país.' from dual union all
    select 'CK_ERP_IMP_CODIGO_MAYUS',               'El código del impuesto debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_IMTA_IMP_CODIGO',                'El impuesto ya tiene una tasa con ese código.' from dual union all
    select 'CK_ERP_IMTA_CODIGO_MAYUS',              'El código de la tasa debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_ITV_TASA_FECHA',                 'La tasa ya tiene una vigencia que empieza en esa fecha.' from dual union all
    select 'CK_ERP_ITV_PORCENTAJE',                 'El porcentaje debe estar entre 0 y 100.' from dual union all
    select 'UK_ERP_CAFI_PAIS_CODIGO',               'Ya existe una categoría fiscal con ese código en el país.' from dual union all
    select 'CK_ERP_CAFI_CODIGO_MAYUS',              'El código de la categoría fiscal debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_CATA_CAFI_TASA',                 'La categoría fiscal ya incluye esa tasa.' from dual union all
    select 'CK_ERP_CATA_PORCENTAJE_BASE',           'El porcentaje de la base debe ser mayor que 0 y no superar 100.' from dual union all
    select 'UK_ERP_COT_MON_FECHA_EMP',              'Ya existe una cotización para ese par de monedas en esa fecha.' from dual union all
    select 'CK_ERP_COT_MONEDAS',                    'La moneda origen y la moneda destino deben ser distintas.' from dual union all
    select 'CK_ERP_COT_TASAS_POS',                  'Las tasas de compra y venta deben ser mayores que cero.' from dual union all
    select 'UK_ERP_EMCF_EMPRESA',                   'La empresa ya tiene su configuración del ERP.' from dual union all
    select 'UK_ERP_SUC_EMP_CODIGO',                 'Ya existe una sucursal con ese código en la empresa.' from dual union all
    select 'UK_ERP_SUC_EMP_ESTABLEC',               'Ya existe una sucursal con ese código de establecimiento en la empresa.' from dual union all
    select 'CK_ERP_SUC_CODIGO_MAYUS',               'El código de la sucursal debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_SUC_ESTABLECIMIENTO',            'El establecimiento debe tener 3 dígitos (ej. 001).' from dual union all
    select 'UK_ERP_TDI_PAIS_CODIGO',                'Ya existe un tipo de documento con ese código en el país.' from dual union all
    select 'CK_ERP_TDI_CODIGO_MAYUS',               'El código del tipo de documento debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_PRS_TDI_NRO',                    'Ya existe una persona con ese tipo y número de documento.' from dual union all
    select 'UK_ERP_PAR_CODIGO_EMP',                 'Ese parámetro ya está definido para la empresa (o como valor general).' from dual union all
    select 'CK_ERP_PAR_CODIGO_MAYUS',               'El código del parámetro debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_PERI_EMP_MOD_ANIO_MES',          'Ese período ya existe para la empresa y el módulo.' from dual union all
    select 'FK_ERP_PAI_MON',                        'No se puede eliminar la moneda: es la moneda de un país.' from dual union all
    select 'FK_ERP_COT_MON_ORIGEN',                 'No se puede eliminar la moneda: tiene cotizaciones.' from dual union all
    select 'FK_ERP_COT_MON_DESTINO',                'No se puede eliminar la moneda: tiene cotizaciones.' from dual union all
    select 'FK_ERP_EMCF_MON_FUNC',                  'No se puede eliminar la moneda: es la moneda funcional de una empresa.' from dual union all
    select 'FK_ERP_UBI_PAI',                        'No se puede eliminar el país: tiene ubicaciones.' from dual union all
    select 'FK_ERP_UBI_UBI_PADRE',                  'No se puede eliminar la ubicación: tiene ubicaciones dependientes.' from dual union all
    select 'FK_ERP_IMP_PAI',                        'No se puede eliminar el país: tiene impuestos.' from dual union all
    select 'FK_ERP_IMTA_IMP',                       'No se puede eliminar el impuesto: tiene tasas.' from dual union all
    select 'FK_ERP_CATA_IMTA',                      'No se puede eliminar la tasa: la usa una categoría fiscal.' from dual union all
    select 'FK_ERP_PRS_TDI',                        'No se puede eliminar el tipo de documento: lo usan personas.' from dual union all
    select 'FK_ERP_PRS_PAI',                        'No se puede eliminar el país: lo usan personas.' from dual union all
    select 'FK_ERP_SUC_UBI',                        'No se puede eliminar la ubicación: la usa una sucursal.' from dual union all
    select 'UK_ERP_FUNC_CODIGO',                    'Ya existe una funcionalidad con ese código.' from dual union all
    select 'UK_ERP_RUB_CODIGO',                     'Ya existe un rubro con ese código.' from dual union all
    select 'UK_ERP_RUFU_RUB_FUNC',                  'El rubro ya incluye esa funcionalidad.' from dual union all
    select 'UK_ERP_EMFU_EMP_FUNC',                  'La empresa ya tiene esa funcionalidad.' from dual union all
    select 'UK_ERP_DPTO_EMP_CODIGO',                'Ya existe un departamento con ese código en la empresa.' from dual union all
    select 'UK_ERP_PTEX_SUC_CODIGO',                'La sucursal ya tiene un punto de expedición con ese código.' from dual union all
    select 'CK_ERP_PTEX_CODIGO',                    'El punto de expedición debe tener 3 dígitos (ej. 001).' from dual union all
    select 'UK_ERP_USSU_USU_SUC_DPTO',              'El usuario ya tiene asignada esa sucursal (y departamento).' from dual union all
    select 'UK_ERP_DPO_SUC_CODIGO',                 'La sucursal ya tiene un depósito con ese código.' from dual union all
    select 'UK_ERP_TIRL_CODIGO',                    'Ya existe un rol de persona con ese código.' from dual union all
    select 'UK_ERP_PRRO_PRS_EMP_ROL',               'La persona ya tiene ese rol en la empresa.' from dual union all
    select 'FK_ERP_DPTO_SUC',                       'No se puede eliminar la sucursal: tiene departamentos.' from dual union all
    select 'FK_ERP_PTEX_SUC',                       'No se puede eliminar la sucursal: tiene puntos de expedición.' from dual union all
    select 'FK_ERP_DPO_SUC',                        'No se puede eliminar la sucursal: tiene depósitos.' from dual union all
    select 'FK_ERP_PTEX_DPTO',                      'No se puede eliminar el departamento: tiene puntos de expedición.' from dual union all
    select 'FK_ERP_DPO_DPTO',                       'No se puede eliminar el departamento: tiene depósitos.' from dual union all
    select 'FK_ERP_PRRO_TIRL',                      'No se puede eliminar el rol: lo tienen personas.' from dual union all
    select 'FK_ERP_EMCF_RUB',                       'No se puede eliminar el rubro: lo usa una empresa.' from dual union all
    select 'UK_ERP_PRDO_TDI_NRO',                   'Ya existe una persona con ese tipo y número de documento.' from dual union all
    select 'CK_ERP_PRDO_VIGENCIA',                  'La fecha de vencimiento debe ser igual o posterior a la fecha desde.' from dual union all
    select 'UK_ERP_FERI_PAIS_FECHA',                'Ya hay un feriado cargado en esa fecha para el país.' from dual union all
    select 'UK_ERP_PEHA_PERI_USU',                  'El usuario ya tiene una habilitación para ese período.' from dual union all
    select 'CK_ERP_ITV_MINIMO',                     'El monto mínimo debe ser positivo e indicar su moneda.' from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje
 when not matched then
    insert (codigo, mensaje) values (s.codigo, s.mensaje);

commit;
