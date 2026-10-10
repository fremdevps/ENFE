-- =============================================================================
-- Mensajes de error por constraint del módulo General del ERP (idempotente).
-- Los usa el manejador central adm_gen_error_api.
-- =============================================================================
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
    select 'FK_ERP_EMCF_RUB',                       'No se puede eliminar el rubro: lo usa una empresa.' from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje
 when not matched then
    insert (codigo, mensaje) values (s.codigo, s.mensaje);

commit;
