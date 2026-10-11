create or replace package erp_stk_traslado_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_traslado_ctr   (capa ctr)
-- Tabla   : erp_stk_traslado
-- =============================================================================

    -- Inserta el registro; la PK y la auditoría nulas toman su valor por defecto.
    procedure insertar (
        i_traslado  in  erp_stk_traslado%rowtype,
        o_traslado_id  out erp_stk_traslado.traslado_id%type
    );

    -- Graba todas las columnas del registro (obtenido antes con bloquear).
    procedure actualizar (
        i_traslado  in erp_stk_traslado%rowtype
    );

    -- Bloquea y devuelve el registro (no_data_found si no existe).
    function bloquear (
        i_traslado_id  in erp_stk_traslado.traslado_id%type
    ) return erp_stk_traslado%rowtype;

end erp_stk_traslado_ctr;
/
