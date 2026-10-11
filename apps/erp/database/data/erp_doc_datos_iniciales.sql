-- =============================================================================
-- Datos iniciales del módulo Documentos del ERP (idempotente).
--   1. Clases de documento (catálogo de sistema).
--   2. Motivos tipificados (códigos SIFEN: Manual Técnico SIFEN v150, campo E401, pág. 77;
--      motivos de inutilización: §11.1.1, pág. 112; de cancelación: tabla J, pág. 117).
--   3. Códigos de respuesta de SIFEN (Manual Técnico SIFEN v150 cap. 12, pág. 145-159).
--   4. Tipos de documento base de cada empresa ya configurada en el ERP.
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;

-- 1. Clases de documento -------------------------------------------------------
merge into erp_doc_clase_documento t
using (
    select 'FACTURA' codigo, 'Factura' nombre, 'Venta o compra de bienes y servicios' descripcion, 10 orden from dual union all
    select 'NOTA_CREDITO', 'Nota de crédito', 'Devoluciones, descuentos y ajustes a favor del receptor', 20 from dual union all
    select 'NOTA_DEBITO', 'Nota de débito', 'Recargos y ajustes a cargo del receptor', 30 from dual union all
    select 'REMISION', 'Nota de remisión', 'Traslado de mercaderías', 40 from dual union all
    select 'AUTOFACTURA', 'Autofactura', 'Compra a quien no emite comprobantes', 50 from dual union all
    select 'RECIBO', 'Recibo', 'Cobro de dinero', 60 from dual union all
    select 'ORDEN_PAGO', 'Orden de pago', 'Pago a proveedores y terceros', 70 from dual union all
    select 'ANTICIPO', 'Anticipo', 'Dinero recibido o entregado a cuenta', 80 from dual union all
    select 'RETENCION', 'Comprobante de retención', 'Retenciones de impuestos practicadas o sufridas', 90 from dual union all
    select 'AJUSTE', 'Ajuste', 'Ajustes internos de stock o de cuenta corriente', 100 from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.nombre = s.nombre, t.descripcion = s.descripcion, t.orden = s.orden
 when not matched then
    insert (codigo, nombre, descripcion, orden) values (s.codigo, s.nombre, s.descripcion, s.orden);

-- 2. Motivos generales (empresa nula) ------------------------------------------
merge into erp_doc_motivo t
using (
    -- notas de crédito y débito: motivo de emisión SIFEN (iMotEmi / dDesMotEmi)
    select n.tipo, m.codigo, m.nombre, m.codigo_sifen, m.nombre descripcion_sifen
      from (select 'C' tipo from dual union all select 'D' from dual) n
     cross join (select 'DEVOLUCION_AJUSTE' codigo, 'Devolución y Ajuste de precios' nombre, 1 codigo_sifen from dual union all
                 select 'DEVOLUCION', 'Devolución', 2 from dual union all
                 select 'DESCUENTO', 'Descuento', 3 from dual union all
                 select 'BONIFICACION', 'Bonificación', 4 from dual union all
                 select 'CREDITO_INCOBRABLE', 'Crédito incobrable', 5 from dual union all
                 select 'RECUPERO_COSTO', 'Recupero de costo', 6 from dual union all
                 select 'RECUPERO_GASTO', 'Recupero de gasto', 7 from dual union all
                 select 'AJUSTE_PRECIO', 'Ajuste de precio', 8 from dual) m
    union all
    select 'A', 'ERROR_EMISION', 'Error en la emisión del documento', null, null from dual union all
    select 'A', 'NO_ENTREGADO', 'La mercadería no fue entregada al cliente', null, null from dual union all
    select 'A', 'SERVICIO_NO_PRESTADO', 'El servicio no fue prestado al cliente', null, null from dual union all
    select 'I', 'SALTO_NUMERACION', 'Salto en la numeración', null, null from dual union all
    select 'I', 'ERROR_LLENADO', 'Error técnico de llenado en la emisión', null, null from dual union all
    select 'I', 'RECHAZO', 'Documento rechazado cuyo ajuste cambia el código de control', null, null from dual union all
    select 'I', 'EXTRAVIO', 'Extravío del comprobante preimpreso', null, null from dual union all
    select 'I', 'DETERIORO', 'Deterioro del comprobante preimpreso', null, null from dual union all
    select 'R', 'DATOS_INCORRECTOS', 'Datos incorrectos del documento', null, null from dual union all
    select 'R', 'DESCONOCIMIENTO', 'Operación desconocida por el receptor', null, null from dual
) s
   on (t.tipo = s.tipo and t.codigo = s.codigo and t.empresa_id is null)
 when matched then
    update set t.nombre = s.nombre, t.codigo_sifen = s.codigo_sifen, t.descripcion_sifen = s.descripcion_sifen
 when not matched then
    insert (empresa_id, tipo, codigo, nombre, codigo_sifen, descripcion_sifen)
    values (null, s.tipo, s.codigo, s.nombre, s.codigo_sifen, s.descripcion_sifen);

-- 3. Códigos de respuesta de SIFEN ----------------------------------------------
-- efecto: A aprobado/éxito del documento o evento, O aprobado con observación, R rechazo,
--         E en proceso (volver a consultar), I informativo (éxito de un servicio de consulta o recepción).
merge into erp_doc_fe_cod_respuesta t
using (
    select '0001' codigo, 'Certificado de transmisor inválido' mensaje, 'TLS' servicio, 'R' efecto, 'N' es_reintentable,
           'Revisar el certificado de la conexión: debe ser de un prestador habilitado y permitir autenticación de cliente.' como_resolver from dual union all
    select '0002', 'Plazo de validez del certificado digital', 'TLS', 'R', 'N', 'El certificado de la conexión está vencido o todavía no rige: renovarlo.' from dual union all
    select '0003', 'Cadena de certificación', 'TLS', 'R', 'N', 'El certificado no pertenece a un prestador habilitado o fue revocado.' from dual union all
    select '0004', 'LCR del certificado transmisor', 'TLS', 'R', 'S', 'La lista de certificados revocados no estuvo disponible: reintentar más tarde.' from dual union all
    select '0005', 'Certificado del transmisor revocado', 'TLS', 'R', 'N', 'Obtener un certificado nuevo.' from dual union all
    select '0006', 'Certificado raíz no pertenece al MIC', 'TLS', 'R', 'N', 'Usar un certificado emitido bajo la autoridad raíz del país.' from dual union all
    select '0007', 'No existe la extensión del RUC del emisor en el certificado', 'TLS', 'R', 'N', 'El certificado debe llevar el RUC (SerialNumber o SubjectAlternativeName).' from dual union all
    select '0100', 'Fallo de schema XML del área de datos', 'Mensaje', 'R', 'N', 'El XML no cumple el esquema: validar contra el XSD de la versión.' from dual union all
    select '0101', 'Fallo de schema: no existe el campo raíz esperado para el mensaje', 'Mensaje', 'R', 'N', 'Revisar el elemento raíz del mensaje.' from dual union all
    select '0102', 'Fallo de schema: no existe el atributo versión para el campo raíz esperado', 'Mensaje', 'R', 'N', 'Revisar la versión del formato.' from dual union all
    select '0104', 'Existe algún namespace diferente del namespace estándar del DE', 'Mensaje', 'R', 'N', 'Quitar namespaces ajenos.' from dual union all
    select '0105', 'Existen caracteres de edición en el inicio o en el final del mensaje, o entre los campos XML', 'Mensaje', 'R', 'N', 'El XML no debe llevar espacios ni saltos entre etiquetas.' from dual union all
    select '0106', 'Utilizado prefijo en el namespace', 'Mensaje', 'R', 'N', 'No usar prefijos de namespace.' from dual union all
    select '0107', 'Utilizada codificación diferente de UTF-8', 'Mensaje', 'R', 'N', 'Transmitir en UTF-8.' from dual union all
    select '0120', 'Certificado inválido', 'Firma', 'R', 'N', 'Falta el certificado de firma o no permite firma digital y no repudio.' from dual union all
    select '0121', 'Fechas del certificado inválidas', 'Firma', 'R', 'N', 'El certificado de firma está vencido o todavía no rige.' from dual union all
    select '0122', 'No existe la extensión del RUC en el certificado', 'Firma', 'R', 'N', 'El certificado de firma debe llevar el RUC.' from dual union all
    select '0123', 'Cadena de certificación inválida', 'Firma', 'R', 'N', 'El certificado de firma no es de un prestador habilitado.' from dual union all
    select '0124', 'Problema en la LCR del certificado de firma', 'Firma', 'R', 'S', 'La lista de certificados revocados no estuvo disponible: reintentar más tarde.' from dual union all
    select '0125', 'Certificado de firma revocado', 'Firma', 'R', 'N', 'Obtener un certificado nuevo y volver a firmar.' from dual union all
    select '0126', 'Certificado raíz no corresponde al MIC', 'Firma', 'R', 'N', 'Usar un certificado emitido bajo la autoridad raíz del país.' from dual union all
    select '0140', 'Firma difiere del estándar', 'Firma', 'R', 'N', 'Revisar la referencia (URI) y las transformaciones de la firma.' from dual union all
    select '0141', 'Valor de la firma (SignatureValue) diferente del calculado', 'Firma', 'R', 'N', 'El documento cambió después de firmarse o la canonicalización no coincide: volver a generar y firmar.' from dual union all
    select '0142', 'RUC del certificado utilizado para firmar no pertenece al contribuyente emisor', 'Firma', 'R', 'N', 'Firmar con el certificado del emisor del documento.' from dual union all
    select '0160', 'XML malformado', 'Mensaje', 'R', 'N', 'Revisar la estructura del XML.' from dual union all
    select '0161', 'Servidor de procesamiento momentáneamente sin respuesta', 'Mensaje', 'R', 'S', 'Reintentar más tarde.' from dual union all
    select '0162', 'Servidor de procesamiento paralizado, sin tiempo de regreso', 'Mensaje', 'R', 'S', 'Reintentar más tarde; evaluar la contingencia.' from dual union all
    select '0163', 'Versión del formato del WS no soportada', 'Mensaje', 'R', 'N', 'Revisar la versión del formato configurada.' from dual union all
    select '0180', 'Elemento de cabecera inexistente en el SOAP Header', 'Mensaje', 'R', 'N', 'Revisar el sobre SOAP.' from dual union all
    select '0183', 'RUC del certificado utilizado en la conexión no pertenece a un contribuyente activo', 'Mensaje', 'R', 'N', 'Regularizar el estado del RUC.' from dual union all
    select '0200', 'Mensaje de datos de entrada del WS siRecepDE superior a 1000 KB', 'siRecepDE', 'R', 'N', 'Reducir el tamaño del documento.' from dual union all
    select '0260', 'Autorización del DE satisfactoria', 'siRecepDE', 'A', 'N', null from dual union all
    select '0270', 'Mensaje de datos de entrada del WS siRecepLoteDE superior a 10.000 KB', 'siRecepLoteDE', 'R', 'N', 'Enviar lotes más chicos.' from dual union all
    select '0300', 'Lote recibido con éxito', 'siRecepLoteDE', 'I', 'N', 'Consultar el resultado con el número de lote.' from dual union all
    select '0301', 'Lote no encolado para procesamiento', 'siRecepLoteDE', 'R', 'S', 'Volver a enviar los documentos.' from dual union all
    select '0320', 'Mensaje de datos de entrada del WS siResultLoteDE superior a 1000 KB', 'siResultLoteDE', 'R', 'N', null from dual union all
    select '0340', 'RUC del certificado de conexión no autorizado a consultar el lote', 'siResultLoteDE', 'R', 'N', 'El lote solo lo consulta el RUC que lo transmitió.' from dual union all
    select '0360', 'Número del lote inexistente', 'siResultLoteDE', 'R', 'N', 'Consultar cada documento por su código de control.' from dual union all
    select '0361', 'Lote en procesamiento', 'siResultLoteDE', 'E', 'S', 'Volver a consultar más tarde.' from dual union all
    select '0362', 'Procesamiento de lote concluido', 'siResultLoteDE', 'I', 'N', 'Registrar el resultado de cada documento.' from dual union all
    select '0363', 'Lote con tipos distintos de DE', 'siResultLoteDE', 'R', 'N', 'Un lote lleva un solo tipo de documento.' from dual union all
    select '0380', 'Mensaje de datos de entrada del WS siConsDE superior a 1000 KB', 'siConsDE', 'R', 'N', null from dual union all
    select '0420', 'CDC inexistente', 'siConsDE', 'I', 'N', 'El documento no está en SIFEN: volver a enviarlo.' from dual union all
    select '0421', 'RUC del certificado sin permiso para consultar el DE', 'siConsDE', 'R', 'N', 'Consultar con el certificado del emisor o del receptor.' from dual union all
    select '0422', 'CDC encontrado', 'siConsDE', 'I', 'N', 'Tomar el resultado del contenedor del documento.' from dual union all
    select '0460', 'Mensaje de datos de entrada del WS siConsRUC superior a 1000 KB', 'siConsRUC', 'R', 'N', null from dual union all
    select '0500', 'RUC no existe', 'siConsRUC', 'I', 'N', 'Revisar el RUC del receptor.' from dual union all
    select '0501', 'RUC sin permiso para utilizar el WS', 'siConsRUC', 'R', 'N', null from dual union all
    select '0502', 'RUC encontrado', 'siConsRUC', 'I', 'N', null from dual union all
    select '0560', 'Mensaje de datos de entrada del WS siRecepEvento superior a 1000 KB', 'siRecepEvento', 'R', 'N', null from dual union all
    select '0600', 'Evento registrado correctamente', 'siRecepEvento', 'A', 'N', null from dual union all
    select '1000', 'CDC no correspondiente con las informaciones del XML', 'DE', 'R', 'N', 'El código de control no coincide con los campos del documento: volver a generar.' from dual union all
    select '1001', 'CDC duplicado', 'DE', 'R', 'N', 'Ya se autorizó un documento con ese código de control: consultar su estado antes de reenviar.' from dual union all
    select '1002', 'Documento electrónico duplicado', 'DE', 'R', 'N', 'Ya se autorizó un documento con ese timbrado, establecimiento, punto y número.' from dual union all
    select '1003', 'DV del CDC inválido', 'DE', 'R', 'N', 'Recalcular el dígito verificador del código de control.' from dual union all
    select '1004', 'La fecha y hora de la firma digital es adelantada', 'DE', 'R', 'N', 'Revisar la hora del servidor (sincronizar el reloj).' from dual union all
    select '1005', 'Transmisión extemporánea del DE', 'DE', 'O', 'N', 'El documento fue aprobado fuera del plazo de transmisión; puede haber sanción.' from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje, t.servicio = s.servicio, t.efecto = s.efecto,
               t.es_reintentable = s.es_reintentable, t.como_resolver = s.como_resolver
 when not matched then
    insert (codigo, mensaje, servicio, efecto, es_reintentable, como_resolver)
    values (s.codigo, s.mensaje, s.servicio, s.efecto, s.es_reintentable, s.como_resolver);

-- 4. Tipos de documento base para las empresas ya configuradas en el ERP -------
begin
    for r in (select empresa_id from erp_gen_empresa_config) loop
        erp_doc_tipo_documento_api.crear_base(i_empresa_id => r.empresa_id);
    end loop;
end;
/

commit;
