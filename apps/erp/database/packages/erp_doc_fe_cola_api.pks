create or replace package erp_doc_fe_cola_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_cola_api   (capa api)
-- Desc    : Fachada de la cola de envío de documentos electrónicos para jobs, servicios
--           y pantallas. Ninguna rutina confirma: el consumidor (job / servicio) hace
--           commit después de cada paso; en APEX lo hace APEX.
--           Reencolar a mano requiere el permiso ERP_DOC_FE_REENVIAR (solo se verifica
--           dentro de una sesión APEX).
--           Estados y transiciones: erp_doc_fe_cola_reg.
-- =============================================================================

    c_err_sin_permiso   constant pls_integer := -20137;

    c_permiso_reenviar  constant varchar2(30) := 'ERP_DOC_FE_REENVIAR';

    procedure encolar (
        i_fe_documento_id  in number
    );

    -- Toma hasta i_cantidad documentos para el envío síncrono (for update skip locked).
    function tomar_pendientes (
        i_empresa_id  in number,
        i_tipo_de     in number default null,
        i_cantidad    in number default 1
    ) return sys.odcinumberlist;

    procedure armar_lote (
        i_empresa_id  in  number,
        i_tipo_de     in  number default null,
        o_fe_lote_id  out number,
        o_cantidad    out number
    );

    function generar_xml_lote (
        i_fe_lote_id  in number
    ) return clob;

    procedure registrar_envio_lote (
        i_fe_lote_id         in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_numero_lote        in varchar2 default null,
        i_tiempo_proceso     in number   default null
    );

    procedure registrar_resultado (
        i_fe_documento_id    in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_protocolo          in varchar2 default null,
        i_estado_resultado   in varchar2 default null
    );

    procedure registrar_error (
        i_fe_documento_id  in number,
        i_error            in varchar2
    );

    procedure registrar_sin_respuesta (
        i_fe_documento_id  in number
    );

    -- Bitácora del intercambio (transacción autónoma). Devuelve el identificador del registro.
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
    );

end erp_doc_fe_cola_api;
/
