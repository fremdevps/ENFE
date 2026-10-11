create or replace package body erp_doc_fe_lote_ctr
as

    procedure insertar (
        i_empresa_id  in  erp_doc_fe_lote.empresa_id%type,
        i_tipo_de     in  erp_doc_fe_lote.tipo_de%type,
        i_estado      in  erp_doc_fe_lote.estado%type,
        o_fe_lote_id  out erp_doc_fe_lote.fe_lote_id%type
    ) is
    begin
        insert into erp_doc_fe_lote (empresa_id, tipo_de, estado)
        values (i_empresa_id, i_tipo_de, i_estado)
        returning fe_lote_id into o_fe_lote_id;
    end insertar;

    procedure insertar_detalle (
        i_fe_lote_id       in erp_doc_fe_lote_detalle.fe_lote_id%type,
        i_fe_documento_id  in erp_doc_fe_lote_detalle.fe_documento_id%type,
        i_orden            in erp_doc_fe_lote_detalle.orden%type
    ) is
    begin
        insert into erp_doc_fe_lote_detalle (fe_lote_id, fe_documento_id, orden)
        values (i_fe_lote_id, i_fe_documento_id, i_orden);
    end insertar_detalle;

    function bloquear (
        i_fe_lote_id  in erp_doc_fe_lote.fe_lote_id%type
    ) return erp_doc_fe_lote%rowtype is
        r_lote  erp_doc_fe_lote%rowtype;
    begin
        select *
          into r_lote
          from erp_doc_fe_lote
         where fe_lote_id = i_fe_lote_id
           for update;
        return r_lote;
    exception
        when no_data_found then
            return r_lote;
    end bloquear;

    procedure actualizar (
        i_registro  in erp_doc_fe_lote%rowtype
    ) is
    begin
        update erp_doc_fe_lote
           set cantidad              = i_registro.cantidad,
               estado                = i_registro.estado,
               numero_lote           = i_registro.numero_lote,
               codigo_respuesta      = i_registro.codigo_respuesta,
               mensaje_respuesta     = i_registro.mensaje_respuesta,
               tiempo_proceso        = i_registro.tiempo_proceso,
               fecha_envio           = i_registro.fecha_envio,
               fecha_respuesta       = i_registro.fecha_respuesta,
               fecha_limite_consulta = i_registro.fecha_limite_consulta,
               intentos              = i_registro.intentos,
               proximo_intento       = i_registro.proximo_intento,
               ultimo_error          = i_registro.ultimo_error
         where fe_lote_id = i_registro.fe_lote_id;
    end actualizar;

    procedure actualizar_detalle (
        i_fe_lote_id         in erp_doc_fe_lote_detalle.fe_lote_id%type,
        i_fe_documento_id    in erp_doc_fe_lote_detalle.fe_documento_id%type,
        i_estado_resultado   in erp_doc_fe_lote_detalle.estado_resultado%type,
        i_codigo_respuesta   in erp_doc_fe_lote_detalle.codigo_respuesta%type,
        i_mensaje_respuesta  in erp_doc_fe_lote_detalle.mensaje_respuesta%type
    ) is
    begin
        update erp_doc_fe_lote_detalle
           set estado_resultado  = i_estado_resultado,
               codigo_respuesta  = i_codigo_respuesta,
               mensaje_respuesta = i_mensaje_respuesta
         where fe_lote_id      = i_fe_lote_id
           and fe_documento_id = i_fe_documento_id;
    end actualizar_detalle;

    function contar_sin_resultado (
        i_fe_lote_id  in erp_doc_fe_lote_detalle.fe_lote_id%type
    ) return pls_integer is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from erp_doc_fe_lote_detalle
         where fe_lote_id = i_fe_lote_id
           and estado_resultado is null;
        return v_cantidad;
    end contar_sin_resultado;

end erp_doc_fe_lote_ctr;
/
