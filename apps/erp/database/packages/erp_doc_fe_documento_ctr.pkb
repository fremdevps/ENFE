create or replace package body erp_doc_fe_documento_ctr
as

    procedure insertar (
        i_registro         in  erp_doc_fe_documento%rowtype,
        o_fe_documento_id  out erp_doc_fe_documento.fe_documento_id%type
    ) is
    begin
        insert into erp_doc_fe_documento
               (empresa_id, origen_modulo, origen_tipo, origen_id, tipo_documento_id, numerador_id, fe_certificado_id,
                tipo_de, timbrado, establecimiento, punto_expedicion, numero, serie, tipo_emision, cdc, codigo_seguridad,
                version_formato, ambiente, fecha_emision, fecha_firma, fecha_limite_envio, receptor_documento,
                receptor_nombre, moneda, monto_total, monto_impuesto, cantidad_items, digest_value, url_qr, datos,
                xml_firmado, estado_envio, estado_sifen, intentos, proximo_intento)
        values (i_registro.empresa_id, upper(i_registro.origen_modulo), upper(i_registro.origen_tipo), i_registro.origen_id,
                i_registro.tipo_documento_id, i_registro.numerador_id, i_registro.fe_certificado_id,
                i_registro.tipo_de, i_registro.timbrado, i_registro.establecimiento, i_registro.punto_expedicion,
                i_registro.numero, i_registro.serie, i_registro.tipo_emision, i_registro.cdc, i_registro.codigo_seguridad,
                i_registro.version_formato, i_registro.ambiente, i_registro.fecha_emision, i_registro.fecha_firma,
                i_registro.fecha_limite_envio, i_registro.receptor_documento,
                i_registro.receptor_nombre, i_registro.moneda, i_registro.monto_total, i_registro.monto_impuesto,
                i_registro.cantidad_items, i_registro.digest_value, i_registro.url_qr, i_registro.datos,
                i_registro.xml_firmado, i_registro.estado_envio, i_registro.estado_sifen, 0, i_registro.proximo_intento)
        returning fe_documento_id into o_fe_documento_id;
    end insertar;

    function obtener (
        i_fe_documento_id  in erp_doc_fe_documento.fe_documento_id%type
    ) return erp_doc_fe_documento%rowtype is
        r_documento  erp_doc_fe_documento%rowtype;
    begin
        select *
          into r_documento
          from erp_doc_fe_documento
         where fe_documento_id = i_fe_documento_id;
        return r_documento;
    exception
        when no_data_found then
            return r_documento;
    end obtener;

    function bloquear (
        i_fe_documento_id  in erp_doc_fe_documento.fe_documento_id%type
    ) return erp_doc_fe_documento%rowtype is
        r_documento  erp_doc_fe_documento%rowtype;
    begin
        select *
          into r_documento
          from erp_doc_fe_documento
         where fe_documento_id = i_fe_documento_id
           for update;
        return r_documento;
    exception
        when no_data_found then
            return r_documento;
    end bloquear;

    function bloquear_pendientes (
        i_empresa_id  in erp_doc_fe_documento.empresa_id%type,
        i_tipo_de     in erp_doc_fe_documento.tipo_de%type,
        i_cantidad    in pls_integer,
        i_estado_1    in erp_doc_fe_documento.estado_envio%type,
        i_estado_2    in erp_doc_fe_documento.estado_envio%type
    ) return sys.odcinumberlist is
        cursor cur_pendientes is
            select fe_documento_id
              from erp_doc_fe_documento
             where empresa_id = i_empresa_id
               and estado_envio in (i_estado_1, i_estado_2)
               and proximo_intento <= localtimestamp
               and (i_tipo_de is null or tipo_de = i_tipo_de)
             order by fecha_limite_envio, fe_documento_id
               for update skip locked;
        v_ids  sys.odcinumberlist := sys.odcinumberlist();
        v_id   erp_doc_fe_documento.fe_documento_id%type;
    begin
        -- con skip locked el bloqueo se toma al hacer fetch: se lee fila a fila hasta la cantidad
        -- pedida (no se puede limitar con fetch first, que no admite for update)
        open cur_pendientes;
        loop
            exit when v_ids.count >= coalesce(i_cantidad, 0);
            fetch cur_pendientes into v_id;
            exit when cur_pendientes%notfound;
            v_ids.extend;
            v_ids(v_ids.count) := v_id;
        end loop;
        close cur_pendientes;
        return v_ids;
    end bloquear_pendientes;

    procedure actualizar_ciclo (
        i_registro  in erp_doc_fe_documento%rowtype
    ) is
    begin
        update erp_doc_fe_documento
           set estado_envio      = i_registro.estado_envio,
               estado_sifen      = i_registro.estado_sifen,
               estado_receptor   = i_registro.estado_receptor,
               fe_lote_id        = i_registro.fe_lote_id,
               codigo_respuesta  = i_registro.codigo_respuesta,
               mensaje_respuesta = i_registro.mensaje_respuesta,
               protocolo         = i_registro.protocolo,
               fecha_envio       = i_registro.fecha_envio,
               fecha_respuesta   = i_registro.fecha_respuesta,
               intentos          = i_registro.intentos,
               proximo_intento   = i_registro.proximo_intento,
               ultimo_error      = i_registro.ultimo_error
         where fe_documento_id = i_registro.fe_documento_id;
    end actualizar_ciclo;

end erp_doc_fe_documento_ctr;
/
