create or replace package body erp_gen_impuesto_reg
as

    function calcular_porcentaje (
        i_impuesto_tasa_id  in erp_gen_impuesto_tasa.impuesto_tasa_id%type,
        i_fecha             in date
    ) return number is
        v_porcentaje  erp_gen_impuesto_tasa_vig.porcentaje%type;
    begin
        select porcentaje
          into v_porcentaje
          from erp_gen_impuesto_tasa_vig
         where impuesto_tasa_id = i_impuesto_tasa_id
           and fecha_desde <= i_fecha
         order by fecha_desde desc
         fetch first 1 row only;
        return v_porcentaje;
    exception
        when no_data_found then
            raise_application_error(c_err_tasa_sin_vigencia,
                'La tasa de impuesto no tiene un porcentaje vigente al '
                || to_char(i_fecha, 'DD/MM/YYYY') || '.');
    end calcular_porcentaje;

    function calcular_impuestos (
        i_categoria_fiscal_id  in erp_gen_categoria_fiscal.categoria_fiscal_id%type,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in erp_gen_moneda.moneda_id%type,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab is
        v_resultado     erp_impuesto_calc_tab := erp_impuesto_calc_tab();
        v_decimales     pls_integer := i_decimales;
        v_estado        erp_gen_categoria_fiscal.estado%type;
        v_impuesto_id   number := -1;
        v_divisor       number;
        v_base_neta     number;
        v_resto_base    number;
        v_resto_monto   number;
        v_monto         number;
        v_base          number;
        v_impuesto      number;

        type t_tasa is record (
            impuesto_id       number,
            impuesto_tasa_id  number,
            codigo            erp_gen_impuesto_tasa.codigo%type,
            porcentaje_base   number,
            nro               pls_integer,
            cantidad          pls_integer,
            total_base        number,
            porcentaje        number
        );
        type t_tasas is table of t_tasa index by pls_integer;
        v_tasas  t_tasas;

        procedure agregar_exento (
            i_impuesto_id  in number,
            i_pct_base     in number,
            i_monto_exento in number
        ) is
        begin
            v_resultado.extend;
            v_resultado(v_resultado.count) := erp_impuesto_calc_typ(
                i_impuesto_id, null, 'EXENTO', 0, i_pct_base, i_monto_exento, i_monto_exento, 0);
        end agregar_exento;
    begin
        -- Sin datos que calcular (ej. pantalla recién abierta): resultado vacío, no error.
        if i_categoria_fiscal_id is null or i_monto is null or i_moneda_id is null then
            return v_resultado;
        end if;

        begin
            select estado into v_estado
              from erp_gen_categoria_fiscal
             where categoria_fiscal_id = i_categoria_fiscal_id;
        exception
            when no_data_found then
                v_estado := null;
        end;
        if v_estado is null or v_estado <> 'A' then
            raise_application_error(c_err_categoria_invalida, 'La categoría fiscal no existe o está inactiva.');
        end if;

        if v_decimales is null then
            select decimales into v_decimales from erp_gen_moneda where moneda_id = i_moneda_id;
        end if;

        for r_tasa in (
            select t.impuesto_id, ct.impuesto_tasa_id, t.codigo, ct.porcentaje_base,
                   row_number() over (partition by t.impuesto_id order by ct.orden, ct.impuesto_tasa_id) nro,
                   count(*) over (partition by t.impuesto_id) cantidad,
                   sum(ct.porcentaje_base) over (partition by t.impuesto_id) total_base
              from erp_gen_categoria_tasa ct
              join erp_gen_impuesto_tasa t on t.impuesto_tasa_id = ct.impuesto_tasa_id
             where ct.categoria_fiscal_id = i_categoria_fiscal_id
               and t.estado = 'A'
             order by t.impuesto_id, nro
        ) loop
            if r_tasa.total_base > 100 then
                raise_application_error(c_err_base_excedida,
                    'La categoría fiscal asigna más del 100 % de la base a un mismo impuesto.');
            end if;
            v_tasas(v_tasas.count + 1).impuesto_id := r_tasa.impuesto_id;
            v_tasas(v_tasas.count).impuesto_tasa_id := r_tasa.impuesto_tasa_id;
            v_tasas(v_tasas.count).codigo           := r_tasa.codigo;
            v_tasas(v_tasas.count).porcentaje_base  := r_tasa.porcentaje_base;
            v_tasas(v_tasas.count).nro              := r_tasa.nro;
            v_tasas(v_tasas.count).cantidad         := r_tasa.cantidad;
            v_tasas(v_tasas.count).total_base       := r_tasa.total_base;
            v_tasas(v_tasas.count).porcentaje       :=
                calcular_porcentaje(i_impuesto_tasa_id => r_tasa.impuesto_tasa_id, i_fecha => i_fecha);
        end loop;

        for i in 1 .. v_tasas.count loop
            if v_tasas(i).impuesto_id <> v_impuesto_id then
                v_impuesto_id := v_tasas(i).impuesto_id;
                v_resto_base  := 100;
                v_resto_monto := i_monto;
                -- Base neta total del impuesto. Con impuesto incluido:
                --   monto = base_neta x (1 + suma(%base x tasa) / 10000)
                -- (fórmula de la DNIT para gravado parcial: base = 100·M·P / (10000 + T·P)).
                if i_incluye_impuesto = 'S' then
                    v_divisor := 0;
                    for j in i .. v_tasas.count loop
                        exit when v_tasas(j).impuesto_id <> v_impuesto_id;
                        v_divisor := v_divisor + v_tasas(j).porcentaje_base * v_tasas(j).porcentaje;
                    end loop;
                    v_base_neta := i_monto / (1 + v_divisor / 10000);
                else
                    v_base_neta := i_monto;
                end if;
            end if;

            v_base     := round(v_base_neta * v_tasas(i).porcentaje_base / 100, v_decimales);
            v_impuesto := round(v_base * v_tasas(i).porcentaje / 100, v_decimales);
            if i_incluye_impuesto = 'S' then
                -- La última tasa de un impuesto que cubre el 100 % absorbe el redondeo,
                -- para que base + impuesto sume exactamente el monto.
                if v_tasas(i).nro = v_tasas(i).cantidad and v_tasas(i).total_base = 100 then
                    v_impuesto := v_resto_monto - v_base;
                end if;
                v_monto := v_base + v_impuesto;
            else
                if v_tasas(i).nro = v_tasas(i).cantidad and v_tasas(i).total_base = 100 then
                    v_base     := v_resto_monto;
                    v_impuesto := round(v_base * v_tasas(i).porcentaje / 100, v_decimales);
                end if;
                v_monto := v_base;
            end if;

            v_resultado.extend;
            v_resultado(v_resultado.count) := erp_impuesto_calc_typ(
                v_tasas(i).impuesto_id, v_tasas(i).impuesto_tasa_id, v_tasas(i).codigo, v_tasas(i).porcentaje,
                v_tasas(i).porcentaje_base, v_monto, v_base, v_impuesto);

            v_resto_base  := v_resto_base - v_tasas(i).porcentaje_base;
            v_resto_monto := v_resto_monto - v_monto;

            if v_tasas(i).nro = v_tasas(i).cantidad and v_resto_base > 0 then
                agregar_exento(i_impuesto_id => v_tasas(i).impuesto_id, i_pct_base => v_resto_base, i_monto_exento => v_resto_monto);
            end if;
        end loop;

        if v_resultado.count = 0 then
            agregar_exento(i_impuesto_id => null, i_pct_base => 100, i_monto_exento => i_monto);
        end if;

        return v_resultado;
    end calcular_impuestos;

end erp_gen_impuesto_reg;
/
