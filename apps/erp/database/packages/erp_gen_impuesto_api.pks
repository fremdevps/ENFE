create or replace package erp_gen_impuesto_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_impuesto_api   (capa api)
-- Desc    : Cálculo de impuestos para APEX / REST / documentos.
--   select * from table(erp_gen_impuesto_api.obtener_calculo(:categoria, sysdate, 110000, 'S', :pyg));
-- =============================================================================

    function obtener_porcentaje (
        i_impuesto_tasa_id  in number,
        i_fecha             in date default trunc(current_date)
    ) return number;

    function obtener_calculo (
        i_categoria_fiscal_id  in number,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in number,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab;

end erp_gen_impuesto_api;
/
