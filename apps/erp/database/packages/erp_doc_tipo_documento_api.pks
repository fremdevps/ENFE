create or replace package erp_doc_tipo_documento_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_tipo_documento_api   (capa api)
-- Desc    : Tipos de documento de la empresa. El comportamiento es dato: el código del
--           ERP solo consulta la clase (erp_doc_clase_documento) y los atributos del tipo,
--           nunca el código del tipo de documento.
-- =============================================================================

    -- Crea para la empresa los tipos de documento habituales de Paraguay (los que falten);
    -- no modifica los existentes. Después la empresa los ajusta o agrega los suyos.
    procedure crear_base (
        i_empresa_id  in number
    );

    -- Código del tipo de comprobante en el registro mensual vigente a la fecha; null si no tiene.
    function obtener_codigo_fiscal (
        i_tipo_documento_id  in number,
        i_fecha              in date default current_date
    ) return varchar2;

end erp_doc_tipo_documento_api;
/
