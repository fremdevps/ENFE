-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/erp/database)

-- >>> apps/erp/database/packages/erp_gen_parametro_ctr.pkb
create or replace package body erp_gen_parametro_ctr
as

    function obtener (
        i_codigo      in erp_gen_parametro.codigo%type,
        i_empresa_id  in erp_gen_parametro.empresa_id%type default null
    ) return erp_gen_parametro%rowtype is
        r_parametro  erp_gen_parametro%rowtype;
    begin
        select *
          into r_parametro
          from erp_gen_parametro
         where codigo = upper(i_codigo)
           and (empresa_id = i_empresa_id or empresa_id is null)
         order by empresa_id nulls last
         fetch first 1 row only;
        return r_parametro;
    exception
        when no_data_found then
            return r_parametro;
    end obtener;

end erp_gen_parametro_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_periodo_ctr.pkb
create or replace package body erp_gen_periodo_ctr
as

    function obtener (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type
    ) return erp_gen_periodo%rowtype is
        r_periodo  erp_gen_periodo%rowtype;
    begin
        select *
          into r_periodo
          from erp_gen_periodo
         where empresa_id = i_empresa_id
           and modulo     = upper(i_modulo)
           and anio       = i_anio
           and mes        = i_mes;
        return r_periodo;
    exception
        when no_data_found then
            return r_periodo;
    end obtener;

    procedure insertar (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type,
        i_estado      in erp_gen_periodo.estado%type
    ) is
    begin
        merge into erp_gen_periodo t
        using (select i_empresa_id empresa_id, upper(i_modulo) modulo, i_anio anio, i_mes mes from dual) s
           on (t.empresa_id = s.empresa_id and t.modulo = s.modulo and t.anio = s.anio and t.mes = s.mes)
         when not matched then
            insert (empresa_id, modulo, anio, mes, estado)
            values (s.empresa_id, s.modulo, s.anio, s.mes, i_estado);
    end insertar;

    procedure actualizar (
        i_periodo_id    in erp_gen_periodo.periodo_id%type,
        i_estado        in erp_gen_periodo.estado%type,
        i_fecha_cierre  in erp_gen_periodo.fecha_cierre%type,
        i_cerrado_por   in erp_gen_periodo.cerrado_por%type
    ) is
    begin
        update erp_gen_periodo
           set estado       = i_estado,
               fecha_cierre = i_fecha_cierre,
               cerrado_por  = i_cerrado_por
         where periodo_id = i_periodo_id;
    end actualizar;

end erp_gen_periodo_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_persona_ctr.pkb
create or replace package body erp_gen_persona_ctr
as

    procedure insertar (
        i_persona  in  erp_gen_persona%rowtype,
        o_persona_id out erp_gen_persona.persona_id%type
    ) is
    begin
        insert into erp_gen_persona (
            tipo_persona, tipo_doc_identidad_id, nro_documento, dv, razon_social, nombres, apellidos,
            nombre_fantasia, es_contribuyente, pais_id, fecha_nacimiento, email, telefono, observacion, estado)
        values (
            i_persona.tipo_persona, i_persona.tipo_doc_identidad_id, i_persona.nro_documento, i_persona.dv,
            i_persona.razon_social, i_persona.nombres, i_persona.apellidos, i_persona.nombre_fantasia,
            i_persona.es_contribuyente, i_persona.pais_id, i_persona.fecha_nacimiento, i_persona.email,
            i_persona.telefono, i_persona.observacion, i_persona.estado)
        returning persona_id into o_persona_id;
    end insertar;

    procedure actualizar (
        i_persona  in erp_gen_persona%rowtype
    ) is
    begin
        update erp_gen_persona
           set tipo_persona          = i_persona.tipo_persona,
               tipo_doc_identidad_id = i_persona.tipo_doc_identidad_id,
               nro_documento         = i_persona.nro_documento,
               dv                    = i_persona.dv,
               razon_social          = i_persona.razon_social,
               nombres               = i_persona.nombres,
               apellidos             = i_persona.apellidos,
               nombre_fantasia       = i_persona.nombre_fantasia,
               es_contribuyente      = i_persona.es_contribuyente,
               pais_id               = i_persona.pais_id,
               fecha_nacimiento      = i_persona.fecha_nacimiento,
               email                 = i_persona.email,
               telefono              = i_persona.telefono,
               observacion           = i_persona.observacion,
               estado                = i_persona.estado
         where persona_id = i_persona.persona_id;
    end actualizar;

