create or replace package erp_stk_numerador_ctr
    authid definer
    accessible by (package erp_stk_traslado_reg)
as
-- =============================================================================
-- Paquete : erp_stk_numerador_ctr   (capa ctr)
-- Tabla   : erp_stk_numerador
-- =============================================================================

    -- Entrega el siguiente número del documento para la empresa y la sucursal.
    -- Bloquea la fila del numerador hasta el fin de la transacción del documento
    -- (nunca en transacción autónoma: un rollback devuelve el número).
    procedure actualizar_siguiente (
        i_empresa_id   in  erp_stk_numerador.empresa_id%type,
        i_sucursal_id  in  erp_stk_numerador.sucursal_id%type,
        i_codigo       in  erp_stk_numerador.codigo%type,
        o_numero       out erp_stk_numerador.ultimo_numero%type
    );

end erp_stk_numerador_ctr;
/
