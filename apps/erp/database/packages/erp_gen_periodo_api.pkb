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
