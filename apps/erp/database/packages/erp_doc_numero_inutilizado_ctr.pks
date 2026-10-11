create or replace package erp_doc_numero_inutilizado_ctr
    authid definer
    accessible by (package erp_doc_numerador_reg, package erp_doc_numerador_api)
as
-- =============================================================================
-- Paquete : erp_doc_numero_inutilizado_ctr   (capa ctr)
-- Tabla   : erp_doc_numero_inutilizado
-- =============================================================================

    procedure insertar (
        i_empresa_id             in  erp_doc_numero_inutilizado.empresa_id%type,
        i_numerador_id           in  erp_doc_numero_inutilizado.numerador_id%type,
        i_numero_desde           in  erp_doc_numero_inutilizado.numero_desde%type,
        i_numero_hasta           in  erp_doc_numero_inutilizado.numero_hasta%type,
        i_tipo                   in  erp_doc_numero_inutilizado.tipo%type,
        i_motivo_id              in  erp_doc_numero_inutilizado.motivo_id%type,
        i_motivo                 in  erp_doc_numero_inutilizado.motivo%type,
        i_fecha                  in  erp_doc_numero_inutilizado.fecha%type,
        o_numero_inutilizado_id  out erp_doc_numero_inutilizado.numero_inutilizado_id%type
    );

    -- Hay algún rango registrado que se cruza con [desde, hasta].
    function existe_solapado (
        i_numerador_id  in erp_doc_numero_inutilizado.numerador_id%type,
        i_numero_desde  in erp_doc_numero_inutilizado.numero_desde%type,
        i_numero_hasta  in erp_doc_numero_inutilizado.numero_hasta%type
    ) return boolean;

    -- Último número del rango registrado que contiene a i_numero; null si está libre.
    function obtener_fin_rango (
        i_numerador_id  in erp_doc_numero_inutilizado.numerador_id%type,
        i_numero        in erp_doc_numero_inutilizado.numero_desde%type
    ) return erp_doc_numero_inutilizado.numero_hasta%type;

end erp_doc_numero_inutilizado_ctr;
/
