create or replace package body erp_doc_fe_cola_api
as

    procedure encolar (
        i_fe_documento_id  in number
    ) is
        v_usuario    varchar2(255) := sys_context('APEX$SESSION', 'APP_USER');
        r_documento  erp_doc_fe_documento%rowtype;
    begin
        if v_usuario is not null then
            r_documento := erp_doc_fe_documento_ctr.obtener(i_fe_documento_id => i_fe_documento_id);
            if not adm_seg_seguridad_reg.tiene_permiso(i_username       => v_usuario,
                                                       i_permiso_codigo => c_permiso_reenviar,
                                                       i_empresa_id     => r_documento.empresa_id) then
                raise_application_error(c_err_sin_permiso, 'No tiene permiso para reenviar documentos electrónicos.');
            end if;
        end if;
        erp_doc_fe_cola_reg.encolar(i_fe_documento_id => i_fe_documento_id);
    end encolar;

    function tomar_pendientes (
        i_empresa_id  in number,
        i_tipo_de     in number default null,
        i_cantidad    in number default 1
    ) return sys.odcinumberlist is
    begin
        return erp_doc_fe_cola_reg.tomar_pendientes(i_empresa_id => i_empresa_id, i_tipo_de => i_tipo_de, i_cantidad => i_cantidad);
    end tomar_pendientes;

    procedure armar_lote (
        i_empresa_id  in  number,
        i_tipo_de     in  number default null,
        o_fe_lote_id  out number,
        o_cantidad    out number
    ) is
    begin
        erp_doc_fe_cola_reg.armar_lote(i_empresa_id => i_empresa_id, i_tipo_de => i_tipo_de,
                                       o_fe_lote_id => o_fe_lote_id, o_cantidad => o_cantidad);
    end armar_lote;

    function generar_xml_lote (
        i_fe_lote_id  in number
    ) return clob is
    begin
        return erp_doc_fe_cola_reg.generar_xml_lote(i_fe_lote_id => i_fe_lote_id);
    end generar_xml_lote;

    procedure registrar_envio_lote (
        i_fe_lote_id         in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_numero_lote        in varchar2 default null,
        i_tiempo_proceso     in number   default null
    ) is
    begin
        erp_doc_fe_cola_reg.registrar_envio_lote(i_fe_lote_id        => i_fe_lote_id,
                                                 i_codigo_respuesta  => i_codigo_respuesta,
                                                 i_mensaje_respuesta => i_mensaje_respuesta,
                                                 i_numero_lote       => i_numero_lote,
                                                 i_tiempo_proceso    => i_tiempo_proceso);
    end registrar_envio_lote;

    procedure registrar_resultado (
        i_fe_documento_id    in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_protocolo          in varchar2 default null,
        i_estado_resultado   in varchar2 default null
    ) is
    begin
        erp_doc_fe_cola_reg.registrar_resultado(i_fe_documento_id   => i_fe_documento_id,
                                                i_codigo_respuesta  => i_codigo_respuesta,
                                                i_mensaje_respuesta => i_mensaje_respuesta,
                                                i_protocolo         => i_protocolo,
                                                i_estado_resultado  => i_estado_resultado);
    end registrar_resultado;

    procedure registrar_error (
        i_fe_documento_id  in number,
        i_error            in varchar2
    ) is
    begin
        erp_doc_fe_cola_reg.registrar_error(i_fe_documento_id => i_fe_documento_id, i_error => i_error);
    end registrar_error;

    procedure registrar_sin_respuesta (
        i_fe_documento_id  in number
    ) is
    begin
        erp_doc_fe_cola_reg.registrar_sin_respuesta(i_fe_documento_id => i_fe_documento_id);
    end registrar_sin_respuesta;

    procedure registrar_log (
        i_empresa_id        in  number,
        i_servicio          in  varchar2,
        i_url               in  varchar2 default null,
        i_fe_documento_id   in  number   default null,
        i_fe_lote_id        in  number   default null,
        i_fe_evento_id      in  number   default null,
        i_id_envio          in  varchar2 default null,
        i_pedido            in  clob     default null,
        i_respuesta         in  clob     default null,
        i_estado_http       in  number   default null,
        i_codigo_respuesta  in  varchar2 default null,
        i_duracion_ms       in  number   default null,
        i_error             in  varchar2 default null,
        o_fe_log_id         out number
    ) is
        r_log  erp_doc_fe_log%rowtype;
    begin
        r_log.empresa_id       := i_empresa_id;
        r_log.servicio         := i_servicio;
        r_log.url              := i_url;
        r_log.fe_documento_id  := i_fe_documento_id;
        r_log.fe_lote_id       := i_fe_lote_id;
        r_log.fe_evento_id     := i_fe_evento_id;
        r_log.id_envio         := i_id_envio;
        r_log.pedido           := i_pedido;
        r_log.respuesta        := i_respuesta;
        r_log.estado_http      := i_estado_http;
        r_log.codigo_respuesta := i_codigo_respuesta;
        r_log.duracion_ms      := i_duracion_ms;
        r_log.error            := i_error;
        erp_doc_fe_log_ctr.insertar(i_registro => r_log, o_fe_log_id => o_fe_log_id);
    end registrar_log;

end erp_doc_fe_cola_api;
/