end erp_gen_persona_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_empresa_func_ctr.pkb
create or replace package body erp_gen_empresa_func_ctr
as

    procedure insertar (
        i_empresa_id        in erp_gen_empresa_func.empresa_id%type,
        i_funcionalidad_id  in erp_gen_empresa_func.funcionalidad_id%type
    ) is
    begin
        merge into erp_gen_empresa_func t
        using (select i_empresa_id empresa_id, i_funcionalidad_id funcionalidad_id from dual) s
           on (t.empresa_id = s.empresa_id and t.funcionalidad_id = s.funcionalidad_id)
         when matched then
            update set t.estado = 'A'
         when not matched then
            insert (empresa_id, funcionalidad_id, estado)
            values (s.empresa_id, s.funcionalidad_id, 'A');
    end insertar;

end erp_gen_empresa_func_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_moneda_reg.pkb
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

-- >>> apps/erp/database/packages/erp_gen_impuesto_reg.pkb
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
        v_resto_base    number;
        v_resto_monto   number;
        v_monto         number;
        v_porcentaje    number;
        v_base          number;
        v_impuesto      number;

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
            if r_tasa.impuesto_id <> v_impuesto_id then
                v_impuesto_id := r_tasa.impuesto_id;
                v_resto_base  := 100;
                v_resto_monto := i_monto;
                if r_tasa.total_base > 100 then
                    raise_application_error(c_err_base_excedida,
                        'La categoría fiscal asigna más del 100 % de la base a un mismo impuesto.');
                end if;
            end if;

            -- La última tasa de un impuesto que cubre el 100 % toma el resto, para que
            -- la suma de las partes sea exactamente el monto (sin diferencias de redondeo).
            if r_tasa.nro = r_tasa.cantidad and r_tasa.total_base = 100 then
                v_monto := v_resto_monto;
            else
                v_monto := round(i_monto * r_tasa.porcentaje_base / 100, v_decimales);
            end if;

            v_porcentaje := calcular_porcentaje(i_impuesto_tasa_id => r_tasa.impuesto_tasa_id, i_fecha => i_fecha);
            if i_incluye_impuesto = 'S' then
                v_base     := round(v_monto / (1 + v_porcentaje / 100), v_decimales);
                v_impuesto := v_monto - v_base;
            else
                v_base     := v_monto;
                v_impuesto := round(v_monto * v_porcentaje / 100, v_decimales);
            end if;

            v_resultado.extend;
            v_resultado(v_resultado.count) := erp_impuesto_calc_typ(
                r_tasa.impuesto_id, r_tasa.impuesto_tasa_id, r_tasa.codigo, v_porcentaje,
                r_tasa.porcentaje_base, v_monto, v_base, v_impuesto);

            v_resto_base  := v_resto_base - r_tasa.porcentaje_base;
            v_resto_monto := v_resto_monto - v_monto;

            if r_tasa.nro = r_tasa.cantidad and v_resto_base > 0 then
                agregar_exento(i_impuesto_id => r_tasa.impuesto_id, i_pct_base => v_resto_base, i_monto_exento => v_resto_monto);
            end if;
        end loop;

        if v_resultado.count = 0 then
            agregar_exento(i_impuesto_id => null, i_pct_base => 100, i_monto_exento => i_monto);
        end if;

        return v_resultado;
    end calcular_impuestos;

end erp_gen_impuesto_reg;
/

