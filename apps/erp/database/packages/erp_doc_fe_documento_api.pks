create or replace package erp_doc_fe_documento_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_documento_api   (capa api)
-- Desc    : Emisión de documentos electrónicos para los módulos del ERP: arma el DE desde
--           la estructura de entrada JSON, genera el CDC, firma, arma el QR y deja el
--           documento en la cola de envío (pendiente). Todo en la transacción del llamador
--           (no confirma): si la factura no se graba, el documento electrónico tampoco.
--           Estructura de entrada: docs/diseno-fase2-documentos-sifen.md §5.
-- =============================================================================

    c_err_config     constant pls_integer := -20144;
    c_err_duplicado  constant pls_integer := -20145;

    -- i_frase: frase con la que se cifraron la clave privada y el CSC de la empresa.
    procedure emitir (
        i_empresa_id         in  number,
        i_origen_modulo      in  varchar2,
        i_origen_tipo        in  varchar2,
        i_origen_id          in  number,
        i_tipo_documento_id  in  number,
        i_datos              in  clob,
        i_frase              in  varchar2,
        i_numerador_id       in  number default null,
        o_fe_documento_id    out number,
        o_cdc                out varchar2
    );

    -- Vuelve a verificar la firma del XML guardado; null si es válida, o el motivo.
    function obtener_error_firma (
        i_fe_documento_id  in number
    ) return varchar2;

end erp_doc_fe_documento_api;
/
