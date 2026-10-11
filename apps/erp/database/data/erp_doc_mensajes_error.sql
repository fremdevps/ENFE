-- =============================================================================
-- Mensajes de error por constraint del módulo Documentos del ERP (idempotente).
-- Los usa el manejador central adm_gen_error_api.
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;
merge into adm_gen_mensaje_error t
using (
    select 'UK_ERP_CLDO_CODIGO'             codigo, 'Ya existe una clase de documento con ese código.' mensaje from dual union all
    select 'CK_ERP_CLDO_CODIGO_MAYUS',              'El código de la clase de documento debe estar en mayúsculas.' from dual union all
    select 'UK_ERP_TIDO_EMP_CODIGO',                'La empresa ya tiene un tipo de documento con ese código.' from dual union all
    select 'CK_ERP_TIDO_CODIGO_MAYUS',              'El código del tipo de documento debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_TIDO_MODULO',                    'El módulo del tipo de documento debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_TIDO_CUENTA_COHERENTE',          'Si el documento afecta una cuenta corriente indique el signo (débito o crédito); si no afecta, ambos van en "ninguno".' from dual union all
    select 'CK_ERP_TIDO_SIFEN',                     'Los tipos de emisión electrónica llevan el código SIFEN; los demás no.' from dual union all
    select 'CK_ERP_TIDO_ELECTR_TIMBRADO',           'Un tipo de documento electrónico siempre exige timbrado.' from dual union all
    select 'CK_ERP_TIDO_MAX_ITEMS',                 'El máximo de ítems debe ser mayor que cero.' from dual union all
    select 'CK_ERP_TIDO_DIAS_ANTIGUEDAD',           'La antigüedad máxima no puede ser negativa.' from dual union all
    select 'FK_ERP_TIDO_CLDO',                      'No se puede eliminar la clase: la usan tipos de documento.' from dual union all
    select 'UK_ERP_TDFI_TIDO_FECHA',                'El tipo de documento ya tiene un código fiscal que rige desde esa fecha.' from dual union all
    select 'UK_ERP_MOTI_TIPO_CODIGO_EMP',           'Ya existe un motivo de ese tipo con ese código.' from dual union all
    select 'CK_ERP_MOTI_CODIGO_MAYUS',              'El código del motivo debe estar en mayúsculas.' from dual union all
    select 'CK_ERP_MOTI_SIFEN',                     'El código SIFEN del motivo va con su descripción y solo en motivos de notas de crédito o débito.' from dual union all
    select 'UK_ERP_TIMB_EMP_NUMERO',                'La empresa ya tiene un timbrado con ese número.' from dual union all
    select 'CK_ERP_TIMB_NUMERO',                    'El número de timbrado debe tener 8 dígitos.' from dual union all
    select 'CK_ERP_TIMB_VIGENCIA',                  'El fin de vigencia del timbrado debe ser igual o posterior al inicio.' from dual union all
    select 'CK_ERP_TIMB_HASTA_PAPEL',               'Los timbrados preimpresos y autoimpresores llevan fecha de fin de vigencia.' from dual union all
    select 'UK_ERP_NUME_TIMB_PTEX_TIDO',            'Ya existe un numerador para ese timbrado, punto de expedición, tipo de documento y serie.' from dual union all
    select 'CK_ERP_NUME_SERIE',                     'La serie son dos letras mayúsculas (AA, AB…).' from dual union all
    select 'CK_ERP_NUME_RANGO',                     'El rango de numeración no es válido: el número final debe ser igual o mayor que el inicial.' from dual union all
    select 'CK_ERP_NUME_NUMERO_ACTUAL',             'El número actual debe estar dentro del rango del numerador.' from dual union all
    select 'CK_ERP_NUME_DIAS_AVISO',                'Los días de aviso no pueden ser negativos.' from dual union all
    select 'CK_ERP_NUME_PORCENTAJE_AVISO',          'El porcentaje de aviso debe estar entre 0 y 100.' from dual union all
    select 'FK_ERP_NUME_TIMB',                      'No se puede eliminar el timbrado: tiene numeradores.' from dual union all
    select 'FK_ERP_NUME_PTEX',                      'No se puede eliminar el punto de expedición: tiene numeradores.' from dual union all
    select 'FK_ERP_NUME_TIDO',                      'No se puede eliminar el tipo de documento: tiene numeradores.' from dual union all
    select 'UK_ERP_NUUS_NUME_USU',                  'El usuario ya está autorizado en ese numerador.' from dual union all
    select 'UK_ERP_NUIN_NUME_DESDE',                'Ese número ya está anulado o inutilizado.' from dual union all
    select 'CK_ERP_NUIN_RANGO',                     'El rango de números no es válido.' from dual union all
    select 'CK_ERP_NUIN_MOTIVO',                    'El motivo es obligatorio (al menos 5 caracteres).' from dual union all
    select 'FK_ERP_NUIN_NUME',                      'No se puede eliminar el numerador: tiene números anulados o inutilizados.' from dual union all
    select 'FK_ERP_NUIN_MOTI',                      'No se puede eliminar el motivo: está en uso.' from dual union all
    select 'UK_ERP_FECE_EMP_HUELLA',                'Ese certificado ya está cargado para la empresa.' from dual union all
    select 'CK_ERP_FECE_VIGENCIA',                  'Las fechas de validez del certificado no son correctas.' from dual union all
    select 'UK_ERP_FECO_EMPRESA',                   'La empresa ya tiene su configuración de facturación electrónica.' from dual union all
    select 'CK_ERP_FECO_VERSION',                   'La versión del formato debe tener 3 dígitos (ej. 150).' from dual union all
    select 'CK_ERP_FECO_ID_CSC',                    'El identificador del CSC debe tener hasta 4 dígitos.' from dual union all
    select 'CK_ERP_FECO_MAX_LOTE',                  'Un lote lleva entre 1 y 50 documentos.' from dual union all
    select 'CK_ERP_FECO_PLAZOS',                    'Los plazos en horas deben ser mayores que cero.' from dual union all
    select 'CK_ERP_FECO_REINTENTOS',                'La cantidad de intentos y la espera entre reintentos deben ser mayores que cero.' from dual union all
    select 'FK_ERP_FECO_FECE',                      'No se puede eliminar el certificado: es el que usa la empresa para firmar.' from dual union all
    select 'UK_ERP_FEAC_EMP_CODIGO',                'La empresa ya tiene cargada esa actividad económica.' from dual union all
    select 'UK_ERP_FECR_CODIGO',                    'Ya existe ese código de respuesta.' from dual union all
    select 'CK_ERP_FECR_CODIGO',                    'El código de respuesta debe tener 4 dígitos.' from dual union all
    select 'UK_ERP_FEDO_CDC',                       'Ya existe un documento electrónico con ese código de control.' from dual union all
    select 'UK_ERP_FEDO_ORIGEN',                    'Ese documento ya tiene su documento electrónico.' from dual union all
    select 'FK_ERP_FEDO_TIDO',                      'No se puede eliminar el tipo de documento: tiene documentos electrónicos.' from dual union all
    select 'FK_ERP_FEDO_NUME',                      'No se puede eliminar el numerador: tiene documentos electrónicos.' from dual union all
    select 'FK_ERP_FEDO_FECE',                      'No se puede eliminar el certificado: firmó documentos electrónicos.' from dual union all
    select 'UK_ERP_FELD_LOTE_DOCUMENTO',            'El documento ya está en ese lote.' from dual union all
    select 'CK_ERP_FEEV_REFERENCIA',                'El evento debe indicar el documento afectado o, si es una inutilización, el rango de números.' from dual union all
    select 'CK_ERP_FEEV_MOTIVO',                    'El motivo del evento es obligatorio (al menos 5 caracteres).' from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje
 when not matched then
    insert (codigo, mensaje) values (s.codigo, s.mensaje);

commit;
