create or replace package erp_stk_lote_ctr
    authid definer
    accessible by (package erp_stk_lote_api)
as
-- =============================================================================
-- Paquete : erp_stk_lote_ctr   (capa ctr)
-- Tabla   : erp_stk_lote
-- =============================================================================

    procedure insertar (
        i_lote     in  erp_stk_lote%rowtype,
        o_lote_id  out erp_stk_lote.lote_id%type
    );

    procedure actualizar (
        i_lote  in erp_stk_lote%rowtype
    );

    -- Registro vacío (lote_id null) si no existe.
    function obtener (
        i_lote_id  in erp_stk_lote.lote_id%type
    ) return erp_stk_lote%rowtype;

end erp_stk_lote_ctr;
/
