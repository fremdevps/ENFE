create or replace package body erp_stk_comun_utl
as

    g_usuario  varchar2(100);

    function obtener_usuario return varchar2 is
    begin
        return coalesce(sys_context('APEX$SESSION', 'APP_USER'), g_usuario);
    end obtener_usuario;

    function obtener_usuario_auditoria return varchar2 is
    begin
        return coalesce(obtener_usuario, user);
    end obtener_usuario_auditoria;

    procedure asignar_usuario (
        i_username  in varchar2
    ) is
    begin
        g_usuario := upper(trim(i_username));
    end asignar_usuario;

    procedure validar_permiso (
        i_permiso     in varchar2,
        i_empresa_id  in number
    ) is
        v_usuario  varchar2(255) := obtener_usuario;
    begin
        if v_usuario is null then
            return;
        end if;
        if not adm_seg_seguridad_reg.tiene_permiso(i_username       => v_usuario,
                                                   i_permiso_codigo => i_permiso,
                                                   i_empresa_id     => i_empresa_id) then
            raise_application_error(c_err_sin_permiso, 'No tiene permiso para realizar esta acción en Inventario.');
        end if;
    end validar_permiso;

end erp_stk_comun_utl;
/