-- >>> apps/erp/database/packages/erp_gen_periodo_reg.pkb
create or replace package body erp_gen_periodo_reg
as

    function es_estricto (
        i_empresa_id  in number
    ) return boolean is
        r_parametro  erp_gen_parametro%rowtype;
    begin
        r_parametro := erp_gen_parametro_ctr.obtener(i_codigo => 'ERP_GEN_PERIODO_ESTRICTO', i_empresa_id => i_empresa_id);
        return coalesce(upper(r_parametro.valor), 'N') = 'S';
    end es_estricto;

    -- El usuario de la sesión APEX tiene una habilitación vigente para el período cerrado.
    function tiene_habilitacion (
        i_periodo_id  in erp_gen_periodo.periodo_id%type
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from erp_gen_periodo_habilita h
          join adm_seg_usuario u on u.usuario_id = h.usuario_id
         where h.periodo_id = i_periodo_id
           and upper(u.username) = upper(sys_context('APEX$SESSION', 'APP_USER'))
           and h.fecha_hasta >= trunc(current_date);
        return v_cantidad > 0;
    end tiene_habilitacion;

    function es_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) return boolean is
        r_periodo  erp_gen_periodo%rowtype;
    begin
        r_periodo := erp_gen_periodo_ctr.obtener(
                         i_empresa_id => i_empresa_id,
                         i_modulo     => i_modulo,
                         i_anio       => extract(year from i_fecha),
                         i_mes        => extract(month from i_fecha));
        if r_periodo.periodo_id is null then
            return not es_estricto(i_empresa_id => i_empresa_id);
        end if;
        if r_periodo.estado = 'A' then
            return true;
        end if;
        return tiene_habilitacion(i_periodo_id => r_periodo.periodo_id);
    end es_abierto;

    procedure validar_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) is
        r_periodo  erp_gen_periodo%rowtype;
    begin
        if es_abierto(i_empresa_id => i_empresa_id, i_modulo => i_modulo, i_fecha => i_fecha) then
            return;
        end if;
        r_periodo := erp_gen_periodo_ctr.obtener(
                         i_empresa_id => i_empresa_id,
                         i_modulo     => i_modulo,
                         i_anio       => extract(year from i_fecha),
                         i_mes        => extract(month from i_fecha));
        if r_periodo.periodo_id is null then
            raise_application_error(c_err_periodo_no_existe,
                'El período ' || to_char(i_fecha, 'MM/YYYY') || ' de ' || upper(i_modulo)
                || ' no está habilitado.');
        end if;
        raise_application_error(c_err_periodo_cerrado,
            'El período ' || to_char(i_fecha, 'MM/YYYY') || ' de ' || upper(i_modulo)
            || ' está cerrado.');
    end validar_abierto;

end erp_gen_periodo_reg;
/

-- >>> apps/erp/database/packages/erp_gen_persona_reg.pkb
create or replace package body erp_gen_persona_reg
as

    function calcular_dv_ruc (
        i_numero  in varchar2
    ) return varchar2 is
        c_base_max  constant pls_integer := 11;
        v_numero    varchar2(100) := upper(trim(i_numero));
        v_digitos   varchar2(400);
        v_caracter  varchar2(1);
        v_total     pls_integer := 0;
        v_k         pls_integer := 2;
        v_resto     pls_integer;
    begin
        if v_numero is null then
            return null;
        end if;
        for i in 1 .. length(v_numero) loop
            v_caracter := substr(v_numero, i, 1);
            v_digitos  := v_digitos || case when v_caracter between '0' and '9'
                                            then v_caracter
                                            else to_char(ascii(v_caracter)) end;
        end loop;
        for i in reverse 1 .. length(v_digitos) loop
            if v_k > c_base_max then
                v_k := 2;
            end if;
            v_total := v_total + to_number(substr(v_digitos, i, 1)) * v_k;
            v_k     := v_k + 1;
        end loop;
        v_resto := mod(v_total, 11);
        return case when v_resto > 1 then to_char(11 - v_resto) else '0' end;
    end calcular_dv_ruc;

    procedure aplicar_formato_documento (
        io_nro_documento  in out nocopy varchar2,
        io_dv             in out nocopy varchar2
    ) is
    begin
        io_nro_documento := upper(replace(replace(trim(io_nro_documento), '.', ''), ' ', ''));
        io_dv            := trim(io_dv);
        if io_dv is null and instr(io_nro_documento, '-') > 0 then
            io_dv            := substr(io_nro_documento, instr(io_nro_documento, '-', -1) + 1);
            io_nro_documento := substr(io_nro_documento, 1, instr(io_nro_documento, '-', -1) - 1);
        end if;
    end aplicar_formato_documento;

    procedure validar_documento (
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type
    ) is
        r_tipo  erp_gen_tipo_doc_identidad%rowtype;
    begin
        begin
            select * into r_tipo
              from erp_gen_tipo_doc_identidad
             where tipo_doc_identidad_id = i_tipo_doc_identidad_id
               and estado = 'A';
        exception
            when no_data_found then
                raise_application_error(c_err_tipo_doc_invalido, 'El tipo de documento no existe o está inactivo.');
        end;

        if r_tipo.formato_regexp is not null
           and not regexp_like(i_nro_documento, r_tipo.formato_regexp) then
            raise_application_error(c_err_documento_formato,
                'El número de documento no tiene el formato esperado para ' || r_tipo.nombre || '.');
        end if;

        if r_tipo.tiene_dv = 'S' then
            if i_dv is null or i_dv <> calcular_dv_ruc(i_numero => i_nro_documento) then
                raise_application_error(c_err_dv_invalido,
                    'El dígito verificador no corresponde al número de ' || r_tipo.nombre || '.');
            end if;
        end if;
    end validar_documento;

