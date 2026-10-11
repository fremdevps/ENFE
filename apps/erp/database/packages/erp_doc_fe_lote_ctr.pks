create or replace package erp_doc_fe_lote_ctr
    authid definer
    accessible by (package erp_doc_fe_cola_reg, package erp_doc_fe_cola_api)
as
-- =============================================================================
-- Paquete : erp_doc_fe_lote_ctr   (capa ctr)
-- Tablas  : erp_doc_fe_lote y su detalle erp_doc_fe_lote_detalle
-- =============================================================================

    procedure insertar (
        i_empresa_id  in  erp_doc_fe_lote.empresa_id%type,
        i_tipo_de     in  erp_doc_fe_lote.tipo_de%type,
        i_estado      in  erp_doc_fe_lote.estado%type,
        o_fe_lote_id  out erp_doc_fe_lote.fe_lote_id%type
    );

    procedure insertar_detalle (
        i_fe_lote_id       in erp_doc_fe_lote_detalle.fe_lote_id%type,
        i_fe_documento_id  in erp_doc_fe_lote_detalle.fe_documento_id%type,
        i_orden            in erp_doc_fe_lote_detalle.orden%type
    );

    -- select … for update; registro vacío si no existe.
    function bloquear (
        i_fe_lote_id  in erp_doc_fe_lote.fe_lote_id%type
    ) return erp_doc_fe_lote%rowtype;

    -- Actualiza cantidad, estado, respuesta y reintentos.
    procedure actualizar (
        i_registro  in erp_doc_fe_lote%rowtype
    );

    procedure actualizar_detalle (
        i_fe_lote_id         in erp_doc_fe_lote_detalle.fe_lote_id%type,
        i_fe_documento_id    in erp_doc_fe_lote_detalle.fe_documento_id%type,
        i_estado_resultado   in erp_doc_fe_lote_detalle.estado_resultado%type,
        i_codigo_respuesta   in erp_doc_fe_lote_detalle.codigo_respuesta%type,
        i_mensaje_respuesta  in erp_doc_fe_lote_detalle.mensaje_respuesta%type
    );

    -- Documentos del lote que todavía no tienen resultado.
    function contar_sin_resultado (
        i_fe_lote_id  in erp_doc_fe_lote_detalle.fe_lote_id%type
    ) return pls_integer;

end erp_doc_fe_lote_ctr;
/
