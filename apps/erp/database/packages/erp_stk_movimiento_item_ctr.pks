create or replace package erp_stk_movimiento_item_ctr
    authid definer
    accessible by (package erp_stk_movimiento_reg)
as
-- =============================================================================
-- Paquete : erp_stk_movimiento_item_ctr   (capa ctr)
-- Tabla   : erp_stk_movimiento_item
-- =============================================================================

    type t_item_tab is table of erp_stk_movimiento_item%rowtype index by pls_integer;

    -- Inserta todas las líneas de un movimiento en una sola operación (forall).
    -- La colección debe ser densa (1 .. count).
    procedure insertar (
        i_items  in t_item_tab
    );

end erp_stk_movimiento_item_ctr;
/
