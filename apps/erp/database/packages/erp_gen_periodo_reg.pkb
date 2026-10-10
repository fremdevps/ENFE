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
