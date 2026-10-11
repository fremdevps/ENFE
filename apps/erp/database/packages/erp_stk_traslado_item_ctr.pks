create or replace package erp_stk_traslado_item_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_traslado_item_ctr   (capa ctr)
-- Tabla   : erp_stk_traslado_item
-- =============================================================================

    -- Inserta el registro; la PK y la auditoría nulas toman su valor por defecto.
    procedure insertar (
        i_item  in  erp_stk_traslado_item%rowtype,
        o_traslado_item_id  out erp_stk_traslado_item.traslado_item_id%type
    );

    -- Graba todas las columnas del registro (obtenido antes con bloquear).
    procedure actualizar (
        i_item  in erp_stk_traslado_item%rowtype
    );

    procedure eliminar (
        i_traslado_item_id  in erp_stk_traslado_item.traslado_item_id%type
    );

end erp_stk_traslado_item_ctr;
/
