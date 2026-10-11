create or replace package erp_stk_traslado_recep_det_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_traslado_recep_det_ctr   (capa ctr)
-- Tabla   : erp_stk_traslado_recep_det
-- =============================================================================

    -- Inserta el registro; la PK y la auditoría nulas toman su valor por defecto.
    procedure insertar (
        i_detalle  in  erp_stk_traslado_recep_det%rowtype,
        o_traslado_recep_det_id  out erp_stk_traslado_recep_det.traslado_recep_det_id%type
    );

    -- Graba todas las columnas del registro (obtenido antes con bloquear).
    procedure actualizar (
        i_detalle  in erp_stk_traslado_recep_det%rowtype
    );

    -- Bloquea y devuelve el registro (no_data_found si no existe).
    function bloquear (
        i_traslado_recep_det_id  in erp_stk_traslado_recep_det.traslado_recep_det_id%type
    ) return erp_stk_traslado_recep_det%rowtype;

end erp_stk_traslado_recep_det_ctr;
/
