create or replace package erp_stk_traslado_recep_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_traslado_recep_ctr   (capa ctr)
-- Tabla   : erp_stk_traslado_recep
-- =============================================================================

    -- Inserta el registro; la PK y la auditoría nulas toman su valor por defecto.
    procedure insertar (
        i_recepcion  in  erp_stk_traslado_recep%rowtype,
        o_traslado_recep_id  out erp_stk_traslado_recep.traslado_recep_id%type
    );

end erp_stk_traslado_recep_ctr;
/
