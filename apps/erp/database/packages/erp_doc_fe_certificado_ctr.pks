create or replace package erp_doc_fe_certificado_ctr
    authid definer
    accessible by (package erp_doc_fe_config_api, package erp_doc_fe_documento_api)
as
-- =============================================================================
-- Paquete : erp_doc_fe_certificado_ctr   (capa ctr)
-- Tabla   : erp_doc_fe_certificado
-- =============================================================================

    procedure insertar (
        i_registro           in  erp_doc_fe_certificado%rowtype,
        o_fe_certificado_id  out erp_doc_fe_certificado.fe_certificado_id%type
    );

    -- Registro vacío (fe_certificado_id null) si no existe.
    function obtener (
        i_fe_certificado_id  in erp_doc_fe_certificado.fe_certificado_id%type
    ) return erp_doc_fe_certificado%rowtype;

end erp_doc_fe_certificado_ctr;
/
