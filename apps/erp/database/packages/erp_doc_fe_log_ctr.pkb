create or replace package body erp_doc_fe_log_ctr
as

    procedure insertar (
        i_registro   in  erp_doc_fe_log%rowtype,
        o_fe_log_id  out erp_doc_fe_log.fe_log_id%type
    ) is
        pragma autonomous_transaction;
    begin
        insert into erp_doc_fe_log
               (empresa_id, servicio, url, fe_documento_id, fe_lote_id, fe_evento_id, id_envio,
                pedido, respuesta, estado_http, codigo_respuesta, duracion_ms, error)
        values (i_registro.empresa_id, i_registro.servicio, i_registro.url, i_registro.fe_documento_id,
                i_registro.fe_lote_id, i_registro.fe_evento_id, i_registro.id_envio,
                i_registro.pedido, i_registro.respuesta, i_registro.estado_http, i_registro.codigo_respuesta,
                i_registro.duracion_ms, substr(i_registro.error, 1, 4000))
        returning fe_log_id into o_fe_log_id;
        commit;
    end insertar;

end erp_doc_fe_log_ctr;
/
