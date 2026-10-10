create or replace package body erp_gen_moneda_api
as

    function obtener_cotizacion (
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number is
    begin
        return erp_gen_moneda_reg.calcular_cotizacion(
                   i_moneda_id_origen  => i_moneda_id_origen,
                   i_moneda_id_destino => i_moneda_id_destino,
                   i_fecha             => i_fecha,
                   i_empresa_id        => i_empresa_id,
                   i_tipo              => i_tipo);
    end obtener_cotizacion;

    function obtener_monto_convertido (
        i_monto              in number,
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number is
    begin
        return erp_gen_moneda_reg.calcular_conversion(
                   i_monto             => i_monto,
                   i_moneda_id_origen  => i_moneda_id_origen,
                   i_moneda_id_destino => i_moneda_id_destino,
                   i_fecha             => i_fecha,
                   i_empresa_id        => i_empresa_id,
                   i_tipo              => i_tipo);
    end obtener_monto_convertido;

    function obtener_monto_redondeado (
        i_monto      in number,
        i_moneda_id  in number,
        i_es_precio  in varchar2 default 'N'
    ) return number is
    begin
        return erp_gen_moneda_reg.aplicar_redondeo(i_monto => i_monto, i_moneda_id => i_moneda_id, i_es_precio => i_es_precio);
    end obtener_monto_redondeado;

end erp_gen_moneda_api;
/
