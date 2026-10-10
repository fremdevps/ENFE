create or replace package erp_gen_empresa_func_ctr
    authid definer
    accessible by (package erp_gen_funcionalidad_api)
as
-- =============================================================================
-- Paquete : erp_gen_empresa_func_ctr   (capa ctr)
-- Tabla   : erp_gen_empresa_func
-- =============================================================================

    -- Activa la funcionalidad en la empresa (la crea si no existe). Idempotente.
    procedure insertar (
        i_empresa_id        in erp_gen_empresa_func.empresa_id%type,
        i_funcionalidad_id  in erp_gen_empresa_func.funcionalidad_id%type
    );

end erp_gen_empresa_func_ctr;
/
