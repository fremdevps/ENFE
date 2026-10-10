create or replace package body erp_gen_impuesto_api
as

    function obtener_porcentaje (
        i_impuesto_tasa_id  in number,
        i_fecha             in date default trunc(current_date)
    ) return number is
    begin
        return erp_gen_impuesto_reg.calcular_porcentaje(i_impuesto_tasa_id => i_impuesto_tasa_id, i_fecha => i_fecha);
    end obtener_porcentaje;

    function obtener_calculo (
        i_categoria_fiscal_id  in number,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in number,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab is
    begin
        return erp_gen_impuesto_reg.calcular_impuestos(
                   i_categoria_fiscal_id => i_categoria_fiscal_id,
                   i_fecha               => i_fecha,
                   i_monto               => i_monto,
                   i_incluye_impuesto    => i_incluye_impuesto,
                   i_moneda_id           => i_moneda_id,
                   i_decimales           => i_decimales);
    end obtener_calculo;

end erp_gen_impuesto_api;
/
