create or replace package erp_gen_moneda_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_moneda_reg   (capa reg)
-- Desc    : Redondeo por moneda, búsqueda de cotización y conversión de montos.
-- =============================================================================

    c_err_moneda_no_existe       constant pls_integer := -20100;
    c_err_cotizacion_no_existe   constant pls_integer := -20101;
    c_err_cotizacion_vencida     constant pls_integer := -20102;

    -- Redondea a los decimales de la moneda (de importe o de precio).
    function aplicar_redondeo (
        i_monto      in number,
        i_moneda_id  in erp_gen_moneda.moneda_id%type,
        i_es_precio  in varchar2 default 'N'
    ) return number;

    -- Cuántas unidades de la moneda destino vale 1 unidad de la moneda origen.
    -- Busca la última cotización <= i_fecha (a igual fecha prefiere la de la
    -- empresa sobre la general); si no hay par directo, usa 1 / par inverso.
    -- i_tipo C=compra, V=venta; null = el configurado en la empresa (o V).
    -- Parámetro ERP_GEN_COTIZACION_DIAS_MAX: antigüedad máxima admitida.
    function calcular_cotizacion (
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    -- Convierte y redondea a la moneda destino.
    function calcular_conversion (
        i_monto              in number,
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

end erp_gen_moneda_reg;
/
