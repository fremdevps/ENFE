create or replace package erp_gen_parametro_ctr
    authid definer
    accessible by (package erp_gen_parametro_api, package erp_gen_moneda_reg, package erp_gen_periodo_reg)
as
-- =============================================================================
-- Paquete : erp_gen_parametro_ctr   (capa ctr)
-- Tabla   : erp_gen_parametro
-- =============================================================================

    -- Fila del parámetro para la empresa; si no existe, la general (empresa_id null).
    -- Si no hay ninguna, devuelve un registro vacío (parametro_id null).
    function obtener (
        i_codigo      in erp_gen_parametro.codigo%type,
        i_empresa_id  in erp_gen_parametro.empresa_id%type default null
    ) return erp_gen_parametro%rowtype;

end erp_gen_parametro_ctr;
/
