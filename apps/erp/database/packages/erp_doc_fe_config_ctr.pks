create or replace package erp_doc_fe_config_ctr
    authid definer
    accessible by (package erp_doc_fe_config_api, package erp_doc_fe_documento_api)
as
-- =============================================================================
-- Paquete : erp_doc_fe_config_ctr   (capa ctr)
-- Tabla   : erp_doc_fe_config
-- =============================================================================

    -- Registro vacío (fe_config_id null) si la empresa no tiene configuración.
    function obtener (
        i_empresa_id  in erp_doc_fe_config.empresa_id%type
    ) return erp_doc_fe_config%rowtype;

    -- Crea la configuración de la empresa con los valores por defecto si no existe.
    procedure insertar (
        i_empresa_id  in erp_doc_fe_config.empresa_id%type
    );

    procedure actualizar_csc (
        i_empresa_id   in erp_doc_fe_config.empresa_id%type,
        i_id_csc       in erp_doc_fe_config.id_csc%type,
        i_csc_cifrado  in erp_doc_fe_config.csc_cifrado%type
    );

    procedure actualizar_certificado (
        i_empresa_id         in erp_doc_fe_config.empresa_id%type,
        i_fe_certificado_id  in erp_doc_fe_config.fe_certificado_id%type
    );

end erp_doc_fe_config_ctr;
/
