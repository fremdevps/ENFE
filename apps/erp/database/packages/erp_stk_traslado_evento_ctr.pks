create or replace package erp_stk_traslado_evento_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_traslado_evento_ctr   (capa ctr)
-- Tabla   : erp_stk_traslado_evento
-- =============================================================================

    -- Inserta el registro; la PK y la auditoría nulas toman su valor por defecto.
    procedure insertar (
        i_evento  in  erp_stk_traslado_evento%rowtype,
        o_traslado_evento_id  out erp_stk_traslado_evento.traslado_evento_id%type
    );

end erp_stk_traslado_evento_ctr;
/
