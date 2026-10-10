create or replace package erp_gen_persona_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_persona_reg   (capa reg)
-- Desc    : Reglas de personas: normalización y validación del documento,
--           dígito verificador del RUC (algoritmo módulo 11 de la SET/DNIT).
-- =============================================================================

    c_err_documento_formato  constant pls_integer := -20109;
    c_err_dv_invalido        constant pls_integer := -20110;
    c_err_tipo_doc_invalido  constant pls_integer := -20111;

    -- Dígito verificador módulo 11 (base máxima 11). Las letras se reemplazan por
    -- su código ASCII, igual que el algoritmo publicado por la SET.
    function calcular_dv_ruc (
        i_numero  in varchar2
    ) return varchar2;

    -- Quita puntos y espacios, pasa a mayúsculas y, si viene "80012345-6" sin dv,
    -- separa número y dígito verificador.
    procedure aplicar_formato_documento (
        io_nro_documento  in out nocopy varchar2,
        io_dv             in out nocopy varchar2
    );

    procedure validar_documento (
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type
    );

end erp_gen_persona_reg;
/
