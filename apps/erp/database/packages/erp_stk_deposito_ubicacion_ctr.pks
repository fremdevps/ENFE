create or replace package erp_stk_deposito_ubicacion_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_deposito_ubicacion_ctr   (capa ctr)
-- Tabla   : erp_stk_deposito_ubicacion
-- =============================================================================

    -- Inserta la ubicación si no existe ese código en el depósito (idempotente)
    -- y devuelve su identificador.
    procedure insertar (
        i_deposito_id            in  erp_stk_deposito_ubicacion.deposito_id%type,
        i_codigo                 in  erp_stk_deposito_ubicacion.codigo%type,
        i_nombre                 in  erp_stk_deposito_ubicacion.nombre%type,
        i_tipo                   in  erp_stk_deposito_ubicacion.tipo%type,
        i_es_disponible          in  erp_stk_deposito_ubicacion.es_disponible%type,
        o_deposito_ubicacion_id  out erp_stk_deposito_ubicacion.deposito_ubicacion_id%type
    );

end erp_stk_deposito_ubicacion_ctr;
/
