create or replace package erp_gen_moneda_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_moneda_api   (capa api)
-- Desc    : Cotización, conversión y redondeo para APEX / REST / otros módulos.
--           Ver erp_gen_moneda_reg para el detalle de la búsqueda.
-- =============================================================================

    function obtener_cotizacion (
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    function obtener_monto_convertido (
        i_monto              in number,
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    function obtener_monto_redondeado (
        i_monto      in number,
        i_moneda_id  in number,
        i_es_precio  in varchar2 default 'N'
    ) return number;

end erp_gen_moneda_api;
/
