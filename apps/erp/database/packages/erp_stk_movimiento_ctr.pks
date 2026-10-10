create or replace package erp_stk_movimiento_ctr
    authid definer
    accessible by (package erp_stk_movimiento_reg)
as
-- =============================================================================
-- Paquete : erp_stk_movimiento_ctr   (capa ctr)
-- Tabla   : erp_stk_movimiento
-- =============================================================================

    procedure insertar (
        i_movimiento     in  erp_stk_movimiento%rowtype,
        o_movimiento_id  out erp_stk_movimiento.movimiento_id%type
    );

    -- Bloquea y devuelve el movimiento (no_data_found si no existe).
    function bloquear (
        i_movimiento_id  in erp_stk_movimiento.movimiento_id%type
    ) return erp_stk_movimiento%rowtype;

    procedure actualizar_estado (
        i_movimiento_id  in erp_stk_movimiento.movimiento_id%type,
        i_estado         in erp_stk_movimiento.estado%type
    );

end erp_stk_movimiento_ctr;
/