end erp_gen_persona_reg;
/

-- >>> apps/erp/database/packages/erp_gen_parametro_api.pkb
create or replace package body erp_gen_parametro_api
as

    function obtener_texto (
        i_codigo      in varchar2,
        i_empresa_id  in number   default null,
        i_defecto     in varchar2 default null
    ) return varchar2 is
        r_parametro  erp_gen_parametro%rowtype;
    begin
        r_parametro := erp_gen_parametro_ctr.obtener(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        return coalesce(r_parametro.valor, i_defecto);
    end obtener_texto;

    function obtener_numero (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in number default null
    ) return number is
        v_valor  erp_gen_parametro.valor%type;
    begin
        v_valor := obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        if v_valor is null then
            return i_defecto;
        end if;
        return to_number(v_valor, '99999999999999999999D9999999999', 'nls_numeric_characters=''.,''');
    end obtener_numero;

    function obtener_fecha (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in date   default null
    ) return date is
        v_valor  erp_gen_parametro.valor%type;
    begin
        v_valor := obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        if v_valor is null then
            return i_defecto;
        end if;
        return to_date(v_valor, 'YYYY-MM-DD');
    end obtener_fecha;

    function obtener_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number      default null,
        i_defecto     in varchar2    default 'N'
    ) return varchar2 is
    begin
        return case upper(obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id, i_defecto => i_defecto))
                   when 'S' then 'S'
                   else 'N'
               end;
    end obtener_sn;

end erp_gen_parametro_api;
/

-- >>> apps/erp/database/packages/erp_gen_moneda_api.pkb
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

-- >>> apps/erp/database/packages/erp_gen_impuesto_api.pkb
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

-- >>> apps/erp/database/packages/erp_gen_periodo_api.pkb
create or replace package body erp_gen_periodo_api
as

    procedure validar_permiso (
        i_permiso     in varchar2,
        i_empresa_id  in number
    ) is
        v_usuario  varchar2(255) := sys_context('APEX$SESSION', 'APP_USER');
    begin
        if v_usuario is null then
            return;
        end if;
        if not adm_seg_seguridad_reg.tiene_permiso(i_username       => v_usuario,
                                                   i_permiso_codigo => i_permiso,
                                                   i_empresa_id     => i_empresa_id) then
            raise_application_error(c_err_sin_permiso, 'No tiene permiso para realizar esta acción sobre el período.');
        end if;
    end validar_permiso;

    procedure cambiar_estado (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number,
        i_mes         in number,
        i_estado      in varchar2
    ) is
        r_periodo  erp_gen_periodo%rowtype;
    begin
        if i_mes is null or i_mes not between 1 and 12 then
            raise_application_error(c_err_mes_invalido, 'Indique el mes (1 a 12) del período.');
        end if;
        erp_gen_periodo_ctr.insertar(i_empresa_id => i_empresa_id, i_modulo => i_modulo,
                                     i_anio => i_anio, i_mes => i_mes, i_estado => 'A');
        r_periodo := erp_gen_periodo_ctr.obtener(i_empresa_id => i_empresa_id, i_modulo => i_modulo,
                                                 i_anio => i_anio, i_mes => i_mes);
        erp_gen_periodo_ctr.actualizar(
            i_periodo_id   => r_periodo.periodo_id,
            i_estado       => i_estado,
            i_fecha_cierre => case when i_estado = 'C' then systimestamp else r_periodo.fecha_cierre end,
            i_cerrado_por  => case when i_estado = 'C'
                                   then coalesce(sys_context('APEX$SESSION', 'APP_USER'), user)
                                   else r_periodo.cerrado_por end);
    end cambiar_estado;

    procedure validar_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) is
    begin
        erp_gen_periodo_reg.validar_abierto(i_empresa_id => i_empresa_id, i_modulo => i_modulo, i_fecha => i_fecha);
    end validar_abierto;

    function es_abierto_sn (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) return varchar2 is
    begin
        return case when erp_gen_periodo_reg.es_abierto(i_empresa_id => i_empresa_id, i_modulo => i_modulo, i_fecha => i_fecha)
                    then 'S' else 'N' end;
    end es_abierto_sn;

    procedure crear_anio (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number
    ) is
    begin
        validar_permiso(i_permiso => 'ERP_GEN_PERIODO_CERRAR', i_empresa_id => i_empresa_id);
        for v_mes in 1 .. 12 loop
            erp_gen_periodo_ctr.insertar(i_empresa_id => i_empresa_id, i_modulo => i_modulo,
                                         i_anio => i_anio, i_mes => v_mes, i_estado => 'A');
        end loop;
    end crear_anio;

    procedure cerrar (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number,
        i_mes         in number
    ) is
    begin
        validar_permiso(i_permiso => 'ERP_GEN_PERIODO_CERRAR', i_empresa_id => i_empresa_id);
        cambiar_estado(i_empresa_id => i_empresa_id, i_modulo => i_modulo, i_anio => i_anio, i_mes => i_mes, i_estado => 'C');
    end cerrar;

    procedure reabrir (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number,
        i_mes         in number
    ) is
    begin
        validar_permiso(i_permiso => 'ERP_GEN_PERIODO_REABRIR', i_empresa_id => i_empresa_id);
        cambiar_estado(i_empresa_id => i_empresa_id, i_modulo => i_modulo, i_anio => i_anio, i_mes => i_mes, i_estado => 'A');
    end reabrir;

