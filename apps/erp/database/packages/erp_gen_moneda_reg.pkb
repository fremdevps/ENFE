create or replace package body erp_gen_moneda_reg
as

    function aplicar_redondeo (
        i_monto      in number,
        i_moneda_id  in erp_gen_moneda.moneda_id%type,
        i_es_precio  in varchar2 default 'N'
    ) return number is
        v_decimales  erp_gen_moneda.decimales%type;
    begin
        if i_monto is null then
            return null;
        end if;
        select case when i_es_precio = 'S' then decimales_precio else decimales end
          into v_decimales
          from erp_gen_moneda
         where moneda_id = i_moneda_id;
        return round(i_monto, v_decimales);
    exception
        when no_data_found then
            raise_application_error(c_err_moneda_no_existe, 'La moneda indicada no existe.');
    end aplicar_redondeo;

    -- Última cotización del par (origen -> destino) <= i_fecha. null si no hay.
    procedure buscar_par (
        i_moneda_id_origen   in  number,
        i_moneda_id_destino  in  number,
        i_fecha              in  date,
        i_empresa_id         in  number,
        i_tipo               in  varchar2,
        o_tasa               out number,
        o_fecha              out date
    ) is
    begin
        select case when i_tipo = 'C' then tasa_compra else tasa_venta end, fecha
          into o_tasa, o_fecha
          from erp_gen_cotizacion
         where moneda_id_origen  = i_moneda_id_origen
           and moneda_id_destino = i_moneda_id_destino
           and fecha <= i_fecha
           and (empresa_id = i_empresa_id or empresa_id is null)
         order by fecha desc, empresa_id nulls last
         fetch first 1 row only;
    exception
        when no_data_found then
            o_tasa  := null;
            o_fecha := null;
    end buscar_par;

    function calcular_cotizacion (
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number is
        v_tipo       varchar2(1) := i_tipo;
        v_tasa       number;
        v_fecha      date;
        v_dias_max   number;
        r_parametro  erp_gen_parametro%rowtype;
    begin
        if i_moneda_id_origen = i_moneda_id_destino then
            return 1;
        end if;

        if v_tipo is null and i_empresa_id is not null then
            select max(tipo_cotizacion) into v_tipo
              from erp_gen_empresa_config
             where empresa_id = i_empresa_id;
        end if;
        v_tipo := coalesce(v_tipo, 'V');

        buscar_par(i_moneda_id_origen  => i_moneda_id_origen,
                   i_moneda_id_destino => i_moneda_id_destino,
                   i_fecha             => trunc(i_fecha),
                   i_empresa_id        => i_empresa_id,
                   i_tipo              => v_tipo,
                   o_tasa              => v_tasa,
                   o_fecha             => v_fecha);
        if v_tasa is null then
            buscar_par(i_moneda_id_origen  => i_moneda_id_destino,
                       i_moneda_id_destino => i_moneda_id_origen,
                       i_fecha             => trunc(i_fecha),
                       i_empresa_id        => i_empresa_id,
                       i_tipo              => v_tipo,
                       o_tasa              => v_tasa,
                       o_fecha             => v_fecha);
            if v_tasa is not null then
                v_tasa := 1 / v_tasa;
            end if;
        end if;

        if v_tasa is null then
            raise_application_error(c_err_cotizacion_no_existe,
                'No hay cotización cargada para el par de monedas a la fecha '
                || to_char(i_fecha, 'DD/MM/YYYY') || '.');
        end if;

        r_parametro := erp_gen_parametro_ctr.obtener(i_codigo => 'ERP_GEN_COTIZACION_DIAS_MAX', i_empresa_id => i_empresa_id);
        v_dias_max  := to_number(r_parametro.valor);
        if v_dias_max is not null and trunc(i_fecha) - v_fecha > v_dias_max then
            raise_application_error(c_err_cotizacion_vencida,
                'La última cotización del par de monedas es del ' || to_char(v_fecha, 'DD/MM/YYYY')
                || ': cargue la cotización del día.');
        end if;

        return v_tasa;
    end calcular_cotizacion;

    function calcular_conversion (
        i_monto              in number,
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number is
    begin
        return aplicar_redondeo(
                   i_monto     => i_monto * calcular_cotizacion(
                                      i_moneda_id_origen  => i_moneda_id_origen,
                                      i_moneda_id_destino => i_moneda_id_destino,
                                      i_fecha             => i_fecha,
                                      i_empresa_id        => i_empresa_id,
                                      i_tipo              => i_tipo),
                   i_moneda_id => i_moneda_id_destino);
    end calcular_conversion;

end erp_gen_moneda_reg;
/