end erp_gen_periodo_api;
/

-- >>> apps/erp/database/packages/erp_gen_persona_api.pkb
create or replace package body erp_gen_persona_api
as

    -- Arma, normaliza y valida el registro antes de insertar/actualizar.
    function preparar (
        i_persona_id             in number,
        i_tipo_persona           in varchar2,
        i_tipo_doc_identidad_id  in number,
        i_nro_documento          in varchar2,
        i_dv                     in varchar2,
        i_razon_social           in varchar2,
        i_nombres                in varchar2,
        i_apellidos              in varchar2,
        i_nombre_fantasia        in varchar2,
        i_es_contribuyente       in varchar2,
        i_pais_id                in number,
        i_fecha_nacimiento       in date,
        i_email                  in varchar2,
        i_telefono               in varchar2,
        i_observacion            in varchar2,
        i_estado                 in varchar2
    ) return erp_gen_persona%rowtype is
        r_persona  erp_gen_persona%rowtype;
    begin
        r_persona.persona_id            := i_persona_id;
        r_persona.tipo_persona          := i_tipo_persona;
        r_persona.tipo_doc_identidad_id := i_tipo_doc_identidad_id;
        r_persona.nro_documento         := i_nro_documento;
        r_persona.dv                    := i_dv;
        r_persona.nombres               := trim(i_nombres);
        r_persona.apellidos             := trim(i_apellidos);
        r_persona.razon_social          := coalesce(trim(i_razon_social),
                                                    trim(r_persona.nombres || ' ' || r_persona.apellidos));
        r_persona.nombre_fantasia       := trim(i_nombre_fantasia);
        r_persona.es_contribuyente      := coalesce(i_es_contribuyente, 'N');
        r_persona.pais_id               := i_pais_id;
        r_persona.fecha_nacimiento      := i_fecha_nacimiento;
        r_persona.email                 := lower(trim(i_email));
        r_persona.telefono              := trim(i_telefono);
        r_persona.observacion           := i_observacion;
        r_persona.estado                := coalesce(i_estado, 'A');

        erp_gen_persona_reg.aplicar_formato_documento(io_nro_documento => r_persona.nro_documento,
                                                      io_dv            => r_persona.dv);
        erp_gen_persona_reg.validar_documento(i_tipo_doc_identidad_id => r_persona.tipo_doc_identidad_id,
                                              i_nro_documento         => r_persona.nro_documento,
                                              i_dv                    => r_persona.dv);
        return r_persona;
    end preparar;

    procedure crear (
        i_tipo_persona           in  erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in  erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in  erp_gen_persona.nro_documento%type,
        i_dv                     in  erp_gen_persona.dv%type,
        i_razon_social           in  erp_gen_persona.razon_social%type,
        i_nombres                in  erp_gen_persona.nombres%type,
        i_apellidos              in  erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in  erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in  erp_gen_persona.es_contribuyente%type,
        i_pais_id                in  erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in  erp_gen_persona.fecha_nacimiento%type,
        i_email                  in  erp_gen_persona.email%type,
        i_telefono               in  erp_gen_persona.telefono%type,
        i_observacion            in  erp_gen_persona.observacion%type,
        i_estado                 in  erp_gen_persona.estado%type,
        o_persona_id             out erp_gen_persona.persona_id%type
    ) is
    begin
        erp_gen_persona_ctr.insertar(
            i_persona    => preparar(
                                i_persona_id            => null,
                                i_tipo_persona          => i_tipo_persona,
                                i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                                i_nro_documento         => i_nro_documento,
                                i_dv                    => i_dv,
                                i_razon_social          => i_razon_social,
                                i_nombres               => i_nombres,
                                i_apellidos             => i_apellidos,
                                i_nombre_fantasia       => i_nombre_fantasia,
                                i_es_contribuyente      => i_es_contribuyente,
                                i_pais_id               => i_pais_id,
                                i_fecha_nacimiento      => i_fecha_nacimiento,
                                i_email                 => i_email,
                                i_telefono              => i_telefono,
                                i_observacion           => i_observacion,
                                i_estado                => i_estado),
            o_persona_id => o_persona_id);
    end crear;

    procedure modificar (
        i_persona_id             in erp_gen_persona.persona_id%type,
        i_tipo_persona           in erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type,
        i_razon_social           in erp_gen_persona.razon_social%type,
        i_nombres                in erp_gen_persona.nombres%type,
        i_apellidos              in erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in erp_gen_persona.es_contribuyente%type,
        i_pais_id                in erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in erp_gen_persona.fecha_nacimiento%type,
        i_email                  in erp_gen_persona.email%type,
        i_telefono               in erp_gen_persona.telefono%type,
        i_observacion            in erp_gen_persona.observacion%type,
        i_estado                 in erp_gen_persona.estado%type
    ) is
    begin
        erp_gen_persona_ctr.actualizar(
            i_persona => preparar(
                             i_persona_id            => i_persona_id,
                             i_tipo_persona          => i_tipo_persona,
                             i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                             i_nro_documento         => i_nro_documento,
                             i_dv                    => i_dv,
                             i_razon_social          => i_razon_social,
                             i_nombres               => i_nombres,
                             i_apellidos             => i_apellidos,
                             i_nombre_fantasia       => i_nombre_fantasia,
                             i_es_contribuyente      => i_es_contribuyente,
                             i_pais_id               => i_pais_id,
                             i_fecha_nacimiento      => i_fecha_nacimiento,
                             i_email                 => i_email,
                             i_telefono              => i_telefono,
                             i_observacion           => i_observacion,
                             i_estado                => i_estado));
    end modificar;

    procedure validar_documento (
        i_tipo_doc_identidad_id  in number,
        i_nro_documento          in varchar2,
        i_dv                     in varchar2
    ) is
    begin
        erp_gen_persona_reg.validar_documento(i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                                              i_nro_documento         => i_nro_documento,
                                              i_dv                    => i_dv);
    end validar_documento;

    function obtener_dv_ruc (
        i_numero  in varchar2
    ) return varchar2 is
    begin
        return erp_gen_persona_reg.calcular_dv_ruc(i_numero => i_numero);
    end obtener_dv_ruc;

end erp_gen_persona_api;
/

-- >>> apps/erp/database/packages/erp_gen_funcionalidad_api.pkb
create or replace package body erp_gen_funcionalidad_api
as

    function es_activa_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number
    ) return varchar2 is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from erp_gen_funcionalidad f
          join erp_gen_empresa_func ef on ef.funcionalidad_id = f.funcionalidad_id
         where f.codigo      = upper(i_codigo)
           and f.estado      = 'A'
           and ef.empresa_id = i_empresa_id
           and ef.estado     = 'A';
        return case when v_cantidad > 0 then 'S' else 'N' end;
    end es_activa_sn;

    procedure crear_desde_rubro (
        i_empresa_id  in number
    ) is
    begin
        for r in (select rf.funcionalidad_id
                    from erp_gen_empresa_config ec
                    join erp_gen_rubro_func rf on rf.rubro_id = ec.rubro_id
                   where ec.empresa_id = i_empresa_id) loop
            erp_gen_empresa_func_ctr.insertar(i_empresa_id => i_empresa_id, i_funcionalidad_id => r.funcionalidad_id);
        end loop;
    end crear_desde_rubro;

end erp_gen_funcionalidad_api;
/
